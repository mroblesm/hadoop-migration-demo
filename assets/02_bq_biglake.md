# 2. Enable SQL consumption from BigQuery using BigLake External tables

Once data is migrated, new BigLake external tables are defined to enable consumption from BigQuery, and HQL code is translated to BigQuery SQL.

## 2.1.- Creation of BigLake external tables

BigLake external tables point to data in GCS and use a BigLake connection for access mgmt. delegation.

First, a BigQuery dataset is created.
```console
DATASET="datalake_demo"
BQ_REGION=$(terraform output -raw bigquery_region)
bq --location=${BQ_REGION} mk \
    --dataset \
    ${GOOGLE_CLOUD_PROJECT}:${DATASET}
```

Below different approaches to create BigLake tables.

**A. Using bq**

More details in [public docs](https://docs.cloud.google.com/bigquery/docs/create-cloud-storage-table-biglake#create-table-storage).

First, table definition files for each table are created.
```console
BL_CONN=$(terraform output -raw biglake_connection)
DATA_BUCKET=$(terraform output -raw data_bucket)
bq mkdef --autodetect=true \
--connection_id=${BL_CONN} \
--source_format=PARQUET \
gs://${DATA_BUCKET}/data/customers/*.parquet > /tmp/customers_tabledef.json
bq mkdef --autodetect=true \
--connection_id=${BL_CONN} \
--source_format=PARQUET \
gs://${DATA_BUCKET}/data/transactions/*.parquet > /tmp/transactions_tabledef.json
```
Secondly, tables are created using the table definion files.
```
bq mk --table \
  --external_table_definition=/tmp/customers_tabledef.json \
  ${GOOGLE_CLOUD_PROJECT}:${DATASET}.customers
bq mk --table \
  --external_table_definition=/tmp/transactions_tabledef.json \
  ${GOOGLE_CLOUD_PROJECT}:${DATASET}.transactions
```

**B. Auto discover tables from GCS**

Dataplex Universal Catalog Automatic Discovery is a BigQuery feature to scan data in Cloud Storage buckets to extract and then catalog metadata. As part of the discovery scan, the job can create BigLake external tables for the migrated parquet tables in GCS.

Execute following code to create and run a discovery scan. Tables will be created in a new BigQuery dataset named as the origin GCS bucket.
```console
SCAN_ID="hive-tables-scan"
gcloud dataplex datascans create data-discovery $SCAN_ID \
    --project=$GOOGLE_CLOUD_PROJECT \
    --location=$REGION \
    --data-source-resource="//storage.googleapis.com/projects/${GOOGLE_CLOUD_PROJECT}/buckets/${DATA_BUCKET}" \
    --bigquery-publishing-connection="${BL_CONN}" \
    --bigquery-publishing-dataset-location="${BQ_REGION}" \
    --bigquery-publishing-dataset-project="projects/${GOOGLE_CLOUD_PROJECT}" \
    --bigquery-publishing-table-type="BIGLAKE" \
    --storage-include-patterns="data/customers/*.parquet,data/transactions/*.parquet" \
    --on-demand="ON_DEMAND"
gcloud dataplex datascans run $SCAN_ID \
  --location=$REGION
```

In Google Cloud console, navigate to BigQuery Governance > Metadata curation. Under Cloud Storage Discovery you will see the newly job created (`hive-tables-scan`). Click on the job name for details.
Under Scan History, you can see the job execution we just triggered. If you click on it you will see the number of files scanned and tables created by the job.
Navigate to the newly created dataset (name of the GCS bucket), and explore the created tables. You can differentiate these tables from the ones created in previous step, as a label "metadata-managed-mode : discovery_managed" indicates the tables are managed by a discovery job.

**C. Hive Managed tables migration**

BigQuery Migration Services supports [migration of Hive managed tables](https://docs.cloud.google.com/bigquery/docs/hdfs-data-lake-transfer). For Hive Managed tables, it is required to set up Dataproc Metastore. BQMS relies on STS for HDFS data transfer as described in previous step.

## 2.2.- Migration of SQL queries

Query translation from HIVE queries (HiveQL) to the BigQuery SQL dialect (GoogleSQL) can be done interactively or as a batch job. Below instructions to run interactive in GCP Console
* Navigate to BigQuery Migration Services page
* Select Translate SQL, Interactive Translation
* A new translation view shows up. Here, select 'HiveQL' on the left panel, and paste the following query:
```sql
-- HIVE script with a dummy query
USE google;
SELECT CAST(delivery_time AS DATE) AS delivery_date,distribution_center_id,product_id, quantity_to_delivery,SUM(quantity_to_delivery) OVER (PARTITION BY distribution_center_id, product_id ORDER BY delivery_time)   FROM product_deliveries_hive WHERE quantity_to_delivery > 0;
```
* Execute they query and check the results back.
