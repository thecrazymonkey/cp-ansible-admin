#!/usr/bin/env bash
#
# Schema Management Integration Test
#
# Runs the schema management playbook through a full CRUD lifecycle
# using all three schema types (Avro, Protobuf, JSON Schema):
#   1. Register new subjects — one per schema type
#   2. Update compatibility to FORWARD
#   3. Set mode to READONLY, then verify playbook restores READWRITE
#   4. Evolve schemas by adding a new field
#   5. Soft delete the latest schema version
#   6. Hard delete all schema versions
#
# After each step, verifies the result against the Schema Registry REST API.
#
# Required environment variables:
#   SR_URL             - Schema Registry base URL (e.g. http://localhost:8081)
#   OAUTH_TOKEN_URI    - OAuth token endpoint
#   OAUTH_CLIENT_ID    - OAuth client ID
#   OAUTH_CLIENT_SECRET - OAuth client secret
#
# Usage:
#   SR_URL=http://localhost:8081 \
#   OAUTH_TOKEN_URI=https://idp/oauth2/token \
#   OAUTH_CLIENT_ID=my-client \
#   OAUTH_CLIENT_SECRET=my-secret \
#     bash tests/schemas/run_test.sh [inventory_path]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVENTORY="${1:-tests/schemas/inventory.yml}"

# Subject names follow the convention: <topic>-value
SUBJECTS=("schema-test-avro-value" "schema-test-proto-value" "schema-test-json-value")
LABELS=("Avro" "Protobuf" "JSON Schema")

# --- Validate required env vars ---

missing=()
for var in SR_URL OAUTH_TOKEN_URI OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET; do
    if [[ -z "${!var}" ]]; then
        missing+=("$var")
    fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required environment variables: ${missing[*]}"
    echo "See script header for usage."
    exit 1
fi

# --- Helper functions ---

get_token() {
    local response
    response=$(curl -s -X POST "$OAUTH_TOKEN_URI" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=${OAUTH_CLIENT_ID}&client_secret=${OAUTH_CLIENT_SECRET}")

    local token
    token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null) || {
        echo "ERROR: Failed to obtain OAuth token. Response: $response"
        exit 1
    }
    echo "$token"
}

# Performs GET against SR API. Sets RESPONSE_BODY and RESPONSE_STATUS.
sr_get() {
    local path="$1"
    local token
    token=$(get_token)

    local http_output
    http_output=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $token" \
        "${SR_URL}/${path}")

    RESPONSE_STATUS=$(echo "$http_output" | tail -1)
    RESPONSE_BODY=$(echo "$http_output" | sed '$d')
}

assert_status() {
    local expected="$1"
    local step_name="$2"
    if [[ "$RESPONSE_STATUS" != "$expected" ]]; then
        echo "FAIL [$step_name]: expected HTTP $expected, got $RESPONSE_STATUS. Response: $RESPONSE_BODY"
        exit 1
    fi
}

assert_body_contains() {
    local expected="$1"
    local step_name="$2"
    if [[ "$RESPONSE_BODY" != *"$expected"* ]]; then
        echo "FAIL [$step_name]: expected response to contain '$expected', got: $RESPONSE_BODY"
        exit 1
    fi
}

# Performs PUT against SR API. Sets RESPONSE_BODY and RESPONSE_STATUS.
sr_put() {
    local path="$1"
    local body="$2"
    local token
    token=$(get_token)

    local http_output
    http_output=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        -d "$body" \
        "${SR_URL}/${path}")

    RESPONSE_STATUS=$(echo "$http_output" | tail -1)
    RESPONSE_BODY=$(echo "$http_output" | sed '$d')
}

assert_body_equals() {
    local expected="$1"
    local step_name="$2"
    if [[ "$RESPONSE_BODY" != "$expected" ]]; then
        echo "FAIL [$step_name]: expected '$expected', got: $RESPONSE_BODY"
        exit 1
    fi
}

# Performs DELETE against SR API. Sets RESPONSE_BODY and RESPONSE_STATUS.
sr_delete() {
    local path="$1"
    local token
    token=$(get_token)

    local http_output
    http_output=$(curl -s -w "\n%{http_code}" \
        -X DELETE \
        -H "Authorization: Bearer $token" \
        "${SR_URL}/${path}")

    RESPONSE_STATUS=$(echo "$http_output" | tail -1)
    RESPONSE_BODY=$(echo "$http_output" | sed '$d')
}

pass() {
    echo "PASS [$1]"
    echo ""
}

run_playbook() {
    local step_file="$1"
    ansible-playbook "$PROJECT_DIR/schemas_management.yml" \
        -i "$INVENTORY" \
        -e "@$step_file" \
        -vv
}

# --- Test steps ---

cd "$PROJECT_DIR"

echo "============================================"
echo "Schema Management Integration Test"
echo "============================================"
echo "SR_URL:    $SR_URL"
echo "Inventory: $INVENTORY"
echo "Subjects:  ${SUBJECTS[*]}"
echo "============================================"
echo ""

# Step 0: Cleanup — delete test subjects if they exist from a previous run
echo "Step 0: Cleanup stale test subjects"
for i in "${!SUBJECTS[@]}"; do
    sr_delete "subjects/${SUBJECTS[$i]}"
    if [[ "$RESPONSE_STATUS" == "200" ]]; then
        echo "  Cleaned up ${SUBJECTS[$i]} (soft delete)"
        sr_delete "subjects/${SUBJECTS[$i]}?permanent=true"
        echo "  Cleaned up ${SUBJECTS[$i]} (hard delete)"
    fi
done
pass "Step 0: Cleanup"

# Step 1: Register new subjects (Avro, Protobuf, JSON Schema)
echo "Step 1: Register new subjects (Avro, Protobuf, JSON Schema)"
run_playbook tests/schemas/step_1_register.yml

for i in "${!SUBJECTS[@]}"; do
    sr_get "subjects/${SUBJECTS[$i]}/versions"
    assert_status "200" "Step 1: Register ${LABELS[$i]}"
    assert_body_equals "[1]" "Step 1: Register ${LABELS[$i]}"
    pass "Step 1: Register ${LABELS[$i]}"
done

# Step 2: Update compatibility to FORWARD
echo "Step 2: Update compatibility to FORWARD"
run_playbook tests/schemas/step_2_update_compat.yml

for i in "${!SUBJECTS[@]}"; do
    sr_get "config/${SUBJECTS[$i]}"
    assert_status "200" "Step 2: Update compatibility ${LABELS[$i]}"
    assert_body_contains "FORWARD" "Step 2: Update compatibility ${LABELS[$i]}"
    pass "Step 2: Update compatibility ${LABELS[$i]}"
done

# Step 3: Set mode to READONLY, verify playbook restores READWRITE
echo "Step 3: Mode READONLY -> READWRITE"

sr_put "mode" '{"mode": "READONLY"}'
assert_status "200" "Step 3a: Set READONLY"

sr_get "mode"
assert_status "200" "Step 3b: Verify READONLY"
assert_body_contains "READONLY" "Step 3b: Verify READONLY"
pass "Step 3a: Mode set to READONLY"

run_playbook tests/schemas/step_1_register.yml

sr_get "mode"
assert_status "200" "Step 3c: Verify READWRITE"
assert_body_contains "READWRITE" "Step 3c: Verify READWRITE"
pass "Step 3: Mode restored to READWRITE"

# Step 4: Evolve schemas (add phone_number field)
echo "Step 4: Evolve schemas with new field"
run_playbook tests/schemas/step_3_evolve_schema.yml

for i in "${!SUBJECTS[@]}"; do
    sr_get "subjects/${SUBJECTS[$i]}/versions"
    assert_status "200" "Step 4: Evolve schema ${LABELS[$i]}"
    assert_body_equals "[1,2]" "Step 4: Evolve schema ${LABELS[$i]}"
    pass "Step 4: Evolve schema ${LABELS[$i]}"
done

# Step 5: Soft delete latest version
echo "Step 5: Soft delete latest version"
run_playbook tests/schemas/step_4_soft_delete.yml

for i in "${!SUBJECTS[@]}"; do
    sr_get "subjects/${SUBJECTS[$i]}/versions"
    assert_status "200" "Step 5: Soft delete ${LABELS[$i]}"
    assert_body_equals "[1]" "Step 5: Soft delete ${LABELS[$i]}"
    pass "Step 5: Soft delete ${LABELS[$i]}"
done

# Step 6: Hard delete all versions
echo "Step 6: Hard delete all versions"
run_playbook tests/schemas/step_5_hard_delete.yml

for i in "${!SUBJECTS[@]}"; do
    sr_get "subjects/${SUBJECTS[$i]}/versions"
    assert_status "404" "Step 6: Hard delete ${LABELS[$i]}"
    pass "Step 6: Hard delete ${LABELS[$i]}"
done

echo "============================================"
echo "All tests passed"
echo "============================================"
