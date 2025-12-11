variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "aws_profile_front" {
  type        = string
  description = "AWS CLI profile for frontend account (Learner Lab A)"
  default     = "academy-front"
}

variable "frontend_image" {
  type        = string
  description = "Docker image for frontend"
  default     = "aceofglass14/pokedx-frontend:latest"
}
