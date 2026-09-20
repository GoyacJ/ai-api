#!/usr/bin/env bash
# Source-deploy start/stop. Run from anywhere; the script always uses the repo root.
# Usage: ./deploy.sh start | stop
# Typical flow: git pull && ./deploy.sh stop && ./deploy.sh start
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

BIN="$ROOT/new-api"
RUN_DIR="$ROOT/.run"
PID_FILE="$RUN_DIR/new-api.pid"
LOG_DIR="$ROOT/logs"
CONSOLE_LOG="$LOG_DIR/console.log"
STOP_WAIT_SECONDS="${STOP_WAIT_SECONDS:-130}"

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

pid_alive() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

read_pid() {
  if [ -f "$PID_FILE" ]; then
    tr -d '[:space:]' < "$PID_FILE"
  fi
}

running_pid() {
  local pid
  pid="$(read_pid)"
  if pid_alive "$pid"; then
    printf '%s\n' "$pid"
    return 0
  fi
  return 1
}

cmd_start() {
  local pid version
  if pid="$(running_pid)"; then
    die "already running (pid $pid); run '$0 stop' first"
  fi
  rm -f "$PID_FILE"

  [ -f "$ROOT/.env" ] || die ".env not found; copy and edit it before start"
  need_cmd bun
  need_cmd go

  mkdir -p "$RUN_DIR" "$LOG_DIR"

  version="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || true)"
  echo "building frontend..."
  (
    cd "$ROOT/web"
    bun install --frozen-lockfile
    DISABLE_ESLINT_PLUGIN=true VITE_REACT_APP_VERSION="$version" bun run build
  )

  echo "building backend..."
  CGO_ENABLED=0 GOWORK=off go build \
    -ldflags "-s -w -X 'github.com/QuantumNous/new-api/common.Version=${version}'" \
    -o "$BIN"

  echo "starting $BIN..."
  nohup "$BIN" >>"$CONSOLE_LOG" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" > "$PID_FILE"

  sleep 1
  if ! pid_alive "$pid"; then
    rm -f "$PID_FILE"
    die "process exited immediately; see $CONSOLE_LOG"
  fi
  echo "started pid $pid"
}

cmd_stop() {
  local pid waited=0
  if ! pid="$(running_pid)"; then
    rm -f "$PID_FILE"
    echo "not running"
    return 0
  fi

  echo "stopping pid $pid..."
  kill -TERM "$pid" 2>/dev/null || true
  while pid_alive "$pid"; do
    if [ "$waited" -ge "$STOP_WAIT_SECONDS" ]; then
      echo "graceful stop timed out, sending SIGKILL"
      kill -KILL "$pid" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if pid_alive "$pid"; then
    die "failed to stop pid $pid"
  fi
  rm -f "$PID_FILE"
  echo "stopped"
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  *)
    echo "usage: $0 start | stop" >&2
    exit 2
    ;;
esac
