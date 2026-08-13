# Leverages Streams for Apache Kafka Images
# Streams for Apache Kafka 2.9 is based on Apache Kafka 3.9.0 and Strimzi 0.45.x.
FROM registry.redhat.io/amq-streams/kafka-39-rhel9:2.9.4-15
USER root:root

# DEBEZIUM_MAVEN_VERSION = Maven package version (x.x.x.Final)
#   https://mvnrepository.com/artifact/io.debezium/debezium-connector-postgres
# When upgrading, update the SHA-256 digests below to match the new artifacts.

ENV KAFKA_CONNECT_PLUGINS_DIR=/opt/kafka/plugins \
    EXTERNAL_LIBS_DIR=/opt/kafka/libs \
    DEBEZIUM_MAVEN_VERSION=3.1.3.Final \
    # To get updated digests after a version bump, run:
    #   curl -s https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/<version>/debezium-connector-postgres-<version>-plugin.tar.gz.sha256
    #   curl -s https://repo1.maven.org/maven2/io/debezium/debezium-scripting/<version>/debezium-scripting-<version>.tar.gz.sha256
    DEBEZIUM_CONNECTOR_POSTGRES_SHA256=2ed3f0b1dd3ee3b1180cc975e0464b675cca5f972db6a9ae3a75f5376874f652 \
    DEBEZIUM_SCRIPTING_SHA256=2c4053ffdcf18d0a73fc845c641c02026631ea8f598a5342741ad7b601c8251d

RUN rm -rf /opt/kafka-exporter

# Download Debezium connector plugins directly from Maven Central and verify each
# against the SHA-256 digest pinned above before extraction.
RUN mkdir -p "$KAFKA_CONNECT_PLUGINS_DIR" "$EXTERNAL_LIBS_DIR" && \
    curl -fsSL -o /tmp/connector-postgres.tar.gz \
        "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_MAVEN_VERSION}/debezium-connector-postgres-${DEBEZIUM_MAVEN_VERSION}-plugin.tar.gz" && \
    echo "${DEBEZIUM_CONNECTOR_POSTGRES_SHA256}  /tmp/connector-postgres.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/connector-postgres.tar.gz -C "$KAFKA_CONNECT_PLUGINS_DIR" && \
    rm /tmp/connector-postgres.tar.gz && \
    curl -fsSL -o /tmp/scripting.tar.gz \
        "https://repo1.maven.org/maven2/io/debezium/debezium-scripting/${DEBEZIUM_MAVEN_VERSION}/debezium-scripting-${DEBEZIUM_MAVEN_VERSION}.tar.gz" && \
    echo "${DEBEZIUM_SCRIPTING_SHA256}  /tmp/scripting.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/scripting.tar.gz -C "$EXTERNAL_LIBS_DIR" && \
    rm /tmp/scripting.tar.gz

USER 1001
