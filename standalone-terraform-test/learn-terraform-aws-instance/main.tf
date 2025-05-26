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

resource "aws_security_group" "allow_dev_ports" {
  name        = "allow_dev_ports"
  description = "Allow inbound traffic for development"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node.js default port"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Python/Flask default port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "app_server_profile" {
  name = "app-server-profile"
  role = "EC2-SSM-ParameterStore-ReadOnly" # <-- Replace with your IAM role name
}

resource "aws_instance" "app_server" {
  
  # old ami           = "ami-0e82046e2f06c0a68"  # Amazon Linux 2 AMI

  ami = "ami-03d8b47244d950bbb" # Amazon Linux 2023 AMI

  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_dev_ports.id]
  iam_instance_profile = aws_iam_instance_profile.app_server_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Update system packages
              sudo yum update -y

              sudo yum install -y nodejs
              sudo yum install -y git  

              # Get the GitHub password (this is a secure string parameter)
              export DCAVEY_GITHUB_PASSWORD=$(aws ssm get-parameter --name "DCAVEY_GITHUB_PASSWORD" --with-decryption --region eu-west-1 --query "Parameter.Value" --output text)
              export OPENAI_API_KEY=$(aws ssm get-parameter --name "OPENAI_API_KEY" --with-decryption --region eu-west-1 --query "Parameter.Value" --output text)

              # Change to ec2-user's home directory
              cd /home/ec2-user

              # Get the repo
              git clone https://dcavey:$DCAVEY_GITHUB_PASSWORD@github.com/dcavey/my-openai-mockup-test.git

              cd my-openai-mockup-test

              # install the required nodejs packages
              sudo npm install express

              # Start the node server
              node mock_openai.js
EOF

  tags = {
    Name = "mock-openAI-server"
  }
}
