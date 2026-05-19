resource "aws_lb" "wp_alb" {
  name               = "wp-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "wp_tg" {
  name     = "wp-tg-${var.environment}"
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

resource "aws_launch_template" "wp" {
  name_prefix   = "wp-template-"
  image_id      = var.wp_ami_id
  instance_type = local.cfg.instance_type

  network_interfaces {
    security_groups = [aws_security_group.web.id]
  }

  user_data = base64encode(templatefile("${path.module}/mount_efs.sh", {
    efs_id = aws_efs_file_system.wp_efs.id
  }))
}

resource "aws_autoscaling_group" "wp_asg" {
  name                = "wp-asg-${var.environment}"
  vpc_zone_identifier = aws_subnet.private_web[*].id
  target_group_arns   = [aws_lb_target_group.wp_tg.arn]
  
  min_size         = local.cfg.asg_min
  max_size         = local.cfg.asg_max
  desired_capacity = local.cfg.asg_min

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

resource "aws_launch_template" "bastion" {
  name_prefix   = "bastion-template-"
  image_id      = var.bastion_ami_id
  instance_type = "t3.micro"

  network_interfaces {
    security_groups             = [aws_security_group.bastion.id]
    associate_public_ip_address = true
  }
}

resource "aws_autoscaling_group" "bastion_asg" {
  name                = "bastion-asg-${var.environment}"
  vpc_zone_identifier = aws_subnet.public[*].id
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }
}