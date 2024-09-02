#!/bin/bash

AGENT_NAME=$1

if [ -z "$AGENT_NAME" ]; then
    echo "Usage: create_agent <agent_name>"
    exit 1
fi

# Create user and add to sudo group
adduser --disabled-password --gecos "" $AGENT_NAME
usermod -aG sudo $AGENT_NAME

# Set up passwordless sudo for this agent
echo "$AGENT_NAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$AGENT_NAME

# Set up SSH for the agent
mkdir -p /home/$AGENT_NAME/.ssh
cp /root/.ssh/id_rsa /home/$AGENT_NAME/.ssh/
chown -R $AGENT_NAME:$AGENT_NAME /home/$AGENT_NAME/.ssh
chmod 600 /home/$AGENT_NAME/.ssh/id_rsa

# Generate SSH keys for the agent
su - $AGENT_NAME -c "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N ''"
su - $AGENT_NAME -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"

# Set up agent's environment
su - $AGENT_NAME << EOF
git config --global user.email "$AGENT_NAME@soft-flow.com"
git config --global user.name "$AGENT_NAME"
ssh-keyscan github.com >> ~/.ssh/known_hosts

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
setfacl -m u:$AGENT_NAME:rwx /shared_agents
setfacl -m u:$AGENT_NAME:rwx /shared_user  # Changed from rx to rwx

echo "Agent $AGENT_NAME created successfully with full sudo access and Next.js setup"