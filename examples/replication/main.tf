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
    class          = "pg.x2.medium.2c"
    readonly_class = "pgro.x2.medium.1c"
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

# create postgresql service.

module "this" {
  source = "../.."

  infrastructure = {
    vpc_id = alicloud_vpc.example.id
  }

  architecture                  = "replication"
  replication_readonly_replicas = 3
  resources                     = local.resources
  storage                       = local.storage
}

output "context" {
  value = module.this.context
}

output "refer" {
  value = nonsensitive(module.this.refer)
}

output "connection" {
  value = module.this.connection
}

output "connection_without_port" {
  value = module.this.connection_without_port
}

output "connection_readonly" {
  value = module.this.connection_readonly
}

output "connection_without_port_readonly" {
  value = module.this.connection_without_port_readonly
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

output "endpoints" {
  value = module.this.endpoints
}

output "endpoints_readonly" {
  value = module.this.endpoints_readonly
}
