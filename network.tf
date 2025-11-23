locals {
  public_subnet_cidr  = ["10.0.3.0/24"]
  private_subnet_cidr = ["10.0.1.0/24"]
  num_public_azs      = length(local.public_subnet_cidr)
  num_private_azs     = length(local.private_subnet_cidr)
  private_subnets_ids = [
    for subnet in aws_subnet.private_az : subnet.id
  ]
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_az" {
  count             = local.num_public_azs
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.public_subnet_cidr[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_subnet" "private_az" {
  count             = local.num_private_azs
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.private_subnet_cidr[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_route_table" "public" {
  count  = local.num_public_azs
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "private_az" {
  count  = local.num_private_azs
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw_az[count.index].id
  }
}

resource "aws_route_table_association" "public_subnet_az" {
  count          = local.num_public_azs
  subnet_id      = aws_subnet.public_az[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private_subnet_az" {
  count          = local.num_private_azs
  subnet_id      = aws_subnet.private_az[count.index].id
  route_table_id = aws_route_table.private_az[count.index].id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "public_igw" {
  count                  = local.num_public_azs
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_vpc_endpoint" "vpc_s3_endpoint" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.public[*].id
}

resource "aws_eip" "nat_gw_az" {
  count      = local.num_private_azs
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "gw_az" {
  count         = local.num_private_azs
  subnet_id     = aws_subnet.public_az[count.index].id
  allocation_id = aws_eip.nat_gw_az[count.index].id
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${local.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnets_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security Group for VPC endpoints to access ECR, S3 via VPC endpoints"
  vpc_id      = aws_vpc.vpc.id
}
