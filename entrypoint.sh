#!/usr/bin/env bash
set -euo pipefail

# Apply SPARK_DRIVER_MEMORY (spark-defaults.conf cannot read environment variables).
CONF="${SPARK_HOME}/conf/spark-defaults.conf"
sed -i '/^spark\.driver\.memory/d' "${CONF}"
echo "spark.driver.memory               ${SPARK_DRIVER_MEMORY:-2g}" >> "${CONF}"

# Only needed if someone overrides the container user to root.
ROOT_FLAG=""
if [ "$(id -u)" = "0" ]; then
  ROOT_FLAG="--allow-root"
fi

echo "──────────────────────────────────────────────────────────"
echo " Apache Spark ${SPARK_VERSION} + Iceberg + JupyterLab"
echo " JupyterLab  → http://localhost:${JUPYTER_HOST_PORT:-8888}"
echo " Spark UI    → http://localhost:4040 (while a session is active)"
echo " Driver mem  → ${SPARK_DRIVER_MEMORY:-2g}"
echo "──────────────────────────────────────────────────────────"

# shellcheck disable=SC2086
exec jupyter lab \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT:-8888}" \
    --no-browser \
    ${ROOT_FLAG} \
    --IdentityProvider.token="${JUPYTER_TOKEN:-}" \
    --ServerApp.root_dir="${HOME}/work" \
    "$@"
