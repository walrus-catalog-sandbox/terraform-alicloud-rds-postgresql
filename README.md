# Alibaba ApsaraDB RDS for PostgreSQL Service

Terraform module which deploys [PostgreSQL](https://www.alibabacloud.com/help/en/rds/apsaradb-rds-for-postgresql) service on Alibaba Cloud.

- [x] Support standalone(one read-write HA instance) and replication(one read-write HA instance and multiple read-only instances, for read write splitting).

## Usage

```hcl
module "postgresql" {
  source = "..."

  infrastructure = {
    vpc_id        = "..."
    domain_suffix = "..."
  }

  architecture    = "replication"
  engine_version  = "15.0"          # https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createdbinstance
}
```

## Examples

- [Replication](./examples/replication)
- [Standalone](./examples/standalone)


## Contributing

Please read our [contributing guide](./docs/CONTRIBUTING.md) if you're interested in contributing to Walrus template.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_alicloud"></a> [alicloud](#requirement\_alicloud) | >= 1.212.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_alicloud"></a> [alicloud](#provider\_alicloud) | >= 1.212.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.5.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [alicloud_db_database.database](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/db_database) | resource |
| [alicloud_db_instance.primary](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/db_instance) | resource |
| [alicloud_db_readonly_instance.secondary](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/db_readonly_instance) | resource |
| [alicloud_pvtz_zone_record.primary](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/pvtz_zone_record) | resource |
| [alicloud_pvtz_zone_record.secondary](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/pvtz_zone_record) | resource |
| [alicloud_rds_account.account](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/rds_account) | resource |
| [alicloud_security_group.target](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/security_group) | resource |
| [alicloud_security_group_rule.target](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/security_group_rule) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [alicloud_db_zones.selected](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/db_zones) | data source |
| [alicloud_kms_keys.selected](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/kms_keys) | data source |
| [alicloud_pvtz_zones.selected](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/pvtz_zones) | data source |
| [alicloud_vpcs.selected](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/vpcs) | data source |
| [alicloud_vswitches.selected](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/data-sources/vswitches) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Specify the deployment architecture, select from standalone or replication. | `string` | `"standalone"` | no |
| <a name="input_context"></a> [context](#input\_context) | Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.<br><br>Examples:<pre>context:<br>  project:<br>    name: string<br>    id: string<br>  environment:<br>    name: string<br>    id: string<br>  resource:<br>    name: string<br>    id: string</pre> | `map(any)` | `{}` | no |
| <a name="input_database"></a> [database](#input\_database) | Specify the database name. | `string` | `"mydb"` | no |
| <a name="input_engine_parameters"></a> [engine\_parameters](#input\_engine\_parameters) | Specify the deployment engine parameters, select for https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-describeparametertemplates. | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `null` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Specify the deployment engine version, select from https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createdbinstance. | `string` | `"15.0"` | no |
| <a name="input_infrastructure"></a> [infrastructure](#input\_infrastructure) | Specify the infrastructure information for deploying.<br><br>Examples:<pre>infrastructure:<br>  vpc_id: string                  # the ID of the VPC where the PostgreSQL service applies<br>  kms_key_id: sting,optional      # the ID of the KMS key which to encrypt the PostgreSQL data<br>  domain_suffix: string           # a private DNS namespace of the PrivateZone where to register the applied PostgreSQL service</pre> | <pre>object({<br>    vpc_id        = string<br>    kms_key_id    = optional(string)<br>    domain_suffix = string<br>  })</pre> | n/a | yes |
| <a name="input_password"></a> [password](#input\_password) | Specify the account password, ref to https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createaccount. | `string` | `null` | no |
| <a name="input_replication_readonly_replicas"></a> [replication\_readonly\_replicas](#input\_replication\_readonly\_replicas) | Specify the number of read-only replicas under the replication deployment. | `number` | `1` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Specify the computing resources.<br><br>The computing resource design of Alibaba Cloud is very complex, it also needs to consider on the storage resource, please view the specification document for more information.<br><br>Examples:<pre>resources:<br>  class: string, optional            # https://www.alibabacloud.com/help/en/rds/apsaradb-rds-for-postgresql/primary-apsaradb-rds-for-postgresql-instance-types<br>  readonly_class: string, optional   # https://www.alibabacloud.com/help/en/rds/apsaradb-rds-for-postgresql/read-only-apsaradb-rds-for-postgresql-instance-types</pre> | <pre>object({<br>    class          = optional(string)<br>    readonly_class = optional(string)<br>  })</pre> | <pre>{<br>  "class": "rds.pg.s2.large",<br>  "readonly_class": "rds.pg.s2.large"<br>}</pre> | no |
| <a name="input_storage"></a> [storage](#input\_storage) | Specify the storage resources, select from local\_ssd, cloud\_ssd, cloud\_essd, cloud\_essd2 or cloud\_essd3.<br><br>Choosing the storage resource is also related to the computing resource, please view the specification document for more information.<br><br>Examples:<pre>storage:<br>  class: string, optional        # https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/db_instance#db_instance_storage_type<br>  size: number, optional         # in megabyte</pre> | <pre>object({<br>    class = optional(string, "local_ssd")<br>    size  = optional(number, 20 * 1024)<br>  })</pre> | <pre>{<br>  "class": "local_ssd",<br>  "size": 20480<br>}</pre> | no |
| <a name="input_username"></a> [username](#input\_username) | Specify the account username, ref to https://www.alibabacloud.com/help/en/rds/developer-reference/api-rds-2014-08-15-createaccount. | `string` | `"rdsuser"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_context"></a> [context](#output\_context) | The input context, a map, which is used for orchestration. |
| <a name="output_database"></a> [database](#output\_database) | The name of database to access. |
| <a name="output_endpoint_internal"></a> [endpoint\_internal](#output\_endpoint\_internal) | The internal endpoints, a string list, which are used for internal access. |
| <a name="output_endpoint_internal_readonly"></a> [endpoint\_internal\_readonly](#output\_endpoint\_internal\_readonly) | The internal readonly endpoints, a string list, which are used for internal readonly access. |
| <a name="output_password"></a> [password](#output\_password) | The password of the account to access the database. |
| <a name="output_selector"></a> [selector](#output\_selector) | The selector, a map, which is used for dependencies or collaborations. |
| <a name="output_username"></a> [username](#output\_username) | The username of the account to access the database. |
<!-- END_TF_DOCS -->

## License

Copyright (c) 2023 [Seal, Inc.](https://seal.io)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [LICENSE](./LICENSE) file for details.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
