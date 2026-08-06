# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible project for managing Confluent Platform components through declarative configuration via REST APIs. It supports topics, RBAC, quotas, ACLs (Zookeeper and Centralized), connectors, schemas, and secrets management.

## Common Commands

```bash
# Preview changes (dry-run)
ansible-playbook -i hosts_sample.yml <playbook>.yml --check -vv

# Apply configuration
ansible-playbook -i hosts_sample.yml <playbook>.yml

# Dump current state to file
ansible-playbook -i hosts_sample.yml <playbook>.yml -e <role>_dump_file=true

# Run with extra variables
ansible-playbook -i hosts_sample.yml <playbook>.yml -e @examples/<example>.yml

# Debug mode
ansible-playbook <playbook>.yml -vvv
```

Available playbooks: `topics_management.yml`, `rbac_management.yml`, `quota_management.yml`, `zacl_management.yml`, `cacl_management.yml`, `connectors_management.yml`, `schemas_management.yml`, `secretsregistry_management.yml`

## Linting

```bash
ansible-lint
```

Configuration is in `.ansible-lint`.

## Architecture

### Role Pattern

Each role follows a consistent lifecycle pattern in `tasks/main.yml`:
1. **Authorization** - Get auth header (OAuth or Basic) via `common/_authorization_header.yml`
2. **Cluster ID** - Auto-discover if not provided via `common/_cluster_id.yml`
3. **Dump** - Fetch current state from API
4. **Save** - Optionally write current state to file
5. **Delta** - Compare desired vs current state, populate `*_to_add`, `*_to_delete`, `*_to_reconfigure*` lists
6. **CRUD** - Execute create/update/delete operations (skipped in check mode)

### Authentication Flow

The `common` role provides authentication helpers:
- `_authorization_header.yml` - Routes to OAuth or Basic auth based on `oauth_enabled`
- `_oauth.yml` - Gets Bearer token from OAuth token endpoint
- `_basic_auth.yml` - Sets up Basic auth header

### Variable Separation

Two authentication contexts exist:
- **REST API** (`rest_server_url`, `rest_user`, `rest_user_password`) - Used by topic, quota, zacl, connector, schema, secrets roles
- **MDS API** (`mds_server_url`, `mds_user`, `mds_user_password`) - Used by rbac and cacl roles (requires SystemAdmin)

### Protected Resources

Each role has protection mechanisms to prevent accidental deletion of internal resources:
- `topic_protected` - Regex for protected topics (default: `^_confluent.*|^connect.*|^ksql.*`)
- `rbac_protected_accounts` - Principal patterns to protect
- `*_delete_enabled` - Boolean flags controlling delete operations (most default to false)

### State Management

All roles support:
- `<role>_dump_file: true` - Enable state dump
- `<role>_dump_destination` - Path for dumped state file

## Development Guidelines

### General Principles

- Always use Ansible built-in modules (e.g., `ansible.builtin.uri`, `ansible.builtin.file`) instead of external CLI commands when a module exists for the task. Avoid `shell` or `command` modules for operations that can be done with native modules.
- Run `ansible-lint` after code changes and automatically fix any issues it reports.
- Keep changes minimal and focused. Don't refactor surrounding code when fixing a bug or adding a feature.

### Module Naming (FQCN)

- Use Fully Qualified Collection Names for all modules: `ansible.builtin.uri`, `ansible.builtin.set_fact`, `ansible.builtin.debug`, `ansible.builtin.include_tasks`, `ansible.builtin.copy`, etc.
- For community modules, also use FQCN: `community.general.lists_mergeby`, etc.

### Task Naming and Structure

- Every task must have a descriptive `name:` field that clearly states what the task does.
- Use imperative verb phrases: "Create topics", "Dump current RBAC bindings", "Set delta variables".
- Task files should be named by operation and entity: `<entity>_<operation>.yml` (e.g., `topics_create.yml`, `schemas_dump.yml`).
- Shared/included files from `common/` are prefixed with underscore: `_authorization_header.yml`, `_cluster_id.yml`.

### Role Lifecycle

- Every new role must follow the 6-step lifecycle in its `main.yml`:
  1. Authorization — include `common/_authorization_header.yml`
  2. Cluster ID — include `common/_cluster_id.yml` (if applicable)
  3. Dump — fetch current state from API
  4. Save — optionally write state to file
  5. Delta — compare desired vs current state
  6. CRUD — execute create/update/delete (gated by check mode)
- Do not combine lifecycle steps into a single task file. Keep each phase in its own file.

### Variable Naming

- All role variables must be prefixed with the role name: `topics_*`, `rbac_*`, `schemas_*`, `connectors_*`, `quotas_*`, `secrets_*`, `zacl_*`, `cacl_*`.
- State variables follow the pattern:
  - `<prefix>`: desired state (user input)
  - `<prefix>_current`: current state from API
  - `<prefix>_to_add`: items to create
  - `<prefix>_to_delete`: items to remove
  - `<prefix>_to_reconfigure`: items to update
- Configuration flags: `<prefix>_delete_enabled` (boolean), `<prefix>_protected` (regex pattern), `<prefix>_dump_file` (boolean), `<prefix>_dump_destination` (path).
- Define all default values in `defaults/main.yml`. Use `vars/main.yml` only for static reference data (e.g., lookup tables).

### Check Mode and Idempotency

- Read-only operations (API dumps, state fetches) must always execute, even in check mode. Use `check_mode: false` on these tasks.
- Write operations (create, update, delete) must be gated with `when: not ansible_check_mode`.
- All CRUD tasks must be gated by delta checks: only run when there are items in the corresponding `_to_add`, `_to_delete`, or `_to_reconfigure` lists.
- Every `ansible.builtin.uri` task that modifies state must specify `changed_when` based on the HTTP response status code.

### HTTP API Calls (`ansible.builtin.uri`)

- All API interactions use `ansible.builtin.uri` — never `curl`, `shell`, or `command`.
- Always include these parameters for API calls:
  - `validate_certs` — respect the TLS configuration
  - `client_cert` / `client_key` / `ca_path` — pass through TLS parameters (use `none` conditional when not defined)
  - `headers.Authorization` — use the `authorization_header` variable set by the auth flow
  - `headers.Content-Type: application/json` — for POST/PUT/PATCH requests
  - `body_format: json` — when sending JSON bodies
  - `return_content: true` — to capture response body
- Use `failed_when` for custom failure logic instead of relying on default status code handling. This allows tolerating expected errors (e.g., 404 on delete).
- Use `register` to capture responses for downstream processing.

### Error Handling

- Use `failed_when` and `changed_when` on all `ansible.builtin.uri` tasks to explicitly define success/failure/change criteria.
- When delete operations should tolerate "not found" responses, include the 404 status or equivalent error code in the `failed_when` condition.
- Use `no_log: true` on tasks that handle sensitive data (OAuth tokens, passwords, credentials).
- Do not use `block/rescue` for general error handling. Let failures propagate naturally — the declarative model handles retries at the playbook level.

### Loops and Iteration

- Always set `loop_control.loop_var` when using `ansible.builtin.include_tasks` inside a loop to avoid variable conflicts with nested loops. Use descriptive names: `item_topic`, `item_connector`, `item_rbac`, etc.
- For complex data transformations, prefer Jinja2 filters over multiple sequential tasks: `groupby`, `map`, `selectattr`, `rejectattr`, `items2dict`, `combine`, `difference`.
- Use `flatten(levels=1)` when working with lists of lists to avoid unexpected deep flattening.

### Jinja2 and Filters

- Use `|d()` (or `|default()`) to provide safe defaults for optional variables. Use `|d([])` for lists, `|d('')` for strings, `|d(0)` for numbers.
- Use `|combine()` to merge dictionaries. For deep merges, use `recursive=true`.
- Use `|regex_search()` for pattern matching against protected resource lists and whitelists.
- For config comparison, use `|items2dict(key_name='name')` to normalize config lists into comparable dictionaries, then `|dictsort` for stable comparison.
- Prefer inline Jinja2 expressions over `.j2` template files for API request bodies.

### Protected Resources

- Every role that supports deletion must have:
  - A `<prefix>_delete_enabled` flag (default `false` for destructive roles).
  - A `<prefix>_protected` regex pattern to prevent accidental deletion of internal/system resources.
- Delta calculations must filter out protected resources before populating `_to_delete` lists.
- Never remove or weaken default protection patterns without explicit justification.

### Secrets and Security

- Use `no_log: true` on any task that processes passwords, tokens, or credentials.
- Never hardcode credentials in task files. All secrets must come from inventory variables or Ansible Vault.
- TLS parameters (`client_tls_cert`, `client_tls_key`, `ca_tls_path`) must be optional with conditional `none` defaults.
- Basic auth headers must be constructed using `b64encode`: `"Basic {{ (_user+':'+_user_password)|b64encode }}"`.

### State Dump and Save

- All roles must support dumping current state to a file via `<prefix>_dump_file: true`.
- Dump files are written using `ansible.builtin.copy` with `content:` set to the formatted state (`|to_nice_yaml(indent=2)`).
- Save operations must use `delegate_to: localhost` when running against remote hosts.
- Save tasks should use `check_mode: false` so state can be captured even during dry runs.

### Playbook Structure

- Each management playbook follows this standard pattern:
  ```yaml
  ---
  - name: <Entity> management
    gather_facts: false
    hosts: "{{ run_host|default('localhost') }}"
    environment: "{{ proxy_env }}"
    tasks:
      - name: Set Variables
        import_role:
          name: common
      - name: Process <Entity>
        import_role:
          name: <role_name>
  ```
- Always set `gather_facts: false` — this project only calls REST APIs, no host facts are needed.
- Support the `run_host` variable to allow overriding the target host.
- Support `proxy_env` for environments that require HTTP proxy configuration.

## Key Files

- `hosts_sample.yml` - Complete inventory template with all configuration options
- `roles/common/` - Shared authentication and cluster discovery
- `examples/` - Configuration examples for each role
