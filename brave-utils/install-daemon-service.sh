#!/bin/bash
# Script to install and manage the Brave debug daemon systemd service

set -euo pipefail

SERVICE_NAME="brave-debug-daemon.service"
SERVICE_FILE="brave-debug-daemon.service"
DAEMON_SCRIPT="$(pwd)/brave-debug-daemon.sh"
LAUNCH_SCRIPT="$(pwd)/brave-launch.sh"
USER_SERVICE_DIR="$HOME/.config/systemd/user"

# Function to install the service
install_service() {
    echo "Installing Brave debug daemon systemd service..."
    
    # Check if scripts exist
    if [[ ! -f "$DAEMON_SCRIPT" ]]; then
        echo "Error: brave-debug-daemon.sh not found in current directory"
        exit 1
    fi
    
    if [[ ! -f "$LAUNCH_SCRIPT" ]]; then
        echo "Error: brave-launch.sh not found in current directory"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "$DAEMON_SCRIPT" "$LAUNCH_SCRIPT"
    
    # Create user systemd directory if it doesn't exist
    mkdir -p "$USER_SERVICE_DIR"
    
    # Copy the service file, replacing script paths
    sed "s|%h/source_code/everything.fzf/brave-utils/brave-debug-daemon.sh|$DAEMON_SCRIPT|g" \
        "$SERVICE_FILE" > "$USER_SERVICE_DIR/$SERVICE_FILE"
    
    echo "Service file installed to: $USER_SERVICE_DIR/$SERVICE_FILE"
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    echo "Systemd user daemon reloaded"
    echo ""
    echo "To manage the daemon service:"
    echo "  systemctl --user start $SERVICE_NAME"
    echo "  systemctl --user stop $SERVICE_NAME"
    echo "  systemctl --user status $SERVICE_NAME"
    echo "  systemctl --user enable $SERVICE_NAME  # Start on login"
    echo ""
    echo "To launch browsers:"
    echo "  $LAUNCH_SCRIPT"
    echo "  $LAUNCH_SCRIPT '' '' --new-window"
}

# Function to uninstall the service
uninstall_service() {
    echo "Uninstalling Brave debug daemon systemd service..."
    
    # Stop and disable the service if it's running
    if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "Stopping service..."
        systemctl --user stop "$SERVICE_NAME"
    fi
    
    if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "Disabling service..."
        systemctl --user disable "$SERVICE_NAME"
    fi
    
    # Remove the service file
    if [[ -f "$USER_SERVICE_DIR/$SERVICE_FILE" ]]; then
        rm "$USER_SERVICE_DIR/$SERVICE_FILE"
        echo "Service file removed"
    fi
    
    # Reload systemd
    systemctl --user daemon-reload
    echo "Systemd user daemon reloaded"
}

# Function to show service status
show_status() {
    echo "Brave debug daemon service status:"
    echo ""
    
    if systemctl --user list-unit-files "$SERVICE_NAME" --no-legend | grep -q "$SERVICE_NAME"; then
        echo "Service installed: ✓"
        
        if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            echo "Auto-start enabled: ✓"
        else
            echo "Auto-start enabled: ✗"
        fi
        
        if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            echo "Currently running: ✓"
        else
            echo "Currently running: ✗"
        fi
        
        echo ""
        systemctl --user status "$SERVICE_NAME" --no-pager -l
    else
        echo "Service not installed"
    fi
}

# Function to test the setup
test_setup() {
    echo "Testing Brave debug setup..."
    
    # Check if daemon is running
    if ! systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "❌ Daemon service is not running"
        echo "Start it with: systemctl --user start $SERVICE_NAME"
        return 1
    fi
    
    echo "✓ Daemon service is running"
    
    # Test the daemon directly
    if "$DAEMON_SCRIPT" status | grep -q "Daemon running"; then
        echo "✓ Daemon is responsive"
    else
        echo "❌ Daemon is not responsive"
        return 1
    fi
    
    # Check if socket exists
    local socket_path="/run/user/$UID/brave/brave.sock"
    if [[ -S "$socket_path" ]]; then
        echo "✓ Socket exists: $socket_path"
    else
        echo "❌ Socket not found: $socket_path"
        return 1
    fi
    
    echo ""
    echo "✓ Setup is working correctly!"
    echo "You can now launch browsers with: $LAUNCH_SCRIPT"
}

# Main script logic
case "${1:-help}" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    status)
        show_status
        ;;
    start)
        systemctl --user start "$SERVICE_NAME"
        echo "Daemon service started"
        ;;
    stop)
        systemctl --user stop "$SERVICE_NAME"
        echo "Daemon service stopped"
        ;;
    restart)
        systemctl --user restart "$SERVICE_NAME"
        echo "Daemon service restarted"
        ;;
    enable)
        systemctl --user enable "$SERVICE_NAME"
        echo "Daemon service enabled (will start on login)"
        ;;
    disable)
        systemctl --user disable "$SERVICE_NAME"
        echo "Daemon service disabled"
        ;;
    test)
        test_setup
        ;;
    logs)
        journalctl --user -u "$SERVICE_NAME" -f
        ;;
    help|*)
        echo "Usage: $0 {install|uninstall|status|start|stop|restart|enable|disable|test|logs}"
        echo ""
        echo "Commands:"
        echo "  install    - Install the systemd service"
        echo "  uninstall  - Remove the systemd service"
        echo "  status     - Show service status"
        echo "  start      - Start the daemon service"
        echo "  stop       - Stop the daemon service"
        echo "  restart    - Restart the daemon service"
        echo "  enable     - Enable auto-start on login"
        echo "  disable    - Disable auto-start"
        echo "  test       - Test the complete setup"
        echo "  logs       - Follow service logs"
        echo ""
        echo "Example workflow:"
        echo "  $0 install     # Install the service"
        echo "  $0 enable      # Enable auto-start on login"
        echo "  $0 start       # Start the daemon now"
        echo "  $0 test        # Test that everything works"
        echo ""
        echo "Then launch browsers with:"
        echo "  ./brave-launch.sh"
        exit 1
        ;;
esac
