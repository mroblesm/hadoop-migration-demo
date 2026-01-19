
/******************************************
 Local variables declaration
 *****************************************/

locals {
  project_id                      = "${var.project_id}"
  project_number                  = "${var.project_number}"
  region                          = "${var.region}"
  zone                            = "${var.zone}"
  bigquery_region                 = "us"
  vpc_name                        = "vpc-main"
  vpc_subnet_name                 = "spark-subnet"
  subnet_cidr_range               = "10.0.0.0/24"

  dataproc_legacy_bucket          = "${local.project_id}-dataproc-legacy"
  dataproc_legacy_dw_bucket       = "${local.project_id}-dataproc-legacy-dw"
  ranger_pwd_bucket               = "${local.project_id}-ranger-pwd"
  ranger_pwd_enc                  = "ranger-password.enc"
  code_bucket                     = "${local.project_id}-code"
  data_bucket                     = "${local.project_id}-data"
  keyring                         = "demo-keyring"
  key                             = "demo-key"
}

/******************************************
 API Enablement
 *****************************************/

resource "google_project_service" "service-serviceusage" {
  project = local.project_id
  service = "serviceusage.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-cloudresourcemanager" {
  project = local.project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-servicemanagement" {
  project = local.project_id
  service = "servicemanagement.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-orgpolicy" {
  project = local.project_id
  service = "orgpolicy.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-compute" {
  project = local.project_id
  service = "compute.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-bigquerystorage" {
  project = local.project_id
  service = "bigquerystorage.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-bigqueryconnection" {
  project = local.project_id
  service = "bigqueryconnection.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-dataproc" {
  project = local.project_id
  service = "dataproc.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-biglake" {
  project = local.project_id
  service = "biglake.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "enable_compute_google_apis" {
  project = local.project_id
  service = "compute.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "enable_container_google_apis" {
  project = local.project_id
  service = "container.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "enable_dataplex_api" {
  project = var.project_id
  service = "dataplex.googleapis.com"
}

resource "google_project_service" "service-servicenetworking" {
  project = local.project_id
  service = "servicenetworking.googleapis.com"
  disable_dependent_services  = true
}

resource "google_project_service" "service-storagetransfer" {
  project = var.project_id
  service = "storagetransfer.googleapis.com"
} 

resource "time_sleep" "google_api_activation_time_delay" {
  create_duration = "120s"
  depends_on = [
    google_project_service.service-serviceusage,
    google_project_service.service-cloudresourcemanager,
    google_project_service.service-servicemanagement,
    google_project_service.service-orgpolicy,
    google_project_service.service-compute,
    google_project_service.service-bigquerystorage,
    google_project_service.service-bigqueryconnection,
    google_project_service.service-dataproc,
    google_project_service.service-biglake,
    google_project_service.service-servicenetworking,
    google_project_service.service-storagetransfer,
    google_project_service.enable_compute_google_apis,
    google_project_service.enable_container_google_apis,
    google_project_service.enable_dataplex_api
  ]  
}

/******************************************
 Org policies
 *****************************************/

resource "google_project_organization_policy" "orgPolicyUpdate_disableSerialPortLogging" {
  project                 = "${local.project_id}"
  constraint = "compute.disableSerialPortLogging"
  boolean_policy {
    enforced = false
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_requireOsLogin" {
  project                 = "${local.project_id}"
  constraint = "compute.requireOsLogin"
  boolean_policy {
    enforced = false
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_requireShieldedVm" {
  project                 = "${local.project_id}"
  constraint = "compute.requireShieldedVm"
  boolean_policy {
    enforced = false
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_vmCanIpForward" {
  project                 = "${local.project_id}"
  constraint = "compute.vmCanIpForward"
  list_policy {
    allow {
      all = true
    }
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_vmExternalIpAccess" {
  project                 = "${local.project_id}"
  constraint = "compute.vmExternalIpAccess"
  list_policy {
    allow {
      all = true
    }
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_restrictVpcPeering" {
  project                 = "${local.project_id}"
  constraint = "compute.restrictVpcPeering"
  list_policy {
    allow {
      all = true
    }
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "google_project_organization_policy" "orgPolicyUpdate_disableServiceAccountKeyCreation" {
  project                 = "${local.project_id}"
  constraint = "iam.disableServiceAccountKeyCreation"
   boolean_policy {
    enforced = false
  }
  depends_on = [
    time_sleep.google_api_activation_time_delay
  ]
}

resource "time_sleep" "sleep_after_org_policy_updates" {
  create_duration = "3m"
  depends_on = [
    google_project_organization_policy.orgPolicyUpdate_disableSerialPortLogging,
    google_project_organization_policy.orgPolicyUpdate_requireOsLogin,
    google_project_organization_policy.orgPolicyUpdate_requireShieldedVm,
    google_project_organization_policy.orgPolicyUpdate_vmCanIpForward,
    google_project_organization_policy.orgPolicyUpdate_vmExternalIpAccess,
    google_project_organization_policy.orgPolicyUpdate_restrictVpcPeering,
    google_project_organization_policy.orgPolicyUpdate_disableServiceAccountKeyCreation,
  ]
}

/******************************************
 Custom Roles
 *****************************************/

resource "google_project_iam_custom_role" "customconnectiondelegate" {
  role_id     = "CustomConnectionDelegate"
  title       = "Custom Connection Delegate"
  description = "Used for BQ connections"
  permissions = ["biglake.tables.create","biglake.tables.delete","biglake.tables.get",
  "biglake.tables.list","biglake.tables.lock","biglake.tables.update",
  "bigquery.connections.delegate"]
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_project_iam_custom_role" "custom-role-custom-delegate" {
  role_id     = "CustomDelegate"
  title       = "Custom Delegate"
  description = "Used for BLMS connections"
  permissions = ["bigquery.connections.delegate"]
  depends_on = [
    google_project_iam_custom_role.customconnectiondelegate,
    time_sleep.sleep_after_org_policy_updates
  ]
}


/******************************************
 Network
 *****************************************/

resource "google_compute_network" "vpc_main" {
  project                 = "${local.project_id}"
  description             = "Network for Spark workloads"
  name                    = local.vpc_name
  auto_create_subnetworks = false
  mtu                     = 1460
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_compute_subnetwork" "spark_subnet" {
  project       = "${local.project_id}"
  name          = local.vpc_subnet_name
  ip_cidr_range = local.subnet_cidr_range
  region        = local.region
  network       = google_compute_network.vpc_main.id
  private_ip_google_access = true
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

# Firewall: Allow internal communication between nodes (Critical for Hadoop/Spark)
resource "google_compute_firewall" "allow_internal" {
  name    = "legacy-allow-internal"
  network = google_compute_network.vpc_main.name

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = [local.subnet_cidr_range]

  depends_on = [
    google_compute_subnetwork.spark_subnet
  ]
}

# Firewall: Allow SSH from IAP (Identity-Aware Proxy) for secure access
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"] # Google IAP CIDR
}

# Enable access to internet via Cloud NAT
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "nat-router"
  network = google_compute_network.vpc_main.name
  region  = var.region
}
module "cloud-nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  project_id                         = var.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  name                               = "nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

/******************************************
 Cloud Storage
 *****************************************/

resource "google_storage_bucket" "ranger_pwd_bucket" {
  project                           = local.project_id 
  name                              = local.ranger_pwd_bucket
  location                          = local.region
  uniform_bucket_level_access       = true
  force_destroy                     = true
}

resource "google_storage_bucket" "dataproc_legacy_bucket" {
  project                           = local.project_id 
  name                              = local.dataproc_legacy_bucket
  location                          = local.region
  uniform_bucket_level_access       = true
  force_destroy                     = true
}

resource "google_storage_bucket" "dataproc_legacy_dw_bucket" {
  project                           = local.project_id 
  name                              = local.dataproc_legacy_dw_bucket
  location                          = local.region
  uniform_bucket_level_access       = true
  force_destroy                     = true
}

resource "google_storage_bucket" "code_bucket" {
  project                           = local.project_id 
  name                              = local.code_bucket
  location                          = local.region
  uniform_bucket_level_access       = true
  force_destroy                     = true
}

resource "google_storage_bucket" "data_bucket" {
  project                           = local.project_id 
  name                              = local.data_bucket
  location                          = local.region
  uniform_bucket_level_access       = true
  force_destroy                     = true
}

output "code_bucket" {
  value = google_storage_bucket_object.code_bucket.id
}

output "data_bucket" {
  value = google_storage_bucket_object.data_bucket.id
}

/******************************************
 Code assets to GCS
 *****************************************/

resource "google_storage_bucket_object" "default" {
 name         = "01"
 source       = "src/scripts/legacy-hadoop/01-generate-data.py"
 content_type = "text/plain"
 bucket       = google_storage_bucket.code_bucket.id
}

/******************************************
 Service Accounts
 *****************************************/

resource "google_service_account" "dataproc_service_account" {
  account_id   = local.project_id
  display_name = "Dataproc Service Account"
  depends_on = [
    time_sleep.sleep_after_org_policy_updates
  ]
}

resource "google_project_iam_member" "dataproc_service_account_roles" {
  // NOTE: Owner role is kept for demo simplicity and robustness.
  // In a production environment, use granular roles instead.
  for_each = toset([
    "roles/owner",
    "roles/bigquery.admin",
    "roles/storage.admin",
    "roles/dataproc.worker",
    "roles/secretmanager.secretAccessor",
    "roles/cloudkms.cryptoKeyEncrypterDecrypter",
  ])
  project  = local.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.dataproc_service_account.email}"

  depends_on = [
    google_service_account.dataproc_service_account
  ]
}

/******************************************
 KMS 
 *****************************************/

resource "google_kms_key_ring" "keyring" {
  name     = "app-secure-keyring"
  location = local.region
}

resource "google_kms_crypto_key" "cryptokey" {
  name            = "app-password-key"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "7776000s" # Rotate key every 90 days

  lifecycle {
    prevent_destroy = false
  }
}

# Note: Ideally, pass 'plaintext' via a variable (var.password) rather than hardcoding.
resource "google_kms_secret_ciphertext" "encrypted_password" {
  crypto_key = google_kms_crypto_key.cryptokey.id
  plaintext  = var.ranger_pwd
}

output "ranger_pwd_clear" {
  value = var.ranger_pwd
}

resource "google_storage_bucket_object" "ciphertext_upload" {
  name    = local.ranger_pwd_enc
  bucket  = local.ranger_pwd_bucket
  
  # The ciphertext attribute is Base64 encoded encrypted data
  content = google_kms_secret_ciphertext.encrypted_password.ciphertext
  
  content_type = "text/plain"
}

/******************************************
 Dataproc emulating Legacy cluster 
 *****************************************/

resource "google_dataproc_cluster" "legacy_cluster" {
  name   = "legacy-hadoop-cluster"
  region = var.region

  cluster_config {
    staging_bucket = local.dataproc_legacy_bucket

    master_config {
      num_instances = 1
      machine_type  = "e2-medium"
      disk_config {
        boot_disk_type    = "pd-ssd"
        boot_disk_size_gb = 30
        num_local_ssds    = 1
        local_ssd_interface = "nvme"
      }
    }

    worker_config {
      num_instances = 1
      machine_type  = "e2-medium"
      disk_config {
        boot_disk_type    = "pd-ssd"
        boot_disk_size_gb = 30
        num_local_ssds    = 1
        local_ssd_interface = "nvme"
      }
    }

    gce_cluster_config {
      subnetwork = google_compute_subnetwork.spark_subnet.id
      # Scopes to allow access to GCS and BigQuery (if needed later)
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      tags = ["legacy-hadoop"]

      internal_ip_only = "true"

      shielded_instance_config{
        enable_secure_boot          = true
        enable_vtpm                 = true
        enable_integrity_monitoring = true
      }
    }

    software_config {
      image_version = "2.2-debian12"

      optional_components = [
        "JUPYTER", 
        "RANGER", 
        "SOLR", 
        "ZOOKEEPER"
      ]

      # Setup properties
      properties = {
        "dataproc:dataproc.allow.zero.workers"            = "false"
        "dataproc:solr.gcs.path"                          = "gs://${local.dataproc_legacy_bucket}/solr"
        "dataproc:ranger.kms.key.uri"                     = "projects/${local.project_id}/locations/${local.region}/keyRings/${local.keyring}/cryptoKeys/${local.key}"
        "dataproc:ranger.admin.password.uri"              = "gs://${local.ranger_pwd_bucket}/${local.ranger_pwd_enc}"
        "dataproc:ranger.gcs.plugin.mysql.kms.key.uri"    = "projects/${local.project_id}/locations/${local.region}/keyRings/${local.keyring}/cryptoKeys/${local.key}"
        "dataproc:ranger.gcs.plugin.mysql.password.uri"   = "gs://${local.ranger_pwd_bucket}/${local.ranger_pwd_enc}"
        "spark:spark.dataproc.enhanced.optimizer.enabled" = "true"
        "spark:spark.dataproc.enhanced.execution.enabled" = "true"
        "dataproc:dataproc.cluster.caching.enabled"       = "true"
      }

    }

    # Enable Component Gateway for easy web access to Ranger, Jupyter, etc.
    endpoint_config {
      enable_http_port_access = true
    }

  }
}

output "legacy_hadoop_cluster" {
  value = google_dataproc_cluster.legacy_cluster.name
}

/******************************************
 BigLake
 *****************************************/

# BigLake connection
resource "google_bigquery_connection" "biglake_connection" {
   connection_id = "biglake-connection"
   location      = local.bigquery_region
   friendly_name = "biglake-connection"
   description   = "biglake-connection"
   cloud_resource {}
   depends_on = [ 
      google_project_iam_custom_role.custom-role-custom-delegate
   ]
}

# Allow BigLake to read storage
resource "google_project_iam_member" "bq_connection_iam_object_viewer" {
  project  = local.project_id
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}

# Allow BigLake to custom role
resource "google_project_iam_member" "biglake_customconnectiondelegate" {
  project  = local.project_id
  role     = google_project_iam_custom_role.customconnectiondelegate.id
  member   = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection,
    google_project_iam_custom_role.customconnectiondelegate
  ]
}

# Allow Dataplex SA to use BigLake connection for Discovery Job (BQ Conn Admin)
resource "google_project_iam_member" "dataplex_biglake_publisher" {
  project  = local.project_id
  role     = "roles/dataplex.discoveryBigLakePublishingServiceAgent"
  member   = "serviceAccount:service-${local.project_number}@gcp-sa-dataplex.iam.gserviceaccount.com"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}

resource "google_project_iam_member" "bq_connection_discovery_agent" {
  project  = local.project_id
  role     = "roles/dataplex.discoveryServiceAgent"
  member   = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection
  ]
}
# TODO roles/dataplex.discoveryServiceAgent on bucket
# TODO roles/dataplex.discoveryBigLakePublishingServiceAgent on the bigquery connection

resource "google_project_iam_member" "biglake_connection_service_agent" {
  project  = local.project_id
  role     = "roles/dataplex.discoveryServiceAgent"
  member   = "serviceAccount:${google_bigquery_connection.biglake_connection.cloud_resource[0].service_account_id}"

  depends_on = [
    google_bigquery_connection.biglake_connection,
    google_project_iam_custom_role.customconnectiondelegate
  ]
}

output "biglake_connection" {
  value = google_bigquery_connection.biglake_connection.connection_id
}







































