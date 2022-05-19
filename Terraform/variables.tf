variable "vpc_id" {
  type    = string
  default = "vpc-016f189049b6fad52"
}

variable "subnet_A_cidr" {
  type    = string
  default = "10.20.0.0/25"

}
variable "subnet_B_cidr" {
  type    = string
  default = "10.20.0.128/25"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.20.0.0/24"
}
variable "region" {
  type    = string
  default = "us-west-2"
}
variable "ssh_key" {
  type    = string
  default = "test"
}