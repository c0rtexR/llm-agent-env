FROM ubuntu:latest

# Use a different mirror for faster downloads
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror.math.princeton.edu/pub/ubuntu/|g' /etc/apt/sources.list

# Install necessary packages with retries
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    openssh-client \
    sqlite3 \
    curl \
    sudo \
    acl \
    openssh-server \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Ensure the /run/sshd directory exists and clean up apt cache
RUN mkdir -p /run/sshd && chmod 0755 /run/sshd

# Configure SSH
RUN echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Set up environment variables
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=lts/*
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH
ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH=$PNPM_HOME:$PATH

# Install NVM
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# Install Node.js
RUN . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

# Install pnpm and Next.js
RUN . $NVM_DIR/nvm.sh && \
    npm install -g pnpm && \
    mkdir -p $PNPM_HOME && \
    pnpm config set global-bin-dir $PNPM_HOME && \
    pnpm add -g next && \
    echo "export PATH=$PATH:$PNPM_HOME" >> /root/.bashrc

# Verify installations
RUN . $NVM_DIR/nvm.sh && \
    . /root/.bashrc && \
    node --version && \
    npm --version && \
    pnpm --version && \
    which next && \
    next --version

# Create and activate virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python WebSocket library
RUN pip3 install websockets

# Set up shared folders with write access for all
RUN mkdir /shared_agents && chmod 777 /shared_agents && \
    mkdir /shared_user && chmod 777 /shared_user

# Create scripts folder and copy scripts
RUN mkdir -p /usr/local/bin/scripts
COPY docker/create_agent.sh /usr/local/bin/scripts/
COPY docker/delete_agent.sh /usr/local/bin/scripts/
COPY src/irc_websocket_server.py /usr/local/bin/scripts/
COPY docker/start_container.sh /usr/local/bin/scripts/

RUN chmod +x /usr/local/bin/scripts/create_agent.sh \
    /usr/local/bin/scripts/delete_agent.sh \
    /usr/local/bin/scripts/start_container.sh

# Add scripts folder to PATH
ENV PATH="/usr/local/bin/scripts:${PATH}"

# Expose WebSocket port and Next.js default port
EXPOSE 6667 3000

# Expose the SSH port
EXPOSE 22

# Use the script as the entrypoint
ENTRYPOINT ["/usr/local/bin/scripts/start_container.sh"]