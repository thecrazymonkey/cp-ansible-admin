# Confluent Platform REST Admin

A comprehensive Ansible project for managing Confluent Platform components through declarative configuration. This project provides automation for topics, RBAC, quotas, ACLs, connectors, schemas, and secrets management.

## Overview

The Confluent Platform REST Admin project enables infrastructure-as-code management of Confluent Platform environments. It supports both new cluster deployments and existing cluster management by performing initial state dumps and applying desired configurations through REST APIs and CLI tools.

## Requirements

- **Confluent Platform 7.0 or later** (verified against CP 8.0). The topic role requires
  `partitions_count` in the `/kafka/v3/clusters/{id}/topics` response — it asserts this and
  fails with an explicit message rather than dumping incomplete state — and fetches every
  topic's configuration in one call to `/kafka/v3/clusters/{id}/topics/-/configs`. The
  pre-7.0 fallbacks that issued one request per topic have been removed.
- **Kafka Connect 5.5 or later** for the connectors role, which uses `/connectors?expand=info`
  to retrieve all connector configurations in a single call. Older workers ignore `expand` and
  return a plain name list; the role asserts on this and fails with a version message.

## Supported Use Cases

1. **Topic Management** - Create, update, delete topics with configuration management
2. **RBAC Management** - Manage role-based access control and permissions
3. **Quota Management** - Configure user and client quotas
4. **ACL Management** - Manage both Zookeeper and Centralized ACLs
5. **Connector Management** - Deploy and manage Kafka Connect connectors
6. **Schema Management** - Register, update, and manage schemas in Schema Registry
7. **Secrets Management** - Manage secrets in Kafka Connect Secret Registry

## Project Structure

```
cp-rest-admin/
├── roles/
│   ├── topic/              # Kafka topics management
│   ├── rbac/               # Role-based access control
│   ├── quota/              # User and client quotas
│   ├── zacl/               # Zookeeper ACLs
│   ├── cacl/               # Centralized ACLs
│   ├── connectors/         # Kafka Connect connectors
│   ├── schema/             # Schema Registry management
│   ├── secretsregistry/    # Connect Secret Registry
│   └── common/             # Shared functionality
├── examples/               # Example configurations
├── tests/                  # Integration tests
├── settings/               # Configuration files
├── *.yml                  # Management playbooks
└── hosts_*.yml            # Inventory files
```

## Roles Overview

### Topic Management (`topic`)
- **Purpose**: Manage Kafka topics, partitions, and configurations
- **Features**: Create/update/delete topics, partition management, configuration changes
- **API**: Confluent Server REST API v3
- **Authentication**: Basic Auth, OAuth

### RBAC Management (`rbac`)
- **Purpose**: Manage role-based access control and permissions
- **Features**: Create/update/delete role bindings, cluster-wide permissions
- **API**: Confluent MDS (Metadata Service) REST API
- **Authentication**: Basic Auth (SystemAdmin required)
- **Note**: Uses separate MDS variables (`mds_server_url`, `mds_user`, `mds_user_password`)

### Quota Management (`quota`)
- **Purpose**: Configure rate limits for users and clients
- **Features**: Producer/consumer byte rates, request percentage limits
- **API**: Kafka Admin API (CLI-based)
- **Authentication**: SASL/SSL via client properties

### Zookeeper ACL Management (`zacl`)
- **Purpose**: Manage traditional Kafka ACLs
- **Features**: Topic, group, cluster ACLs with various permissions
- **API**: Confluent Server REST API
- **Authentication**: Basic Auth

### Centralized ACL Management (`cacl`)
- **Purpose**: Manage centralized ACLs through MDS
- **Features**: Unified ACL management across clusters
- **API**: Confluent MDS REST API
- **Authentication**: Basic Auth
- **Note**: Uses separate MDS variables (`mds_server_url`, `mds_user`, `mds_user_password`)

### Connector Management (`connectors`)
- **Purpose**: Deploy and manage Kafka Connect connectors
- **Features**: Create/update/delete connectors, configuration management
- **API**: Kafka Connect REST API
- **Authentication**: Basic Auth

### Schema Management (`schema`)
- **Purpose**: Manage Schema Registry schemas
- **Features**: Register/update/delete schemas, compatibility settings
- **API**: Schema Registry REST API
- **Authentication**: Basic Auth, TLS

### Secret Registry Management (`secretsregistry`)
- **Purpose**: Manage secrets in Kafka Connect Secret Registry
- **Features**: Create/update/delete secrets, version management
- **API**: Connect Secret Registry REST API
- **Authentication**: Basic Auth, OAuth

## Common Configuration

### Required Variables

Most roles use these standard REST API variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `rest_server_url` | Kafka REST API URL | `https://kafka1.confluent.io:8090` |
| `rest_user` | Username for authentication | `admin` |
| `rest_user_password` | Password for authentication | `admin` |

### RBAC-Specific Variables

RBAC management uses separate MDS (Metadata Service) variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `mds_server_url` | MDS REST API URL | `https://kafka1.confluent.io:8090` |
| `mds_user` | MDS username (must be SystemAdmin) | `mds` |
| `mds_user_password` | MDS password | `mds` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `oauth_enabled` | `false` | Enable OAuth authentication |
| `oauth_token_uri` | `""` | OAuth token endpoint |
| `oauth_client_id` | `""` | OAuth client ID |
| `oauth_client_secret` | `""` | OAuth client secret |
| `cluster_id` | `""` | Kafka cluster ID (auto-discovered if empty) |
| `binary_base_path` | `/home/confluent/confluent-7.0.1` | Path to Confluent binaries |
| `api_timeout` | `30` | Timeout in seconds for every Confluent REST API call, across all roles |
| `oauth_timeout` | `{{ api_timeout }}` | Timeout in seconds for the IdP token call only |

> Both are defined in the `common` role, which every management playbook imports first.
>
> `oauth_timeout` defaults to `api_timeout`, so setting `api_timeout` alone still covers
> everything. Override it separately when your identity provider is slower than the Confluent
> APIs — lowering `api_timeout` to fail fast on REST calls would otherwise shorten the token
> call too.
>
> `api_timeout` replaces the former `secret_timeout`. An inventory that still sets
> `secret_timeout` keeps working: the `secretsregistry` role honours the value for that run and
> prints a deprecation notice telling you to rename it.

### TLS Configuration

| Variable | Description |
|----------|-------------|
| `client_tls_cert` | Client certificate path |
| `client_tls_key` | Client private key path |
| `ca_tls_path` | CA certificate path |

## Usage Examples

### 1. Topic Management

```bash
# Preview topic changes
ansible-playbook -i hosts_sample.yml topics_management.yml --check -vv

# Apply topic configuration
ansible-playbook -i hosts_sample.yml topics_management.yml

# Dump current topics
ansible-playbook -i hosts_sample.yml topics_management.yml -e topic_dump_file=true
```

### 2. RBAC Management

```bash
# Preview RBAC changes (uses mds_server_url, mds_user, mds_user_password)
ansible-playbook -i hosts_sample.yml rbac_management.yml --check -vv

# Apply RBAC configuration
ansible-playbook -i hosts_sample.yml rbac_management.yml

# Dump current role bindings
ansible-playbook -i hosts_sample.yml rbac_management.yml -e rbac_dump_file=true
```

### 3. Quota Management

```bash
# Preview quota changes
ansible-playbook -i hosts_sample.yml quota_management.yml --check -vv

# Apply quota configuration
ansible-playbook -i hosts_sample.yml quota_management.yml
```

### 4. ACL Management

```bash
# Zookeeper ACLs
ansible-playbook -i hosts_sample.yml zacl_management.yml --check -vv
ansible-playbook -i hosts_sample.yml zacl_management.yml

# Centralized ACLs (uses mds_server_url, mds_user, mds_user_password)
ansible-playbook -i hosts_sample.yml cacl_management.yml --check -vv
ansible-playbook -i hosts_sample.yml cacl_management.yml
```

### 5. Connector Management

```bash
# Preview connector changes
ansible-playbook -i hosts_sample.yml connectors_management.yml --check -vv

# Apply connector configuration
ansible-playbook -i hosts_sample.yml connectors_management.yml
```

### 6. Schema Management

```bash
# Preview schema changes
ansible-playbook -i hosts_sample.yml schemas_management.yml --check -vv

# Apply schema configuration
ansible-playbook -i hosts_sample.yml schemas_management.yml

# Backup schemas
ansible-playbook -i hosts_sample.yml schemas_management.yml -e dump_only=true

# Restore schemas
ansible-playbook -i hosts_sample.yml schemas_management.yml -e restore_only=true
```

### 7. Secret Registry Management

```bash
# Preview secret changes
ansible-playbook -i hosts_sample.yml secretsregistry_management.yml --check -vv

# Apply secret configuration
ansible-playbook -i hosts_sample.yml secretsregistry_management.yml -e @examples/secrets_example.yml
```

## Configuration Formats

### Topics Configuration

```yaml
topics:
  - topic_name: my-topic
    partitions_count: 6
    replication_factor: 3
    configs:
      - name: min.insync.replicas
        value: "2"
      - name: retention.ms
        value: "604800000"
```

### RBAC Configuration

```yaml
rolebindings:
  - clusterName: my-cluster
    name: connector-admin
    principal: User:connectAdmin
    resources:
      - name: my-topic
        patternType: PREFIXED
        resourceType: Topic
    role: DeveloperWrite
```

### Quota Configuration

```yaml
quotas:
  users:
    - users: alice
      consumer_byte_rate: 1000000.0
      producer_byte_rate: 1000000.0
      request_percentage: 20.0
  clients:
    - clients: my-client
      consumer_byte_rate: 500000.0
      producer_byte_rate: 500000.0
```

### Connector Configuration

```yaml
connectors:
  - name: datagen-source
    connector.class: io.confluent.kafka.connect.datagen.DatagenConnector
    kafka.topic: test-topic
    quickstart: stock_trades
    key.converter: org.apache.kafka.connect.storage.StringConverter
    value.converter: io.confluent.connect.avro.AvroConverter
    value.converter.schema.registry.url: http://schema-registry:8081
```

### Schema Configuration

```yaml
schemas:
  topics:
    - name: my-topic
      value:
        schema_file_src_path: "/path/to/schema.avsc"
        compatibility: "BACKWARD"
      key:
        schema_file_src_path: "/path/to/key-schema.avsc"
```

### Secrets Configuration

```yaml
secrets:
  - path: "database"
    key: "username"
    secret: "db_user"
  - path: "database"
    key: "password"
    secret: "supersecret123"
```

## Safety Features

### Protected Resources

Each role includes protection mechanisms:

- **Topics**: `topic_protected` regex (default: `^_confluent.*|^connect.*|^ksql.*`)
- **RBAC**: `rbac_protected_accounts` for critical users
- **Secrets**: `secret_protected` regex for Connect internals
- **Schemas**: `topic_protected` for internal topics

### Delete Controls

Delete operations are controlled by flags:

- `topic_delete_enabled` (default: `false`)
- `rbac_delete_enabled` (default: `false`)
- `quotas_delete_enabled` (default: `false`)
- `connectors_delete_enabled` (default: `false`)
- `acl_delete_enabled` (default: `false`)
- `secret_delete_enabled` (default: `false`)

All delete flags default to `false` — deletions must be explicitly enabled per run or inventory.

### State Backup

All roles support dumping current state:

```yaml
# Enable state dump
<role>_dump_file: true
<role>_dump_destination: ./<role>_dump_out.yml
```

Dump files are written with mode `0600`. They default to the working directory and the default
filenames are listed in `.gitignore` — **do not commit them**, and change `.gitignore` too if you
point a `_dump_destination` at a different path inside the repo. Connector dumps can embed
credentials (JDBC passwords, API keys), and Secret Registry dumps contain secret values in
plaintext.

## Check Mode Support

All playbooks support Ansible's check mode for dry-run operations:

```bash
# Preview changes without applying
ansible-playbook -i inventory.yml playbook.yml --check -vv
```

## Authentication Methods

### Basic Authentication

For most roles (topics, quotas, zacls, connectors, schemas, secrets):
```yaml
rest_user: admin
rest_user_password: admin
rest_server_url: https://kafka1.confluent.io:8090
```

For RBAC and Centralized ACL management:
```yaml
mds_user: mds
mds_user_password: mds
mds_server_url: https://kafka1.confluent.io:8090
```

### OAuth Authentication

```yaml
oauth_enabled: true
oauth_token_uri: https://oauth-server.com/oauth2/token
oauth_client_id: client-id
oauth_client_secret: client-secret
```

### TLS/SSL Configuration

```yaml
client_tls_cert: /path/to/client.crt
client_tls_key: /path/to/client.key
ca_tls_path: /path/to/ca.crt
```

## Environment-Specific Configuration

### Development Environment

```yaml
# Relaxed settings for development
topic_delete_enabled: true
rbac_delete_enabled: true
topic_protected: ^_confluent.*
```

### Production Environment

```yaml
# Strict settings for production
topic_delete_enabled: false
rbac_delete_enabled: false
topic_protected: ^_confluent.*|^connect.*|^ksql.*|_schemas|^confluent.*
rbac_protected_accounts: "User:superUser|User:systemAdmin"
```

## Inventory Examples

The project includes several inventory templates:

- `hosts_sample.yml` - Complete configuration example
- `hosts_sample_schema.yml` - Schema-focused configuration
- `hosts_aws.yml` - AWS-specific configuration

## Troubleshooting

### Common Issues

1. **Authentication Failures**: Verify credentials and API endpoints
2. **Permission Errors**: Check user roles and RBAC permissions
3. **Connection Issues**: Verify network connectivity and TLS settings
4. **State Conflicts**: Use check mode to preview changes

### Debug Mode

Enable verbose logging:

```bash
ansible-playbook playbook.yml -vvv
```

### State Validation

Dump current state before making changes:

```bash
ansible-playbook playbook.yml -e <role>_dump_file=true --check
```

## Dependencies

- Ansible 2.9+
- Python `requests` library
- Confluent Platform binaries (for quota and partition management)
- Network access to Confluent Platform APIs

## Examples

See the `examples/` directory for complete configuration examples for each role.

## Testing

### Schema Management Integration Test

The `tests/schemas/` directory contains an end-to-end integration test that exercises the full schema CRUD lifecycle against a live Schema Registry. It covers all three schema types (Avro, Protobuf, JSON Schema) and runs the following steps:

| Step | Description |
|------|-------------|
| 0 | Cleanup stale test subjects from previous runs |
| 1 | Register new subjects (one per schema type) |
| 2 | Update subject compatibility to FORWARD |
| 3 | Set global mode to READONLY, verify the playbook restores READWRITE |
| 4 | Evolve schemas by adding a new field |
| 5 | Soft delete the latest schema version |
| 6 | Hard delete all schema versions |

After each step the test verifies the result directly against the Schema Registry REST API.

#### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `SR_URL` | Schema Registry base URL (e.g. `http://localhost:8081`) |
| `OAUTH_TOKEN_URI` | OAuth token endpoint |
| `OAUTH_CLIENT_ID` | OAuth client ID |
| `OAUTH_CLIENT_SECRET` | OAuth client secret |

#### Running the Test

```bash
SR_URL=http://localhost:8081 \
OAUTH_TOKEN_URI=https://idp.example.com/oauth2/token \
OAUTH_CLIENT_ID=my-client \
OAUTH_CLIENT_SECRET=my-secret \
  bash tests/schemas/run_test.sh [inventory_path]
```

The optional `inventory_path` argument defaults to `tests/schemas/inventory.yml`.

## Contributing

1. Follow existing role patterns and naming conventions
2. Include comprehensive error handling
3. Support both check mode and regular execution
4. Add appropriate protection mechanisms
5. Document all variables and usage examples

## License

See LICENSE file for details.