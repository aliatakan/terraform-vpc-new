variable company {}
variable profile {}
variable region {}
variable environment {}
variable class {
  type = map
  default = {
    "dev"   = "21"
    "prod"  = "22"
  }
} 

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "Vpc" {
  cidr_block = format("10.%s.0.0/16", var.class[var.environment])

  tags = {
    Name = format("%s-%s-vpc", var.company, var.environment)
  }
}

resource "aws_subnet" "PrivateSubnet" {
  count               = 2
  vpc_id              = aws_vpc.Vpc.id
  cidr_block          = format("10.%s.%s.0/24", var.class[var.environment], count.index + 10)
  availability_zone   = data.aws_availability_zones.available.names[count.index]

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Name                              = format("%s-%s-private-subnet-%s", var.company, var.environment, count.index + 1)
    Type                              = "private"
    
  }
}

resource "aws_subnet" "PublicSubnet" {
  count                   = 2
  vpc_id                  = aws_vpc.Vpc.id
  cidr_block              = format("10.%s.%s.0/24", var.class[var.environment], count.index + 20)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/role/elb" = "1"
    Name                     = format("%s-%s-public-subnet-%s", var.company, var.environment, count.index + 1)
    Type                     = "public"
  }
}

resource "aws_internet_gateway" "Igw" {
  vpc_id = aws_vpc.Vpc.id

  tags = {
    Name = format("%s-%s-igw", var.company, var.environment)
  }
}

resource "aws_route_table" "PublicRouteTable" {
  vpc_id = aws_vpc.Vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Igw.id
  }

  tags = {
    Name = format("%s-%s-public-route-table", var.company, var.environment)
  }
}

resource "aws_route_table_association" "PublicRouteTableAsc" {
  count           = 2
  subnet_id       = aws_subnet.PublicSubnet[count.index].id
  route_table_id  = aws_route_table.PublicRouteTable.id
}

resource "aws_eip" "ElasticIp" {
  depends_on = [aws_internet_gateway.Igw]
}

resource "aws_nat_gateway" "Ngw" {
  allocation_id   = aws_eip.ElasticIp.id
  subnet_id       = aws_subnet.PublicSubnet[0].id
  depends_on      = [aws_eip.ElasticIp]

  tags = {
    Name = format("%s-%s-ngw", var.company, var.environment)
  }
}

resource "aws_route_table" "PrivateRouteTable" {
  vpc_id = aws_vpc.Vpc.id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.Ngw.id
  }

  tags = {
    Name = format("%s-%s-private-route-table", var.company, var.environment)
  }
}

resource "aws_route_table_association" "PrivateRouteTableAsc" {
  count           = 2
  subnet_id       = aws_subnet.PrivateSubnet[count.index].id
  route_table_id  = aws_route_table.PrivateRouteTable.id
}

# OUTPUTS
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.Vpc.id
}