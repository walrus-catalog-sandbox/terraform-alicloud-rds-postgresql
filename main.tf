locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  namespace = join("-", [local.project_name, local.environment_name])

  tags = {
    "Name" = join("-", [local.namespace, local.resource_name])

    "walrus.seal.io/catalog-name"     = "terraform-alicloud-rds-postgresql"
    "walrus.seal.io/project-id"       = local.project_id
    "walrus.seal.io/environment-id"   = local.environment_id
    "walrus.seal.io/resource-id"      = local.resource_id
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }

  architecture = coalesce(var.architecture, "standalone")
}

# create vpc.

resource "alicloud_vpc" "default" {
  count = var.infrastructure.vpc_id == null ? 1 : 0

  vpc_name    = "default"
  cidr_block  = "10.0.0.0/16"
  description = "default"
}

resource "alicloud_vswitch" "default" {
  for_each = var.infrastructure.vpc_id == null ? {
    for i, c in data.alicloud_db_zones.selected.ids : c => cidrsubnet(alicloud_vpc.default[0].cidr_block, 8, i)
  } : {}

  vpc_id      = alicloud_vpc.default[0].id
  zone_id     = each.key
  cidr_block  = each.value
  description = "default"

  depends_on = [data.alicloud_db_zones.selected]
}

#
# Ensure
#

data "alicloud_vpcs" "selected" {
  ids = [var.infrastructure.vpc_id != null ? var.infrastructure.vpc_id : alicloud_vpc.default[0].id]

  status = "Available"

  lifecycle {
    postcondition {
      condition     = length(self.ids) == 1
      error_message = "VPC is not avaiable"
    }
  }

  depends_on = [alicloud_vpc.default]
}

data "alicloud_vswitches" "selected" {
  vpc_id = data.alicloud_vpcs.selected.ids[0]

  lifecycle {
    postcondition {
      condition     = local.architecture == "replication" ? length(self.ids) > 1 : length(self.ids) > 0
      error_message = "Replication mode needs multiple vswitches"
    }
  }

  depends_on = [alicloud_vswitch.default]
}

data "alicloud_kms_keys" "selected" {
  count = var.infrastructure.kms_key_id != null ? 1 : 0

  ids = [var.infrastructure.kms_key_id]

  status = "Enabled"
}

data "alicloud_pvtz_zones" "selected" {
  count = var.infrastructure.domain_suffix == null ? 0 : 1

  keyword     = var.infrastructure.domain_suffix
  search_mode = "EXACT"

  lifecycle {
    postcondition {
      condition     = length(self.ids) == 1
      error_message = "Failed to get available private zone"
    }
  }
}

#
# Random
#

# create a random password for blank password input.

resource "random_password" "password" {
  length      = 16
  special     = false
  lower       = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
}

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name        = join("-", [local.resource_name, random_string.name_suffix.result])
  fullname    = format("walrus-%s", md5(join("-", [local.namespace, local.name])))
  description = "Created by Walrus catalog, and provisioned by Terraform."
  database    = coalesce(var.database, "mydb")
  username    = coalesce(var.username, "rdsuser")
  password    = coalesce(var.password, random_password.password.result)

  replication_readonly_replicas = var.replication_readonly_replicas == 0 ? 1 : var.replication_readonly_replicas
}

#
# Deployment
#

locals {
  version = coalesce(var.engine_version, "16.0")
  parameters = merge(
    {
      synchronous_commit = "off"
    },
    {
      for c in(var.engine_parameters != null ? var.engine_parameters : []) : c.name => c.value
      if try(c.value != "", false)
    }
  )
  publicly_accessible = try(var.infrastructure.publicly_accessible, false)
}

data "alicloud_db_zones" "selected" {
  category                 = "HighAvailability"
  engine                   = "PostgreSQL"
  engine_version           = local.version
  db_instance_class        = try(var.resources.class, "pg.n2.2c.1m")
  db_instance_storage_type = try(var.storage.class, "cloud_essd")

  lifecycle {
    postcondition {
      condition     = length(self.ids) > 1
      error_message = "VPC needs multiple zones distributed in different vswitches"
    }
  }
}

# create primary instance.

locals {
  zones = setintersection(data.alicloud_db_zones.selected.ids, data.alicloud_vswitches.selected.vswitches[*].zone_id)
  vswitch_zone_map = {
    for v in data.alicloud_vswitches.selected.vswitches : v.id => v.zone_id
    if contains(local.zones, v.zone_id)
  }
  vswitches = keys(local.vswitch_zone_map)
}

resource "alicloud_db_instance" "primary" {
  instance_name = local.fullname
  tags          = local.tags

  category        = "HighAvailability"
  vpc_id          = data.alicloud_vpcs.selected.ids[0]
  vswitch_id      = join(",", [local.vswitches[0], local.vswitches[1]])
  zone_id         = local.vswitch_zone_map[local.vswitches[0]]
  zone_id_slave_a = local.vswitch_zone_map[local.vswitches[1]]
  security_ips    = local.publicly_accessible ? ["0.0.0.0/0", data.alicloud_vpcs.selected.vpcs[0].cidr_block] : [data.alicloud_vpcs.selected.vpcs[0].cidr_block]

  engine         = "PostgreSQL"
  engine_version = local.version
  dynamic "parameters" {
    for_each = try(nonsensitive(local.parameters), local.parameters)
    content {
      name  = parameters.key
      value = parameters.value
    }
  }

  instance_type            = data.alicloud_db_zones.selected.db_instance_class
  db_instance_storage_type = data.alicloud_db_zones.selected.db_instance_storage_type
  storage_auto_scale       = "Disable"
  instance_storage         = try(var.storage.size / 1024, 20)
  encryption_key           = try(var.storage.class != "local_ssd", false) ? try(data.alicloud_kms_keys.selected[0].ids[0], null) : null

  force_restart       = true
  deletion_protection = false

  depends_on = [alicloud_vswitch.default]
}

# create database.

resource "alicloud_db_database" "database" {
  name        = local.database
  description = local.description

  instance_id   = alicloud_db_instance.primary.id
  character_set = "utf8"

  lifecycle {
    ignore_changes = [
      name,
      character_set,
    ]
  }
}

resource "alicloud_rds_account" "account" {
  account_description = local.description

  db_instance_id   = alicloud_db_instance.primary.id
  account_type     = "Super"
  account_name     = local.username
  account_password = local.password

  lifecycle {
    ignore_changes = [
      account_name,
      account_password,
    ]
  }
}

resource "alicloud_db_account_privilege" "privilege" {
  count = local.username != "postgres" ? 1 : 0

  privilege    = "DBOwner"
  instance_id  = alicloud_db_instance.primary.id
  account_name = alicloud_rds_account.account.account_name
  db_names     = [alicloud_db_database.database.name]

  depends_on = [
    alicloud_rds_account.account,
    alicloud_db_database.database
  ]

  lifecycle {
    ignore_changes = [
      account_name,
      db_names,
    ]
  }
}

# create secondary instance.

resource "alicloud_db_readonly_instance" "secondary" {
  count = local.architecture == "replication" ? local.replication_readonly_replicas : 0

  instance_name = join("-", [local.fullname, "secondary", tostring(count.index)])
  tags          = local.tags

  master_db_instance_id = alicloud_db_instance.primary.id
  vswitch_id            = local.vswitches[count.index % length(local.vswitches)]
  zone_id               = local.vswitch_zone_map[local.vswitches[count.index % length(local.vswitches)]]
  security_ips          = local.publicly_accessible ? ["0.0.0.0/0", data.alicloud_vpcs.selected.vpcs[0].cidr_block] : [data.alicloud_vpcs.selected.vpcs[0].cidr_block]

  engine_version = alicloud_db_instance.primary.engine_version
  dynamic "parameters" {
    for_each = try(nonsensitive(local.parameters), local.parameters)
    content {
      name  = parameters.key
      value = parameters.value
    }
  }

  instance_type            = coalesce(var.resources.readonly_class, alicloud_db_instance.primary.instance_type)
  db_instance_storage_type = alicloud_db_instance.primary.db_instance_storage_type
  instance_storage         = alicloud_db_instance.primary.instance_storage

  force_restart       = true
  deletion_protection = false

  depends_on = [
    alicloud_db_database.database,
    alicloud_rds_account.account
  ]
}

#
# Exposing
#

resource "alicloud_db_connection" "primary" {
  count = local.publicly_accessible ? 1 : 0

  instance_id = alicloud_db_instance.primary.id
  port        = local.port
}

resource "alicloud_db_connection" "secondary" {
  count = local.publicly_accessible && local.architecture == "replication" ? local.replication_readonly_replicas : 0

  instance_id = alicloud_db_readonly_instance.secondary[count.index].id
  port        = local.port
}

resource "alicloud_pvtz_zone_record" "primary" {
  count = var.infrastructure.domain_suffix == null ? 0 : 1

  zone_id = data.alicloud_pvtz_zones.selected[0].ids[0]

  type  = "CNAME"
  rr    = format("%s.%s", (local.architecture == "replication" ? join("-", [local.name, "primary"]) : local.name), local.namespace)
  value = alicloud_db_instance.primary.connection_string
  ttl   = 30
}

resource "alicloud_pvtz_zone_record" "secondary" {
  count = var.infrastructure.domain_suffix != null && local.architecture == "replication" ? local.replication_readonly_replicas : 0

  zone_id = data.alicloud_pvtz_zones.selected[0].ids[0]

  type  = "CNAME"
  rr    = format("%s.%s", join("-", [local.name, "secondary", tostring(count.index)]), local.namespace)
  value = alicloud_db_readonly_instance.secondary[count.index].connection_string
  ttl   = 30
}
