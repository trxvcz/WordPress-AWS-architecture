# --- APPLICATION LOAD BALANCER (ALB) ---
resource "aws_lb" "wp_alb" {
  name               = "VPC-01-APPLB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  # ALB musi być w podsieciach publicznych (A i B)
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "wp_tg" {
  name     = "VPC-01-AppTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wp_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_tg.arn
  }
}

# --- WORDPRESS LAUNCH TEMPLATE ---
resource "aws_launch_template" "wp" {
  name_prefix   = "VPC-01-WP-Template-"
  image_id      = var.wp_ami_id
  instance_type = "t3.micro" # Ograniczenie Labowe
  key_name      = "vockey"   # Dodany klucz SSH do diagnostyki

  network_interfaces {
    # Przypięcie nowej nazwy grupy: VPC-01-AppSG
    security_groups = [aws_security_group.app.id]
  }

  user_data = base64encode(templatefile("${path.module}/mount_efs.sh", {
    efs_id = aws_efs_file_system.wp_efs.id
  }))
}

# --- WORDPRESS AUTO SCALING GROUP ---
resource "aws_autoscaling_group" "wp_asg" {
  name                = "VPC-01-appWP-ASG"
  # Maszyny lądują wyłącznie w podsieciach prywatnych
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  target_group_arns   = [aws_lb_target_group.wp_tg.arn]
  
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.wp.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.wp_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}


# --- BASTIONY (Prywatne) ---
resource "aws_instance" "bastion_a" {
  ami                    = var.bastion_ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = "vockey" # Klucz konta studenckiego
  tags                   = { Name = "VPC-01-Bastion-A" }
}

resource "aws_instance" "bastion_b" {
  ami                    = var.bastion_ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = "vockey"
  tags                   = { Name = "VPC-01-Bastion-B" }
}

# --- NETWORK LOAD BALANCER (Publiczny) ---
resource "aws_lb" "net_lb" {
  name               = "VPC-01-NetLB"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.netlb.id]
}

resource "aws_lb_target_group" "net_lb_tg" {
  name        = "VPC-01-NetLB-TG"
  port        = 22
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
}

resource "aws_lb_listener" "net_lb_ssh" {
  load_balancer_arn = aws_lb.net_lb.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.net_lb_tg.arn
  }
}

# Podpięcie Bastionów do Load Balancera
resource "aws_lb_target_group_attachment" "bastion_a" {
  target_group_arn = aws_lb_target_group.net_lb_tg.arn
  target_id        = aws_instance.bastion_a.id
  port             = 22
}

resource "aws_lb_target_group_attachment" "bastion_b" {
  target_group_arn = aws_lb_target_group.net_lb_tg.arn
  target_id        = aws_instance.bastion_b.id
  port             = 22
}
