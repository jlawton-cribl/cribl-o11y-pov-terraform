#!/bin/bash

set -euo pipefail

# Script to provision Cribl Cloud observability pipeline via API
# This script creates pipelines, destinations, and routes for the O11y POV

# Configuration
ORG="${CRIBL_ORG}"
GROUP="${CRIBL_GROUP}"
CLIENT_ID="${CRIBL_CLIENT_ID}"
CLIENT_SECRET="${CRIBL_CLIENT_SECRET}"
API_BASE="https://main-${ORG}.cribl.cloud/api/v1"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Get authentication token
get_token() {
  log_info "Authenticating with Cribl Cloud..."

  TOKEN_RESPONSE=$(curl -s -X POST \
    https://login.cribl.cloud/oauth/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=client_credentials&audience=https://cribl.cloud")

  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

  if [ -z "$ACCESS_TOKEN" ]; then
    log_error "Failed to obtain access token"
    exit 1
  fi

  log_success "Authentication successful"
  echo "$ACCESS_TOKEN"
}

# API call helper
api_call() {
  local method=$1
  local endpoint=$2
  local data=$3
  local token=$4

  local url="${API_BASE}${endpoint}"

  log_info "API: $method $endpoint"

  if [ -z "$data" ]; then
    curl -s -X "$method" \
      "$url" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json"
  else
    curl -s -X "$method" \
      "$url" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "$data"
  fi
}

# Create pipeline
create_pipeline() {
  local pipeline_id=$1
  local pipeline_name=$2
  local description=$3
  local token=$4

  log_info "Creating pipeline: $pipeline_id ($pipeline_name)"

  local pipeline_def=$(cat "${SCRIPT_DIR}/pipelines/${pipeline_id}.json")

  api_call "POST" "/groups/${GROUP}/pipelines" "$pipeline_def" "$token" | python3 -m json.tool

  log_success "Pipeline created: $pipeline_id"
}

# Create destination
create_destination() {
  local dest_id=$1
  local dest_type=$2
  local dest_config=$3
  local token=$4

  log_info "Creating destination: $dest_id ($dest_type)"

  api_call "POST" "/groups/${GROUP}/destinations" "$dest_config" "$token" | python3 -m json.tool

  log_success "Destination created: $dest_id"
}

# Create route
create_route() {
  local route_id=$1
  local route_config=$2
  local token=$3

  log_info "Creating route: $route_id"

  api_call "POST" "/groups/${GROUP}/routes" "$route_config" "$token" | python3 -m json.tool

  log_success "Route created: $route_id"
}

# Main provisioning logic
main() {
  local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  log_info "Starting Cribl O11y POV provisioning"
  log_info "Organization: $ORG"
  log_info "Group: $GROUP"
  log_info "API Base: $API_BASE"

  # Get token
  TOKEN=$(get_token)

  # Create pipelines
  log_info "=== Creating Pipelines ==="

  create_pipeline "normalize-labels" "Normalize" "Normalize field names, add labels, flatten structure" "$TOKEN"
  create_pipeline "structure-repair" "Repair" "Repair multiline traces, normalize severity, parse JSON" "$TOKEN"
  create_pipeline "volume-reduction" "Reduce" "Reduce volume by filtering noise and sampling" "$TOKEN"

  # Create destinations
  log_info "=== Creating Destinations ==="

  # New Relic destination
  NR_DEST_CONFIG=$(cat <<EOF
{
  "id": "newrelic-otlp",
  "type": "http_event_collector",
  "description": "New Relic OTLP HTTP ingest",
  "httpClientConfig": {
    "url": "https://otlp.nr-data.net:4318/v1/logs",
    "method": "POST",
    "headers": {
      "api-key": "${NR_API_KEY}",
      "Content-Type": "application/json"
    },
    "tlsClientConfig": {
      "insecureSkipVerify": false,
      "minVersion": "1.2"
    },
    "timeout": "30s"
  },
  "format": {
    "type": "json",
    "pretty": false
  },
  "batch": {
    "enabled": true,
    "size": 1000,
    "timeout": "5s"
  }
}
EOF
)
  create_destination "newrelic-otlp" "http_event_collector" "$NR_DEST_CONFIG" "$TOKEN"

  # S3 destination
  S3_DEST_CONFIG=$(cat <<EOF
{
  "id": "s3-parquet",
  "type": "s3",
  "description": "S3 Parquet archive for long-term storage",
  "bucketName": "${S3_BUCKET}",
  "region": "${S3_REGION}",
  "prefix": "cribl-o11y-pov/logs",
  "path": "year=%Y/month=%m/day=%d/hour=%H",
  "compression": "snappy",
  "format": "parquet",
  "batch": {
    "enabled": true,
    "size": 50,
    "timeout": "60s"
  },
  "partitioning": {
    "enabled": true,
    "fields": [
      { "name": "year", "value": "%Y" },
      { "name": "month", "value": "%m" },
      { "name": "day", "value": "%d" },
      { "name": "hour", "value": "%H" }
    ]
  }
}
EOF
)
  create_destination "s3-parquet" "s3" "$S3_DEST_CONFIG" "$TOKEN"

  # Cribl Lake destination
  LAKE_DEST_CONFIG=$(cat <<EOF
{
  "id": "cribl-lake",
  "type": "cribl_lake",
  "description": "Cribl Lake for native query engine",
  "database": "pov_logs",
  "table": "observability_events",
  "partitioning": {
    "enabled": true,
    "fields": [
      { "name": "year", "value": "%Y" },
      { "name": "month", "value": "%m" },
      { "name": "day", "value": "%d" }
    ]
  },
  "batch": {
    "enabled": true,
    "size": 100,
    "timeout": "30s"
  }
}
EOF
)
  create_destination "cribl-lake" "cribl_lake" "$LAKE_DEST_CONFIG" "$TOKEN"

  # Create routes
  log_info "=== Creating Routes ==="

  ERRORS_ROUTE=$(cat <<'EOF'
{
  "id": "route-errors-to-nr",
  "filter": "__e.level === 'error' || __e.severity === 'ERROR' || __e.severity === 'FATAL'",
  "routes": [
    {
      "pipeline": "normalize-labels",
      "destination": "newrelic-otlp"
    }
  ],
  "priority": 10
}
EOF
)
  create_route "route-errors-to-nr" "$ERRORS_ROUTE" "$TOKEN"

  INFO_ROUTE=$(cat <<'EOF'
{
  "id": "route-info-to-s3",
  "filter": "__e.level === 'info' || __e.level === 'debug'",
  "routes": [
    {
      "pipeline": "volume-reduction",
      "destination": "s3-parquet"
    }
  ],
  "priority": 20
}
EOF
)
  create_route "route-info-to-s3" "$INFO_ROUTE" "$TOKEN"

  ALL_ROUTE=$(cat <<'EOF'
{
  "id": "route-all-to-lake",
  "filter": "true",
  "routes": [
    {
      "pipeline": "structure-repair",
      "destination": "cribl-lake"
    }
  ],
  "priority": 30
}
EOF
)
  create_route "route-all-to-lake" "$ALL_ROUTE" "$TOKEN"

  log_success "=== Provisioning Complete ==="
  log_info "Resources created:"
  log_info "  Pipelines: normalize-labels, structure-repair, volume-reduction"
  log_info "  Destinations: newrelic-otlp, s3-parquet, cribl-lake"
  log_info "  Routes: route-errors-to-nr, route-info-to-s3, route-all-to-lake"
  log_info ""
  log_info "Next step: Run 'terraform apply' to commit and deploy configuration"
}

# Run main function
main "$@"
