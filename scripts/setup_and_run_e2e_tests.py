import os
import subprocess
import time

def run_command(command):
    print(f"Running command: {command}")
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    return output.decode('utf-8'), error.decode('utf-8'), process.returncode

def initialize_test_environment():
    print("Initializing test environment...")
    os.chdir('tests')
    
    # Check if package.json exists, if not create it
    if not os.path.exists('package.json'):
        run_command("npm init -y")
    
    # Install Cypress and other necessary packages
    run_command("npm install --save-dev cypress")
    
    # Ensure the test:ci script is in package.json
    with open('package.json', 'r') as f:
        package_json = f.read()
    if '"test:ci"' not in package_json:
        run_command('npm pkg set scripts.test:ci="cypress run --headless --config-file cypress.config.js --reporter spec"')
    
    os.chdir('..')
    print("Test environment initialized.")

def build_docker_image():
    print("Building Docker image...")
    output, error, return_code = run_command("docker build -t llm-agent-env .")
    if return_code != 0:
        print(f"Error building Docker image: {error}")
        return False
    print("Docker image built successfully.")
    return True

def start_docker_container():
    print("Starting Docker container in detached mode...")
    output, error, return_code = run_command("docker run -d -p 6668:6668 -p 3010:3000 -p 2222:22 --name llm-agent-container llm-agent-env")
    if return_code != 0:
        print(f"Error starting Docker container: {error}")
        return False
    print("Docker container started successfully.")
    return True

def wait_for_container(timeout=60, interval=1):
    print(f"Waiting for Docker container to be ready (timeout: {timeout}s)...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        output, error, return_code = run_command("docker ps --filter name=llm-agent-container --format '{{.Status}}'")
        if "Up" not in output:
            print(f"Container not running. Waiting... ({time.time() - start_time:.2f}s elapsed)")
            time.sleep(interval)
            continue

        output, error, return_code = run_command("docker exec llm-agent-container service ssh status")
        print(f"SSH status check output: {output}")
        if "is running" in output:
            print(f"SSH is running. Container is ready! Waited for {time.time() - start_time:.2f} seconds.")
            return True

        output, error, return_code = run_command("docker exec llm-agent-container pgrep -f irc_websocket_server.py")
        if return_code == 0:
            print(f"WebSocket server is running. Waited for {time.time() - start_time:.2f} seconds.")
            return True

        time.sleep(interval)

    print(f"Container or services not ready after {timeout} seconds.")
    return False

def run_tests():
    print("Running E2E tests...")
    os.chdir('tests')
    process = subprocess.Popen("npm run test:ci", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True, text=True)
    
    while True:
        output = process.stdout.readline()
        if output == '' and process.poll() is not None:
            break
        if output:
            print(output.strip())
    
    return_code = process.poll()
    os.chdir('..')
    
    if return_code == 0:
        print("All tests passed successfully!")
    else:
        print(f"Tests failed with return code: {return_code}")

def check_container_logs():
    print("Checking container logs...")
    output, error, return_code = run_command("docker logs llm-agent-container")
    if return_code == 0:
        print("Container logs:")
        print(output)
    else:
        print(f"Error retrieving container logs: {error}")

def main():
    initialize_test_environment()

    if not build_docker_image():
        print("Docker image build failed. Exiting.")
        return

    if not start_docker_container():
        print("Docker container start failed. Exiting.")
        return

    if not wait_for_container():
        print("Container setup failed. Checking logs...")
        check_container_logs()
        print("Stopping and removing Docker container...")
        run_command("docker stop llm-agent-container")
        run_command("docker rm llm-agent-container")
        return

    run_tests()

    print("Stopping and removing Docker container...")
    run_command("docker stop llm-agent-container")
    run_command("docker rm llm-agent-container")

if __name__ == "__main__":
    main()