#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -x  # Print commands and their arguments as they are executed

# Change to the project root directory
cd "$(dirname "$0")/.."

# Stop and remove all containers using the image llm-agent-env, including stopped ones
docker ps -a -q --filter ancestor=llm-agent-env | xargs -r docker rm -f

# Create a temporary build context
mkdir -p temp_build_context
cp -r docker scripts src temp_build_context/

# Rebuild the Docker image
if ! docker build -t llm-agent-env -f docker/Dockerfile temp_build_context; then
    echo "Docker build failed"
    rm -rf temp_build_context
    exit 1
fi

# Clean up the temporary build context
rm -rf temp_build_context

# Start a new container with an interactive shell
docker run -it -p 6668:6668 -p 3010:3000 llm-agent-env