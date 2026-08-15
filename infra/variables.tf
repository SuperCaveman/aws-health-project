variable "aws_region" {
  description = "AWS Region for the low-cost HealthOps demo."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short, lowercase project identifier."
  type        = string
  default     = "healthops"
}

variable "budget_email" {
  description = "Email address for cost-budget notifications."
  type        = string
}
