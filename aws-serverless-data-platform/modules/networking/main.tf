# =============================================================================
# Networking Module
# Creates VPC, subnets, NAT gateways, and related networking components
# =============================================================================

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.networking.vpc.cidr
  enable_dns_hostnames = var.networking.vpc.enable_dns_hostnames
  enable_dns_support   = var.networking.vpc.enable_dns_support

  tags = merge(var.common_tags, var.additional_tags, {
    Name = var.vpc_name
    Type = "vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "igw-${var.environment}-${var.region}"
    Type = "internet-gateway"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.networking.subnets.public)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.subnets.public[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "subnet-public-${var.environment}-${var.region}-${count.index + 1}"
    Type = "public-subnet"
    Tier = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.networking.subnets.private)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.networking.subnets.private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "subnet-private-${var.environment}-${var.region}-${count.index + 1}"
    Type = "private-subnet"
    Tier = "private"
  })
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(var.networking.subnets.database)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.networking.subnets.database[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "subnet-database-${var.environment}-${var.region}-${count.index + 1}"
    Type = "database-subnet"
    Tier = "database"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.networking.nat_gateway.single_nat_gateway ? 1 : length(aws_subnet.public)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "eip-nat-${var.environment}-${var.region}-${count.index + 1}"
    Type = "elastic-ip"
  })
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = var.networking.nat_gateway.single_nat_gateway ? 1 : length(aws_subnet.public)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "nat-${var.environment}-${var.region}-${count.index + 1}"
    Type = "nat-gateway"
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "rt-public-${var.environment}-${var.region}"
    Type = "route-table"
    Tier = "public"
  })
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count = var.networking.nat_gateway.single_nat_gateway ? 1 : length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.networking.nat_gateway.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "rt-private-${var.environment}-${var.region}-${count.index + 1}"
    Type = "route-table"
    Tier = "private"
  })
}

# Route Table for Database Subnets
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "rt-database-${var.environment}-${var.region}"
    Type = "route-table"
    Tier = "database"
  })
}

# Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations - Private
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.networking.nat_gateway.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Route Table Associations - Database
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# VPC Flow Logs (if enabled)
resource "aws_flow_log" "vpc" {
  count = var.networking.flow_logs.enable ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count = var.networking.flow_logs.enable ? 1 : 0

  name              = "/aws/vpc/flowlogs/${var.environment}-${var.region}"
  retention_in_days = var.networking.flow_logs.retention_days

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "log-group-vpc-flow-${var.environment}-${var.region}"
    Type = "log-group"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.networking.flow_logs.enable ? 1 : 0

  name = "VPCFlowLogRole-${var.environment}-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, var.additional_tags, {
    Name = "role-vpc-flow-log-${var.environment}-${var.region}"
    Type = "iam-role"
  })
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.networking.flow_logs.enable ? 1 : 0

  name = "VPCFlowLogPolicy-${var.environment}-${var.region}"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
} 