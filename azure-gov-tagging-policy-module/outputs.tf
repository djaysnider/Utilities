output "inheritance_assignment_ids" {
  description = "Policy assignment IDs for subscription tag inheritance."
  value       = { for k, v in azurerm_subscription_policy_assignment.inherit_subscription_tags : k => v.id }
}

output "required_tag_assignment_ids" {
  description = "Policy assignment IDs for missing inherited tag checks."
  value       = { for k, v in azurerm_subscription_policy_assignment.required_subscription_tags : k => v.id }
}

output "vm_required_tag_assignment_ids" {
  description = "Policy assignment IDs for missing VM tag checks."
  value       = { for k, v in azurerm_subscription_policy_assignment.required_vm_tags : k => v.id }
}

output "allowed_value_assignment_ids" {
  description = "Policy assignment IDs for allowed-value checks."
  value = merge(
    { for k, v in azurerm_subscription_policy_assignment.subscription_allowed_values : k => v.id },
    { for k, v in azurerm_subscription_policy_assignment.vm_allowed_values : "vm_${k}" => v.id }
  )
}

output "date_stamp_assignment_ids" {
  description = "Policy assignment IDs for date-stamp format checks."
  value       = { for k, v in azurerm_subscription_policy_assignment.date_stamp_format : k => v.id }
}

output "tag_deviation_report_command" {
  description = "Azure CLI command to export non-compliant resources for this tag policy set."
  value       = "pwsh ./scripts/report-tag-deviations.ps1 -AssignmentPrefix ${var.name_prefix}"
}
