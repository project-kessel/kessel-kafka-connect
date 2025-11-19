# Kessel Kafka Connect

A dedicated Kafka Connect image to be leveraged with Streams for Apache Kafka

Currently the Connect image only contains the Debezium connector for PostgreSQL, any other connectors or plugins/libs required would need to be added in the future.

Plugins are installed using the [docker-maven-download](https://github.com/debezium/container-images/blob/main/connect-base/2.7/docker-maven-download.sh) script provided by Debezium's container-images repo and is useful for installing other plugins and libs. Review the script for more information on how to use it.

# Kafka Connectors Legend

Here are the current list of Kafka Connectors managed by the Fabric Kessel team which are deployed via this repo

|Connector Name|Deploy File|Service Provider|Purpose|
|--------------|-----------|----------------|-------|
|kessel-inventory-api-connector|[kafkaconnect-w-auth.yml](./deploy/kafkaconnect-w-auth.yml)|Kessel|Used to capture all outbox events from the Inventory API DB outbox table for Relations replication|
|hbi-migration-connector|[hbi-hosts-migration-connector.yml](./deploy/sp-connectors/hbi-hosts-migration-connector.yml)|HBI|Used to perform an initial migration from HBI's `hosts` table|
|hbi-outbox-connector|[hbi-outbox-connector.yml](./deploy/sp-connectors/hbi-outbox-connector.yml)|HBI|Used to capture all outbox events from HBI's DB outbox table for replication|


### To Build Container Image:

_Linux/Windows_
```shell
export IMAGE=your-quay-repo
make docker-build-push
```

_MacOS_

```shell
export QUAY_REPO_INVENTORY=your-quay-repo # required
podman login quay.io # required, this target assumes you are already logged in
make build-push-minimal
```

### Kafka Connect Deployment
The KafkaConnect CR templates can be used to deploy a Kafka Connect cluster using the image built with the provided Dockerfile. There are 3 versions of the KafkaConnect CR: one with authentication, one without, and one for FedRAMP

The `kafkaconnect-no-auth.yml` template is useful for Ephemeral testing, where the Clowder-provided Kafka cluster can be used for the Connect cluster and does not require any authentication. In ephemeral, by default Kessel Inventory API ships with Kessel Kafka Connect and can be deployed that way.

The `kafkaconnect-w-auth.yml` template is used for Stage/Prod and relies on AWS MSK. It is configured with SASL/SCRAM and requires credentials to authenticate to the cluster. In order to authenticate, you will need a Kakfa user configured for the MSK cluster. See the **Managed Streaming for Apache Kafka (MSK) via App-Interface** section of the App Interface docs on how to add users. Note, the Inventory API Debezium Connector is also deployed as part of this manifest

The final template, `kafka-connect-fedramp.yml`, is similar to the `kafkaconnect-w-auth.yml` deploy file but is designed for FedRAMP and leveraging a Strimzi Kafka cluster vs MSK.

#### Using the Templates

To use the templates in your existing deployment template, copy the contents of the template to your existing template, and add the parameters to your existing parameter section in your deploy templates

To use the templates directly:

**Without Auth**
```shell
oc process --local -f deploy/kafkaconnect-no-auth.yml \
    -p BOOTSTRAP_SERVERS=<Bootstrap Server Address> | oc apply -f -
```

> [!NOTE]
> Any parameters defined in the template can be overwritten with `-p PARAM=VALUE` if desired.
>
> Ephemeral Kafka clusters are not configured with Auth enabled, testing auth in Ephemeral would require a separate Kafka cluster.

**With Auth**
```shell
oc process --local -f deploy/kafkaconnect-w-auth.yml \
    -p BOOTSTRAP_SERVERS=<Bootstrap Server Address> \
    -p KAFKA_USERNAME=<Kafka Username> \
    -p KAFKA_USER_SECRET_NAME=<Name of Kafka Secret> \
    -p KAFKA_USER_SECRET_KEY=<Key in Secret where password is defined> | oc apply -f -
```
