terraform {
  required_version = "~> 0.14"
  required_providers {
    anaml = {
      source = "simple-machines/anaml"
    }
    anaml-operations = {
      source = "simple-machines/anaml-operations"
    }
  }
}

provider "anaml" {
  host     = "http://localhost:8080/api"
  username = "03d147fe-0fa8-4aef-bce6-e6fbcd1cd000"
  password = "test secret"
  branch   = "official"
}

provider "anaml-operations" {
  host     = "http://127.0.0.1:8080/api"
  username = "03d147fe-0fa8-4aef-bce6-e6fbcd1cd000"
  password = "test secret"
}


data "anaml_source" "s3a" {
  name = anaml-operations_source.s3a.name
}

data "anaml_cluster" "local" {
  name = anaml-operations_cluster.local.name
}

data "anaml_destination" "s3a" {
  name = anaml-operations_destination.s3a.name
}

resource "anaml_entity" "household" {
  name           = "household"
  description    = "A household level view"
  default_column = "household"
}

resource "anaml_table" "household" {
  name           = "household"
  description    = "A household level view"

  source {
    source = data.anaml_source.s3a.id
    folder = "household"
  }

  event {
    entities = {
      (anaml_entity.household.id) = "household_id"
    }
    timestamp_column = "timestamp"
  }
}

resource "anaml_table" "household_normalised" {
  name           = "household_normalised"
  description    = "A household level view"

  expression     = "SELECT * FROM household"
  sources        = [ anaml_table.household.id ]

  event {
    entities = {
      (anaml_entity.household.id) = "household"
    }
    timestamp_column = "timestamp"
  }
}

resource "anaml_feature_template" "household_count" {
  name           = "household_count"
  description    = "Count of household items"
  table          = anaml_table.household.id
  select         = "count"
  aggregation    = "sum"
}

resource "anaml_feature" "household_count" {
  for_each       = toset(["1", "2", "4"])
  days           = parseint(each.key, 10)

  name           = "household_count_${each.key}_days"
  description    = "Count of household items"
  table          = anaml_table.household.id
  select         = "count"
  aggregation    = "sum"
  template       = anaml_feature_template.household_count.id
}

resource "anaml_feature_set" "household" {
  name           = "household"
  entity         = anaml_entity.household.id
  features       = [
      anaml_feature.household_count["1"].id
    , anaml_feature.household_count["2"].id
    , anaml_feature.household_count["4"].id
    ]
}

resource "anaml_feature_store" "household_daily" {
  name           = "household_daily"
  description    = "Daily view of households"
  start_date     = "2020-01-01"
  end_date       = "2021-01-01"
  feature_set    = anaml_feature_set.household.id
  enabled        = true
  cluster        = data.anaml_cluster.local.id
  destination {
    destination = data.anaml_destination.s3a.id
    folder = "household_results"
  }
  daily_schedule {
    start_time_of_day = "00:00:00"
  }
}

resource "anaml_feature_store" "household_cron" {
  name           = "household_cron"
  description    = "Daily view of households"
  feature_set    = anaml_feature_set.household.id
  enabled        = true
  cluster        = data.anaml_cluster.local.id
  destination {
    destination = data.anaml_destination.s3a.id
    folder = "household_results"
  }
  cron_schedule {
    cron_string = "* * * * *"
  }
}

resource "anaml_feature_store" "household_never" {
  name           = "household_never"
  description    = "Manually scheduled view of households"
  start_date     = "2020-01-01"
  end_date       = "2021-01-01"
  feature_set    = anaml_feature_set.household.id
  enabled        = true
  cluster        = data.anaml_cluster.local.id
  destination {
    destination = data.anaml_destination.s3a.id
    folder = "household_results"
  }
}

resource "anaml_feature_store" "household_daily_retry" {
  name           = "household_daily_retry"
  description    = "Daily view of households"
  feature_set    = anaml_feature_set.household.id
  enabled        = true
  cluster        = data.anaml_cluster.local.id
  destination {
    destination = data.anaml_destination.s3a.id
    folder = "household_results"
  }
  daily_schedule {
    start_time_of_day = "00:00:00"

    fixed_retry_policy {
      backoff = "PT1H30M"
      max_attempts = 3
    }
  }
}

resource "anaml_feature_store" "household_cron_retry" {
  name           = "household_cron_retry"
  description    = "Daily view of households"
  feature_set    = anaml_feature_set.household.id
  enabled        = true
  cluster        = data.anaml_cluster.local.id
  destination {
    destination = data.anaml_destination.s3a.id
    folder = "household_results"
  }
  cron_schedule {
    cron_string = "* * * * *"

    fixed_retry_policy {
      backoff = "PT1H30M"
      max_attempts = 3
    }
  }
}

resource "anaml-operations_cluster" "local" {
  name               = "Terraform Local Cluster"
  description        = "A local cluster created by Terraform"
  is_preview_cluster = true

  local {
    anaml_server_url = "http://localhost:8080"
    basic {
      username = "admin"
      password = "test password"
    }
  }

  spark_config {
    enable_hive_support = true
  }
}

resource "anaml-operations_cluster" "spark_server" {
  name               = "Terraform Spark Server Cluster"
  description        = "A Spark server cluster created by Terraform"
  is_preview_cluster = false

  spark_server {
    spark_server_url = "http://localhost:8080"
  }

  spark_config {
    enable_hive_support = true
  }
}

resource "anaml-operations_source" "s3" {
  name        = "Terraform S3 Source"
  description = "An S3 source created by Terraform"

  s3 {
    bucket         = "my-bucket"
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = true
  }
}

resource "anaml-operations_source" "s3a" {
  name        = "Terraform S3A Source"
  description = "An S3A source created by Terraform"

  s3a {
    bucket      = "my-bucket"
    path        = "/path/to/file"
    endpoint    = "http://example.com"
    file_format = "orc"
    access_key  = "access"
    secret_key  = "secret"
  }
}

resource "anaml-operations_source" "hive" {
  name        = "Terraform Hive Source"
  description = "An Hive source created by Terraform"

  hive {
    database = "my_database"
  }
}

resource "anaml-operations_source" "jdbc" {
  name        = "Terraform JDBC Source"
  description = "An JDBC source created by Terraform"

  jdbc {
    url    = "jdbc://my/database"
    schema = "my_schema"

    credentials_provider {
      basic {
        username = "admin"
        password = "test password"
      }
    }
  }
}

resource "anaml-operations_source" "big_query" {
  name        = "Terraform BigQuery Source"
  description = "An BigQuery source created by Terraform"

  big_query {
    path = "/path/to/file"
  }
}

resource "anaml-operations_source" "gcs" {
  name        = "Terraform GCS Source"
  description = "An GCS source created by Terraform"

  gcs {
    bucket         = "my-bucket"
    path           = "/path/to/file"
    file_format    = "parquet"
  }
}

resource "anaml-operations_source" "local" {
  name        = "Terraform Local Source"
  description = "An Local source created by Terraform"

  local {
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = false
  }
}

resource "anaml-operations_source" "hdfs" {
  name        = "Terraform HDFS Source"
  description = "An HDFS source created by Terraform"

  hdfs {
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = false
  }
}

resource "anaml-operations_source" "kafka" {
  name        = "Terraform Kafka Source"
  description = "An Kafka source created by Terraform"

  kafka {
    bootstrap_servers = "http://bootstrap"
    schema_registry_url = "http://schema-registry"
    property {
      key = "jamf"
      gcp {
        secret_project = "example"
        secret_id = "sid"
      }
    }
  }
}

resource "anaml-operations_destination" "s3" {
  name        = "Terraform S3 Destination"
  description = "An S3 destination created by Terraform"

  s3 {
    bucket         = "my-bucket"
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = true
  }
}

resource "anaml-operations_destination" "s3a" {
  name        = "Terraform S3A Destination"
  description = "An S3A destination created by Terraform"

  s3a {
    bucket      = "my-bucket"
    path        = "/path/to/file"
    endpoint    = "http://example.com"
    file_format = "orc"
    access_key  = "access"
    secret_key  = "secret"
  }
}

resource "anaml-operations_destination" "hive" {
  name        = "Terraform Hive Destination"
  description = "An Hive destination created by Terraform"

  hive {
    database = "my_database"
  }
}

resource "anaml-operations_destination" "jdbc" {
  name        = "Terraform JDBC Destination"
  description = "An JDBC destination created by Terraform"

  jdbc {
    url    = "jdbc://my/database"
    schema = "my_schema"

    credentials_provider {
      basic {
        username = "admin"
        password = "test password"
      }
    }
  }
}

resource "anaml-operations_destination" "big_query_temporary" {
  name        = "Terraform BigQuery Destination with Temporary Staging Area"
  description = "An BigQuery destination created by Terraform"

  big_query {
    path = "/path/to/file"
    temporary_staging_area {
      bucket = "my-bucket"
    }
  }
}

resource "anaml-operations_destination" "big_query_persistent" {
  name        = "Terraform BigQuery Destination with Persistent Staging Area"
  description = "An BigQuery destination created by Terraform"

  big_query {
    path = "/path/to/file"
    persistent_staging_area {
      bucket = "my-bucket"
      path = "/path/to/file"
    }
  }
}

resource "anaml-operations_destination" "gcs" {
  name        = "Terraform GCS Destination"
  description = "An GCS destination created by Terraform"

  gcs {
    bucket         = "my-bucket"
    path           = "/path/to/file"
    file_format    = "parquet"
  }
}

resource "anaml-operations_destination" "local" {
  name        = "Terraform Local Destination"
  description = "An Local destination created by Terraform"

  local {
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = false
  }
}

resource "anaml-operations_destination" "hdfs" {
  name        = "Terraform HDFS Destination"
  description = "An HDFS destination created by Terraform"

  hdfs {
    path           = "/path/to/file"
    file_format    = "csv"
    include_header = false
  }
}

resource "anaml-operations_destination" "kafka" {
  name        = "Terraform Kafka Destination"
  description = "An Kafka destination created by Terraform"

  kafka {
    bootstrap_servers = "http://bootstrap"
    schema_registry_url = "http://schema-registry"
    property {
      key = "username"
      value = "fred"
    }
    property {
      key = "password"
      aws {
        secret_id = "secret_number_3"
      }
    }
  }
}

resource "anaml-operations_user" "jane" {
  name       = "Jane"
  email      = "jane@example.com"
  given_name = "Jane"
  surname    = "Doe"
  password   = "hunter23"
  roles      = ["viewer", "operator", "author"]
}

resource "anaml-operations_user" "john" {
  name       = "John"
  email      = "john@example.com"
  given_name = "John"
  surname    = "Doe"
  password   = "hunter23"
  roles      = ["super_user"]
}

resource "anaml-operations_caching" "caching" {
  name           = "household_caching"
  description    = "Caching of tables for households"
  prefix_uri     = "file:///tmp/anaml/caching
  spec {
    table  = anaml_table.household.id
    entity = anaml_entity.household.id
  }
  cluster        = data.anaml_cluster.local.id
  daily_schedule {
    start_time_of_day = "00:00:00"
  }
}

resource "anaml-operations_monitoring" "monitoring" {
  name           = "household_monitoring"
  description    = "Monitoring of tables for households"
  enabled        = true
  tables         = [
      anaml_table.household.id
    ]
  cluster        = data.anaml_cluster.local.id
  daily_schedule {
    start_time_of_day = "00:00:00"
  }
}

resource "anaml-operations_user_group" "engineering" {
  name        = "Engineering"
  description = "A user group with engineering members."
  members     = [
    anaml-operations_user.jane.id,
    anaml-operations_user.john.id,
  ]
}

resource "anaml-operations_branch_protection" "official" {
  protection_pattern    = "official"
  merge_approval_rules  {
    restricted {
      num_required_approvals = 1
      approvers {
        user_group {
          id = anaml-operations_user_group.engineering.id
        }
      }
    }
  }
  merge_approval_rules  {
    open {
      num_required_approvals = 2
    }
  }
  push_whitelist {
    user {
      id = anaml-operations_user.john.id
    }
  }
  apply_to_admins       = true
  allow_branch_deletion = false
}
