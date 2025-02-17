terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_iam_role" "ec2_instance_connect" {
  name = "ec2_instance_connect"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_instance_connect_policy" {
  name = "ec2_instance_connect_policy"
  role = aws_iam_role.ec2_instance_connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = "vpc-0bdad83f4156bc452"  # Replace with your VPC ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2000
    to_port     = 2100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-0e82046e2f06c0a68"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_ssh_http.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_connect.name

  user_data = <<-EOF
              #!/bin/bash
              set -x

              # Update packages
              sudo yum update -y

              # Install Docker
              sudo amazon-linux-extras install docker -y

              # Start Docker service
              sudo service docker start

              # Enable Docker service
              sudo systemctl enable docker

              # Add the default user to the docker group
              sudo usermod -aG docker ec2-user

              # Create a script to run Docker containers
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
              sudo systemctl daemon-reload

              # Enable Docker containers service
              sudo systemctl enable docker-containers.service

              # Start Docker containers service
              sudo systemctl start docker-containers.service
              EOF

  tags = {   
    Name = "docker-enabled-aws-instance"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_connect" {
  name = "ec2_instance_connect"
  role = aws_iam_role.ec2_instance_connect.name
}
