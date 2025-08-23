# Brave Debug Utils

A modular system for managing Brave browser remote debugging with persistent infrastructure.

## Architecture

This system separates the networking infrastructure from the browser process:

1. **Daemon** (`brave-debug-daemon.sh`) - Lightweight, persistent service that manages:
   - FIFO pipes (`in.fifo`, `out.fifo`)
   - Unix socket (`brave.sock`)
   - Netcat bridge between socket and pipes

2. **Browser Launcher** (`brave-launch.sh`) - On-demand script that:
   - Launches Brave with `--remote-debugging-pipe`
   - Connects to existing FIFO pipes
   - Exits cleanly when browser closes

## Benefits

- **Persistent infrastructure**: Socket and pipes stay available even when browser closes
- **Fast browser restart**: No need to restart networking when reopening browser
- **Automatic recovery**: Daemon restarts if it crashes
- **Resource efficient**: Daemon uses minimal resources (~50MB RAM, 10% CPU)
- **Clean separation**: Browser and networking are independent

## Quick Start

```bash
cd brave-utils

# Install and start the daemon service
./install-daemon-service.sh install
./install-daemon-service.sh enable
./install-daemon-service.sh start

# Test the setup
./install-daemon-service.sh test

# Launch a browser (can be done multiple times)
./brave-launch.sh

# Launch with extra arguments
./brave-launch.sh '' '' --new-window --incognito
```

## Usage

### Daemon Management

```bash
# Direct daemon control
./brave-debug-daemon.sh start     # Start daemon
./brave-debug-daemon.sh stop      # Stop daemon
./brave-debug-daemon.sh status    # Check status
./brave-debug-daemon.sh test      # Test connection

# Systemd service control
systemctl --user start brave-debug-daemon
systemctl --user status brave-debug-daemon
systemctl --user enable brave-debug-daemon  # Auto-start on login
```

### Browser Launching

```bash
# Use default FIFOs
./brave-launch.sh

# Use custom FIFOs
./brave-launch.sh /path/to/in.fifo /path/to/out.fifo

# Add extra Brave arguments
./brave-launch.sh '' '' --new-window --incognito

# Show help
./brave-launch.sh --help
```

### Integration with brave.fzf

The daemon creates a socket at `/run/user/$UID/brave/brave.sock` that `brave.fzf` can use:

```bash
# Make sure daemon is running
systemctl --user start brave-debug-daemon

# Launch a browser
./brave-launch.sh

# Use brave.fzf (from parent directory)
../brave.fzf t
```

## Files Created

- `/run/user/$UID/brave/brave.sock` - Unix socket for DevTools Protocol
- `/run/user/$UID/brave/in.fifo` - Input FIFO pipe
- `/run/user/$UID/brave/out.fifo` - Output FIFO pipe
- `/run/user/$UID/brave/daemon.pid` - Daemon PID file

## Troubleshooting

### Daemon won't start
```bash
# Check logs
journalctl --user -u brave-debug-daemon -f

# Manual start for debugging
./brave-debug-daemon.sh start
```

### Browser won't connect
```bash
# Check if daemon is running
./brave-debug-daemon.sh status

# Check if FIFOs exist
ls -la /run/user/$UID/brave/

# Test daemon connection
./brave-debug-daemon.sh test
```

### Socket permission issues
```bash
# Check socket permissions
ls -la /run/user/$UID/brave/brave.sock

# Restart daemon
systemctl --user restart brave-debug-daemon
```

## Advanced Usage

### Multiple Browser Instances

You can launch multiple browsers connected to the same daemon:

```bash
./brave-launch.sh &  # First instance
./brave-launch.sh '' '' --new-window &  # Second instance
```

### Custom FIFO Locations

For testing or special setups:

```bash
# Start daemon with custom location (manual setup)
mkdir -p /tmp/brave-test
mkfifo /tmp/brave-test/in.fifo /tmp/brave-test/out.fifo
nc -lUk /tmp/brave-test/test.sock >/tmp/brave-test/in.fifo </tmp/brave-test/out.fifo &

# Launch browser with custom FIFOs
./brave-launch.sh /tmp/brave-test/in.fifo /tmp/brave-test/out.fifo
```

## Systemd Service Details

The daemon service is configured with:
- **Auto-restart**: Always restarts on failure
- **Resource limits**: 50MB RAM, 10% CPU
- **Security**: Minimal permissions, protected filesystem
- **Logging**: Integrated with systemd journal

View service configuration:
```bash
systemctl --user cat brave-debug-daemon
```
