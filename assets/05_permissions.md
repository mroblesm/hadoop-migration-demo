# 5. Permissions and Policies migration

This last step shows how Ranger permissions can be migrated to Google Cloud's Cloud IAM in BigQuery ([docs](https://docs.cloud.google.com/bigquery/docs/access-control-basic-roles)) and BigQuery's column-level and row-level access policies ([1](https://docs.cloud.google.com/bigquery/docs/column-level-security-intro), [2](https://docs.cloud.google.com/bigquery/docs/row-level-security-intro))

You will need to first setup the Google users and groups in Cloud IAM that will replicate the user principals and groups in the legacy Hadoop platform (`analyst_us` and `analyst_eu`). If you don't have access to your organisation, you can use existing Google users and groups as target users (you will need the mapping in next steps).

## Using BQMS to migrate Ranger policies

Once target users and groups are created, [BQMS Hadoop permissions migration tool](https://docs.cloud.google.com/bigquery/docs/hadoop-permissions-migration) can be used to first extract the metadata from the source Hadoop cluster, then create the necessary resources in Google Cloud based on defined "configuration files".

Below indicates the source and target components during the migration:
* Ranger Resource (Hive Table) → BigQuery Table.
* Ranger Allow Policy → IAM Role (roles/bigquery.dataViewer).
* Ranger Row Filter → BigQuery Row Access Policy.
* Ranger Masking → BigQuery Policy Tags.

The required steps to execute the migration are as follow. Details found in next sections, for any clarification refer to public documentation.
1. Extract metadata from source
2. Create Principals mapping ruleset configuration file
3. Generate Principals mapping file ‘principals.yaml’
4. Create permissions configuration file
5. Generate Permissions mapping file ‘permissions.yaml’
6. Apply permissions to BQ / GCS Folders


**1. Extract metadata for Hive, HDFS and Ranger**

First step is to extract existing metadata using `dwh-dumper-tool` (part of BQMS). This tool needs to be installed and executed in a node in source Hadoop platform with access to the services.

We will reproduce this in the legacy hadoop cluster created at the beginning, SSH-ing in the master node.
```console
LEGACY_CLUSTER_NAME=$(terraform output -raw legacy_hadoop_cluster)
MASTER_NODE=${LEGACY_CLUSTER_NAME}-m
RANGER_PWD=$(terraform output -raw ranger_pwd_clear)
CODE_BUCKET=$(terraform output -raw code_bucket)
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap 
```
Once in the master node, download and execute the tool (recommend to check dwh tool Github repo for the latest version):
```
wget https://github.com/google/dwh-migration-tools/releases/download/v1.7.0/dwh-migration-tools-v1.7.0.zip
unzip dwh-migration-tools-v1.7.0.zip
cd dwh-migration-tools-v1.7.0/dumper/bin
./dwh-migration-dumper \
  --connector ranger \
  --host ${MASTER_NODE} \
  --port 6080 \
  --user admin \
  --password ${RANGER_PWD} \
  --ranger-scheme http \
  --output gs://${CODE_BUCKET}/ranger-dumper-output.zip \
  --assessment
sudo ./dwh-migration-dumper --connector hdfs \
  --host ${MASTER_NODE} \
  --port 8020 \
  --output gs://${CODE_BUCKET}/hdfs-dumper-output.zip \
  --assessment
./dwh-migration-dumper \
  --connector hiveql \
  --database datalake_demo \
  --host ${MASTER_NODE} \
  --port 9083 \
  --output gs://${CODE_BUCKET}/translation_output/hive-dumper-output.zip \
  --assessment
```
Check the execution outputs of the three dumper commands to verify their successful execution. They will generate the results in GCS files (`ranger-dumper-output.zip`, `hdfs-dumper-output.zip`, `hive-dumper-output.zip`). These files contain Hive, HDFS and Ranger assets to migrate (database, tables, user, groups, policies).

**2. Create Principals mapping ruleset configuration file**

Next step is to create a principals mapping file.
First, a ruleset configuration file is required, containing mapping rules that will instruct BQMS how to map each of your sources Hadoop principals (users, groups, functional accounts) to Cloud IAM user, groups and service accounts.
We will use an example file. **You need to replace required values with the Google identities you created / selected previuosly**: edit the file before proceeding. Once updated, run the following command from cloud shell:
```
gsutil cp src/scripts/05-permissions-migration/principals-ruleset.yaml gs://${CODE_BUCKET}
```

**3. Generate Principals mapping file ‘principals.yaml’**

With the ruleset configuration file, invoke dwh tool to generate principals mapping file. SSH back to the master node to run this command:
```console
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap
cd dwh-migration-tools-v1.7.0/permissions-migration/bin
./dwh-permissions-migration expand \
    --principal-ruleset gs://${CODE_BUCKET}/principals-ruleset.yaml \
    --hdfs-dumper-output gs://${CODE_BUCKET}/hdfs-dumper-output.zip \
    --ranger-dumper-output gs://${CODE_BUCKET}/ranger-dumper-output.zip \
    --output-principals gs://${CODE_BUCKET}/principals.yaml
```
Check the execution output to verify it has executed successfully. It will generate a file GCS `principals.yaml`. This file contains the exact mapping of principals.

**4. Create configuration files**

Next step is to create the target configuration files.
First, a permissions configuration file is required. This file defines customisation of how permissions from Ranger map to BigQuery (i.e. to use a custom IAM role for certain tables).
We will use an example file that does not contain any customisation. Run the following command from cloud shell:
```
gsutil cp src/scripts/05-permissions-migration/permissions-config.yaml gs://${CODE_BUCKET}
```
Secondly, database and tables configuration file are required for translation. These files define how databases and tables are mapped to target destinations, and are used to create a  tables mapping YAML for HiveToBigQuery service in BQMS.
**You need to replace required values before copying these files to GCS**
```
gcloud storage cp src/scripts/05-permissions-migration/database.config.yaml gs://${CODE_BUCKET}/translation/
gcloud storage cp src/scripts/05-permissions-migration/tables.config.yaml gs://${CODE_BUCKET}/translation/
AUTH_TOKEN=$(gcloud auth print-access-token)
curl -d '{
  "tasks": {
      "string": {
        "type": "HiveQL2BigQuery_Translation",
        "translation_details": {
            "target_base_uri": "gs://'"${CODE_BUCKET}"'/translation_output",
            "source_target_mapping": {
              "source_spec": {
                  "base_uri": "gs://'"${CODE_BUCKET}"'/translation"
              }
            },
            "target_types": ["metadata"]
        }
      }
  }
  }' \
  -H "Content-Type:application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" -X POST https://bigquerymigration.googleapis.com/v2alpha/projects/${GOOGLE_CLOUD_PROJECT}/locations/${BQ_REGION}/workflows
```
When completed, a mapping file is generated for each table in database within a predefined path in `gs://${CODE_BUCKET}`.

**5. Generate Permissions mapping file ‘permissions.yaml’**

With the permissions configuration file, invoke dwh tool to generate the target permissions file. SSH back to the master node to run this command:
```console
gcloud compute ssh ${MASTER_NODE} --project=${GOOGLE_CLOUD_PROJECT} --zone=${ZONE} --tunnel-through-iap
./dwh-permissions-migration build \
    --permissions-ruleset gs://${CODE_BUCKET}/permissions-config.yaml \
    --tables gs://${CODE_BUCKET}/translation_output/ \
    --principals gs://${CODE_BUCKET}/principals.yaml \
    --ranger-dumper-output gs://${CODE_BUCKET}/ranger-dumper-output.zip \
    --output-permissions gs://${CODE_BUCKET}/permissions.yaml
```
Check the execution output to verify it has executed successfully. It will generate a file GCS `permissions.yaml`. This file contains permissions from your source mapped to BigQuery IAM bindings.

**6. Apply permissions to BQ / GCS Folders**

Once you have generated a target permissions file, you can then run the dwh tool to apply the IAM permissions to BigQuery.
```console
./dwh-permissions-migration apply \
    --permissions gs://${CODE_BUCKET}/permissions.yaml
```

## Alternative approach

If you encounter any issue with BQMS, alternatively the following steps create the resulted BQ policies, replacing analyst_us and analyst_eu with the Google identities you created previuosly.

* Grant read access to tables, to either individual users or groups:

```sql
-- Grant access to `transactions` table to single user in EU Analysts
GRANT `roles/bigquery.dataViewer`
ON TABLE `datalake_demo.transactions`
TO 'user:analyst_eu@your-org.com';

-- Grant access to `customers` table to US Analysts group
GRANT `roles/bigquery.dataViewer`
ON TABLE `datalake_demo.customers`
TO 'group:data-analysts-us@your-org.com';
```

* Apply row level access policy to `transactions` table (`analyst_eu` user can only see data where region is "EU"):

```sql
-- Apply Row Level Security (Mapped from Ranger Row Filter policy)
CREATE OR REPLACE ROW ACCESS POLICY `eu_filter_migrated`
ON `datalake_demo.transactions`
GRANT TO ('user:analyst_eu@your-org.com')
FILTER USING (region = 'EU');
```

* Apply Column Masking (Mapped from Ranger Masking policy) to `datalake_demo.customers` table, email column
  * First, create a Policy tag taxonomy (`privacy`) under BigQuery, Governance > Policy tags
  * Then, add Data Policies by creating a new Policy tag in the taxonomy (`pii_tag`) with a 'Email Mask' rule associated to Principal `data-analysts-us@your-org.com`.
  * Finally, navigate to BigQuery studio, select the `customers` table, Edit schema, select `email` column and click on `Add policy tag` on the top. Select the taxonomy `privacy` with the policy tag `pii_tag` to apply to the column.
  * Once policy tag is attached to table column, only the indicated principal will have access to the column, and it will see data as per configured rule (masked emails).
