#!/bin/bash

# Function to display a header
function display_header() {
    echo "=============================================="
    echo "           Titan Edge Setup Script"
    echo "=============================================="
}

# Prompt the user for the hash
function prompt_for_hash() {
    read -p "Please enter your hash value (myhash): " MYHASH
    if [[ -z "$MYHASH" ]]; then
        echo "Error: Hash value cannot be empty."
        exit 1
    fi
}

# Pull the Titan Edge Docker image
function pull_docker_image() {
    echo "Pulling the Titan Edge Docker image..."
    docker pull nezha123/titan-edge
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to pull the Docker image."
        exit 1
    fi
}

# Create the Titan Edge configuration directory
function create_config_directory() {
    echo "Creating the configuration directory at ~/.titanedge..."
    mkdir -p ~/.titanedge
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create the configuration directory."
        exit 1
    fi
}

# Run the Titan Edge container
function run_titan_edge_container() {
    echo "Running the Titan Edge container in detached mode..."
    docker run --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to start the Titan Edge container."
        exit 1
    fi
}

# Bind the device with the hash
function bind_device() {
    echo "Binding the device with the provided hash..."
    docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash="$MYHASH" https://api-test1.container1.titannet.io/api/v2/device/binding
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to bind the device."
        exit 1
    fi
}

# Main function to execute the steps
function main() {
    display_header
    prompt_for_hash
    pull_docker_image
    create_config_directory
    run_titan_edge_container
    bind_device
    echo "Titan Edge setup completed successfully."
}

# Execute the main function
main