locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  namespace = join("-", [local.project_name, local.environment_name])

  tags = {
    "walrus.seal.io/project-id"       = local.project_id
    "walrus.seal.io/environment-id"   = local.environment_id
    "walrus.seal.io/resource-id"      = local.resource_id
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }

  architecture = coalesce(var.architecture, "standalone")
}

#
# Ensure
#

data "alicloud_vpcs" "selected" {
  ids = [var.infrastructure.vpc_id]

  status = "Available"

  lifecycle {
    postcondition {
      condition     = length(self.ids) == 1
      error_message = "VPC is not avaiable"
    }
  }
}

data "alicloud_vswitches" "selected" {
  vpc_id = data.alicloud_vpcs.selected.ids[0]

  lifecycle {
    postcondition {
      condition     = local.architecture == "replication" ? length(self.ids) > 1 : length(self.ids) > 0
      error_message = "Replication mode needs multiple vswitches"
    }
  }
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
  length      = 10
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
  name     = join("-", [local.resource_name, random_string.name_suffix.result])
  fullname = join("-", [local.namespace, local.name])
  password = coalesce(var.password, random_password.password.result)
}

#
# Deployment
#

# create security group.

resource "alicloud_security_group" "target" {
  name = local.fullname
  tags = local.tags

  vpc_id = data.alicloud_vpcs.selected.ids[0]
}

resource "alicloud_security_group_rule" "target" {
  security_group_id = alicloud_security_group.target.id

  type        = "ingress"
  ip_protocol = "tcp"
  cidr_ip     = data.alicloud_vpcs.selected.vpcs[0].cidr_block
  nic_type    = "intranet"
  policy      = "accept"
  port_range  = "5432/5432"
  priority    = 1
  description = "Access PostgreSQL from VPC"
}

locals {
  version = coalesce(var.engine_version, "15.0")
  parameters = merge(
    {
      synchronous_commit = "off"
    },
    {
      for c in(var.engine_parameters != null ? var.engine_parameters : []) : c.name => c.value
      if c.value != ""
    }
  )
}

data "alicloud_db_zones" "selected" {
  category                 = "HighAvailability"
  engine                   = "PostgreSQL"
  engine_version           = local.version
  db_instance_class        = try(var.resources.class, "rds.pg.s2.large")
  db_instance_storage_type = try(var.storage.class, "local_ssd")

  lifecycle {
    postcondition {
      condition     = length(self.ids) > 1
      error_message = "VPC needs multiple zones distributed in different vswitches"
    }
    postcondition {
      condition     = length(setintersection(self.ids, data.alicloud_vswitches.selected.vswitches[*].zone_id)) > 1
      error_message = format("Selected resource class %s and storage class %s are not available in VPC", self.db_instance_class, self.db_instance_storage_type)
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
  instance_name      = local.fullname
  tags               = local.tags
  category           = "HighAvailability"
  vpc_id             = data.alicloud_vpcs.selected.ids[0]
  vswitch_id         = join(",", [local.vswitches[0], local.vswitches[1]])
  zone_id            = local.vswitch_zone_map[local.vswitches[0]]
  zone_id_slave_a    = local.vswitch_zone_map[local.vswitches[1]]
  security_group_ids = [alicloud_security_group.target.id]

  engine         = "PostgreSQL"
  engine_version = local.version
  dynamic "parameters" {
    for_each = local.parameters
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
}

# create database.

resource "alicloud_db_database" "database" {
  instance_id   = alicloud_db_instance.primary.id
  name          = var.database
  character_set = "utf8"

  lifecycle {
    ignore_changes = [
      name,
      character_set,
    ]
  }
}

resource "alicloud_rds_account" "account" {
  db_instance_id   = alicloud_db_instance.primary.id
  account_type     = "Super"
  account_name     = var.username
  account_password = local.password

  lifecycle {
    ignore_changes = [
      account_name,
      account_password,
    ]
  }
}

# create secondary instance.

resource "alicloud_db_readonly_instance" "secondary" {
  count = local.architecture == "replication" ? coalesce(var.replication_readonly_replicas, 1) : 0

  master_db_instance_id = alicloud_db_instance.primary.id

  instance_name = join("-", [local.fullname, "secondary", tostring(count.index)])
  tags          = local.tags
  vswitch_id    = local.vswitches[count.index % length(local.vswitches)]
  zone_id       = local.vswitch_zone_map[local.vswitches[count.index % length(local.vswitches)]]

  engine_version = alicloud_db_instance.primary.engine_version
  dynamic "parameters" {
    for_each = local.parameters
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

resource "alicloud_pvtz_zone_record" "primary" {
  count = var.infrastructure.domain_suffix == null ? 0 : 1

  zone_id = data.alicloud_pvtz_zones.selected[0].ids[0]

  type = "CNAME"
  rr = format("%s.%s", (local.architecture == "replication" ? join("-", [
    local.name, "primary"
  ]) : local.name), local.namespace)
  value = alicloud_db_instance.primary.connection_string
  ttl   = 30
}

resource "alicloud_pvtz_zone_record" "secondary" {
  count = var.infrastructure.domain_suffix != null && local.architecture == "replication" ? coalesce(var.replication_readonly_replicas, 1) : 0

  zone_id = data.alicloud_pvtz_zones.selected[0].ids[0]

  type  = "CNAME"
  rr    = format("%s.%s", join("-", [local.name, "secondary", tostring(count.index)]), local.namespace)
  value = alicloud_db_readonly_instance.secondary[count.index].connection_string
  ttl   = 30
}
