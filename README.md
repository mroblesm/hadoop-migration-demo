# Legacy Hadoop migration to Google Cloud DataLake

## Introduction

This repository contains a step by step demo that showcase how to migrate from legacy Hadoop data platform with Spark, Hive and Ranger to a Google Cloud modern DataLake.

In detail the demo covers the following areas:

1. Migration of data from HDFS to GCS, and different options for the migration (Cloud Storage, BigLake, Storage Transfer Service)
2. Migration of Hive tables and SQL workloads (BigQuery, BigLake)
3. Migration of Spark workloads (Dataproc, Google Cloud Serverless for Apache Spark)
4. Migration of permissions & access policies (Cloud IAM, BigQuery FGAC)

## Architecture

![Architecture](assets/hadoop_migration.png)

## Installation

The deployment uses Terraform to provision all necessary resources, and several scripts and notebooks to execute each step of the demo.
From a [Google Cloud Cloud Shell](https://cloud.google.com/shell) terminal logged as your admin user, execute the instructions below.

On the top of the Google Cloud console, ensure an existing project is selected. Start by running the following command, replacing project, region and zone values:

```console
gcloud config set project [YOUR-PROJECT-ID]
REGION=[YOUR-REGION]
ZONE=[YOUR-ZONE]
```

This repository provisions several GCP components:

* A Dataproc cluster on GCE to emulate the source legacy Hadoop cluster, using HDFS, Hive, Spark and Ranger, and associated required resources (GCS bucket to store logs for Dataproc clusters, KMS keyring, key and GCS bucket to encrypt and store password for Ranger)
* A VPC `vpc-main` and subnet `spark-subnet` for Spark workloads
* A GCS bucket to store data and metadata
* A BigLake connection to enable access to GCS data from BigQuery
* A service account to run spark workloads

To start the basic infrastructure provisioning:

```console
git clone https://github.com/mroblesm/hadoop-migration-demo.git
cd hadoop-migration-demo/src/terraform
source ./launcher.sh ${GOOGLE_CLOUD_PROJECT} ${REGION} ${ZONE}
```
(following commands assume execution from the root repository directory)

A successful execution will have created a 'legacy-hadoop-cluster' in Dataproc. Next steps provision the content to migrate.

* Run this to upload required scripts to master node
```console
cd src/scripts/00-legacy-hadoop
source upload_to_host.sh ${GOOGLE_CLOUD_PROJECT} ${ZONE}
```

* The following spark job creates 2 Hive external tables with dummy data in HDFS (under /data path): customers, transactions.
```console
cd ../../terraform
CODE_BUCKET=$(terraform output -raw code_bucket)
LEGACY_CLUSTER_NAME=$(terraform output -raw legacy_hadoop_cluster)
gcloud dataproc jobs submit pyspark \
    gs://${CODE_BUCKET}/01-generate-data.py \
    --cluster=${LEGACY_CLUSTER_NAME}  \
    --region=${REGION}
```
* Once the job finishes (it should take about 30-60 seconds), you can verify the data exists in HDFS:
```console
MASTER_NODE=${LEGACY_CLUSTER_NAME}-m
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap  \
    --command="hdfs dfs -ls -R /data/"
```

You should see:
```
/data/customers/_SUCCESS
/data/customers/part-xxxxx.snappy.parquet
/data/transactions/_SUCCESS
/data/transactions/part-xxxxx.snappy.parquet
```

The tables `customers` and `transactions` should also be visible under schema `datalake_demo` in Hive:.
```console
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap \
    --command="beeline -u \"jdbc:hive2://localhost:10000/datalake_demo\" -n root -e 'SHOW TABLES;'"
```

* Next, lets create Users & permissions in legacy cluster.
```console
RANGER_PWD=$(terraform output -raw ranger_pwd_clear)
cd ../scripts/00-legacy-hadoop
source setup_users_policies.sh ${GOOGLE_CLOUD_PROJECT} ${ZONE} ${MASTER_NODE} ${RANGER_PWD}
```
After successful execution:
* 2 users and groups are created: analyst_us, analyst_eu
* Following Ranger policies are set up: 
  * Allow select on all tables for analysts
  * Row Level Filter (user analyst_eu can only see rows with region=EU in transactions table)
  * Masking Policy (Mask PII email in customers table)
Verify users and policies are in effect using beeline from Master node
```console
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap \
    --command="beeline -u \"jdbc:hive2://localhost:10000/datalake_demo\" -n analyst_eu -e 'SELECT region, count(*) FROM transactions GROUP BY region;'"
```
You should see only data for EU:
```
+---------+---------+
| region  |   _c1   |
+---------+---------+
| EU      | 166747  |
+---------+---------+
```
If you see a permissions error, run this command from the master node and try again:
```
sudo hdfs dfs -chmod  a+w /hadoop/tmp/hive/user-install-dir
```

## Step by step demo

[1. Migrate data from HDFS to GCS using STS](assets/01_migrate_data.md)

[2. Enable SQL consumption from BigQuery using BigLake](assets/02_bq_biglake.md)

[3. Run Spark job using Google Cloud Serverless for Spark Batch](assets/03_spark.md)

[4. Interactive session in Colab Enterprise Notebook](assets/04_notebook.md)

[5. Permissions and Policies migration](assets/05_permissions.md)

[6. Migrating to Iceberg tables and BigLake Metastore](assets/06_iceberg.md)

Finally, to clean up the resources created:
```console
cd hadoop-migration-demo/src/terraform
source ./destroyer.sh ${GOOGLE_CLOUD_PROJECT} ${REGION} ${ZONE}
```
