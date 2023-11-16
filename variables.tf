#
# Contextual Fields
#

variable "context" {
  description = <<-EOF
Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.

Examples:
```
context:
  project:
    name: string
    id: string
  environment:
    name: string
    id: string
  resource:
    name: string
    id: string
```
EOF
  type        = map(any)
  default     = {}
}

#
# Infrastructure Fields
#

variable "infrastructure" {
  description = <<-EOF
Specify the infrastructure information for deploying.

Examples:
```
infrastructure:
  vpc_id: string                  # the ID of the VPC where the PostgreSQL service applies
  kms_key_id: sting,optional      # the ID of the KMS key which to encrypt the PostgreSQL data
  domain_suffix: string           # a private DNS namespace of the PrivateZone where to register the applied PostgreSQL service
```
EOF
  type = object({
    vpc_id        = string
    kms_key_id    = optional(string)
    domain_suffix = string
  })
}

#
# Deployment Fields
#

variable "architecture" {
  description = <<-EOF
Specify the deployment architecture, select from standalone or replication.
EOF
  type        = string
  default     = "standalone"
  validation {
    condition     = var.architecture == null || contains(["standalone", "replication"], var.architecture)
    error_message = "Invalid architecture"
  }
}

variable "replication_readonly_replicas" {
  description = <<-EOF
Specify the number of read-only replicas under the replication deployment.
EOF
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 3, 5], var.replication_readonly_replicas)
    error_message = "Invalid number of read-only replicas"
  }
}

variable "engine_version" {
  description = <<-EOF
Specify the deployment engine version, select from https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createdbinstance.
EOF
  type        = string
  default     = "15.0"
  validation {
    condition     = contains(["15.0", "14.0", "13.0"], var.engine_version)
    error_message = "Invalid version"
  }
}

variable "engine_parameters" {
  description = <<-EOF
Specify the deployment engine parameters, select for https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-describeparametertemplates.
EOF
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}

variable "database" {
  description = <<-EOF
Specify the database name.
EOF
  type        = string
  default     = "mydb"
  validation {
    condition     = var.database == null || can(regex("^[a-z][-a-z0-9_]{0,61}[a-z0-9]$", var.database))
    error_message = format("Invalid database: %s", var.database)
  }
}

variable "username" {
  description = <<-EOF
Specify the account username, ref to https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createaccount.
EOF
  type        = string
  default     = "rdsuser"
  validation {
    condition     = var.username != "root" && can(regex("^[A-Za-z_]{0,15}[a-z0-9]$", var.username))
    error_message = format("Invalid username: %s", var.username)
  }
}

variable "password" {
  description = <<-EOF
Specify the account password, ref to https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createaccount.
EOF
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition     = var.password == null || can(regex("^[A-Za-z0-9\\!#\\$%\\^&\\*\\(\\)_\\+\\-=]{8,32}", var.password))
    error_message = "Invalid password"
  }
}

variable "resources" {
  description = <<-EOF
Specify the computing resources.

The computing resource design of Alibaba Cloud is very complex, it also needs to consider on the storage resource, please view the specification document for more information.

Examples:
```
resources:
  class: string, optional            # https://www.alibabacloud.com/help/en/rds/apsaradb-rds-for-postgresql/primary-apsaradb-rds-for-postgresql-instance-types
  readonly_class: string, optional   # https://www.alibabacloud.com/help/en/rds/apsaradb-rds-for-postgresql/read-only-apsaradb-rds-for-postgresql-instance-types
```
EOF
  type = object({
    class          = optional(string)
    readonly_class = optional(string)
  })
  default = {
    class          = "rds.pg.s2.large"
    readonly_class = "rds.pg.s2.large"
  }
}

variable "storage" {
  description = <<-EOF
Specify the storage resources, select from local_ssd, cloud_ssd, cloud_essd, cloud_essd2 or cloud_essd3.

Choosing the storage resource is also related to the computing resource, please view the specification document for more information.

Examples:
```
storage:
  class: string, optional        # https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/db_instance#db_instance_storage_type
  size: number, optional         # in megabyte
```
EOF
  type = object({
    class = optional(string, "local_ssd")
    size  = optional(number, 20 * 1024)
  })
  default = {
    class = "local_ssd"
    size  = 20 * 1024
  }
  validation {
    condition     = var.storage == null || try(var.storage.size >= 20480, true)
    error_message = "Storage size must be larger than 20480Mi"
  }
}