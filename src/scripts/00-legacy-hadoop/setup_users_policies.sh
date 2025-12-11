#!/bin/sh

if [ ! "${CLOUD_SHELL}" = true ] ; then
    echo "This script needs to run on Google Cloud Shell. Exiting ..."
    exit 1
fi

if [ "${#}" -ne 3 ]; then
    echo "Illegal number of parameters. Exiting..."
    echo "Usage: ${0} <gcp_project> <gcp_zone> <hadoop_master_node>"
    echo "Exiting..."
    exit 1
fi
GCP_PROJECT=$1
GCP_ZONE=$2
NODE_NAME=$3

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Setting up users & Ranger policies  ..."

gcloud compute ssh ${NODE_NAME} --project=${GCP_PROJECT} --zone ${GCP_ZONE} --tunnel-through-iap --command="source 02-setup-users.sh"

LOG_DATE=`date`
echo "${LOG_DATE} Setting up users & Ranger policies  finished. Check output for results."
