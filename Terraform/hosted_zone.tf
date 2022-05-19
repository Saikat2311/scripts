resource "aws_route53_zone" "private" {
  name = "novalocal.com"

  vpc {
    vpc_id = var.vpc_id
  }
}