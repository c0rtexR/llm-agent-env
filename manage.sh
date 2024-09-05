#!/bin/bash

# Get the directory of the script
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CONTAINER_NAME="llm-agent-container"
IMAGE_NAME="llm-agent-env"
# Parse command-line options
PROJECT_ROOT=""
while getopts ":p:" opt; do
  case $opt in
    p)
      PROJECT_ROOT="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Shift the parsed options out of the argument list
shift $((OPTIND-1))

# If PROJECT_ROOT is not set via command line, use the default
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
fi

# Verify that PROJECT_ROOT exists
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Error: Specified project root directory does not exist: $PROJECT_ROOT" >&2
    exit 1
fi

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
    echo "  start-websocket      Start the WebSocket server"
    echo "  stop-websocket       Stop the WebSocket server"
    echo "  check-websocket      Check and start the WebSocket server if not running"
    echo "  websocket-logs       Attach to WebSocket server logs"
}

function ensure_container_exists {
    if ! docker ps -a -q -f name=$CONTAINER_NAME | grep -q .; then
        echo "Container does not exist. Creating it now..."
        docker run -d \
            -p 6668:6668 \
            -p 3010:3000 \
            -p 2222:22 \
            -v "$PROJECT_ROOT/../ssh_key:/root/.ssh" \
            -v "$PROJECT_ROOT/../shared_user:/shared_user" \
            --name $CONTAINER_NAME \
            $IMAGE_NAME
    fi
}

function ensure_container_running {
    if ! docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        echo "Container is not running. Attempting to start it..."
        docker start $CONTAINER_NAME || {
            echo "Failed to start existing container. Attempting to recreate..."
            docker rm -f $CONTAINER_NAME 2>/dev/null || true
            docker run -d \
                -p 6668:6668 \
                -p 3010:3000 \
                -p 2222:22 \
                -v "$PROJECT_ROOT/../ssh_key:/root/.ssh" \
                -v "$PROJECT_ROOT/../shared_user:/shared_user" \
                --name $CONTAINER_NAME \
                $IMAGE_NAME
        }
        
        # Wait for the container to be fully up
        echo "Waiting for container to fully start..."
        for i in {1..30}; do
            if docker exec $CONTAINER_NAME echo "Container is responsive" &> /dev/null; then
                echo "Container is now running and responsive."
                break
            fi
            if [ $i -eq 30 ]; then
                echo "Container failed to become responsive after 30 seconds."
                docker logs $CONTAINER_NAME
                exit 1
            fi
            sleep 1
        done
    fi

    # Verify the container is actually running
    if ! docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
        echo "Container failed to start or stay running. Here are the logs:"
        docker logs $CONTAINER_NAME
        exit 1
    fi
}

function exec_in_container {
    ensure_container_running
    docker exec $CONTAINER_NAME "$@" 2>/dev/null
}

function add_agent {
    ensure_container_running
    if [ -z "$1" ]; then
        echo "Please provide an agent name"
        exit 1
    fi
    echo "Creating new agent: $1"
    exec_in_container /bin/bash -c "
        echo 'Current working directory:'
        pwd
        echo 'Contents of /usr/local/bin/scripts:'
        ls -l /usr/local/bin/scripts/
        echo 'Attempting to run create_agent.sh:'
        if [ -f /usr/local/bin/scripts/create_agent.sh ]; then
            echo 'Debugging information:'
            echo 'Current user: '\$(whoami)
            echo 'Current directory: '\$(pwd)
            echo 'Available disk space:'
            df -h
            echo 'Memory usage:'
            free -h
            echo 'Checking if adduser is available:'
            which adduser || echo 'adduser not found'
            echo 'adduser version:'
            adduser --version || echo 'Failed to get adduser version'
            echo 'Running create_agent.sh with bash -x:'
            bash -x /usr/local/bin/scripts/create_agent.sh $1
        else
            echo 'create_agent.sh not found in expected location'
            find / -name create_agent.sh 2>/dev/null
        fi
        echo 'create_agent.sh execution attempt completed'
        echo 'Checking if user was created:'
        id $1 || echo 'User not found'
        echo 'Checking home directory:'
        ls -l /home/$1 || echo 'Home directory not found'
        echo 'Checking /etc/passwd:'
        grep $1 /etc/passwd || echo 'User not found in /etc/passwd'
        echo 'Checking /etc/shadow:'
        sudo grep $1 /etc/shadow || echo 'User not found in /etc/shadow'
        echo 'Checking sudo configuration:'
        sudo grep $1 /etc/sudoers.d/* || echo 'User not found in sudoers'
        echo 'Checking system logs for any relevant errors:'
        grep -i 'adduser\|useradd' /var/log/syslog | tail -n 20 || echo 'No relevant logs found'
    "

    # Copy the SSH key to the host machine
    docker cp $CONTAINER_NAME:/home/$1/.ssh/id_rsa "$PROJECT_ROOT/../ssh_key/$1_id_rsa" || echo "Failed to copy SSH key. This is expected if user creation failed."
    echo "SSH key copied to $PROJECT_ROOT/../ssh_key/$1_id_rsa (if user was created successfully)"
}

function push_to_registry {
    local DOCKER_USERNAME=$1
    if [ -z "$DOCKER_USERNAME" ]; then
        echo "Please provide your Docker Hub username"
        exit 1
    fi
    
    # Check if .env file exists and contains DOCKER_PASSWORD
    if [ -f .env ] && grep -q DOCKER_PASSWORD .env; then
        export $(grep DOCKER_PASSWORD .env | xargs)
        echo "Using saved Docker Hub credentials"
        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    else
        echo "Logging in to Docker Hub..."
        if docker login -u "$DOCKER_USERNAME"; then
            # Save password to .env file
            read -sp "Enter your Docker Hub password to save for future use: " DOCKER_PASSWORD
            echo
            echo "DOCKER_PASSWORD=$DOCKER_PASSWORD" >> .env
            echo "Docker Hub password saved to .env file"
        else
            echo "Login failed. Exiting."
            exit 1
        fi
    fi
    
    echo "Checking if image exists..."
    if ! docker image inspect $IMAGE_NAME > /dev/null 2>&1; then
        echo "Image $IMAGE_NAME does not exist. Running rebuild..."
        rebuild_and_run
    fi
    
    echo "Tagging image..."
    docker tag $IMAGE_NAME $DOCKER_USERNAME/$IMAGE_NAME:latest
    if [ $? -ne 0 ]; then
        echo "Failed to tag image. This shouldn't happen as we just rebuilt it. Please check the logs above."
        exit 1
    fi
    
    echo "Pushing image to Docker Hub..."
    docker push $DOCKER_USERNAME/$IMAGE_NAME:latest
    
    if [ $? -eq 0 ]; then
        echo "Image successfully pushed to Docker Hub"
    else
        echo "Failed to push image to Docker Hub"
        exit 1
    fi
}

function rebuild_and_run {
    echo "Building Docker image..."
    echo "Current directory: $(pwd)"
    echo "PROJECT_ROOT: $PROJECT_ROOT"
    echo "Contents of current directory:"
    ls -la
    echo "Contents of PROJECT_ROOT:"
    ls -la "$PROJECT_ROOT"
    
    if [ ! -f "$PROJECT_ROOT/docker/Dockerfile" ]; then
        echo "Dockerfile not found in $PROJECT_ROOT/Dockerfile."
        echo "Please ensure the Dockerfile exists in the correct directory."
        exit 1
    fi
    
    docker build -t $IMAGE_NAME -f "$PROJECT_ROOT/docker/Dockerfile" "$PROJECT_ROOT"

    echo "Removing existing container if it exists..."
    docker rm -f $CONTAINER_NAME 2>/dev/null || true

    echo "Running new container..."
    docker run -d \
        -p 6668:6668 \
        -p 3010:3000 \
        -p 2222:22 \
        -v "$PROJECT_ROOT/../ssh_key:/root/.ssh" \
        -v "$PROJECT_ROOT/../shared_user:/shared_user" \
        --name $CONTAINER_NAME \
        $IMAGE_NAME
    
    echo "Waiting for container to fully start..."
    for i in {1..30}; do
        if docker exec $CONTAINER_NAME echo "Container is responsive" &> /dev/null; then
            echo "Container is now running and responsive."
            break
        fi
        if [ $i -eq 30 ]; then
            echo "Container failed to become responsive after 30 seconds."
            docker logs $CONTAINER_NAME
            exit 1
        fi
        sleep 1
    done
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
        -v "$PROJECT_ROOT/../ssh_key:/root/.ssh" \
        -v "$PROJECT_ROOT/../shared_user:/shared_user" \
        --name $CONTAINER_NAME \
        softfl0w/llm-agent-env:latest
    
    echo "Waiting for container to fully start..."
    for i in {1..30}; do
        if docker exec $CONTAINER_NAME echo "Container is responsive" &> /dev/null; then
            echo "Container is now running and responsive."
            break
        fi
        if [ $i -eq 30 ]; then
            echo "Container failed to become responsive after 30 seconds."
            docker logs $CONTAINER_NAME
            exit 1
        fi
        sleep 1
    done
}

function start_websocket_server {
    echo "Starting WebSocket server..."
    docker exec $CONTAINER_NAME tmux new-session -d -s websocket_server 'python3 /usr/local/bin/scripts/irc_websocket_server.py'
    echo "WebSocket server start command executed"
}

function stop_websocket_server {
    echo "Stopping WebSocket server..."
    docker exec $CONTAINER_NAME tmux kill-session -t websocket_server
    echo "WebSocket server stopped"
}

function check_websocket_server {
    echo "Checking WebSocket server status..."
    if docker exec $CONTAINER_NAME tmux has-session -t websocket_server 2>/dev/null; then
        echo "WebSocket server is running."
    else
        echo "WebSocket server is not running."
        echo "Attempting to start WebSocket server..."
        start_websocket_server
        sleep 2
        if docker exec $CONTAINER_NAME tmux has-session -t websocket_server 2>/dev/null; then
            echo "WebSocket server started successfully."
        else
            echo "Failed to start WebSocket server."
        fi
    fi
}

function websocket_logs {
    echo "Attaching to WebSocket server logs. Press Ctrl+B then D to detach."
    docker exec -it $CONTAINER_NAME tmux attach-session -t websocket_server
}

function ssh_to_agent {
    agent_name=$1
    container_id=$(docker ps -qf "name=$CONTAINER_NAME")
    
    if [ -z "$container_id" ]; then
        echo "Container not found. Make sure it's running."
        exit 1
    fi

    # Retrieve the agent's private key
    private_key=$(docker exec $container_id cat /home/$agent_name/.ssh/id_rsa)
    
    if [ -z "$private_key" ]; then
        echo "Failed to retrieve private key for $agent_name"
        exit 1
    fi

    # Save the private key to a temporary file
    temp_key_file=$(mktemp)
    echo "$private_key" > $temp_key_file
    chmod 600 $temp_key_file

    # Use the private key for SSH
    ssh -i $temp_key_file -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $agent_name@localhost -p 2222

    # Clean up
    rm $temp_key_file
}

function list_agents {
    ensure_container_running
    echo "Listing all custom agents:"
    exec_in_container bash -c "
        echo 'Contents of /home:'
        ls -l /home
        echo 'Users with home directories:'
        for user in \$(ls /home); do
            if \"\$user\" != \"ubuntu\" && id -u \$user >/dev/null 2>&1; then
                echo \$user
            fi
        done
        echo 'Contents of /root/.agent_passwords:'
        ls -l /root/.agent_passwords
    "
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
        echo "Ensuring container is running..."
        ensure_container_running
        echo "Container status:"
        docker ps -a | grep $CONTAINER_NAME
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
        exec_in_container /usr/local/bin/scripts/delete_agent.sh "$2"
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
        ssh_to_agent "$2"
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
    push)
        push_to_registry "$2"
        ;;
    start-websocket)
        start_websocket_server
        ;;
    stop-websocket)
        stop_websocket_server
        ;;
    check-websocket)
        check_websocket_server
        ;;
    websocket-logs)
        websocket_logs
        ;;
    help|*)
    show_help
    ;;
esac