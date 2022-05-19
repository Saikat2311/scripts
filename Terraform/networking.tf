data "aws_availability_zones" "available" {
  state = "available"
}



resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  vpc_id     = var.vpc_id
  cidr_block = var.vpc_cidr_block
}

resource "aws_subnet" "subnet-A" {
  vpc_id            = var.vpc_id
  cidr_block        = var.subnet_A_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "subnet-application-A"
  }
}
resource "aws_subnet" "subnet-B" {
  vpc_id            = var.vpc_id
  cidr_block        = var.subnet_B_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "subnet-application-B"
  }
}