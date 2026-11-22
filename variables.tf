variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "ha-web"
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for the VPC and its subnets."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDR blocks, ordered by AZ suffix a, then b."
  type        = tuple([string, string])
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDR blocks, ordered by AZ suffix a, then b."
  type        = tuple([string, string])
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}
