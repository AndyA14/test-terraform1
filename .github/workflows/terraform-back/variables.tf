variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "aws_profile_back" {
  type        = string
  description = "AWS CLI profile for backend account (Learner Lab B)"
  default     = "academy-back"
}

variable "backend_image" {
  type        = string
  description = "Docker image for backend"
  default     = "aceofglass14/pokedx-backend:latest"
}

variable "db_name" {
  type        = string
  default     = "pokedx"
}

variable "db_user" {
  type        = string
  default     = "pokedx_user"
}

variable "db_password" {
  type        = string
  default     = "supersecretpassword"
}
