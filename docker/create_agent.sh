#!/bin/bash
set -e
set -x

AGENT_NAME=$1

if [ -z "$AGENT_NAME" ]; then
    echo "Usage: create_agent <agent_name>"
    exit 1
fi

# Create user without a password
adduser --disabled-password --gecos "" $AGENT_NAME || { echo "Failed to create user"; exit 1; }
usermod -aG sudo $AGENT_NAME || { echo "Failed to add user to sudo group"; exit 1; }

# Set up passwordless sudo for this agent
echo "$AGENT_NAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$AGENT_NAME || { echo "Failed to set up sudo"; exit 1; }

# Generate SSH key pair for the agent
su - $AGENT_NAME -c "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''" || { echo "Failed to generate SSH key pair"; exit 1; }

# Add the public key to authorized_keys
su - $AGENT_NAME -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys" || { echo "Failed to add public key to authorized_keys"; exit 1; }

# Set correct permissions
su - $AGENT_NAME -c "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys" || { echo "Failed to set correct permissions"; exit 1; }

# Output the private key (you might want to store this securely or transfer it to the user)
echo "SSH private key for $AGENT_NAME:"
cat /home/$AGENT_NAME/.ssh/id_rsa || { echo "Failed to read private key"; exit 1; }

# Set up agent's environment
su - $AGENT_NAME << EOF || { echo "Failed to set up agent's environment"; exit 1; }
git config --global user.email "$AGENT_NAME@soft-flow.com"
git config --global user.name "$AGENT_NAME"

# Set up access to global Node.js installation
echo 'export NVM_DIR="/usr/local/nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.bashrc

# Create a personal bin directory for the agent
mkdir -p ~/bin
echo "export PATH=\$PATH:/home/$AGENT_NAME/.local/bin:~/bin" >> ~/.bashrc

# Set up a personal Python virtual environment
python3 -m venv ~/.venv
echo "source ~/.venv/bin/activate" >> ~/.bashrc

# Add shared folders to the agent's environment
echo "export SHARED_AGENTS=/shared_agents" >> ~/.bashrc
echo "export SHARED_USER=/shared_user" >> ~/.bashrc

# Set up Next.js development environment
mkdir -p ~/nextjs-projects
echo 'alias create-next-app="npx create-next-app"' >> ~/.bashrc
echo 'alias next-dev="npm run dev -- -p 3000"' >> ~/.bashrc
EOF

# Ensure the agent has access to both shared folders
for folder in /shared_agents /shared_user; do
    if [ -d "$folder" ]; then
        if setfacl -m u:$AGENT_NAME:rwx "$folder"; then
            echo "Successfully set ACL on $folder"
        else
            echo "Failed to set ACL on $folder. Continuing..."
        fi
    else
        echo "$folder directory not found. Skipping ACL setup."
    fi
done

echo "Agent $AGENT_NAME created successfully with full sudo access and Next.js setup"
