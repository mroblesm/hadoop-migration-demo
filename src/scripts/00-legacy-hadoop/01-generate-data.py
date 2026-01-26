from pyspark.sql import SparkSession
from pyspark.sql import Row
import random
import time
from datetime import datetime, timedelta

data_path = "hdfs:///data"
db_name = "datalake_demo"

def generate_data():
    # Initialize Spark Session
    print("Creating Spark Session...")

    spark = SparkSession.builder \
        .appName("DataGenerator") \
        .config("spark.sql.catalogImplementation", "hive") \
        .enableHiveSupport() \
        .getOrCreate()

    # Configuration
    NUM_CUSTOMERS = 10000
    NUM_TRANSACTIONS = 500000
    REGIONS = ['US', 'EU', 'APAC']
    SEGMENTS = ['VIP', 'Standard', 'New']
    
    # --- 1. Generate Customers Data ---
    print(f"Generating {NUM_CUSTOMERS} customers...")

    def create_customer(i):
        cid = f"CUST_{i:05d}"
        return Row(
            customer_id=cid,
            name=f"Customer_{i}",
            email=f"user_{i}@example.com", # PII field
            segment=random.choice(SEGMENTS)
        )

    customers_rdd = spark.sparkContext.parallelize(range(NUM_CUSTOMERS)).map(create_customer)
    df_customers = spark.createDataFrame(customers_rdd)

    # Write to HDFS
    customers_path = f"{data_path}/customers"
    df_customers.repartition(4).write.mode("overwrite").parquet(customers_path)
    print(f"Customers data written to {customers_path}")

    # --- 2. Generate Transactions Data ---
    print(f"Generating {NUM_TRANSACTIONS} transactions...")
    # We generate this in a distributed way using RDDs for better performance if scaling up
    def create_transaction(_):
        cid = f"CUST_{random.randint(0, NUM_CUSTOMERS-1):05d}"
        # Random time in last 30 days
        txn_time = datetime.now() - timedelta(days=random.randint(0, 30))
        return Row(
            transaction_id=f"{int(time.time())}_{random.randint(1000,9999)}",
            customer_id=cid,
            amount=round(random.uniform(10.0, 1000.0), 2),
            region=random.choice(REGIONS),
            timestamp=txn_time.isoformat()
        )

    # Create an RDD with dummy range to parallelize generation
    rdd = spark.sparkContext.parallelize(range(NUM_TRANSACTIONS))
    txn_rdd = rdd.map(create_transaction)
    df_transactions = spark.createDataFrame(txn_rdd)

    # Write to HDFS
    print("Writing results to HDFS...")
    transactions_path = f"{data_path}/transactions"
    df_transactions.repartition(16).write.mode("overwrite").parquet(transactions_path)
    print(f"Transactions data written to {transactions_path}")

    # --- 3. Register in Hive (Optional but recommended for Legacy Demo) ---
    print("Registering tables in Hive...")
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {db_name} LOCATION '/user/hive/warehouse/{db_name}.db'")
    spark.sql(f"CREATE EXTERNAL TABLE IF NOT EXISTS {db_name}.customers (customer_id STRING, name STRING, email STRING, segment STRING) STORED AS PARQUET LOCATION '{customers_path}'")
    spark.sql(f"CREATE EXTERNAL TABLE IF NOT EXISTS {db_name}.transactions (transaction_id STRING, customer_id STRING, amount DOUBLE, region STRING, timestamp STRING) STORED AS PARQUET LOCATION '{transactions_path}'")
    print("Hive external table creation Complete.")
    print(f"Running query 'SELECT * FROM {db_name}.customers LIMIT 50' ...")
    spark.sql(f"SELECT * FROM {db_name}.customers LIMIT 50").show()

    print("Data Generation Complete.")
    spark.stop()

if __name__ == "__main__":
    generate_data()