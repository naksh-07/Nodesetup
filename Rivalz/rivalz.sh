#!/bin/bash

# Install jq
echo "Installing jq..."
sudo apt update
sudo apt install -y jq
echo "jq installed successfully."

# Install Docker
echo "Installing Docker..."
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker installed successfully."

# Check if the directory exists
if [ -d "rivalz-docker" ]; then
  echo "Directory rivalz-docker already exists."
else
  # Create the directory
  mkdir rivalz-docker
  echo "Directory rivalz-docker created."
fi

# Navigate into the directory
cd rivalz-docker

# Ask if the user wants to use a proxy
read -p "Do you want to use a proxy? (Y/N): " use_proxy

# Initialize proxy settings
proxy_type=""
proxy_ip=""
proxy_port=""
proxy_username=""
proxy_password=""

if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    # Prompt for proxy type, IP, and credentials
    read -p "Enter proxy type (http/socks5): " proxy_type
    read -p "Enter proxy IP: " proxy_ip
    read -p "Enter proxy port: " proxy_port
    read -p "Enter proxy username (leave empty if not required): " proxy_username
    read -p "Enter proxy password (leave empty if not required): " proxy_password
    echo

    # Adjust proxy type to http-connect if http is chosen
    if [[ "$proxy_type" == "http" ]]; then
        proxy_type="http-connect"
    fi
fi

# Fetch the latest version of rivalz-node-cli
version=$(curl -s https://be.rivalz.ai/api-v1/system/rnode-cli-version | jq -r '.data')

# Set latest version if version retrieval fails
if [ -z "$version" ]; then
    version="latest"
    echo "Could not fetch the version. Defaulting to latest."
fi

# Create or replace the Dockerfile with the specified content and proxy settings
cat <<EOL > Dockerfile
FROM ubuntu:latest
# Disable interactive configuration
ENV DEBIAN_FRONTEND=noninteractive

# Update and upgrade the system
RUN apt-get update && apt-get install -y curl redsocks iptables iproute2 jq nano

# Install Node.js from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \\
    apt-get install -y nodejs

RUN npm install -g npm

# Install the rivalz-node-cli package globally using npm
RUN npm install -g rivalz-node-cli@$version



# Fix Network Issue with Docker
#RUN curl -fsSL https://gist.githubusercontent.com/NodeFarmer/409d019ce21172b90f479af7c4c742eb/raw/RivalzCLINetworkFix.sh | bash

# Fix Disk Issue
#RUN curl -fsSL https://gist.githubusercontent.com/NodeFarmer/ef0d404eca8ba76f7c5f6864c4134487/raw/RivalzCLIDiskFix.sh | bash

EOL

# Only add redsocks configuration and entrypoint if proxy is used
if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    cat <<EOL >> Dockerfile
# Copy the redsocks configuration
COPY redsocks.conf /etc/redsocks.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint to the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOL
fi

# Add the common CMD instruction for all cases
cat <<EOL >> Dockerfile
# Run the rivalz command and then open a shell
CMD ["bash", "-c", "cd /usr/lib/node_modules/rivalz-node-cli && npm install && rivalz run; exec /bin/bash"]
EOL

# Create the redsocks configuration file only if proxy is used
if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    cat <<EOL > redsocks.conf
base {
    log_debug = off;
    log_info = on;
    log = "file:/var/log/redsocks.log";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $proxy_ip;
    port = $proxy_port;
    type = $proxy_type;
EOL

    # Append login and password if provided
    if [[ -n "$proxy_username" ]]; then
        cat <<EOL >> redsocks.conf
    login = "$proxy_username";
EOL
    fi

    if [[ -n "$proxy_password" ]]; then
        cat <<EOL >> redsocks.conf
    password = "$proxy_password";
EOL
    fi

    cat <<EOL >> redsocks.conf
}
EOL

    # Create the entrypoint script
    cat <<EOL > entrypoint.sh
#!/bin/sh

echo "Starting redsocks..."
redsocks -c /etc/redsocks.conf &
echo "Redsocks started."

# Give redsocks some time to start
sleep 5

echo "Configuring iptables..."
# Configure iptables to redirect HTTP and HTTPS traffic through redsocks
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 12345
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 12345
echo "Iptables configured."

# Execute the user's command
echo "Executing user command..."
exec "\$@"
EOL
fi

# Detect existing rivalz-docker instances and find the highest instance number
existing_instances=$(docker ps -a --filter "name=rivalz-docker-" --format "{{.Names}}" | grep -Eo 'rivalz-docker-[0-9]+' | grep -Eo '[0-9]+' | sort -n | tail -1)

# Set the instance number
if [ -z "$existing_instances" ]; then
  instance_number=1
else
  instance_number=$((existing_instances + 1))
fi

# Set the container name
container_name="rivalz-docker-$instance_number"

# Build the Docker image with the specified name
docker build -t $container_name .

# Display the completion message
echo -e "\e[32mSetup is complete. To run the Docker container, use the following command:\e[0m"
if [[ "$use_proxy" == "Y" || "$use_proxy" == "y" ]]; then
    echo "docker run -it --cap-add=NET_ADMIN --name $container_name $container_name"
else
    echo "docker run -it --name $container_name $container_name"
fi