#!/bin/sh

if [ ! "${CLOUD_SHELL}" = true ] ; then
    echo "This script needs to run on Google Cloud Shell. Exiting ..."
    exit 1
fi

if [ "${#}" -ne 3 ]; then
    echo "Illegal number of parameters. Exiting..."
    echo "Usage: ${0} <gcp_project> <gcp_region> <data_bucket>"
    echo "Exiting..."
    exit 1
fi
GCP_PROJECT=$1
GCP_REGION=$2
BUCKET=$3
ICEBERG_CATALOG="iceberg_catalog"

gcloud dataproc batches submit pyspark migrate_to_iceberg.py \
    --region=${GCP_REGION} \
    --project=${GCP_PROJECT} \
    --version=2.3 \
    --deps-bucket=gs://${GCP_PROJECT}-staging \
    --subnet=projects/${GCP_PROJECT}/regions/${GCP_REGION}/subnetworks/dataproc-serverless-subnet \
    --properties="spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,\
spark.sql.defaultCatalog=${ICEBERG_CATALOG},\
spark.sql.catalog.${ICEBERG_CATALOG}=org.apache.iceberg.spark.SparkCatalog,\
spark.sql.catalog.${ICEBERG_CATALOG}.catalog-impl=org.apache.iceberg.gcp.bigquery.BigQueryMetastoreCatalog,\
spark.sql.catalog.${ICEBERG_CATALOG}.gcp_project=${GCP_PROJECT},\
spark.sql.catalog.${ICEBERG_CATALOG}.gcp_location=${REGION},\
spark.sql.catalog.${ICEBERG_CATALOG}.warehouse=gs://${BUCKET}/${ICEBERG_CATALOG}" \
     -- $BUCKET $ICEBERG_CATALOG