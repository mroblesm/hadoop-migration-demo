# 1. Migrate data from HDFS to GCS using STS

This step uses [Storage Transfer Service](https://docs.cloud.google.com/storage-transfer/docs/create-transfers/agent-based/hdfs) to set up a regular data transfer job from HDFS in legacy Hadoop cluster to a bucket in Google Cloud Storage.

The main steps involved are:

**1. STS Agent & Agent Pool**

First, let's create a STS Agent Pool that will contain the transfer agent.

```console
export AGENT_POOL="legacy-migration-pool"
gcloud transfer agent-pools create $AGENT_POOL \
    --display-name="Legacy Hadoop Migration Pool"
```

Secondly, install the Agent in the Source Cluster and register it in the Agent pool. These steps need to be executed from the Hadoop master node.

```console
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap
sudo apt-get update
sudo apt-get install -y docker.io

AGENT_POOL="legacy-migration-pool"
PROJECT_ID=$(gcloud config get-value project)
MASTER_IP=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" -H "Metadata-Flavor: Google")
SOURCE_NAMENODE_URI="${MASTER_IP}:8020"

sudo gcloud transfer agents install \
  --pool=${AGENT_POOL} \
  --id-prefix=machine1 \
  --mount-directories=/data \
  --hdfs-namenode-uri="${SOURCE_NAMENODE_URI}" \
  --hdfs-username=root
```

Navigate to the STS page in Cloud console, to verify the Agent is up & running (green state) in the Agent pool, ready to use.

**2. STS Transfer job**

Lastly, a STS transfer job is created to periodically copy data from source to destination. These steps can be executed directly from Cloud Shell:

```
# Configuration
JOB_NAME="hdfs-to-gcs-migration"
DATA_BUCKET=$(terraform output -raw data_bucket)

# Create the Transfer Job
sudo gcloud transfer jobs create hdfs:///data gs://${DATA_BUCKET}/data/ \
    --name=${JOB_NAME} \
    --source-agent-pool=${AGENT_POOL}}$ \
    --overwrite-when=different
```

Navigate to GCP Console to verify the STS Tranfer job was created and executed successfully, after which you should see data is now available in the data GCS bucket.

# Alternative approach

If you encounter any issue setting up STS, alternatively in order to continue with the demo you can use Hadoop Distcp (Dataproc images are already configured with GCS connector):
```
cd src/terraform
DATA_BUCKET=$(terraform output data_bucket)
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap \
    --command="hadoop distcp -overwrite -delete /data/customers/* gs://${DATA_BUCKET}/data/customers"
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap \
    --command="hadoop distcp -overwrite -delete /data/transactions/* gs://${DATA_BUCKET}/data/transactions"
```
