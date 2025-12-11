from pyspark.sql import SparkSession
from pyspark.sql import Row
import random
import time
from datetime import datetime, timedelta

def generate_data():
    # Initialize Spark Session
    spark = SparkSession.builder \
        .appName("DataGenerator") \
        .enableHiveSupport() \
        .getOrCreate()

    # Configuration
    NUM_CUSTOMERS = 10000
    NUM_TRANSACTIONS = 500000
    REGIONS = ['US', 'EU', 'APAC']
    SEGMENTS = ['VIP', 'Standard', 'New']
    
    # --- 1. Generate Customers Data ---
    print(f"Generating {NUM_CUSTOMERS} customers...")
    customers_data = []
    for i in range(NUM_CUSTOMERS):
        cid = f"CUST_{i:05d}"
        customers_data.append(Row(
            customer_id=cid,
            name=f"Customer_{i}",
            email=f"user_{i}@example.com", # PII field
            segment=random.choice(SEGMENTS)
        ))
    
    df_customers = spark.createDataFrame(customers_data)
    
    # Write to HDFS
    customers_path = "hdfs:///data/customers"
    df_customers.write.mode("overwrite").parquet(customers_path)
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
    transactions_path = "hdfs:///data/transactions"
    df_transactions.write.mode("overwrite").parquet(transactions_path)
    print(f"Transactions data written to {transactions_path}")

    # --- 3. Register in Hive (Optional but recommended for Legacy Demo) ---
    print("Registering tables in Hive...")
    spark.sql("CREATE SCHEMA IF NOT EXISTS datalake_demo;")
    spark.sql(f"CREATE EXTERNAL TABLE IF NOT EXISTS datalake_demo.customers (customer_id STRING, name STRING, email STRING, segment STRING) STORED AS PARQUET LOCATION '{customers_path}'")
    spark.sql(f"CREATE EXTERNAL TABLE IF NOT EXISTS datalake_demo.transactions (transaction_id STRING, customer_id STRING, amount DOUBLE, region STRING, timestamp STRING) STORED AS PARQUET LOCATION '{transactions_path}'")
    
    print("Data Generation Complete.")
    spark.stop()

if __name__ == "__main__":
    generate_data()