terraform {
  required_version = ">= 1.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.212.0"
    }
  }
}

provider "alicloud" {}

locals {
  category       = "HighAvailability"
  engine         = "PostgreSQL"
  engine_version = "15.0"
  resources = {
    class = "pg.x2.medium.2c"
  }
  storage = {
    class = "cloud_essd"
  }
}

data "alicloud_db_zones" "selected" {
  category                 = local.category
  engine                   = local.engine
  engine_version           = local.engine_version
  db_instance_class        = local.resources.class
  db_instance_storage_type = local.storage.class

  lifecycle {
    postcondition {
      condition     = length(toset(flatten([self.ids]))) > 1
      error_message = "Failed to get Avaialbe Zones"
    }
  }
}

# create vpc.

resource "alicloud_vpc" "example" {
  vpc_name    = "example"
  cidr_block  = "10.0.0.0/16"
  description = "example"
}

resource "alicloud_vswitch" "example" {
  for_each = {
    for i, c in data.alicloud_db_zones.selected.ids : c => cidrsubnet(alicloud_vpc.example.cidr_block, 8, i)
  }

  vpc_id      = alicloud_vpc.example.id
  zone_id     = each.key
  cidr_block  = each.value
  description = "example"
}

# create kms key.

data "alicloud_kms_keys" "example" {
  description_regex = "example"
}

resource "alicloud_kms_key" "example" {
  count = length(data.alicloud_kms_keys.example.ids) == 0 ? 1 : 0

  key_usage              = "ENCRYPT/DECRYPT"
  key_spec               = "Aliyun_AES_256"
  pending_window_in_days = "7"
  status                 = "Enabled"
  automatic_rotation     = "Disabled"
  description            = "example"
}

# create private dns.

#data "alicloud_pvtz_service" "selected" {
#  enable = "On"
#}

resource "alicloud_pvtz_zone" "example" {
  zone_name = "my-dev-dns"

  #  depends_on = [data.alicloud_pvtz_service.selected]
}

resource "alicloud_pvtz_zone_attachment" "example" {
  zone_id = alicloud_pvtz_zone.example.id
  vpc_ids = [alicloud_vpc.example.id]
}

# create postgresql service.

module "this" {
  source = "../.."

  infrastructure = {
    vpc_id        = alicloud_vpc.example.id
    kms_key_id    = length(data.alicloud_kms_keys.example.ids) == 0 ? alicloud_kms_key.example[0].id : data.alicloud_kms_keys.example.ids[0]
    domain_suffix = alicloud_pvtz_zone.example.zone_name
  }

  resources = local.resources
  storage   = local.storage

  depends_on = [alicloud_pvtz_zone.example]
}

output "context" {
  value = module.this.context
}

output "selector" {
  value = module.this.selector
}

output "endpoint_internal" {
  value = module.this.endpoint_internal
}

output "endpoint_internal_readonly" {
  value = module.this.endpoint_internal_readonly
}

output "database" {
  value = module.this.database
}

output "username" {
  value = module.this.username
}

output "password" {
  value = nonsensitive(module.this.password)
}
