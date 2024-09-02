# LLM Agent Environment

[![Docker Pulls](https://img.shields.io/docker/pulls/softfl0w/llm-agent-env.svg)](https://hub.docker.com/r/softfl0w/llm-agent-env)
[![Docker Stars](https://img.shields.io/docker/stars/softfl0w/llm-agent-env.svg)](https://hub.docker.com/r/softfl0w/llm-agent-env)
[![Docker Image Size](https://img.shields.io/docker/image-size/softfl0w/llm-agent-env.svg)](https://hub.docker.com/r/softfl0w/llm-agent-env)
[![Docker Image Version](https://img.shields.io/docker/v/softfl0w/llm-agent-env.svg)](https://hub.docker.com/r/softfl0w/llm-agent-env)

LLM Agent Environment: Docker setup for AI agent development.

[Docker Hub Repository](https://hub.docker.com/r/softfl0w/llm-agent-env)

## Prerequisites

- Docker installed on your system
- Basic knowledge of Docker and command-line operations
- A GitHub SSH key for the agents to use

## Setup

1. Clone this repository:
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. Provide a GitHub SSH key:
   - Create a directory named `ssh_key` in the project root.
   - Copy your GitHub SSH private key to `ssh_key/id_rsa`.
   - Copy your GitHub SSH public key to `ssh_key/id_rsa.pub`.
   - Ensure the permissions are correct:
     ```
     chmod 600 ssh_key/id_rsa
     chmod 644 ssh_key/id_rsa.pub
     ```

3. Create a shared user folder:
   ```
   mkdir shared_user
   ```

4. Build the Docker image and start the container:
   ```
   ./manage.sh rebuild
   ```

## Managing the Environment

Use the `manage.sh` script to easily manage the LLM Agent Environment:

- To rebuild and run the Docker container:
  ```
  ./manage.sh rebuild
  ```

- To run setup and E2E tests:
  ```
  ./manage.sh setup-and-test
  ```

- To run only the E2E tests:
  ```
  ./manage.sh test
  ```

- To create a new agent:
  ```
  ./manage.sh add-agent <agent_name>
  ```

- To delete an existing agent:
  ```
  ./manage.sh delete-agent <agent_name>
  ```

- To list all agents:
  ```
  ./manage.sh list-agents
  ```

- To execute a command in the container:
  ```
  ./manage.sh exec <command>
  ```

- To view container logs:
  ```
  ./manage.sh logs
  ```

- To SSH into the container as an agent:
  ```
  ./manage.sh ssh <agent_name>
  ```

- To stop the container:
  ```
  ./manage.sh stop
  ```

- To start the container:
  ```
  ./manage.sh start
  ```

- To restart the container:
  ```
  ./manage.sh restart
  ```

- To check the container status:
  ```
  ./manage.sh status
  ```

- For help and available options:
  ```
  ./manage.sh help
  ```

## Agent Environment

Each agent's environment includes:

- Sudo access (passwordless)
- Git configuration
- Node.js and npm (via nvm)
- Python virtual environment
- Access to shared folders (/shared_agents and /shared_user)
- Next.js development setup
- Access to the provided GitHub SSH key

## Shared Resources

- `/shared_agents`: A directory accessible by all agents (internal to the container)
- `/shared_user`: A directory mounted from the host, accessible by all agents and the host

## Ports

- 6668: WebSocket server
- 3010: Mapped to container's port 3000 (for Next.js applications)
- 2222: SSH access

## WebSocket Server

The environment includes a WebSocket server (`irc_websocket_server.py`) running on port 6668. This server can be used for real-time communication between agents or external services.

## Troubleshooting

If you encounter issues:

1. Ensure the container is running:
   ```
   ./manage.sh status
   ```

2. Check container logs:
   ```
   ./manage.sh logs
   ```

3. If you can't SSH, verify the SSH service is running inside the container:
   ```
   ./manage.sh exec service ssh status
   ```

4. If agents can't access GitHub, ensure the SSH key was correctly mounted:
   ```
   ./manage.sh exec ls -l /root/.ssh
   ```

5. If you can't access files in the shared user folder, check the mounting:
   ```
   ./manage.sh exec ls -l /shared_user
   ```

## Customization

You can modify the `create_agent.sh` script in the `docker` directory to add or change the setup for each agent. After making changes, rebuild the Docker image using:

```
./manage.sh rebuild
```

## Pushing to Docker Registry

To push the LLM Agent Environment image to Docker Hub:

1. Ensure you have a Docker Hub account and you're logged in:
   ```
   docker login
   ```

2. Use the manage script to push the image:
   ```
   ./manage.sh push <your-dockerhub-username>
   ```

Replace `<your-dockerhub-username>` with your actual Docker Hub username.

This will tag the image and push it to your Docker Hub repository.

## Security Note

This setup is intended for development and testing purposes. For production use, implement proper security measures, including strong passwords and key-based authentication.

## License

This project is licensed under the MIT License with No Warranty. See the [LICENSE](LICENSE) file for details.

**Note:** This software is provided as-is, without any warranty or support. Use at your own risk.

Copyright (c) 2024 c0rtexR, soft-flow