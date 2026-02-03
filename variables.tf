variable "project_name" {
  description = "Base project name (lowercase recommended, letters/numbers/hyphen)"
  type        = string
  default     = "socialapp"
}

variable "location" {
  description = "Azure region to deploy to"
  type        = string
  default     = "centralus"
}