# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Spark 4.1 + Iceberg + JupyterLab for local development.
# Multi-arch: nothing in this file names a CPU architecture, so the same file
# builds natively on Apple Silicon (arm64) and Intel (amd64).
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim-bookworm

ARG SPARK_VERSION=4.1.2
ARG SPARK_MINOR=4.1
ARG HADOOP_VERSION=3
# Iceberg 1.11.0 was the first release with Spark 4.1 support. Override at build
# time with: docker compose build --build-arg ICEBERG_VERSION=1.11.0
ARG ICEBERG_VERSION=1.12.0
ARG JAVA_VERSION=17
ARG NB_USER=spark
ARG NB_UID=1000

LABEL description="Apache Spark ${SPARK_VERSION} + Iceberg ${ICEBERG_VERSION} + JupyterLab"

ENV SPARK_VERSION=${SPARK_VERSION} \
    SPARK_HOME=/opt/spark \
    JAVA_HOME=/opt/java \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3 \
    HOME=/home/${NB_USER}
ENV PATH="${JAVA_HOME}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-${JAVA_VERSION}-jdk-headless wget curl ca-certificates procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Architecture-neutral JAVA_HOME ───────────────────────────────────────────
# ENV cannot run shell commands, so resolve the real JDK path here and expose it
# through a stable symlink (/opt/java) that is identical on arm64 and amd64.
RUN ln -s "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" /opt/java \
    && java -version

# ── Spark ────────────────────────────────────────────────────────────────────
# dlcdn only keeps current releases, so fall back to the permanent archive.
RUN set -eux; \
    f="spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"; \
    wget -q "https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/${f}" -O /tmp/spark.tgz \
      || wget -q "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${f}" -O /tmp/spark.tgz; \
    tar -xzf /tmp/spark.tgz -C /opt; \
    mv "/opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" "${SPARK_HOME}"; \
    rm /tmp/spark.tgz

# ── Iceberg JARs baked into Spark (no runtime Maven download, works offline) ─
#   iceberg-spark-runtime : Spark integration + REST catalog client
#   iceberg-aws-bundle    : S3FileIO and the AWS SDK it needs (used for MinIO)
RUN set -eux; \
    base=https://repo1.maven.org/maven2/org/apache/iceberg; \
    wget -q -P "${SPARK_HOME}/jars" \
      "${base}/iceberg-spark-runtime-${SPARK_MINOR}_2.13/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_MINOR}_2.13-${ICEBERG_VERSION}.jar" \
      "${base}/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar"

# ── Python packages ──────────────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir "pyspark==${SPARK_VERSION}" -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# ── Runtime user + config ────────────────────────────────────────────────────
# All COPY / chmod / chown steps happen BEFORE the USER switch.
RUN useradd --create-home --uid ${NB_UID} --shell /bin/bash ${NB_USER} \
    && mkdir -p /home/${NB_USER}/work /home/${NB_USER}/data /tmp/spark-local \
    && chown -R ${NB_USER}: /home/${NB_USER} /tmp/spark-local

COPY spark-defaults.conf ${SPARK_HOME}/conf/spark-defaults.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R ${NB_USER}: ${SPARK_HOME}/conf

USER ${NB_USER}
WORKDIR /home/${NB_USER}/work

# 8888 JupyterLab · 4040/4041 Spark UI
EXPOSE 8888 4040 4041
ENTRYPOINT ["/entrypoint.sh"]
