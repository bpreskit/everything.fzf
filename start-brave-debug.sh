#!/bin/bash
# Script to start Brave with remote debugging via Unix socket and FIFO pipes
# Based on the technique from brian-special/memories/2025-08-21-brave-debug-fifo.org

set -euo pipefail

# Configuration
BRAVE_DIR="/run/user/$UID/brave"
SOCKET_PATH="$BRAVE_DIR/brave.sock"
IN_FIFO="$BRAVE_DIR/in.fifo"
OUT_FIFO="$BRAVE_DIR/out.fifo"
PIDFILE="$BRAVE_DIR/brave.pid"
BRIDGE_PIDFILE="$BRAVE_DIR/bridge.pid"

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    
    # Kill bridge process if it exists
    if [[ -f "$BRIDGE_PIDFILE" ]]; then
        local bridge_pid=$(cat "$BRIDGE_PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$bridge_pid" ]] && kill -0 "$bridge_pid" 2>/dev/null; then
            echo "Stopping bridge process (PID: $bridge_pid)"
            kill "$bridge_pid" 2>/dev/null || true
        fi
        rm -f "$BRIDGE_PIDFILE"
    fi
    
    # Kill Brave process if it exists
    if [[ -f "$PIDFILE" ]]; then
        local brave_pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$brave_pid" ]] && kill -0 "$brave_pid" 2>/dev/null; then
            echo "Stopping Brave process (PID: $brave_pid)"
            kill "$brave_pid" 2>/dev/null || true
            # Give it a moment to exit gracefully
            sleep 2
            # Force kill if still running
            if kill -0 "$brave_pid" 2>/dev/null; then
                echo "Force killing Brave process"
                kill -9 "$brave_pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PIDFILE"
    fi
    
    # Remove socket and FIFOs
    rm -f "$SOCKET_PATH" "$IN_FIFO" "$OUT_FIFO"
}

# Function to check if processes are running
check_status() {
    local brave_running=false
    local bridge_running=false
    
    if [[ -f "$PIDFILE" ]]; then
        local brave_pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$brave_pid" ]] && kill -0 "$brave_pid" 2>/dev/null; then
            brave_running=true
        fi
    fi
    
    if [[ -f "$BRIDGE_PIDFILE" ]]; then
        local bridge_pid=$(cat "$BRIDGE_PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$bridge_pid" ]] && kill -0 "$bridge_pid" 2>/dev/null; then
            bridge_running=true
        fi
    fi
    
    if $brave_running && $bridge_running && [[ -S "$SOCKET_PATH" ]]; then
        echo "Brave debugging is running (socket: $SOCKET_PATH)"
        return 0
    else
        echo "Brave debugging is not running"
        return 1
    fi
}

# Function to start the debugging setup
start_debug() {
    # Check if already running
    if check_status >/dev/null 2>&1; then
        echo "Brave debugging is already running"
        return 0
    fi
    
    # Create directory
    mkdir -p "$BRAVE_DIR"
    
    # Clean up any existing files
    rm -f "$SOCKET_PATH" "$IN_FIFO" "$OUT_FIFO" "$PIDFILE" "$BRIDGE_PIDFILE"
    
    # Create named pipes (FIFOs)
    echo "Creating named pipes..."
    mkfifo "$IN_FIFO" "$OUT_FIFO"
    
    # Start Brave with remote debugging pipe
    echo "Starting Brave with remote debugging..."
    brave-browser --remote-debugging-pipe \
        --no-first-run \
        --no-default-browser-check \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        3<"$IN_FIFO" 4>"$OUT_FIFO" &
    
    local brave_pid=$!
    echo "$brave_pid" > "$PIDFILE"
    echo "Brave started (PID: $brave_pid)"
    
    # Give Brave a moment to start
    sleep 2
    
    # Check if Brave is still running
    if ! kill -0 "$brave_pid" 2>/dev/null; then
        echo "Error: Brave failed to start"
        cleanup
        return 1
    fi
    
    # Start the persistent bridge server
    echo "Starting bridge server..."
    nc -lUk "$SOCKET_PATH" >"$IN_FIFO" <"$OUT_FIFO" &
    local bridge_pid=$!
    echo "$bridge_pid" > "$BRIDGE_PIDFILE"
    echo "Bridge started (PID: $bridge_pid)"
    
    # Give the bridge a moment to start
    sleep 1
    
    # Check if bridge is still running
    if ! kill -0 "$bridge_pid" 2>/dev/null; then
        echo "Error: Bridge failed to start"
        cleanup
        return 1
    fi
    
    # Test the connection
    echo "Testing connection..."
    if printf '{"id": 1, "method": "Browser.getVersion"}\0' | nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1; then
        echo "Success! Brave debugging is ready at $SOCKET_PATH"
        echo "Use 'brave.fzf' or send DevTools Protocol commands to the socket"
    else
        echo "Warning: Connection test failed, but processes are running"
    fi
}

# Function to stop the debugging setup
stop_debug() {
    cleanup
    echo "Brave debugging stopped"
}

# Main script logic
case "${1:-start}" in
    start)
        start_debug
        ;;
    stop)
        stop_debug
        ;;
    restart)
        stop_debug
        sleep 1
        start_debug
        ;;
    status)
        check_status
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start    - Start Brave with debugging (default)"
        echo "  stop     - Stop Brave and cleanup"
        echo "  restart  - Stop and start again"
        echo "  status   - Check if running"
        echo "  cleanup  - Force cleanup of processes and files"
        exit 1
        ;;
esac
