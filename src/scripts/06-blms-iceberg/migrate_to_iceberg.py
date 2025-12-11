import sys
from pyspark.sql import SparkSession, Row
from pyspark.sql.functions import lit

data_bucket = sys.argv[1]
catalog = sys.argv[2]

hive_schema_name = "ecomm_demo"
hive_table_name = "customers"

blms_db = hive_schema_name # The namespace in the catalog, equivalent to BQ Dataset name. We keep existing one from Hive.

iceberg_table_name = f"{hive_table_name}_iceberg"
full_iceberg_table_name = f"{catalog}.{blms_db}.{iceberg_table_name}"
iceberg_table_uri = f"gs://{data_bucket}/{hive_table_name}" # We'll reuse existing location
iceberg_data_files = f"{iceberg_table_uri}/data" # this will be created by catalog for new Iceberg table
iceberg_metadata_files = f"{iceberg_table_uri}/metadata" # this will be created by catalog for new Iceberg table
hive_parquet_files = iceberg_data_files # We'll use existing data files

spark = SparkSession.builder \
    .appName("MigrateToIceberg") \
    .getOrCreate()

print("---------- No tables yet created yet in the catalog ----------")
spark.sql(f"USE {catalog}")
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS `{blms_db}`")
spark.sql(f"USE `{blms_db}`")
spark.sql("SHOW TABLES").show()

print("## ---------- 1. Read Source Parquet to infer Schema & Partitions ----------")
temp_view = f"{hive_table_name}_gcs"
print(f"Reading source metadata from: {hive_parquet_files} and registering as temp view: {temp_view}")
df_source = spark.read.parquet(hive_parquet_files)
df_source.createOrReplaceTempView(temp_view)

print("## ---------- 2. Create the Empty Iceberg Tables ----------")
# Create the table first so Iceberg knows the schema and partition layout.
# We use 'LIMIT 0' to create the table structure without copying data.

spark.sql(f"DROP TABLE IF EXISTS {full_iceberg_table_name}") 

# We use CTAS (Create Table As Select) with LIMIT 0 to copy schema
# IMPORTANT: Ensure you define the PARTITION BY clause if your source is partitioned
spark.sql(f"""
    CREATE TABLE IF NOT EXISTS {full_iceberg_table_name}
    USING iceberg
    LOCATION '{iceberg_table_uri}'
    AS SELECT * FROM {temp_view} LIMIT 0
""")

print(f"""\
# --- Perform these validations outside Spark (GCP Console):
#    1. Check {data_bucket}/{catalog} GCS URI, no data/metadata files have been created in warehouse dir.
#    2. Check {iceberg_metadata_files} GCS URI, new metadata folder with files have been created.
#    3. Navigate to BigQuery Studio, {blms_db} dataset and verify new BigLake empty table {iceberg_table_name} is created with proper schema,
        Open Catalog Table Configuration 'Location URI' pointing to existing parquet files ({hive_parquet_files}) but no files yet
        (numFiles:0 in Open Catalog Table Configuration Parameters section), also run this query
        SELECT * FROM `{blms_db}.{iceberg_table_name}`""")

print("## ---------- 3. Call add_files to generate Iceberg metadata from existing Hive External table parquet files ----------")

# We verify the count before
print("Rows before add_files:", spark.table(full_iceberg_table_name).count())

spark.sql(f"""
    CALL {catalog}.system.add_files(
        table => '{full_iceberg_table_name}',
        source_table => '`parquet`.`{hive_parquet_files}`'
    )
""")

print("Rows after add_files:", spark.table(full_iceberg_table_name).count())

print("## ---------- Post migration: DML in BigLake Iceberg table ----------")
# We add new data using BLMS

new_data = [
    Row(customer_id="Ice100", name="Mad Max", email="mad.max@example.com", segment="New")
]
new_df = spark.createDataFrame(new_data)

new_df.writeTo(f"{full_iceberg_table_name}").append()

spark.sql(f"SELECT * FROM {full_iceberg_table_name} WHERE customer_id='Ice100'").show()

print(f"""\
# --- Perform these validations outside Spark (GCP Console):
#    1. Check {iceberg_data_files} GCS URI, new Parquet files have been created.
#    2. Check {iceberg_metadata_files} GCS URI, new Iceberg metadata files have been created.
#    3. Run this query to verify new data is immediately available via BigQuery as well:
#       SELECT * FROM `{blms_db}.{iceberg_table_name}` WHERE customer_id='Ice100'""")


print("## ---------- Post migration: DDL in BigLake Iceberg table ----------")

# We modify schema by adding new column default null and insert new record
spark.sql(f"ALTER TABLE {full_iceberg_table_name} ADD COLUMN country STRING")
new_data = [
    Row(customer_id="Ice200", name="Mary Doe", email="mary.doe@example.com", segment="New", country="USA")
]
new_df = spark.createDataFrame(new_data)

new_df.writeTo(f"{full_iceberg_table_name}").append()

print(f"""\
# --- Perform these validations outside Spark (GCP Console):
#    1. Check {iceberg_data_files} GCS URI, new Parquet files have been created.
#    2. Check {iceberg_metadata_files} GCS URI, new Iceberg metadata files have been created.
#    3. Run this query to verify new schema and data are immediately available via BigQuery as well:
#       SELECT * FROM `{blms_db}.{iceberg_table_name}` WHERE customer_id='Ice200'""")

spark.stop()
print("## ---------- Job finished ----------")
