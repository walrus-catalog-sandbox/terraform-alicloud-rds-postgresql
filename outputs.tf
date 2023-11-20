output "context" {
  description = "The input context, a map, which is used for orchestration."
  value       = var.context
}

output "selector" {
  description = "The selector, a map, which is used for dependencies or collaborations."
  value       = local.tags
}

output "endpoint_internal" {
  description = "The internal endpoints, a string list, which are used for internal access."
  value = [
    var.infrastructure.domain_suffix == null ?
    format("%s:5432", alicloud_db_instance.primary.connection_string) :
    format("%s.%s:5432", alicloud_pvtz_zone_record.primary[0].rr, var.infrastructure.domain_suffix)
  ]
}

output "endpoint_internal_readonly" {
  description = "The internal readonly endpoints, a string list, which are used for internal readonly access."
  value = local.architecture == "replication" ? flatten([
    var.infrastructure.domain_suffix == null ?
    formatlist("%s:5432", alicloud_db_readonly_instance.secondary[*].connection_string) :
    [for c in alicloud_pvtz_zone_record.secondary : format("%s.%s:5432", c.rr, var.infrastructure.domain_suffix)]
  ]) : []
}

output "database" {
  description = "The name of database to access."
  value       = var.database
}

output "username" {
  description = "The username of the account to access the database."
  value       = var.username
}

output "password" {
  description = "The password of the account to access the database."
  value       = local.password
  sensitive   = true
}