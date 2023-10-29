// terraform server provisioning using aws resource
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

terraform {
  
  backend "s3" {
    bucket = "terraform-project-july"
    key    = "terraform.tf"
    region = "ap-south-1"
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
  }

#resource "aws_instance" "web" {
#ami           = "ami-057752b3f1d6c4d6c"
#  #instance_type = "t2.micro"
#key_name   = "Aravind"
#tags = {
# Name = "HelloWorld"
  
#creating the VPC
resource "aws_vpc" "Project-vpc" {
cidr_block = "10.10.0.0/16"

tags = {
    Name = "Project-VPC"
  } 
}

# creating the subnet resoruces 

#Availabity zone mumbai 1a
resource "aws_subnet" "Project-public-subnet-1a" {
  vpc_id     = aws_vpc.Project-vpc.id
  cidr_block = "10.10.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "project-public-subnet-1a"
  }
}
resource "aws_subnet" "Project-private-subnet-1a" {
  vpc_id     = aws_vpc.Project-vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "project-private-subnet-1a"
  }
}

#Availabity zone mumbai 1b
resource "aws_subnet" "Project-public-subnet-1b" {
  vpc_id     = aws_vpc.Project-vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "project-public-subnet-1b"
  }
}

resource "aws_subnet" "Project-private-subnet-1b" {
  vpc_id     = aws_vpc.Project-vpc.id
  cidr_block = "10.10.3.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "project-private-subnet-1b"
  }
}

#creating key pair

resource "aws_key_pair" "project-key-pair" {
  key_name   = "project-terraform-june"
  public_key = 
  }

  # creating the security group

  resource "aws_security_group" "Project_SG_allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.Project-vpc.id

  ingress {
    description      = "SSH from PC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP from PC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

# crating Internet Gateway
resource "aws_internet_gateway" "Project_IG" {
  vpc_id = aws_vpc.Project-vpc.id

  tags = {
    Name = "Project-IG"
  }
}
#creating the RT
resource "aws_route_table" "Project-RT" {
  vpc_id = aws_vpc.Project-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Project_IG.id
  }


  tags = {
    Name = "mumbai-RT"
  }
}
# Route table association for public subnet
resource "aws_route_table_association" "Project-RT-associaciation-1" {
  subnet_id      = aws_subnet.Project-public-subnet-1a.id
  route_table_id = aws_route_table.Project-RT.id
}


resource "aws_route_table_association" "Project-RT-associaciation-2" {
  subnet_id      = aws_subnet.Project-public-subnet-1b.id
  route_table_id = aws_route_table.Project-RT.id
}

# creating launch template
resource "aws_launch_template" "Project-RT" {
  name = "Project-RT"

  image_id = "ami-0f5ee92e2d63afc18"
 
  instance_type = "t2.micro"

  key_name = aws_key_pair.project-key-pair.id


  monitoring {
    enabled = true
  }


  placement {
    availability_zone = "us-west-2a"
  }

  vpc_security_group_ids = [aws_security_group.Project_SG_allow_ssh_http.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Project-instance-ASG"
    }
  }

  user_data = filebase64("userdata.sh")
}

resource "aws_autoscaling_group" "Project-ASG" {
  vpc_zone_identifier = [aws_subnet.Project-public-subnet-1a.id,aws_subnet.Project-public-subnet-1b.id]
  
  desired_capacity   = 2
  max_size           = 3
  min_size           = 2

  
  launch_template {
    id      = aws_launch_template.Project-RT.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.Project-TG-1.arn]
}

# ALB TG with ASG

resource "aws_lb_target_group" "Project-TG-1" {
  name     = "Project-TG-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Project-vpc.id
}

# LB Listener with ASG

resource "aws_lb_listener" "Project-listener-1" {
  load_balancer_arn = aws_lb.Project-LB-1.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Project-TG-1.arn
  }
}


#load balancer with ASG

resource "aws_lb" "Project-LB-1" {
  name               = "Mumbai-LB-1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Project_SG_allow_ssh_http.id]
  subnets            = [aws_subnet.Project-public-subnet-1a.id, aws_subnet.Project-public-subnet-1b.id]


  tags = {
    Environment = "production"
  }
}
