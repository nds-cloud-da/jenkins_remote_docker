#!/bin/bash

sudo yum update -y
sudo yum install -y docker git

# docker
sudo usermod -aG docker ec2-user
sudo systemctl enable docker
sudo systemctl start docker

# docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo chmod 666 /var/run/docker.sock
