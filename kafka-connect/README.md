# Kafka Connect Resources

This directory contains the OpenShift templates and Containerfile needed to build and deploy a KafkaConnect cluster using the Streams for Apache Kafka operator from Red Hat

### Kafka Connect Image

The included Containerfile can be used to build the Kafka Connect image needed to spin up a Kafka Connect cluster using Streams for Apache Kafka. It can be built using podman or docker and can also be built via AppSRE/Konflux image build processes. Currently, the Connect image only contains the Debezium connector for PostgreSQL, any other connectors or plugins/libs required would need to be added in your own fork of the Containerfile.

Plugins are installed using the [docker-maven-download](https://github.com/debezium/container-images/blob/main/connect-base/2.7/docker-maven-download.sh) script provided by Debezium's container-images repo and is useful for installing other plugins and libs. Review the script for more information on how to use it.

To build the image locally:

`podman build -t quay.io/<YOUR-REPOSITORY>/<SERVICE_NAME>-kafka-connect -f Containerfile`


### Kafka Connect Deployment
The KafkaConnect CR templates can be used to deploy a Kafka Connect cluster using the image built with the provided Containerfile. The template is designed to allow for multiple service providers to use the same template while avoiding name duplication as these Connect clusters will likely live in the same namespace

There are 2 versions of the KafkaConnect CR: one with authentication, one without

The `kafkaconnect-no-auth.yml` template is useful for Ephemeral, where the Clowder-provided Kafka cluster can be used for the Connect cluster and does not require any authentication.

The `kafkaconnect-w-auth.yml` template is useful for adding to your deployment file for targeting stage/production environments where MSK is likely used and is configured with SASL/SCRAM. In order to authenticate, you will need a Kakfa user configured for the MSK cluster. See the **Managed Streaming for Apache Kafka (MSK) via App-Interface** section of the App Interface docs on how to add users.

// TODO for above, more detailed data should be set in internal docs of some sort so we can link to App Interface perhaps
// Possibly should cover when Kafka versions in general, when does the base image version need to change, etc

#### Using the Templates

To use the templates in your existing deployment template, copy the contents of the template to your existing template, and add the parameters to your existing parameter section in your deploy templates

To use the templates directly:

**Without Auth**
```shell
oc process --local -f kafka-connect/kafkaconnect-w-auth.yml \
    -p SERVICE_NAME=<Name of Service Providers Service> \
    -p BOOTSTRAP_SERVERS=<Bootstrap Server Address> \
    -p KAFKA_CONNECT_IMAGE=<Kafka Connect image name and tag> \
    -p VERSION=<Kafka Version> | oc apply -f -
```

> [!NOTE]
> Any parameters defined in the template can be overwritten with `-p PARAM=VALUE` if desired.
>
> Ephemeral Kafka clusters are not configured with Auth enabled, testing auth in Ephemeral would require a separeate Kafka cluster.

**With Auth**
```shell
oc process --local -f kafka-connect/kafkaconnect-w-auth.yml \
    -p SERVICE_NAME=<Name of Service Providers Service> \
    -p BOOTSTRAP_SERVERS=<Bootstrap Server Address> \
    -p KAFKA_USERNAME=<Kafka Username> \
    -p KAFKA_USER_SECRET_NAME=<Name of Kafka Secret> \
    -p KAFKA_USER_SECRET_KEY=<Key in Secret where password is defined> \
    -p KAFKA_CONNECT_IMAGE=<Kafka Connect image name and tag>  \
    -p VERSION=<Kafka Version> | oc apply -f -
```
