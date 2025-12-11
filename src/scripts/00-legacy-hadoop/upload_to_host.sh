#!/bin/sh

if [ ! "${CLOUD_SHELL}" = true ] ; then
    echo "This script needs to run on Google Cloud Shell. Exiting ..."
    exit 1
fi

if [ "${#}" -ne 2 ]; then
    echo "Illegal number of parameters. Exiting..."
    echo "Usage: ${0} <gcp_project> <gcp_zone>"
    echo "Exiting..."
    exit 1
fi
GCP_PROJECT=$1
GCP_ZONE=$2

NODE_NAME="legacy-hadoop-cluster-m"

# Create compute engine ssh keys beforehand to allow first 'gcloud compute ssh' command to capture desired output
if [ ! -f ~/.ssh/google_compute_engine ]; then
    ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -C google_compute_engine -b 2048 -q -N ""
fi

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Uploading scripts to master node ${NODE_NAME} ..."
REMOTE_HOME=`gcloud compute ssh ${NODE_NAME} --project=${GCP_PROJECT} --zone=${GCP_ZONE} --tunnel-through-iap --command="pwd"`

gcloud compute scp * ${NODE_NAME}:${REMOTE_HOME}  --project=${GCP_PROJECT} --zone ${GCP_ZONE} --tunnel-through-iap 

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Uploading scripts to master node ${NODE_NAME} finished. Check output for results."
