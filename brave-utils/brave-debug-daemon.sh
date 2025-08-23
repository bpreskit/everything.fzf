#!/bin/bash
# Lightweight daemon to set up FIFO pipes, Unix socket, and netcat bridge
# This runs persistently and allows browsers to connect/disconnect on demand

set -euo pipefail

# Configuration
BRAVE_DIR="/run/user/$UID/brave"
SOCKET_PATH="$BRAVE_DIR/brave.sock"
IN_FIFO="$BRAVE_DIR/in.fifo"
OUT_FIFO="$BRAVE_DIR/out.fifo"
PIDFILE="$BRAVE_DIR/daemon.pid"

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up daemon..."
    
    # Remove socket and FIFOs
    rm -f "$SOCKET_PATH" "$IN_FIFO" "$OUT_FIFO" "$PIDFILE"
    
    # Kill any remaining nc processes
    pkill -f "nc.*$SOCKET_PATH" 2>/dev/null || true
}

# Function to check if daemon is already running
check_running() {
    if [[ -f "$PIDFILE" ]]; then
        local pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        fi
    fi
    return 1  # Not running
}

# Function to start the daemon
start_daemon() {
    if check_running; then
        echo "Daemon already running (PID: $(cat "$PIDFILE"))"
        return 0
    fi
    
    echo "Starting Brave debug daemon..."
    
    # Create directory
    mkdir -p "$BRAVE_DIR"
    
    # Clean up any existing files
    rm -f "$SOCKET_PATH" "$IN_FIFO" "$OUT_FIFO" "$PIDFILE"
    
    # Create named pipes (FIFOs)
    echo "Creating named pipes..."
    mkfifo "$IN_FIFO" "$OUT_FIFO"
    
    # Set up signal handlers for cleanup
    trap cleanup EXIT INT TERM
    
    # Write PID file
    echo $$ > "$PIDFILE"
    
    echo "Daemon started (PID: $$)"
    echo "Socket: $SOCKET_PATH"
    echo "Input FIFO: $IN_FIFO"
    echo "Output FIFO: $OUT_FIFO"
    echo ""
    echo "Use brave-launch.sh to start browsers that connect to these pipes"
    echo "Press Ctrl+C to stop the daemon"
    
    # Start the persistent bridge server
    # This is the core of the daemon - it keeps the pipes open
    echo "Starting socat bridge..."

    # Use socat to create a bidirectional bridge between socket and stdio
    # Then connect stdio to the FIFOs
    # exec socat UNIX-LISTEN:"$SOCKET_PATH",fork,reuseaddr EXEC:"cat <$OUT_FIFO & cat >$IN_FIFO; wait"
    exec nc -lUk "$SOCKET_PATH" >"$IN_FIFO" <"$OUT_FIFO"
}

# Function to stop the daemon
stop_daemon() {
    if [[ -f "$PIDFILE" ]]; then
        local pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "Stopping daemon (PID: $pid)"
            kill "$pid" 2>/dev/null || true
            
            # Wait a moment for cleanup
            sleep 1
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                echo "Force killing daemon"
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
    fi
    
    # Clean up files
    rm -f "$SOCKET_PATH" "$IN_FIFO" "$OUT_FIFO" "$PIDFILE"
    
    # Kill any remaining nc processes
    pkill -f "nc.*$SOCKET_PATH" 2>/dev/null || true
    
    echo "Daemon stopped"
}

# Function to show status
show_status() {
    if check_running; then
        local pid=$(cat "$PIDFILE")
        echo "Daemon running (PID: $pid)"
        echo "Socket: $SOCKET_PATH"
        echo "Input FIFO: $IN_FIFO"
        echo "Output FIFO: $OUT_FIFO"
        
        # Test if socket is responsive
        if [[ -S "$SOCKET_PATH" ]]; then
            echo "Socket status: ✓ Available"
        else
            echo "Socket status: ✗ Not available"
        fi
        
        # Check if FIFOs exist
        if [[ -p "$IN_FIFO" && -p "$OUT_FIFO" ]]; then
            echo "FIFOs status: ✓ Available"
        else
            echo "FIFOs status: ✗ Not available"
        fi
    else
        echo "Daemon not running"
    fi
}

# Function to test the connection
test_connection() {
    if ! check_running; then
        echo "Daemon not running"
        return 1
    fi
    
    echo "Testing connection to daemon..."
    if printf '{"id": 1, "method": "Browser.getVersion"}\0' | timeout 5 nc -q 0 -U "$SOCKET_PATH" >/dev/null 2>&1; then
        echo "Connection test: ✓ Success (but no browser connected)"
    else
        echo "Connection test: ✗ Failed or timeout"
        echo "Note: This is normal if no browser is connected to the pipes"
    fi
}

# Main script logic
case "${1:-start}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        show_status
        ;;
    test)
        test_connection
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|test}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the daemon (default)"
        echo "  stop    - Stop the daemon"
        echo "  restart - Restart the daemon"
        echo "  status  - Show daemon status"
        echo "  test    - Test socket connection"
        echo ""
        echo "This daemon provides the networking infrastructure for Brave debugging."
        echo "Use brave-launch.sh to start browsers that connect to the daemon."
        exit 1
        ;;
esac
