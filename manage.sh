#!/bin/bash

# Change to the script's directory
cd "$(dirname "$0")"

CONTAINER_NAME="llm-agent-container"
IMAGE_NAME="llm-agent-env"

function show_help {
    echo "Usage: ./manage.sh [OPTION]"
    echo "Manage the LLM Agent Environment"
    echo ""
    echo "Options:"
    echo "  rebuild              Rebuild and run the Docker container"
    echo "  setup-and-test       Run setup and E2E tests"
    echo "  test                 Run only the E2E tests"
    echo "  add-agent <name>     Create a new agent"
    echo "  delete-agent <name>  Delete an existing agent"
    echo "  list-agents          List all agents in the container"
    echo "  exec <command>       Execute a command in the container"
    echo "  logs                 Show container logs"
    echo "  ssh <agent>          SSH into the container as an agent"
    echo "  stop                 Stop the container"
    echo "  start                Start the container"
    echo "  restart              Restart the container"
    echo "  status               Show the container status"
    echo "  help                 Show this help message"
    echo "  push                 Push the image to Docker Hub"
}

function ensure_container_exists {
    if ! docker ps -a -q -f name=$CONTAINER_NAME | grep -q .; then
        echo "Container does not exist. Creating it now..."
        docker run -d \
            -p 6668:6668 \
            -p 3010:3000 \
            -p 2222:22 \
            -v $(pwd)/ssh_key:/root/.ssh \
            -v $(pwd)/shared_user:/shared_user \
            --name $CONTAINER_NAME \
            $IMAGE_NAME keep-alive
    fi
}

function ensure_container_running {
    ensure_container_exists
    if ! docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        echo "Container is not running. Starting it now..."
        docker start $CONTAINER_NAME
        # Wait for the container to be fully up
        sleep 10
        # Start the WebSocket server
        docker exec $CONTAINER_NAME python3 /usr/local/bin/irc_websocket_server.py &
    fi
}

function exec_in_container {
    ensure_container_running
    docker exec $CONTAINER_NAME "$@" 2>/dev/null
}

function list_agents {
    ensure_container_running
    echo "Listing all custom agents:"
    exec_in_container bash -c "
        for user in \$(ls /home); do
            if [ \"\$user\" != \"ubuntu\" ] && id -u \$user >/dev/null 2>&1; then
                echo \$user
            fi
        done
    "
}

function add_agent {
    ensure_container_running
    if [ -z "$1" ]; then
        echo "Please provide an agent name"
        exit 1
    fi
    echo "Creating new agent: $1"
    exec_in_container /bin/bash -c "/usr/local/bin/create_agent $1" || {
        echo "Failed to create agent. The create_agent script might be missing."
        echo "Checking for the script location..."
        exec_in_container /bin/bash -c "find / -name create_agent 2>/dev/null"
    }
}

function push_to_registry {
    local DOCKER_USERNAME=$1
    if [ -z "$DOCKER_USERNAME" ]; then
        echo "Please provide your Docker Hub username"
        exit 1
    fi
    
    echo "Tagging image..."
    docker tag $IMAGE_NAME $DOCKER_USERNAME/$IMAGE_NAME:latest
    
    echo "Pushing image to Docker Hub..."
    docker push $DOCKER_USERNAME/$IMAGE_NAME:latest
}

function rebuild_and_run {
    echo "Building Docker image..."
    if [ ! -f docker/Dockerfile ]; then
        echo "Dockerfile not found in docker/Dockerfile. Please ensure the Dockerfile exists in the docker directory."
        exit 1
    fi
    docker build -t $IMAGE_NAME -f docker/Dockerfile .

    echo "Removing existing container if it exists..."
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    echo "Running new container..."
    docker run -d \
        -p 6668:6668 \
        -p 3010:3000 \
        -p 2222:22 \
        -v $(pwd)/ssh_key:/root/.ssh \
        -v $(pwd)/shared_user:/shared_user \
        --name $CONTAINER_NAME \
        $IMAGE_NAME
    
    echo "Waiting for container to fully start..."
    sleep 10
    
    echo "Starting WebSocket server..."
    docker exec $CONTAINER_NAME python3 /usr/local/bin/irc_websocket_server.py &
}

function pull_image {
    echo "Pulling pre-built Docker image..."
    docker pull softfl0w/llm-agent-env:latest
    
    echo "Removing existing container if it exists..."
    docker rm -f $CONTAINER_NAME 2>/dev/null || true
    
    echo "Running new container..."
    docker run -d \
        -p 6668:6668 \
        -p 3010:3000 \
        -p 2222:22 \
        -v $(pwd)/ssh_key:/root/.ssh \
        -v $(pwd)/shared_user:/shared_user \
        --name $CONTAINER_NAME \
        softfl0w/llm-agent-env:latest
    
    echo "Waiting for container to fully start..."
    sleep 10
    
    echo "Starting WebSocket server..."
    docker exec $CONTAINER_NAME python3 /usr/local/bin/irc_websocket_server.py &
}

case "$1" in
    rebuild)
        echo "Rebuilding and running Docker container..."
        rebuild_and_run
        ;;
    pull)
        echo "Pulling and running pre-built Docker image..."
        pull_image
        ;;
    setup-and-test)
        echo "Running setup and E2E tests..."
        python setup_and_run_e2e_tests.py
        ;;
    test)
        ensure_container_running
        echo "Running E2E tests..."
        cd tests && npm run test:ci
        ;;
    add-agent)
        add_agent "$2"
        ;;
    delete-agent)
        if [ -z "$2" ]; then
            echo "Please provide an agent name"
            exit 1
        fi
        ensure_container_running
        echo "Deleting agent: $2"
        exec_in_container /usr/local/bin/delete_agent "$2"
        ;;
    list-agents)
        list_agents
        ;;
    exec)
        shift
        echo "Executing command in container: $@"
        exec_in_container "$@"
        ;;
    logs)
        docker logs $CONTAINER_NAME
        ;;
    ssh)
        if [ -z "$2" ]; then
            echo "Please provide an agent name"
            exit 1
        fi
        ensure_container_running
        echo "SSHing into container as agent: $2"
        ssh "$2"@localhost -p 2222
        ;;
    stop)
        echo "Stopping container..."
        docker stop $CONTAINER_NAME
        ;;
    start)
        ensure_container_exists
        echo "Starting container..."
        docker start $CONTAINER_NAME
        ;;
    restart)
        echo "Restarting container..."
        docker restart $CONTAINER_NAME
        ;;
    status)
        if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
            echo "Container is running"
        else
            echo "Container is not running"
        fi
        ;;
    help|*)
        show_help
        ;;
    push)
        push_to_registry "$2"
        ;;
esac