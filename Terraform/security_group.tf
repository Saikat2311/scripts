resource "aws_security_group" "puppet_cluster" {
  name        = "puppet_cluster"
  description = "Allow communication between puppet cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "All connection between ports"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # dynamic "ingress" {
  #   for_each = var.ingress_port
  #   content {
  #     description = "All connection between ports"
  #     from_port   = ingress.
  #     to_port     = 0
  #     protocol    = "-1"
  #     cidr_blocks = [var.vpc_cidr_block]
  #   }
  # }
  tags = {
    Name = "test_puppet_cluster"
  }
}

