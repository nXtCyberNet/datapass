resource "aws_vpc" "datapipeline" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.datapipeline.id
  tags = {
    Name = "vpc-igw"
  }


}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_nat.id
}


resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.datapipeline.id
  cidr_block = "10.0.1.0/27"
  tags = {
    Name = "private-subnet"
  }
}


resource "aws_subnet" "public_nat" {
  vpc_id                  = aws_vpc.datapipeline.id
  cidr_block              = "10.0.0.0/28"
  tags = {
    Name = "nat-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.datapipeline.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_nat.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.datapipeline.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}
