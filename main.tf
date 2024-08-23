terraform {
  backend "s3" { region = "us-east-1" }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region # region of the user account
}

# Creating an ECR Repository
resource "aws_ecr_repository" "ecomm-ecr-repo" {
  name                 = "ecomm-ecr-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Creating an ECS cluster
resource "aws_ecs_cluster" "catbird-nextjs-cluster" {
  name = "catbird-nextjs-cluster-${var.environment}" # Naming the cluster
}

# Creating the task definition
resource "aws_ecs_task_definition" "catbird-nextjs-task-test" {
  family                   = "catbird-nextjs-task-test" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "catbird-nextjs-container",
      "image": "${aws_ecr_repository.ecomm-ecr-repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]                           # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"                              # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512                                   # Specifying the memory our task requires
  cpu                      = 256                                   # Specifying the CPU our task requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn # Stating Amazon Resource Name (ARN) of the execution role
}

# Providing a reference to our default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Providing a reference to our default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "us-east-1c"
}

# Creating a load balancer
resource "aws_alb" "catbird-nextjs-lb" {
  name               = "catbird-nextjs-lb" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.catbird-nextjs-lb_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "catbird-nextjs-lb_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
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

# Creating a target group for the load balancer
resource "aws_lb_target_group" "catbird-nextjs-target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }
}

# Creating a listener for the load balancer
resource "aws_lb_listener" "catbird-nextjs-listener" {
  load_balancer_arn = aws_alb.catbird-nextjs-lb.arn # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catbird-nextjs-target_group.arn # Referencing our target group
  }
}

# Creating the service
resource "aws_ecs_service" "catbird-nextjs-service" {
  name            = "catbird-nextjs-service"
  cluster         = aws_ecs_cluster.catbird-nextjs-cluster.id            # Referencing our created Cluster
  task_definition = aws_ecs_task_definition.catbird-nextjs-task-test.arn # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1 # Setting the number of containers we want deployed to 3

  load_balancer {
    target_group_arn = aws_lb_target_group.catbird-nextjs-target_group.arn # Referencing our target group
    container_name   = "catbird-nextjs-container"
    container_port   = 3000 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true                                                               # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.catbird-nextjs-service_security_group.id}"] # Setting the security group
  }
}

# Creating a security group for the service
resource "aws_security_group" "catbird-nextjs-service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.catbird-nextjs-lb_security_group.id}"]
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol 
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

output "lb_dns" {
  value       = aws_alb.catbird-nextjs-lb.dns_name
  description = "AWS load balancer DNS Name"
}
