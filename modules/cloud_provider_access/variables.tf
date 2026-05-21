variable "project_id" {
  type        = string
  description = "MongoDB Atlas project ID"
}

variable "timeouts" {
  type = object({
    create = optional(string, "30m")
    update = optional(string, "30m")
    delete = optional(string, "30m")
  })
  nullable = true
}
