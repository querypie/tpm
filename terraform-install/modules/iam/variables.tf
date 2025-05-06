variable "team" {
  description = "Team name for resource tagging"
  type        = string
}

variable "owner" {
  description = "Owner name for resource tagging"
  type        = string
}

variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "products" {
  description = "List of products to enable (DAC, SAC, KAC, WAC)"
  type        = string
  default     = "DAC, SAC, KAC, WAC"
}
