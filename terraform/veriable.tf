variable "region" {
  default = "ap-south-1"
}

variable "image_tag" {
  description = "The docker image tag to deploy"
  type        = string
  default     = "latest" # Fallback
}