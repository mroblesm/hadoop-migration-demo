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

gcloud dataproc batches submit pyspark etl_serverless.py \
    --region=${GCP_REGION} \
    --version=2.3 \
    --deps-bucket=gs://${BUCKET} \
    --service-account=dataproc-sa@${GCP_PROJECT}.iam.gserviceaccount.com\
    --subnet=projects/${GCP_PROJECT}/regions/${GCP_REGION}/subnetworks/spark-subnet \
    -- "gs://$BUCKET"