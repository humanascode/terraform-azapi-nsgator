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
  description = <<DESCRIPTION
  Map of rules to create.
  Each rule must have a unique workload value.
  If protocol is "Icmp", ports must not be specified.
  If protocol is not "Icmp", ports must be specified.
DESCRIPTION
  type = map(object({
    access                  = optional(string, "Allow")
    source_ips              = optional(set(string))
    destination_ips         = optional(set(string))
    ports                   = optional(set(string))
    destination_service_tag = optional(string, null)
    protocol                = string
    workload                = string
    source_port_range       = optional(string, "*")
    source_service_tag      = optional(string, null)
  }))

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        rule.source_service_tag != null ? var.source_nsg_id == null : true
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If source_service_tag is provided, source_nsg_id must not be provided.
  ERROR
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        rule.destination_service_tag != null ? var.destination_nsg_id == null : true
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If destination_service_tag is provided, destination_nsg_id must not be provided.
  ERROR
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        rule.destination_service_tag != null ?
        (rule.destination_ips == null || length(rule.destination_ips) == 0) :
        true
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If destination_service_tag is provided, destination ips must not be specified.
  ERROR
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        rule.source_service_tag != null ?
        (rule.source_ips == null || length(rule.source_ips) == 0) :
        true
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If source_service_tag is provided, source_ips must not be specified.
  ERROR
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
  rule.source_service_tag == null ? (rule.source_ips != null && length(rule.source_ips) > 0) : true
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If source_service_tag is not provided, source_ips must be specified.
  ERROR
  }


  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      contains(["Tcp", "Udp", "Icmp", "Esp", "Ah", "*"], rule.protocol)
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  Protocol must be one of: "Tcp", "Udp", "Icmp", "Esp", "Ah", or "*".
  ERROR
  }

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

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
      (
        lower(rule.protocol) == "icmp" ?
        (rule.ports == null || length(rule.ports) == 0) :
        (rule.ports != null && length(rule.ports) > 0)
      )
    ])
    error_message = <<ERROR
  *********************VALIDATION ERROR*********************
  If protocol is "Icmp", ports must not be specified.
  If protocol is not "Icmp", ports must be specified.
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
  nullable    = false
  description = <<DESCRIPTION
  Priority range for the NSG rules.
  This defines the allowed priority range for the NSG rules to be created or updated.
  The priority range must be within the valid range of 100 to 4096.
DESCRIPTION

  validation {
    condition     = var.source_nsg_id != null ? (var.priority_range.source_start != null && var.priority_range.source_end != null) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
When source_nsg_id is provided, priority_range.source_start and priority_range.source_end must be specified.
ERROR
  }
  validation {
    condition     = var.destination_nsg_id != null ? (var.priority_range.destination_start != null && var.priority_range.destination_end != null) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
When destination_nsg_id is provided, priority_range.destination_start and priority_range.destination_end must be specified.
ERROR
  }
  validation {
    condition = var.source_nsg_id != null ? (
      var.priority_range.source_start < var.priority_range.source_end
    ) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
priority_range.source_start must be less than priority_range.source_end.
ERROR
  }
  validation {
    condition = var.destination_nsg_id != null ? (
      var.priority_range.destination_start < var.priority_range.destination_end
    ) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
priority_range.destination_start must be less than priority_range.destination_end.
ERROR
  }
  validation {
    condition = var.source_nsg_id != null ? (
      (var.priority_range.source_start >= 100 && var.priority_range.source_start <= 4096) && (var.priority_range.source_end >= 100 && var.priority_range.source_end <= 4096)
    ) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
priority_range.source_start and priority_range.source_end must be between 100 and 4096, inclusive.
ERROR
  }
  validation {
    condition = var.destination_nsg_id != null ? (
      (var.priority_range.destination_start >= 100 && var.priority_range.destination_start <= 4096) && (var.priority_range.destination_end >= 100 && var.priority_range.destination_end <= 4096)
    ) : true
    error_message = <<ERROR
*********************VALIDATION ERROR*********************
priority_range.destination_start and priority_range.destination_end must be between 100 and 4096, inclusive.
ERROR
  }
}