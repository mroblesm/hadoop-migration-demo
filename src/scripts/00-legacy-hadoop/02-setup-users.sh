#!/bin/sh
# To be executed from Hadoop master node
if [ "${#}" -ne 1 ]; then
    echo "Illegal number of parameters. Exiting..."
    echo "Usage: ${0} <ranger_pwd>"
    echo "Exiting..."
    exit 1
fi
RANGER_PWD=$1

echo "Adding users 'analyst_eu' and 'analyst_us' ..."
sudo useradd analyst_eu
sudo useradd analyst_us

echo "Creating Ranger policies using ranger password ..."
python3 02-setup-ranger-policies.py $RANGER_PWD

echo "Creating Ranger policies finished"
