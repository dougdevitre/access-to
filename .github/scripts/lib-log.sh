#!/usr/bin/env bash
# Shared logging library for Access To admin scripts.
#
# Source this file at the top of any script:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib-log.sh"
#
# Functions:
#   log_init <script-name>     — Set up logging context
#   log_info <message>         — Informational message
#   log_warn <message>         — Warning (also emits ::warning::)
#   log_error <message>        — Error (also emits ::error::)
#   log_success <message>      — Success message
#   log_action <verb> <target> [status] [detail] — Structured action log
#   log_summary                — Print session summary
#   audit_append <entry>       — Append to audit log file
#
# Environment:
#   LOG_FORMAT=text|json        — Output format (default: text)
#   LOG_LEVEL=debug|info|warn   — Minimum log level (default: info)
#   AUDIT_LOG=<path>            — Audit log file path (default: none)

LOG_FORMAT="${LOG_FORMAT:-text}"
LOG_LEVEL="${LOG_LEVEL:-info}"
AUDIT_LOG="${AUDIT_LOG:-}"

_LOG_SCRIPT=""
_LOG_RUN_ID=""
_LOG_START=""
_LOG_ACTION_COUNT=0
_LOG_WARN_COUNT=0
_LOG_ERROR_COUNT=0

log_init() {
  _LOG_SCRIPT="${1:?log_init requires script name}"
  _LOG_RUN_ID="$(date -u '+%Y%m%d%H%M%S')-$$"
  _LOG_START=$(date -u '+%s')
  log_info "Starting $_LOG_SCRIPT (run: $_LOG_RUN_ID)"
}

_log_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

_log_json() {
  local level="$1" message="$2" extra="${3:-}"
  local ts
  ts=$(_log_timestamp)
  local json="{\"ts\":\"$ts\",\"level\":\"$level\",\"script\":\"$_LOG_SCRIPT\",\"run\":\"$_LOG_RUN_ID\",\"msg\":\"$message\""
  if [ -n "$extra" ]; then
    json+=",$extra"
  fi
  json+="}"
  echo "$json"
}

_log_text() {
  local level="$1" message="$2"
  local ts
  ts=$(_log_timestamp)
  echo "[$ts] [$level] $_LOG_SCRIPT: $message"
}

_should_log() {
  local level="$1"
  case "$LOG_LEVEL" in
    debug) return 0 ;;
    info)  [ "$level" != "debug" ] && return 0 || return 1 ;;
    warn)  [ "$level" = "warn" ] || [ "$level" = "error" ] && return 0 || return 1 ;;
    *)     return 0 ;;
  esac
}

log_info() {
  _should_log "info" || return 0
  if [ "$LOG_FORMAT" = "json" ]; then
    _log_json "info" "$1"
  else
    _log_text "INFO" "$1"
  fi
}

log_warn() {
  _should_log "warn" || return 0
  ((_LOG_WARN_COUNT++)) || true
  if [ "$LOG_FORMAT" = "json" ]; then
    _log_json "warn" "$1"
  else
    _log_text "WARN" "$1"
  fi
  echo "::warning::$1"
}

log_error() {
  ((_LOG_ERROR_COUNT++)) || true
  if [ "$LOG_FORMAT" = "json" ]; then
    _log_json "error" "$1"
  else
    _log_text "ERROR" "$1"
  fi
  echo "::error::$1"
}

log_success() {
  _should_log "info" || return 0
  if [ "$LOG_FORMAT" = "json" ]; then
    _log_json "info" "$1" "\"status\":\"success\""
  else
    _log_text "OK" "$1"
  fi
}

# Structured action log for sync operations.
# Usage: log_action "sync-label" "pillar:housing" "success" "created"
log_action() {
  local verb="$1" target="$2" status="${3:-ok}" detail="${4:-}"
  ((_LOG_ACTION_COUNT++)) || true

  if [ "$LOG_FORMAT" = "json" ]; then
    local extra="\"action\":\"$verb\",\"target\":\"$target\",\"status\":\"$status\""
    [ -n "$detail" ] && extra+=",\"detail\":\"$detail\""
    _log_json "info" "$verb $target: $status" "$extra"
  else
    local msg="$verb $target -> $status"
    [ -n "$detail" ] && msg+=" ($detail)"
    _log_text "ACTION" "$msg"
  fi

  # Append to audit log if configured
  if [ -n "$AUDIT_LOG" ]; then
    audit_append "$(_log_json "audit" "$verb $target" "\"action\":\"$verb\",\"target\":\"$target\",\"status\":\"$status\",\"detail\":\"$detail\"")"
  fi
}

log_summary() {
  local end duration
  end=$(date -u '+%s')
  duration=$(( end - _LOG_START ))

  if [ "$LOG_FORMAT" = "json" ]; then
    _log_json "info" "Run complete" "\"duration_s\":$duration,\"actions\":$_LOG_ACTION_COUNT,\"warnings\":$_LOG_WARN_COUNT,\"errors\":$_LOG_ERROR_COUNT"
  else
    _log_text "SUMMARY" "Done in ${duration}s | actions=$_LOG_ACTION_COUNT warnings=$_LOG_WARN_COUNT errors=$_LOG_ERROR_COUNT"
  fi
}

audit_append() {
  local entry="$1"
  if [ -n "$AUDIT_LOG" ]; then
    echo "$entry" >> "$AUDIT_LOG"
  fi
}
