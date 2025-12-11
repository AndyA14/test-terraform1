variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile_frontend" {
  type    = string
  default = "academy-front" # o lo que uses en tu máquina
}

variable "frontend_docker_image" {
  type    = string
  default = "TU_USUARIO_DOCKER/pokemon-frontend:latest"
}
