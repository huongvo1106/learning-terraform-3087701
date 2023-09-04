data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner] # Bitnami
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", 
                     "${var.environment.network_prefix}.102.0/24", 
                     "${var.environment.network_prefix}.103.0/24"]

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]

  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"
  name    = "blog"
  min_size = var.min_size
  max_size = var.max_size

  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = module.blog_alb.target_group_arns
  security_groups = [module.blog_sg.security_group_id]

  image_id           = data.aws_ami.app_ami.id
  instance_type      = var.instance_type
}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "blog-alb"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.blog_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "blog"
      backend_protocol = "HTTP"
      backend_port     = 80
        my_other_target = {
          port = 8080
        }
    }
    
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Dev"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name    = "blog"

  vpc_id                = module.vpc.vpc_id
  ingress_rules         = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks   = ["0.0.0.0/0"]
  egress_rules         = ["all-all"]
  egress_cidr_blocks   = ["0.0.0.0/0"]
}
