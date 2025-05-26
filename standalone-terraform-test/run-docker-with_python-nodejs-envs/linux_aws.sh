#!/bin/bash
set -x

echo "Starting user data script" 

# Update packages
echo "Updating packages" 
sudo yum update -y

# Install Docker
echo "Installing Docker" 
sudo amazon-linux-extras install docker -y

# Start Docker service
echo "Starting Docker service" 
sudo service docker start

# Enable Docker service
echo "Enabling Docker service" 
sudo systemctl enable docker

# Add the default user to the docker group
echo "Adding ec2-user to docker group" 
sudo usermod -aG docker ec2-user

# Create a script to run Docker containers
echo "Creating script to run Docker containers" 
sudo bash -c 'cat <<EOF > /usr/local/bin/start-docker-containers.sh
#!/bin/bash
/usr/bin/docker pull cavengi/electronics-retail-app:latest
/usr/bin/docker pull cavengi/angular-square-drawer:latest
/usr/bin/docker pull cavengi/react-square-drawer:latest
/usr/bin/docker run -d -p 2001:80 cavengi/electronics-retail-app:latest
/usr/bin/docker run -d -p 2002:80 cavengi/angular-square-drawer:latest
/usr/bin/docker run -d -p 2003:80 cavengi/react-square-drawer:latest
EOF'
sudo chmod +x /usr/local/bin/start-docker-containers.sh

# Create systemd service for Docker containers
echo "Creating systemd service for Docker containers" 
sudo bash -c 'cat <<EOF > /etc/systemd/system/docker-containers.service
[Unit]
Description=Run Docker Containers
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/local/bin/start-docker-containers.sh
ExecStop=/usr/bin/docker stop \$(/usr/bin/docker ps -q)

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd daemon
echo "Reloading systemd daemon" 
sudo systemctl daemon-reload

# Enable Docker containers service
echo "Enabling Docker containers service" 
sudo systemctl enable docker-containers.service

# Start Docker containers service
echo "Starting Docker containers service" 
sudo systemctl start docker-containers.service

echo "User data script completed" 


