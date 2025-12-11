#!/bin/sh

export TERRAFORM_BIN=`which terraform`
ERROR_EXIT=1

# Capture input variables
if [ "${#}" -ne 3 ]; then
    echo "Illegal number of parameters. Exiting..."
    echo "Usage: ${0} <gcp_project_id> <gcp_region> <gcp_zone>"
    echo "Exiting ..."
    exit ${ERROR_EXIT}
fi
export GCP_PROJECT_ID=${1}
export GCP_REGION=${2}
export GCP_ZONE=${3}
export GCP_PROJECT_NUMBER=$(gcloud projects describe --format="value(projectNumber)" ${GCP_PROJECT_ID})

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Launching Terraform ..."

"${TERRAFORM_BIN}" init
if [ ! "${?}" -eq 0 ]; then
    LOG_DATE=`date`
    echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} init -reconfigure. Exiting..."
fi

"${TERRAFORM_BIN}" validate 
if [ ! "${?}" -eq 0 ]; then
    LOG_DATE=`date`
    echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} validate. Exiting..."
fi

"${TERRAFORM_BIN}" apply \
    -var="project_id=${GCP_PROJECT_ID}" \
    -var="region=${GCP_REGION}" \
    -var="zone=${GCP_ZONE}" \
    -var="project_number=${GCP_PROJECT_NUMBER}" \
    --auto-approve
if [ ! "${?}" -eq 0 ]; then
    LOG_DATE=`date`
    echo "${LOG_DATE} Unable to run ${TERRAFORM_BIN} apply. Exiting..."
fi 

LOG_DATE=`date`
echo "###########################################################################################"
echo "${LOG_DATE} Execution finished!"