variable "gcp_project" {}
variable "vpc_name" {}
variable "instance_name" {}
variable "region" {
  default = "us-east1"
}
variable "destroyable" {
  default = false
}
variable "user_can_create_db" {
  default = false
}
variable "highly_available" {
  default = true
}
variable "tier" {
  default = "db-custom-1-3840"
}
variable "max_connections" { default = 0 }

# LND PostgreSQL tuning parameters
variable "work_mem" {
  description = "Sets the maximum amount of memory to be used by a query operation (such as a sort or hash table) before writing to temporary disk files"
  type        = string
  default     = null
}
variable "wal_compression" {
  description = "WAL compression method (e.g., 'zstd', 'lz4', 'pglz')"
  type        = string
  default     = null
}
variable "checkpoint_timeout" {
  description = "Maximum time between automatic WAL checkpoints (e.g., '10min')"
  type        = string
  default     = null
}
variable "random_page_cost" {
  description = "Sets the planner's estimate of the cost of a non-sequentially-fetched disk page (e.g., '1.1')"
  type        = string
  default     = null
}
variable "jit_above_cost" {
  description = "Sets the query cost above which JIT compilation is activated (-1 to disable)"
  type        = string
  default     = null
}
variable "jit" {
  description = "Allows JIT compilation (on/off)"
  type        = string
  default     = null
}
variable "autovacuum_vacuum_cost_limit" {
  description = "Vacuum cost amount available before autovacuum worker sleeps"
  type        = string
  default     = null
}
variable "shared_preload_libraries" {
  description = "Lists shared libraries to be preloaded at server start"
  type        = string
  default     = null
}
variable "auto_explain_log_min_duration" {
  description = "Sets the minimum execution time above which statements will be logged by auto_explain"
  type        = string
  default     = null
}
variable "auto_explain_log_analyze" {
  description = "Use EXPLAIN ANALYZE for plan logging (on/off)"
  type        = string
  default     = null
}
variable "auto_explain_log_buffers" {
  description = "Log buffer usage statistics (on/off)"
  type        = string
  default     = null
}
variable "max_locks_per_transaction" {
  description = "Sets the maximum number of locks per transaction"
  type        = string
  default     = null
}
variable "max_pred_locks_per_transaction" {
  description = "Sets the maximum number of predicate locks per transaction"
  type        = string
  default     = null
}
variable "synchronous_standby_names" {
  description = "List of names of potential synchronous standbys"
  type        = string
  default     = null
}
# End of LND PostgreSQL tuning parameters

variable "enable_detailed_logging" {
  description = "Enable detailed logging for the PostgreSQL instance"
  type        = bool
  default     = false
}
variable "database_version" {
  default = "POSTGRES_14"
}
variable "destination_database_version" {
  default = "POSTGRES_15"
}
variable "big_query_viewers" {
  default = []
  type    = list(string)
}
variable "databases" {
  type = list(string)
}
variable "replication" {
  description = "Enable logical replication for the PostgreSQL instance"
  type        = bool
  default     = false
}
variable "provision_read_replica" {
  description = "Provision read replica"
  type        = bool
  default     = false
}
variable "big_query_connection_location" {
  default = "US"
}

variable "prep_upgrade_as_source_db" {
  description = "Configure source destination instance to be upgradable via Database Migration Service"
  type        = bool
  default     = false
}

variable "pre_promotion" {
  description = "Configure the destination instance which becomes the source after the terraform to act nicely with the migration service"
  type        = bool
  default     = false
}

locals {
  gcp_project                  = var.gcp_project
  vpc_name                     = var.vpc_name
  region                       = var.region
  instance_name                = var.instance_name
  database_version             = var.database_version
  destination_database_version = var.destination_database_version
  destroyable                  = var.destroyable
  highly_available             = var.highly_available
  tier                         = var.tier
  max_connections              = var.max_connections

  # LND PostgreSQL tuning parameters
  work_mem                       = var.work_mem
  wal_compression                = var.wal_compression
  checkpoint_timeout             = var.checkpoint_timeout
  random_page_cost               = var.random_page_cost
  jit_above_cost                 = var.jit_above_cost
  jit                            = var.jit
  autovacuum_vacuum_cost_limit   = var.autovacuum_vacuum_cost_limit
  shared_preload_libraries       = var.shared_preload_libraries
  auto_explain_log_min_duration  = var.auto_explain_log_min_duration
  auto_explain_log_analyze       = var.auto_explain_log_analyze
  auto_explain_log_buffers       = var.auto_explain_log_buffers
  max_locks_per_transaction      = var.max_locks_per_transaction
  max_pred_locks_per_transaction = var.max_pred_locks_per_transaction
  synchronous_standby_names      = var.synchronous_standby_names

  databases                     = var.databases
  migration_databases           = concat(var.databases, ["postgres"])
  big_query_viewers             = var.big_query_viewers
  replication                   = var.replication
  provision_read_replica        = var.provision_read_replica
  big_query_connection_location = var.big_query_connection_location
  prep_upgrade_as_source_db     = var.prep_upgrade_as_source_db
  pre_promotion                 = var.pre_promotion
  database_port                 = 5432
}
