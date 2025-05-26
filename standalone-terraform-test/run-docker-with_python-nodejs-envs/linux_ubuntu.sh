#!/bin/bash
set -x

echo "Starting user data script" 

# Update packages
echo "Updating packages" 
sudo apt-get update -y
sudo apt-get upgrade -y

# Create a script to run Docker containers
echo "Creating script to run Docker containers" 
sudo bash -c 'cat <<EOF > /usr/local/bin/start-docker-containers.sh
#!/bin/bash
/usr/bin/docker run -d -p 2001:80 electronics-retail-app:latest
/usr/bin/docker run -d -p 2002:80 angular-square-drawer:latest
/usr/bin/docker run -d -p 2003:80 react-square-drawer:latest
EOF'
sudo chmod +x /usr/local/bin/start-docker-containers.sh

# Run the script to start Docker containers
echo "Running script to start Docker containers"
sudo /usr/local/bin/start-docker-containers.sh

echo "User data script completed" 