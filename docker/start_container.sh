#!/bin/bash

# Start the SSH service
service ssh start -D

# Start the WebSocket server in the background
python3 /usr/local/bin/irc_websocket_server.py &

if [ "$1" = "interactive" ]; then
    # Start an interactive shell
    /bin/bash
else
    # Keep the container running
    tail -f /dev/null
fi