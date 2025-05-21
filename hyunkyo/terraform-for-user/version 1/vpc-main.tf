locals {
  vpc_name = var.vpc_name
  cidr = var.vpc_cidr
  az = split(",", var.availability_zones[var.region])
  count = length(local.az)
  public_subnets = [
    for i in range(local.count):
    cidrsubnet(local.cidr, 8, i)
  ]
  private_subnets = [
    for i in range(local.count):
    cidrsubnet(local.cidr, 8, i+100)
  ]
}

# VPC 정의
resource "aws_vpc" "test" {
  cidr_block = local.cidr
  tags = { Name = local.vpc_name }
}

# VPC default resource에 태그
resource "aws_default_route_table" "test" {
  default_route_table_id = aws_vpc.test.default_route_table_id
  tags = { Name = "${local.vpc_name}-default-route" }
}

resource "aws_default_security_group" "test" {
  vpc_id = aws_vpc.test.id
  tags = { Name = "${local.vpc_name}-default-sg" }
}

# igw, nat-gw 정의
resource "aws_eip" "nat-eip" {
  domain = "vpc"
}

resource "aws_internet_gateway" "test" {
    vpc_id = aws_vpc.test.id
    tags = { Name = "${local.vpc_name}-igw" }
}

resource "aws_nat_gateway" "test" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id = aws_subnet.public_subnets[0].id
  tags = { Name = "${local.vpc_name}-ngw" }
}

# public/private subnet 정의
resource "aws_subnet" "public_subnets" {
  count = length(local.public_subnets)

  vpc_id = aws_vpc.test.id
  cidr_block = local.public_subnets[count.index]
  availability_zone = local.az[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.vpc_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(local.private_subnets)

  vpc_id = aws_vpc.test.id
  cidr_block = local.private_subnets[count.index]
  availability_zone = local.az[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.vpc_name}-private-subnet-${count.index + 1}"
  }
}

# routing table 정의
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.test.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test.id
  }

  tags = {
    Name = "${local.vpc_name}-route-pub"
  }
}

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.test.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.test.id
  }

  tags = {
    Name = "${local.vpc_name}-route-pri"
  }
}

# subnet과 routing table 연관
resource "aws_route_table_association" "routing-asso-pub" {
  count = length(local.az)

  subnet_id = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table_association" "routing-asso-pri" {
  count = length(local.az)

  subnet_id = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route.id
}