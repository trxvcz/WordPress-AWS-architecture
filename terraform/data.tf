# 3. Elastic File System
resource "aws_efs_file_system" "wp_efs" {
  creation_token = "wp-efs-${var.environment}"
  encrypted      = true
}

resource "aws_efs_mount_target" "wp_efs_mt" {
  count           = 2
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.private_web[count.index].id
  security_groups = [aws_security_group.db_efs.id]
}

# 5. Database (RDS)
resource "aws_db_subnet_group" "wp_db" {
  name       = "wp-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id
}

resource "aws_db_instance" "wp_db" {
  identifier             = "wp-db-${lower(var.environment)}"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Adjust via locals if needed
  allocated_storage      = 20
  db_name                = "wordpress"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.wp_db.name
  vpc_security_group_ids = [aws_security_group.db_efs.id]
  multi_az               = local.cfg.multi_az
  skip_final_snapshot    = true
}