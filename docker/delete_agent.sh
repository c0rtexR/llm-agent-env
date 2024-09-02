#!/bin/bash

AGENT_NAME=$1

if [ -z "$AGENT_NAME" ]; then
    echo "Usage: delete_agent <agent_name>"
    exit 1
fi

if id "$AGENT_NAME" &>/dev/null; then
    echo "Deleting agent $AGENT_NAME..."

    # Kill all processes owned by the user
    echo "Terminating processes..."
    sudo pkill -u "$AGENT_NAME"
    
    # Remove the user's sudo permissions
    echo "Removing sudo permissions..."
    sudo rm /etc/sudoers.d/$AGENT_NAME
    
    # Delete the user and their home directory
    echo "Removing user and home directory..."
    sudo deluser --remove-home "$AGENT_NAME"
    
    # Check for any remaining files owned by the user and remove them, excluding shared folders
    echo "Checking for any remaining files (excluding shared folders)..."
    sudo find / \( -path /shared_agents -o -path /shared_user \) -prune -o -user "$AGENT_NAME" -exec rm -rf {} + 2>/dev/null

    # Remove agent's access from shared folders
    sudo setfacl -x u:$AGENT_NAME /shared_agents
    sudo setfacl -x u:$AGENT_NAME /shared_user

    echo "Agent $AGENT_NAME deleted successfully. Files in shared folders were preserved."
else
    echo "Agent $AGENT_NAME does not exist"
fi