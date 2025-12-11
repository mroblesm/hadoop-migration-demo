#!/bin/sh
# To be executed from Hadoop master node

echo "Adding users 'analyst_eu' and 'analyst_us' ..."
sudo useradd analyst_eu
sudo useradd analyst_us

echo "Creating Ranger policies..."
python3 setup_ranger_policies.py
# Optional - to verify access policies from Hive
hdfs dfs -chmod  a+w /hadoop/tmp/hive/user-install-dir
echo "Creating Ranger policies finished"
