variable "name_prefix" {
  description = "Lowercase prefix for policy definitions and assignments."
  type        = string
  default     = "tag-governance"
}

variable "display_name_prefix" {
  description = "Display name prefix for Azure Policy objects."
  type        = string
  default     = "Tag Governance"
}

variable "management_group_id" {
  description = "Optional management group ID for storing custom policy definitions. Assignments are still subscription scoped in this module."
  type        = string
  default     = null
}

variable "assignment_location" {
  description = "Location for system-assigned managed identities on modify policy assignments. Use a valid Azure Government region, for example usgovvirginia."
  type        = string
  default     = "usgovvirginia"
}

variable "enable_inheritance" {
  description = "When true, creates modify assignments that copy subscription tag values onto taggable resources."
  type        = bool
  default     = true
}

variable "required_tag_effect" {
  description = "Effect for missing inherited subscription tags."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.required_tag_effect)
    error_message = "required_tag_effect must be Audit, Deny, or Disabled."
  }
}

variable "vm_required_tag_effect" {
  description = "Effect for missing VM-specific tags."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.vm_required_tag_effect)
    error_message = "vm_required_tag_effect must be Audit, Deny, or Disabled."
  }
}

variable "allowed_values_effect" {
  description = "Effect for allowed-value violations."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.allowed_values_effect)
    error_message = "allowed_values_effect must be Audit, Deny, or Disabled."
  }
}

variable "date_stamp_effect" {
  description = "Effect for date stamp format violations."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.date_stamp_effect)
    error_message = "date_stamp_effect must be Audit, Deny, or Disabled."
  }
}

variable "modify_role_definition_name" {
  description = "Role assigned to policy assignment managed identities so modify policies can update tags."
  type        = string
  default     = "Tag Contributor"
}

variable "modify_role_definition_ids" {
  description = "Role definition IDs embedded in the Azure Policy modify definition. Contributor is broadly compatible; replace with Tag Contributor roleDefinitionId if your tenant requires least privilege."
  type        = list(string)
  default     = ["/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"]
}

variable "subscription_tag_schema" {
  description = "Required subscription-inherited resource tags from the attached policy."
  type = map(object({
    type           = string
    allowed_values = list(string)
  }))

  default = {
    "Owner" = { type = "Text" allowed_values = [] }
    "TechnicalLead" = { type = "Text" allowed_values = [] }
    "EnvironmentType" = { type = "True/False" allowed_values = ["True", "False"] }
    "MaintenanceWindowUTC" = { type = "Text" allowed_values = [] }
    "BillingIdentifier" = { type = "Text" allowed_values = [] }
    "ExpirationDate" = { type = "Date Stamp" allowed_values = [] }
    "Service" = { type = "Text" allowed_values = ["Infrastructure", "Shared Service", "Application"] }
    "Project" = { type = "Text" allowed_values = [] }
    "Status" = { type = "Text" allowed_values = ["Active", "Inactive", "Pending"] }
    "DeployedBy" = { type = "Text" allowed_values = ["Manual", "ARM", "ADO", "Portal"] }
    "Region" = { type = "Text" allowed_values = [] }
    "Compliance" = { type = "Text" allowed_values = [] }
    "DecomDate" = { type = "Date Stamp" allowed_values = [] }
    "DataClassification" = { type = "Text" allowed_values = [] }
    "Priority" = { type = "Text" allowed_values = ["High", "Medium", "Low"] }
    "BackupPolicy" = { type = "Text" allowed_values = ["Gold", "Silver"] }
    "AnsibleManaged" = { type = "True/False" allowed_values = ["True", "False"] }
  }
}

variable "vm_tag_schema" {
  description = "VM-specific tags required in addition to inherited subscription tags."
  type = map(object({
    type           = string
    allowed_values = list(string)
  }))

  default = {
    "EmergencyPatch" = { type = "True/False" allowed_values = ["True", "False"] }
    "PatchDay" = { type = "Text" allowed_values = ["Thu", "Fri", "Sat"] }
    "PatchGroup" = { type = "Text" allowed_values = ["A", "B"] }
    "PatchReboot" = { type = "Text" allowed_values = ["STD", "NR"] }
    "KeepAlive" = { type = "True/False" allowed_values = ["True", "False"] }
    "HybridVM" = { type = "True/False" allowed_values = ["True", "False"] }
    "Version" = { type = "Text" allowed_values = [] }
  }
}
