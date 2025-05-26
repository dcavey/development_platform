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
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user

              # Install Nginx
              sudo amazon-linux-extras install nginx1 -y

              # Configure Nginx for HTTPS
              sudo bash -c 'cat <<EOF > /etc/nginx/nginx.conf
events {}
http {
    server {
        listen 443 ssl;
        server_name your-domain.com;

        ssl_certificate /etc/ssl/certs/your-cert.pem;
        ssl_certificate_key /etc/ssl/private/your-key.pem;

        location /app3 {
            proxy_pass http://localhost:2003;
        }
    }
}
EOF'

              # Start Nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx

              # Pull and run Docker containers
              sudo bash -c 'cat <<EOF > /usr/local/bin/start-docker-containers.sh
#!/bin/bash
/usr/bin/docker pull cavengi/react-square-drawer:latest
/usr/bin/docker run -d -p 2003:80 cavengi/react-square-drawer:latest
EOF'
              sudo chmod +x /usr/local/bin/start-docker-containers.sh
              sudo /usr/local/bin/start-docker-containers.sh
              EOF

  tags = {   
    Name = "docker-with_python-nodejs-env"
  }
}

resource "aws_iam_instance_profile" "ec2_instance_connect" {
  name = "ec2_instance_connect"
  role = aws_iam_role.ec2_instance_connect.name
}
