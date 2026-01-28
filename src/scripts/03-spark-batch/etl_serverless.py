import sys
from pyspark.sql import SparkSession

# Initialize
spark = SparkSession.builder.appName("ServerlessRevenueReport").getOrCreate()

# Arguments
data_location_path = sys.argv[1]
print(f"Using data location path: '{data_location_path}'")

# Read from GCS (or BigLake tables via BigQuery connector)
# Using direct GCS for speed in this demo
df_trans = spark.read.parquet(f"{data_location_path}/data/transactions")
df_cust = spark.read.parquet(f"{data_location_path}/data/customers")

# Transformation
result = df_trans.join(df_cust, "customer_id") \
    .groupBy("segment") \
    .sum("amount") \
    .withColumnRenamed("sum(amount)", "total_revenue")

# -- OLD CODE -- Write to filesystem
# result.write.mode('overwrite').parquet(f"{data_location_path}/revenue_report/data")

# -- NEW CODE -- Write to BigQuery Native Table (Modern Target)
result.write \
  .format("bigquery") \
  .option("table", f"datalake_demo.revenue_report") \
  .option("writeMethod", "direct") \
  .option("writeAtLeastOnce", "true") \
  .mode("overwrite") \
  .save()
print("New data written to 'datalake_demo.revenue_report' BQ table")

spark.stop()