variable "source_nsg_id" {
  description = "The ID of the source NSG."
  type        = string
  default     = null
  validation {
    condition     = var.source_nsg_id != null || var.destination_nsg_id != null
    error_message = "At least one of source_nsg_id or destination_nsg_id must be provided."
  }
}

variable "destination_nsg_id" {
  description = "The ID of the destination NSG."
  type        = string
  default     = null
}

variable "create_outbound_rules" {
  description = "Flag to create outbound rules."
  type        = bool
  default     = true
  validation {
    condition     = var.create_outbound_rules ? (var.source_nsg_id != null ? true : false) : true
    error_message = "Outbound rules can only be created if source_nsg_id is provided."
  }
}

variable "create_inbound_rules" {
  description = "Flag to create inbound rules."
  type        = bool
  default     = true
  validation {
    condition     = var.create_inbound_rules ? (var.destination_nsg_id != null ? true : false) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
Inbound rules can only be created if destination_nsg_id is provided.
Provide a valid destination_nsg_id to create inbound rules.
OR
Set create_inbound_rules to false if you do not want to create inbound rules.
      ERROR
  }
}

variable "rules" {
  description = "Map of rules to create."
  type = map(object({
    access            = optional(string, "Allow")
    source_ips        = set(string)
    destination_ips   = set(string)
    ports             = set(string)
    protocol          = string
    workload          = string
    source_port_range = optional(string, "*")
  }))

  validation {
    condition = (
      length(var.rules) == length(distinct([
        for rule in values(var.rules) : rule.workload
      ]))
    )
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  Each rule must have a unique workload value. Duplicate workload names are not allowed.
  ERROR
  }
}

variable "priority_range" {
  type = object({
    source_start      = optional(number, 0)
    source_end        = optional(number, 0)
    destination_start = optional(number, 0)
    destination_end   = optional(number, 0)
  })
  nullable = false
  validation {
    condition     = var.source_nsg_id != null ? (var.priority_range.source_start != null && var.priority_range.source_end != null) : true
    error_message = "When source_nsg_id is provided, priority_range.source_start and priority_range.source_end must be specified."
  }
  validation {
    condition     = var.destination_nsg_id != null ? (var.priority_range.destination_start != null && var.priority_range.destination_end != null) : true
    error_message = "When destination_nsg_id is provided, priority_range.destination_start and priority_range.destination_end must be specified."
  }
  validation {
    condition = var.source_nsg_id != null ? (
      var.priority_range.source_start < var.priority_range.source_end
    ) : true
    error_message = "priority_range.source_start must be less than priority_range.source_end."
  }
  validation {
    condition = var.destination_nsg_id != null ? (
      var.priority_range.destination_start < var.priority_range.destination_end
    ) : true
    error_message = "priority_range.destination_start must be less than priority_range.destination_end."
  }
}