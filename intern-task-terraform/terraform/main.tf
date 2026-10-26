
locals {
  app_dir    = "${path.module}/../../intern-task-app"
  dockerfile = file("${local.app_dir}/Dockerfile")
  app_py     = file("${local.app_dir}/app/app.py")
  app_port   = tonumber(regex("PORT=([0-9]+)", local.dockerfile)[0])

  systemd_unit = <<-EOT
    [Unit]
    Description=intern-task-app container
    After=docker.service network-online.target
    Requires=docker.service

    [Service]
    Restart=always
    RestartSec=3
    ExecStartPre=-/usr/bin/docker rm -f intern-task-app
    ExecStart=/usr/bin/docker run --rm --name intern-task-app --network host -e PORT=${local.app_port} --read-only --cap-drop ALL --security-opt no-new-privileges --memory 128m intern-task-app:local
    ExecStop=/usr/bin/docker stop intern-task-app

    [Install]
    WantedBy=multi-user.target
  EOT

  cloud_init = {
    package_update = true
    packages       = ["docker.io", "ufw", "curl"]

    users = [
      {
        name                = var.admin_user
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        lock_passwd         = true
        ssh_authorized_keys = var.admin_ssh_public_keys
      }
    ]

    write_files = [
      {
        path        = "/opt/intern-task-app/Dockerfile"
        permissions = "0644"
        encoding    = "b64"
        content     = base64encode(local.dockerfile)
      },
      {
        path        = "/opt/intern-task-app/app/app.py"
        permissions = "0644"
        encoding    = "b64"
        content     = base64encode(local.app_py)
      },
      {
        path        = "/etc/systemd/system/intern-task-app.service"
        permissions = "0644"
        content     = local.systemd_unit
      }
    ]

    runcmd = [
      "mkdir -p /opt/intern-task-app/app",
      "systemctl enable --now docker",
      "ufw default deny incoming",
      "ufw default allow outgoing",
      "ufw allow ${local.app_port}/tcp",
      "ufw allow from ${var.ssh_cidr} to any port 22 proto tcp",
      "ufw --force enable",
      "docker build -t intern-task-app:local /opt/intern-task-app",
      "systemctl daemon-reload",
      "systemctl enable --now intern-task-app",
      "timeout 90 sh -c 'until curl -sf http://127.0.0.1:${local.app_port}/healthz; do sleep 2; done'"
    ]
  }

  cloud_config = "#cloud-config\n${yamlencode(local.cloud_init)}"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "intern-task-vpc"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id  = aws_vpc.main.id
  ingress = []
  egress  = []
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "intern-task-igw"
  }
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:The task requires a public subnet so the app can be reached directly.
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "intern-task-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "intern-task-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name        = "intern-task-app"
  description = "SSH from the admin CIDR and app traffic from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Application traffic"
    from_port   = local.app_port
    to_port     = local.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS for package downloads"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for package downloads"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  #checkov:skip=CKV2_AWS_41:This app does not need AWS API access, so no instance IAM role is attached.
  #checkov:skip=CKV_AWS_126:Detailed monitoring is outside this task's scope.
  ami                         = var.ami_id
  instance_type               = var.instance_type
  ebs_optimized               = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  user_data                   = local.cloud_config
  user_data_replace_on_change = false

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 12
  }

  lifecycle {
    ignore_changes = [user_data]
  }

  tags = {
    Name = "intern-task-app"
  }
}