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

The `kafkaconnect-ephem.yml` template is used for Ephemeral testing and can be deployed via bonfire. Note, the Clowder-provided Kafka cluster is used for the Connect cluster and does not require any authentication. The deployment also includes the Kessel Inventory outbox connector, and HBI outbox connector to simplify test deployments for service providers as well as the Mgmt Fabric teams.

```shell
bonfire deploy kessel -C kessel-kafka-connect

# Kessel Inventory also lists KKC as a dependency and can be deployed automatically while deploying Inventory API
bonfire deploy kessel -C kessel-inventory
```

The `kafkaconnect-w-auth.yml` template is used for Stage/Prod and relies on AWS MSK. It is configured with SASL/SCRAM and requires credentials to authenticate to the cluster. In order to authenticate, you will need a Kakfa user configured for the MSK cluster. See the **Managed Streaming for Apache Kafka (MSK) via App-Interface** section of the App Interface docs on how to add users.

The final template, `kafka-connect-fedramp.yml`, is similar to the `kafkaconnect-w-auth.yml` deploy file but is designed for FedRAMP and leveraging a Strimzi Kafka cluster vs MSK.


#### Configuring Log Levels

Log levels for Kafka Connect and Debezium can be configured independently using template parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CONNECT_LOG_LEVEL` | `INFO` | Log level for Kafka Connect |
| `DEBEZIUM_LOG_LEVEL` | `INFO` | Log level for Debezium connectors |

Valid values: `INFO`, `DEBUG`, `TRACE`

#### Log Format with MDC

Logs include [Debezium MDC](https://debezium.io/documentation/reference/stable/operations/logging.html#adding-mapped-diagnostic-contexts) and Kafka Connect context for easier filtering:

```
2026-02-05 15:00:18,237 INFO  [Postgres|streaming] [kessel-inventory-source-connector|task-0] Processing messages [io.debezium...]
```

**Format:** `[connectorType|activity] [connectorName|taskId] message [loggerClass]`

**Filtering examples:**
```shell
# Filter by connector type
oc logs <pod> | grep "\[Postgres|"

# Filter by connector name
oc logs <pod> | grep "kessel-inventory-source-connector"

# Filter by activity (snapshot, streaming)
oc logs <pod> | grep "|streaming\]"
oc logs <pod> | grep "|snapshot\]"
```
