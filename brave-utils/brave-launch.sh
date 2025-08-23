#!/bin/bash
# Script to launch Brave browser with remote debugging connected to FIFO pipes
# Takes input and output FIFO paths as arguments

set -euo pipefail

# Function to show usage
usage() {
    echo "Usage: $0 [INPUT_FIFO] [OUTPUT_FIFO] [BRAVE_ARGS...]"
    echo ""
    echo "Arguments:"
    echo "  INPUT_FIFO   - Path to input FIFO pipe (default: /run/user/\$UID/brave/in.fifo)"
    echo "  OUTPUT_FIFO  - Path to output FIFO pipe (default: /run/user/\$UID/brave/out.fifo)"
    echo "  BRAVE_ARGS   - Additional arguments to pass to Brave"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use default FIFOs"
    echo "  $0 /tmp/in.fifo /tmp/out.fifo        # Use custom FIFOs"
    echo "  $0 '' '' --new-window                # Use defaults + extra args"
    echo ""
    echo "Default Brave arguments added:"
    echo "  --remote-debugging-pipe"
    echo "  --no-first-run"
    echo "  --no-default-browser-check"
    echo "  --disable-background-timer-throttling"
    echo "  --disable-backgrounding-occluded-windows"
    echo "  --disable-renderer-backgrounding"
}

# Parse arguments
INPUT_FIFO="${1:-/run/user/$UID/brave/in.fifo}"
OUTPUT_FIFO="${2:-/run/user/$UID/brave/out.fifo}"

# If first arg is help, show usage
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    usage
    exit 0
fi

# Shift past the FIFO arguments if they were provided
if [[ $# -ge 2 ]]; then
    shift 2
    EXTRA_ARGS=("$@")
else
    EXTRA_ARGS=()
fi

# If empty strings were passed for FIFOs, use defaults
if [[ -z "$INPUT_FIFO" ]]; then
    INPUT_FIFO="/run/user/$UID/brave/in.fifo"
fi
if [[ -z "$OUTPUT_FIFO" ]]; then
    OUTPUT_FIFO="/run/user/$UID/brave/out.fifo"
fi

echo "Launching Brave with debugging..."
echo "Input FIFO: $INPUT_FIFO"
echo "Output FIFO: $OUTPUT_FIFO"

# Check if FIFOs exist
if [[ ! -p "$INPUT_FIFO" ]]; then
    echo "Error: Input FIFO does not exist: $INPUT_FIFO"
    echo "Make sure brave-debug-daemon.sh is running"
    exit 1
fi

if [[ ! -p "$OUTPUT_FIFO" ]]; then
    echo "Error: Output FIFO does not exist: $OUTPUT_FIFO"
    echo "Make sure brave-debug-daemon.sh is running"
    exit 1
fi

# Default Brave arguments for debugging
BRAVE_ARGS=(
    --remote-debugging-pipe
    --no-first-run
    --no-default-browser-check
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
)

# Add any extra arguments
BRAVE_ARGS+=("${EXTRA_ARGS[@]}")

echo "Starting Brave..."
echo "Command: brave-browser ${BRAVE_ARGS[*]}"
echo ""

# Launch Brave with the FIFOs connected to file descriptors 3 and 4
exec brave-browser "${BRAVE_ARGS[@]}" 3<"$INPUT_FIFO" 4>"$OUTPUT_FIFO"
