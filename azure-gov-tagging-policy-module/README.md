# Azure Government Tag Governance Terraform Module

This module creates Azure Policy definitions and subscription-scoped policy assignments for the attached tagging standard.

It covers:

- Required inherited subscription tags for all taggable resources.
- Modify policies that copy subscription tag values onto resources.
- Required VM-specific tags for `Microsoft.Compute/virtualMachines`.
- Allowed-value checks for controlled tags.
- `YYYY-MM-DD` format checks for date-stamp tags.
- A Resource Graph reporting query and PowerShell wrapper for non-compliant resources.

## Azure Government provider setup

```hcl
provider "azurerm" {
  environment                = "usgovernment"
  skip_provider_registration = true

  features {}
}
```

Before running Terraform from Azure CLI authentication:

```powershell
az cloud set --name AzureUSGovernment
az login
az account set --subscription "<subscription-id>"
```

## Usage

```hcl
module "tag_governance" {
  source = "./azure-gov-tagging-policy-module"

  name_prefix         = "tag-governance"
  display_name_prefix = "Tag Governance"
  assignment_location = "usgovvirginia"

  required_tag_effect    = "Audit"
  vm_required_tag_effect = "Audit"
  allowed_values_effect  = "Audit"
  date_stamp_effect      = "Audit"
}
```

Start with `Audit`. After cleanup, consider changing required and allowed-value effects to `Deny`.

## Reporting deviations

From the module root:

```powershell
pwsh ./scripts/report-tag-deviations.ps1 -AssignmentPrefix tag-governance -OutputPath .\tag-policy-deviations.csv
```

The script uses Azure Resource Graph against `Microsoft.PolicyInsights/PolicyStates` and exports current non-compliant resources.

## Notes

- Azure resources do not automatically inherit subscription or resource group tags. The module uses Azure Policy `modify` assignments for that.
- The modify assignments use system-assigned managed identities and assign `Tag Contributor` at subscription scope.
- Existing resources are evaluated as non-compliant until Azure Policy evaluation completes. Existing tags may require a remediation task or an update cycle before they are corrected.
- The date policy checks `YYYY-MM-DD` shape, not true calendar validity. For example, `2026-99-99` matches the shape but is not a real date. Use the report output for deeper validation if that matters.
- VM-specific tags are required only for `Microsoft.Compute/virtualMachines`. If you also want Arc-enabled servers, add `Microsoft.HybridCompute/machines` to the VM policy condition.
