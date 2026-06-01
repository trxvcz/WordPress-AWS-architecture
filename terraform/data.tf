# --- AMAZON AURORA CLUSTER ---
resource "aws_db_subnet_group" "aurora" {
  name       = "vpc-01-aurora-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "vpc-01-aurora-cluster"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.04.1" # Kompatybilne z MySQL 8.0
  database_name          = "wordpress"
  master_username        = "admin"
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
}

# Tworzenie instancji wewnątrz klastra (Primary i Replica)
resource "aws_rds_cluster_instance" "aurora_instances" {
  count                = local.cfg.multi_az ? 2 : 1
  identifier           = "vpc-01-aurora-instance-${var.environment}-${count.index}"
  cluster_identifier   = aws_rds_cluster.aurora.id
  
  # Poprawka: Aurora MySQL 8.0 wymaga absolutnego minimum w postaci db.t3.medium
  instance_class       = "db.t3.medium" 
  
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  availability_zone    = data.aws_availability_zones.available.names[count.index]
}

# --- ELASTIC FILE SYSTEM (EFS) ---
resource "aws_efs_file_system" "wp_efs" {
  creation_token = "VPC-01-EFS"
  encrypted      = true
  tags = {
    Name = "VPC-01-EFS"
  }
}

resource "aws_efs_mount_target" "wp_efs_mt_a" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "wp_efs_mt_b" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs.id]
}