# 6. Alternative approach using BigLake Iceberg tables and BigLake Metastore instead of BigLake External tables

In this scenario, parquet files from original Hive tables are migrated to Iceberg format. Iceberg tables provide additional benefits over Hive tables, some examples below:
* Snapshot Isolation & Time Travel: You can query data "as of" a specific timestamp. This is excellent for auditing and recovering from bad ETL jobs (SELECT * FROM table FOR SYSTEM_TIME AS OF ...).
* Performance (Metadata Pruning): Iceberg stores min/max statistics in manifest files. BigQuery and Spark can skip massive amounts of data without listing files in GCS, offering significantly faster performance than standard Hive-style Parquet external tables.
* Partition Evolution: You can change the partitioning scheme of a table without rewriting all the data (a major pain point in Hive).

Google provides two components to support this scenario
* BigLake tables for Apache Iceberg
* BigLake Metastore

A PySpark job is provided, that:
* First, it creates empty BigLake Iceberg tables in BLMS pointing to GCS location where original parquet files were migrated
* Secondly, it uses add_files procedure from Iceberg catalog to add existing files to newly created table, to avoid data files to be rewritten.
* Lastly, the job performs DML and DDL operations on `customers` table in Spark using BLMS. These changes are immediately available in BigQuery SQL.

Run the following commands to run the PySpark job:
```console
cd src/scripts/06-blms-iceberg
source spark-submit.sh ${GOOGLE_CLOUD_PROJECT} ${REGION} ${DATA_BUCKET}
```

Navigate to Dataproc > Batches and you will see the submitted job executing. Once the job finishes (around 2-3min.):
* Inspect the job output logs, to verify every step of the execution
* Navigate to BigQuery Studio, `ecomm_demo` dataset. You will see two new tables have been created: `customers_iceberg` and `transactions_iceberg`. These are BigLake Iceberg tables, managed by BigLake Metastore.
* For each table, check the content of the bucket where data was migrated:
  * A new folder 'metadata' have been created along the data, containing Iceberg metadata files managed by the catalog.
  * For `customers` table, new parquet files have been created along existing migrated files. A new column has been added to original table from Spark, and it's available for consumption in BigQuery.
*  Inspect the table details and run these queries from BigQuery Studio. 
```sql
-- Show transactions table's data
SELECT * FROM `ecomm_demo.transactions_iceberg` LIMIT 100;
-- Show new data and schema in customers table
SELECT * FROM `ecomm_demo.customers_iceberg` WHERE customer_id='Ice200';
```
