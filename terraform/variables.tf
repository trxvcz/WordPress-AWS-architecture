variable "aws_region" {
  description = "AWS Region (us-east-2 or us-west-2)"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment: TEST, DEVELOPER, or PRODUCTION"
  type        = string
  default     = "TEST"
  validation {
    condition     = contains(["TEST", "DEVELOPER", "PRODUCTION"], var.environment)
    error_message = "Environment must be TEST, DEVELOPER, or PRODUCTION."
  }
}

variable "wp_ami_id" {
  description = "Pre-configured WordPress AMI ID"
  type        = string
  default = "ami-00e801948462f718a"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default = "SuperTajneHaslo123!"
}

variable "availability_zones" {
  description = "Static AZs for student account"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "bastion_ami_id" {
  description = "Static AMI ID for Bastion"
  type        = string
  default = "ami-00e801948462f718a"
}

locals {
  env_config = {
    TEST = {
      instance_type = "t3.micro"
      multi_az      = false
      asg_min       = 1
      asg_max       = 3
    }
    DEVELOPER = {
      instance_type = "t3.small"
      multi_az      = false
      asg_min       = 2
      asg_max       = 3
    }
    PRODUCTION = {
      instance_type = "t3.medium"
      multi_az      = true
      asg_min       = 2
      asg_max       = 6
    }
  }

  cfg = local.env_config[var.environment]
}