variable "network_name" {
  type    = string
  default = "auth-check-vpc"
  validation {
    condition     = length(var.network_name) > 0
    error_message = "network_name cannot be empty"
  }
}
