resource "aws_launch_template" "server" {
  name_prefix   = "server"
  image_id      = ""
  instance_type = ""
  key_name      = var.ssh_key

  network_interfaces {
    security_groups             = [aws_security_group.puppet_cluster.id]
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.subnet-A.id
    delete_on_termination       = true
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 100

    }
  }
}

resource "aws_autoscaling_group" "server-dc1" {
  desired_capacity = 1
  max_size         = 1
  min_size         = 1
  # vpc_zone_identifier = ["aws_subnet.subnet-A.id"]

  health_check_type = "EC2"

  lifecycle {
    create_before_destroy = true
  }
  for_each = aws_autoscaling_group.server-dc1
  tag {
    key                 = "Name"
    value               = "server-dc1"
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.server.id
    version = "$Latest"
  }
}