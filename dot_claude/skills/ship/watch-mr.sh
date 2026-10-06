#!/usr/bin/env bash
# watch-mr.sh <iid> [interval-seconds]: run from inside the GitLab repo (glab resolves :id).
# Prints one line per change of "state pipeline=<status>", exits when the MR is merged or closed,
# or its pipeline failed or was canceled. Meant to run under Monitor: every line is an event.
set -u
iid="${1:?usage: watch-mr.sh <iid> [interval-seconds]}"
interval="${2:-30}"
last=""
while :; do
  if mr="$(glab api "projects/:id/merge_requests/$iid" 2>/dev/null)"; then
    now="$(printf '%s' "$mr" | jq -r '"\(.state) pipeline=\(.head_pipeline.status // "none")"' | tr -d '\r')"
  else
    now="unreachable (VPN or token?)"
  fi
  if [ "$now" != "$last" ]; then echo "$now"; last="$now"; fi
  case "$now" in
    merged*|closed*|*pipeline=failed|*pipeline=canceled) exit 0 ;;
  esac
  sleep "$interval"
done
