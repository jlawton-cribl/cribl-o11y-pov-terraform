#!/usr/bin/env bash
set -euo pipefail

# ─── Cribl O11y POV — Cribl Stack Bootstrap ───
# Stands up a hybrid worker group with sources, pipeline, destinations, and routes.
# Usage:  ./setup-cribl-stack.sh [--clean]
#   --clean   Delete existing group first (for re-runs / demo resets)

GROUP_ID="cribl-o11y-pov"
PIPELINE_ID="cribl-o11y-enrich"
BASE_URL="https://main-${CRIBL_ORG:?Set CRIBL_ORG}.cribl.cloud"
AUTH_URL="https://login.cribl.cloud/oauth/token"
CLEAN=false
[[ "${1:-}" == "--clean" ]] && CLEAN=true

: "${CRIBL_CLIENT_ID:?Set CRIBL_CLIENT_ID}"
: "${CRIBL_CLIENT_SECRET:?Set CRIBL_CLIENT_SECRET}"

GREEN='\033[0;32m' RED='\033[0;31m' BLUE='\033[0;34m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
TOTAL_START=$SECONDS
STEP=0

log()  { STEP=$((STEP+1)); printf "${BLUE}[%d]${NC} ${BOLD}%-48s${NC}" "$STEP" "$1"; }
pass() { printf "${GREEN}✓${NC} ${DIM}(%ss)${NC}\n" "$1"; }
fail() { printf "${RED}✗${NC}\n  %s\n" "$1"; exit 1; }

api() {
  local method=$1 path=$2; shift 2
  local resp http_code body
  resp=$(curl -s -w "\n%{http_code}" -X "$method" \
    "${BASE_URL}/api/v1${path}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "$@") || fail "curl error"
  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')
  if [[ "$http_code" -ge 400 ]]; then
    local msg
    msg=$(echo "$body" | jq -r '.message // .error // .' 2>/dev/null || echo "$body")
    fail "HTTP $http_code — $msg"
  fi
  echo "$body"
}

printf "\n${BOLD}━━━ Cribl Stack Bootstrap: %s ━━━${NC}\n\n" "$GROUP_ID"

# ── Authenticate ──
log "Authenticating to Cribl Cloud"
s=$SECONDS
TOKEN=$(curl -sf -X POST "$AUTH_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\": \"client_credentials\",
    \"client_id\": \"${CRIBL_CLIENT_ID}\",
    \"client_secret\": \"${CRIBL_CLIENT_SECRET}\",
    \"audience\": \"https://api.cribl.cloud\"
  }" | jq -r '.access_token') || fail "Auth request failed"
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || fail "No token returned — check credentials"
pass $((SECONDS - s))

# ── Clean (optional) ──
if $CLEAN; then
  log "Deleting existing group '${GROUP_ID}'"
  s=$SECONDS
  api DELETE "/master/groups/${GROUP_ID}" >/dev/null 2>&1 || true
  pass $((SECONDS - s))
fi

# ── Create hybrid worker group ──
log "Creating hybrid worker group '${GROUP_ID}'"
s=$SECONDS
api POST "/master/groups" -d "{
  \"id\": \"${GROUP_ID}\",
  \"name\": \"Cribl O11y POV\",
  \"description\": \"Cribl O11y POV — hybrid workers\",
  \"isFleet\": false,
  \"tags\": \"pov,o11y\"
}" >/dev/null
pass $((SECONDS - s))

# ── Create pipeline: eval + mask ──
log "Creating pipeline '${PIPELINE_ID}'"
s=$SECONDS
api POST "/m/${GROUP_ID}/pipelines" -d '{
  "id": "'"${PIPELINE_ID}"'",
  "conf": {
    "output": "default",
    "asyncFuncTimeout": 1000,
    "functions": [
      {
        "id": "eval",
        "filter": "true",
        "disabled": false,
        "conf": {
          "add": [
            { "name": "cribl_wp",      "value": "\"'"${GROUP_ID}"'\"" },
            { "name": "cribl_host",    "value": "os.hostname()" },
            { "name": "index",         "value": "\"cribl\"" }
          ],
          "remove": []
        },
        "description": "Tag with worker group and index"
      },
      {
        "id": "mask",
        "filter": "true",
        "disabled": false,
        "conf": {
          "rules": [
            {
              "matchRegex": "/\\b\\d{3}-\\d{2}-\\d{4}\\b/g",
              "replaceExpr": "\"XXX-XX-XXXX\""
            },
            {
              "matchRegex": "/\\b(?:\\d[ -]*?){13,16}\\b/g",
              "replaceExpr": "\"XXXX-REDACTED\""
            }
          ],
          "fields": ["_raw"],
          "depth": 5
        },
        "description": "Redact SSN and credit card patterns"
      }
    ]
  }
}' >/dev/null
pass $((SECONDS - s))

# ── Create sources ──
log "Creating HTTP source (port 10080)"
s=$SECONDS
api POST "/m/${GROUP_ID}/system/inputs" -d '{
  "id":   "http_in",
  "type": "http",
  "disabled": false,
  "port": 10080,
  "host": "0.0.0.0",
  "tls":  { "disabled": true },
  "authType": "none"
}' >/dev/null
pass $((SECONDS - s))

log "Creating Syslog TCP source (port 5140)"
s=$SECONDS
api POST "/m/${GROUP_ID}/system/inputs" -d '{
  "id":      "syslog_tcp_in",
  "type":    "syslog",
  "disabled": false,
  "host":    "0.0.0.0",
  "tcpPort": 5140,
  "tls":     { "disabled": true }
}' >/dev/null
pass $((SECONDS - s))

# ── Create destinations ──
log "Creating DevNull destination"
s=$SECONDS
api POST "/m/${GROUP_ID}/system/outputs" -d '{
  "id":           "devnull_out",
  "type":         "devnull",
  "systemFields": ["cribl_*"]
}' >/dev/null
pass $((SECONDS - s))

log "Creating S3 destination (disabled)"
s=$SECONDS
api POST "/m/${GROUP_ID}/system/outputs" -d '{
  "id":       "s3_logs",
  "type":     "s3",
  "disabled": true,
  "bucket":   "CHANGEME-cribl-o11y-logs",
  "destPath": "cribl/${_time:%Y}/${_time:%m}/${_time:%d}/${host}",
  "stagePath": "/tmp/cribl",
  "addIdToStagePath": true,
  "compress": "gzip",
  "format":  "json",
  "maxFileSizeMB":       32,
  "maxFileOpenTimeSec": 300,
  "maxFileIdleTimeSec":  30,
  "region":  "us-west-2",
  "objectACL": "private"
}' >/dev/null
pass $((SECONDS - s))

log "Creating New Relic destination (disabled)"
s=$SECONDS
api POST "/m/${GROUP_ID}/system/outputs" -d '{
  "id":       "newrelic_out",
  "type":     "newrelic",
  "disabled": true,
  "url":      "https://log-api.newrelic.com/log/v1",
  "apiKey":   "CHANGEME",
  "concurrency": 5,
  "maxPayloadSizeKB": 1024,
  "compress": true
}' >/dev/null
pass $((SECONDS - s))

# ── Configure routes ──
log "Configuring route (→ enrich → devnull)"
s=$SECONDS
api PATCH "/m/${GROUP_ID}/routes/default" -d '{
  "id": "default",
  "routes": [
    {
      "id":          "cribl-o11y-main",
      "name":        "cribl-o11y-main",
      "filter":      "true",
      "pipeline":    "'"${PIPELINE_ID}"'",
      "output":      "devnull_out",
      "enabled":     true,
      "final":       true,
      "description": "All events → enrich → devnull (swap to s3_logs/newrelic_out)"
    },
    {
      "id":       "default",
      "name":     "default",
      "final":    true,
      "disabled": false,
      "pipeline": "main",
      "filter":   "true",
      "output":   "default"
    }
  ]
}' >/dev/null
pass $((SECONDS - s))

# ── Commit ──
log "Committing configuration"
s=$SECONDS
COMMIT_RESP=$(api POST "/version/commit" -d "{
  \"message\": \"Bootstrap: ${GROUP_ID} — sources, pipeline, destinations, routes\",
  \"group\":   \"${GROUP_ID}\"
}")
VERSION=$(echo "$COMMIT_RESP" | jq -r '.items[0].commit // empty' 2>/dev/null) || VERSION=""
pass $((SECONDS - s))

# ── Deploy ──
log "Deploying to worker group"
s=$SECONDS
if [[ -n "$VERSION" ]]; then
  api PATCH "/master/groups/${GROUP_ID}/deploy" -d "{\"version\": \"${VERSION}\"}" >/dev/null
else
  printf "${DIM}(skipped — no version from commit)${NC}\n"
fi
pass $((SECONDS - s))

# ── Summary ──
ELAPSED=$((SECONDS - TOTAL_START))
echo ""
printf "${BOLD}━━━ Done in %ss ━━━${NC}\n\n" "$ELAPSED"
cat <<EOF
$(printf "${GREEN}Worker Group:${NC}")  ${GROUP_ID} (hybrid)
$(printf "${GREEN}Pipeline:${NC}")     ${PIPELINE_ID} (eval → mask)
$(printf "${GREEN}Sources:${NC}")      HTTP :10080, Syslog TCP :5140
$(printf "${GREEN}Destinations:${NC}") devnull_out (active), s3_logs (disabled), newrelic_out (disabled)
$(printf "${GREEN}Route:${NC}")        all → ${PIPELINE_ID} → devnull_out

$(printf "${DIM}Cloud UI:${NC}")  ${BASE_URL}/w/${GROUP_ID}
$(printf "${DIM}Next:${NC}")      Enable s3_logs / newrelic_out and set real credentials

$(printf "${BOLD}Test (once a hybrid worker is connected):${NC}")
  curl -X POST http://<worker>:10080/cribl \\
    -H 'Content-Type: application/json' \\
    -d '{"message":"hello from cribl o11y pov","ssn":"123-45-6789","cc":"4111-1111-1111-1111"}'

$(printf "${BOLD}Reset:${NC}")
  ./setup-cribl-stack.sh --clean && ./setup-cribl-stack.sh
EOF
echo ""
