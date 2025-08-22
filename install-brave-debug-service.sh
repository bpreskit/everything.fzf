#!/bin/bash
# Script to install and manage the Brave debugging systemd service

set -euo pipefail

SERVICE_NAME="brave-debug@$USER.service"
SERVICE_FILE="brave-debug.service"
SCRIPT_PATH="$(pwd)/start-brave-debug.sh"
USER_SERVICE_DIR="$HOME/.config/systemd/user"

# Function to install the service
install_service() {
    echo "Installing Brave debugging systemd service..."
    
    # Check if the script exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo "Error: start-brave-debug.sh not found in current directory"
        echo "Please run this from the directory containing start-brave-debug.sh"
        exit 1
    fi
    
    # Make sure the script is executable
    chmod +x "$SCRIPT_PATH"
    
    # Create user systemd directory if it doesn't exist
    mkdir -p "$USER_SERVICE_DIR"
    
    # Copy the service file, replacing the script path
    sed "s|/home/%i/source_code/everything.fzf/start-brave-debug.sh|$SCRIPT_PATH|g" \
        "$SERVICE_FILE" > "$USER_SERVICE_DIR/$SERVICE_FILE"
    
    echo "Service file installed to: $USER_SERVICE_DIR/$SERVICE_FILE"
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    echo "Systemd user daemon reloaded"
    echo ""
    echo "To manage the service, use:"
    echo "  systemctl --user start $SERVICE_NAME"
    echo "  systemctl --user stop $SERVICE_NAME"
    echo "  systemctl --user status $SERVICE_NAME"
    echo "  systemctl --user enable $SERVICE_NAME  # Start on login"
    echo "  systemctl --user disable $SERVICE_NAME # Don't start on login"
}

# Function to uninstall the service
uninstall_service() {
    echo "Uninstalling Brave debugging systemd service..."
    
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
    echo "Brave debugging service status:"
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

# Function to enable lingering (allows user services to run without login)
enable_lingering() {
    echo "Enabling user lingering for $USER..."
    sudo loginctl enable-linger "$USER"
    echo "User lingering enabled. User services will now start at boot."
}

# Function to disable lingering
disable_lingering() {
    echo "Disabling user lingering for $USER..."
    sudo loginctl disable-linger "$USER"
    echo "User lingering disabled. User services will only run when logged in."
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
        echo "Service started"
        ;;
    stop)
        systemctl --user stop "$SERVICE_NAME"
        echo "Service stopped"
        ;;
    restart)
        systemctl --user restart "$SERVICE_NAME"
        echo "Service restarted"
        ;;
    enable)
        systemctl --user enable "$SERVICE_NAME"
        echo "Service enabled (will start on login)"
        ;;
    disable)
        systemctl --user disable "$SERVICE_NAME"
        echo "Service disabled"
        ;;
    enable-lingering)
        enable_lingering
        ;;
    disable-lingering)
        disable_lingering
        ;;
    logs)
        journalctl --user -u "$SERVICE_NAME" -f
        ;;
    help|*)
        echo "Usage: $0 {install|uninstall|status|start|stop|restart|enable|disable|enable-lingering|disable-lingering|logs}"
        echo ""
        echo "Commands:"
        echo "  install           - Install the systemd service"
        echo "  uninstall         - Remove the systemd service"
        echo "  status            - Show service status"
        echo "  start             - Start the service"
        echo "  stop              - Stop the service"
        echo "  restart           - Restart the service"
        echo "  enable            - Enable auto-start on login"
        echo "  disable           - Disable auto-start"
        echo "  enable-lingering  - Allow service to run without login (requires sudo)"
        echo "  disable-lingering - Disable running without login (requires sudo)"
        echo "  logs              - Follow service logs"
        echo ""
        echo "Example workflow:"
        echo "  $0 install                    # Install the service"
        echo "  $0 enable                     # Enable auto-start on login"
        echo "  $0 enable-lingering           # Allow running without login"
        echo "  $0 start                      # Start the service now"
        exit 1
        ;;
esac
