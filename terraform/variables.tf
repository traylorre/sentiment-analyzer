variable "aws_region" {
  description = "AWS region"
  type = string
  default = "us-west-2"
}

variable "project_name" {
  description = "Project Name"
  type = string
  default = "sentiment-analyzer"
}

variable "environment" {
  description = "Environment (dev|staging|prod)"
  type = string
  default = "dev"
}
