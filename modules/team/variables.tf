variable "prefix" {
  description = "Company prefix used in every bucket name."
  type        = string
}

variable "team_name" {
  description = "Name of the team. Comes from the team's file name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.team_name))
    error_message = "team_name must be 2-20 characters: lowercase letters, numbers and hyphens."
  }
}

variable "cost_center" {
  description = "Cost center for billing. Added as a tag."
  type        = string
}

variable "buckets" {
  description = "The team's buckets. Every bucket must say if it is public or private."
  type = list(object({
    name       = string
    visibility = string
  }))

  validation {
    condition     = length(var.buckets) >= 1
    error_message = "A team needs at least one bucket."
  }

  validation {
    condition     = alltrue([for b in var.buckets : contains(["public", "private"], b.visibility)])
    error_message = "visibility must be \"public\" or \"private\"."
  }
}