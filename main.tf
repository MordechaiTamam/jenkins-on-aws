provider "aws" {
  region = "us-east-1"
}
data "http" "myip"{
    url = "https://ipv4.icanhazip.com"
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"

  ingress {
        # TCP (change to whatever ports you need)
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        # Please restrict your ingress to only necessary IPs and ports.
        # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
        cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
      }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
data "aws_ami" "ubuntu-image" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-impish-21.10-arm64-server-20211211"]
  }
}

resource "aws_instance" "myInstance" {
  ami           = "ami-04505e74c0741db8d"
  instance_type = "m4.4xlarge"
  key_name = "ubuntu-devops-experts"
  security_groups = ["${aws_security_group.allow_tls.name}"]
  tags = {
    key ="my key"
  }
  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo apt update -y
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt-cache policy docker-ce
    sudo apt install docker-ce -y
    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  EOF

}

resource "local_file" "ip" {
    content  = <<-EOT
    [jenkins]
    ${aws_instance.myInstance.public_ip} ansible_ssh_user=ubuntu
    EOT
    filename = "hosts"
}

output "DNS" {
  value = aws_instance.myInstance.public_dns
}