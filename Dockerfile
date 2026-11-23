# Leverages Streams for Apache Kafka Images
# Streams for Apache Kafka 2.9 is based on Apache Kafka 3.9.0 and Strimzi 0.45.x.
FROM registry.redhat.io/amq-streams/kafka-39-rhel9:2.9.4-27
USER root:root

# The build runs without network access. The Debezium artifacts are pinned in
# artifacts.lock.yaml. Hermeto prefetches them, verifies their checksums, and
# mounts them at /cachi2/output (Konflux does this in CI; `make docker-build-push`
# does it locally).
ARG DEPS_DIR=/cachi2/output/deps/generic

ENV KAFKA_CONNECT_PLUGINS_DIR=/opt/kafka/plugins \
    EXTERNAL_LIBS_DIR=/opt/kafka/libs

RUN rm -rf /opt/kafka-exporter

RUN mkdir -p "$KAFKA_CONNECT_PLUGINS_DIR" "$EXTERNAL_LIBS_DIR" && \
    tar -xzf "${DEPS_DIR}/debezium-connector-postgres-plugin.tar.gz" -C "$KAFKA_CONNECT_PLUGINS_DIR" && \
    tar -xzf "${DEPS_DIR}/debezium-scripting.tar.gz" -C "$EXTERNAL_LIBS_DIR"

USER 1001
