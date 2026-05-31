# security.tf

resource "aws_security_group" "netlb" {
  name        = "VPC-01-NetLB-SG"
  vpc_id      = aws_vpc.main.id
  description = "Obsluga ruchu administracyjnego (SSH)"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "VPC-01-BastionSG"
  vpc_id      = aws_vpc.main.id
  description = "Zabezpieczenie serwerow Bastion"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.netlb.id] # Tylko od NLB
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nat_a" {
  name        = "VPC-01-NATSG-A"
  vpc_id      = aws_vpc.main.id
  description = "Obsluga ruchu wyjsciowego z podsieci prywatnych (A)"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block] # Ruch tylko z wewnatrz VPC
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nat_b" {
  name        = "VPC-01-NATSG-B"
  vpc_id      = aws_vpc.main.id
  description = "Obsluga ruchu wyjsciowego z podsieci prywatnych (B)"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "VPC-01-ALBSG"
  vpc_id      = aws_vpc.main.id
  description = "Przyjmowanie publicznego ruchu webowego"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "VPC-01-AppSG"
  vpc_id      = aws_vpc.main.id
  description = "Zabezpieczenie maszyn aplikacyjnych w ASG"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # Tylko ruch z ALB
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id] # Tylko SSH z Bastionow
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "VPC-01-DBSG"
  vpc_id      = aws_vpc.main.id
  description = "Ochrona warstwy danych (Aurora)"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id] # Tylko od instancji WordPress
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "efs" {
  name        = "VPC-01-EFSSG"
  vpc_id      = aws_vpc.main.id
  description = "Zabezpieczenie wspoldzielonego systemu plikow (EFS)"

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id] # Ruch wylacznie z grupy VPC-01-AppSG
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

