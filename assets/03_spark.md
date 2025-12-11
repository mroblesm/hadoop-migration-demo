# 3. Run Spark job using Google Cloud Serverless for Spark Batch

The following section shows how to migrate a Spark job to Google Cloud Serverless for Apache Spark. This job performs a basic data join and aggregation. Two changes are introduced as part of the migration:
* The original PySpark script expected as input argument the path to the original data location in HDFS for the customers and transactions tables. The new path to GCS where data has been migrated is provided instead. The serverless spark runtime in GCP already ships the required GCS connector libraries.
* The original PySpark script stored the results in a HDFS location. Instead, a BigQuery native table is selected as target.

Execute the following commands to submit a serverless Spark batch job with the updated PySpark script:
```console
cd src/scripts/03-spark-batch
source spark-submit.sh ${GOOGLE_CLOUD_PROJECT} ${REGION} ${DATA_BUCKET}
```

Navigate to Dataproc > Batches and you will see the submitted job executing. Once the job finishes (around 2-3min.), run the following query in BQ Studio to inspect the results
```
SELECT * FROM `ecomm_demo.revenue_report` LIMIT 10;
```

If you want to explore how to orchestrate Spark jobs execution using Google Cloud Serverless for Apache Spark, a commonly adopted approach is to use Composer (Google Cloud managed Airflow). Check out [this tutorial](https://docs.cloud.google.com/composer/docs/composer-3/run-data-analytics-dag-googlecloud) for an example.