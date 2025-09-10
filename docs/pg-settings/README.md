# PostgreSQL Settings Documentation

This document provides detailed explanations of the PostgreSQL configuration options and database flags available in the `blink-infra/modules/postgresql/gcp/variables.tf` file.

## Overview

The PostgreSQL module supports various configuration parameters for performance tuning, logging, and operational settings. These parameters are designed to optimize PostgreSQL instances for different workloads, particularly those related to Lightning Network operations and high-transaction environments.

## Configuration Parameters

### Core Instance Settings

#### `database_version`
- **Default**: `POSTGRES_14`
- **Description**: Specifies the PostgreSQL version for the instance
- **Usage**: Standard PostgreSQL version selection for Cloud SQL

#### `destination_database_version`
- **Default**: `POSTGRES_15`
- **Description**: Target PostgreSQL version for database migrations
- **Usage**: Used during database upgrade processes via Database Migration Service

#### `tier`
- **Default**: `db-custom-1-3840`
- **Description**: Machine type specification for the Cloud SQL instance
- **Usage**: Defines CPU and memory allocation (1 vCPU, 3840MB RAM in default)

#### `highly_available`
- **Default**: `true`
- **Description**: Enables high availability with automatic failover
- **Usage**: Creates a standby replica in a different zone for disaster recovery

### Performance Tuning Parameters

#### `work_mem`
- **Description**: Sets the maximum amount of memory to be used by a query operation (such as a sort or hash table) before writing to temporary disk files
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/work_mem/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Higher values can improve performance for complex queries but increase memory usage per connection

#### `checkpoint_timeout`
- **Description**: Maximum time between automatic WAL checkpoints in seconds (e.g., '600' for 10 minutes)
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default of 300 seconds)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/checkpoint_timeout/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Longer intervals reduce I/O overhead but increase recovery time and WAL disk usage

#### `random_page_cost`
- **Description**: Sets the planner's estimate of the cost of a non-sequentially-fetched disk page (e.g., '1.1')
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default of 4.0)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/random_page_cost/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Lower values (1.1-1.5) are recommended for SSD storage to reflect faster random access

#### `autovacuum_vacuum_cost_limit`
- **Description**: Vacuum cost amount available before autovacuum worker sleeps
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/autovacuum_vacuum_cost_limit/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Higher values make autovacuum more aggressive, potentially improving performance but using more I/O

### Logging and Monitoring Parameters

#### `enable_detailed_logging`
- **Description**: Enable detailed logging for the PostgreSQL instance
- **Type**: `bool`
- **Default**: `false`
- **Usage**: Enables comprehensive logging for debugging and monitoring purposes

#### `auto_explain_log_min_duration`
- **Description**: Sets the minimum execution time above which statements will be logged by auto_explain
- **Type**: `string`
- **Default**: `null` (auto_explain disabled)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://www.postgresql.org/docs/current/auto-explain.html) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Set to a duration (e.g., '1000ms') to log slow queries automatically

#### `auto_explain_log_analyze`
- **Description**: Use EXPLAIN ANALYZE for plan logging (on/off)
- **Type**: `string`
- **Default**: `null`
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://www.postgresql.org/docs/current/auto-explain.html) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: When enabled, provides actual execution statistics in addition to query plans

#### `auto_explain_log_buffers`
- **Description**: Log buffer usage statistics (on/off)
- **Type**: `string`
- **Default**: `null`
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://www.postgresql.org/docs/current/auto-explain.html) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Provides buffer hit/miss statistics in explain output when enabled

### Advanced Configuration Parameters

#### `wal_compression`
- **Description**: Enables compression of full-page writes written to WAL (zstd is available from PostgreSQL 15+ only)
- **Type**: `string`
- **Default**: `null`
- **Cloud SQL Status**: **Not listed/supported**
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/wal_compression/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Can reduce WAL size and I/O, but requires CPU for compression/decompression

#### `max_locks_per_transaction`
- **Description**: Sets the maximum number of locks per transaction (requires restart)
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default of 64)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/max_locks_per_transaction/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: May need to be increased for applications that lock many objects in a single transaction

#### `max_pred_locks_per_transaction`
- **Description**: Sets the maximum number of predicate locks per transaction (requires restart)
- **Type**: `string`
- **Default**: `null` (uses PostgreSQL default of 64)
- **Cloud SQL Status**: Supported
- **Documentation**: [PostgreSQL Docs](https://postgresqlco.nf/doc/en/param/max_pred_locks_per_transaction/) | [Cloud SQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- **Usage**: Used by serializable isolation level; may need adjustment for complex serializable transactions

### Replication and Migration Settings

#### `replication`
- **Description**: Enable logical replication for the PostgreSQL instance
- **Type**: `bool`
- **Default**: `false`
- **Usage**: Enables logical replication slots and publication/subscription functionality

#### `provision_read_replica`
- **Description**: Provision read replica
- **Type**: `bool`
- **Default**: `false`
- **Usage**: Creates a read-only replica for load distribution and disaster recovery

#### `prep_upgrade_as_source_db`
- **Description**: Configure source destination instance to be upgradable via Database Migration Service
- **Type**: `bool`
- **Default**: `false`
- **Usage**: Prepares the instance as a source for database migration operations

#### `pre_promotion`
- **Description**: Configure the destination instance which becomes the source after the terraform to act nicely with the migration service
- **Type**: `bool`
- **Default**: `false`
- **Usage**: Configures the instance for post-migration operations

### BigQuery Integration

#### `big_query_viewers`
- **Description**: List of users/service accounts with BigQuery viewer access
- **Type**: `list(string)`
- **Default**: `[]`
- **Usage**: Grants read access to BigQuery datasets created from PostgreSQL data

#### `big_query_connection_location`
- **Description**: Geographic location for BigQuery connections
- **Default**: `"US"`
- **Usage**: Determines data residency and query performance for BigQuery operations

## Best Practices

### Performance Optimization
- Set `random_page_cost` to 1.1-1.5 for SSD storage
- Adjust `work_mem` based on available memory and concurrent connections
- Use `checkpoint_timeout` of 600-900 seconds for write-heavy workloads
- Enable `auto_explain` logging for queries taking longer than 1000ms

### Monitoring and Debugging
- Enable `enable_detailed_logging` in development environments
- Use `auto_explain` parameters to identify slow queries
- Monitor autovacuum performance with appropriate cost limits

### High Availability
- Always enable `highly_available` for production instances
- Consider `provision_read_replica` for read-heavy workloads
- Use appropriate `tier` sizing based on workload requirements

## Related Documentation
- [PostgreSQL Configuration Documentation](https://www.postgresql.org/docs/current/runtime-config.html)
- [Google Cloud SQL PostgreSQL Flags](https://cloud.google.com/sql/docs/postgres/flags)
- [PostgreSQL Performance Tuning](https://postgresqlco.nf/doc/en/param/)
