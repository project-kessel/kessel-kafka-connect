#!/bin/bash

readonly TEN_DAYS_IN_SECONDS=864000
EXPIRING=false

# Fetch the CA Cert
pushd /tmp
openssl s_client -showcerts -connect $KAFKA_BOOTSTRAP_SERVERS < /dev/null |
   awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="cert"a".pem"; print >out}'

for cert in *.pem; do
    cnname=$(openssl x509 -noout -subject -in $cert | sed -nE 's/.*CN ?= ?(.*)/\1/; s/[ ,.*]/_/g; s/__/_/g; s/_-_/-/; s/^_//g;p')
    if [[ "$cnname" = *"cluster-ca"* ]]; then
        mv "${cert}" cluster-ca.crt
    fi
done

CA_CERT=/tmp/cluster-ca.crt
CA_CERT_EXPIRATION=$(openssl x509 -noout -enddate -in $CA_CERT | cut -d'=' -f 2)

# 10 day check
openssl x509 -checkend $TEN_DAYS_IN_SECONDS -noout -in $CA_CERT
if [[ $? -ne 0 ]]; then
    EXPIRING=true
fi

if [[ "$EXPIRING" == "true" ]]; then
    MESSAGE='{"text":"ALERT: Kafka Cluster CA Cert Expiring within 10 days
    Cluster Name: platform-mq-'"${ENV}"'
    Expiration Date: '"${CA_CERT_EXPIRATION}"'\n
    Alert: Kafka Cluster CA Cert expiration is approaching. The CA Cert will automatically be rotated. Services that require the CA cert for trust must be updated for the new CA Cert when available"}
    '
    RESPONSE=$(curl -X POST -H "Content-Type: application/json" "$WEBHOOK_URL" -d $"$MESSAGE")
    if [[ $? -ne 0 ]]; then
        echo "Failed to send alert: $RESPONSE"
        exit 1
    fi
fi
