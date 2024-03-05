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
  resources = {
    class          = "pg.x2.medium.2c"
    readonly_class = "pgro.x2.medium.1c"
  }
  storage = {
    class = "cloud_essd"
  }
}

# create postgresql service.

module "this" {
  source = "../.."

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

output "connection_readonly" {
  value = module.this.connection_readonly
}

output "address" {
  value = module.this.address
}

output "address_readonly" {
  value = module.this.address_readonly
}

output "port" {
  value = module.this.port
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
