variables {
  ssh_cidr = "203.0.113.0/24"
}

run "app_port_comes_from_dockerfile" {
  command = plan
  assert {
    condition     = output.app_port == 8080
    error_message = "App port must match the Dockerfile PORT."
  }
}

run "security_group_is_least_privilege" {
  command = plan
  assert {
    condition     = length(aws_security_group.app.ingress) == 2
    error_message = "Only SSH and the app port may be open."
  }
}

run "root_volume_is_encrypted" {
  command = plan
  assert {
    condition     = aws_instance.app.root_block_device[0].encrypted == true
    error_message = "Root volume must be encrypted."
  }
}

run "rejects_ssh_open_to_world" {
  command = plan
  variables {
    ssh_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.ssh_cidr]
}