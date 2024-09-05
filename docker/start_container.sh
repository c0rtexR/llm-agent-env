#!/bin/bash

echo "start_container.sh script is running"

# Start the SSH service
service ssh start
echo "SSH service started"

# Start the WebSocket server in a tmux session
echo "Starting WebSocket server..."
tmux new-session -d -s websocket_server 'python3 /usr/local/bin/scripts/irc_websocket_server.py'
echo "WebSocket server start command executed"

# Check if the container should run interactively
if [ "$1" = "interactive" ]; then
    # Start an interactive shell if "interactive" is passed as an argument
    exec /bin/bash
else
    echo "Container running in non-interactive mode"
    # Keep the container running in non-interactive mode
    exec tail -f /dev/null
fi