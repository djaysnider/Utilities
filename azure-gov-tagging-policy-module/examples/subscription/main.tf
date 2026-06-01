terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

provider "azurerm" {
  environment                = "usgovernment"
  skip_provider_registration = true

  features {}
}

module "tag_governance" {
  source = "../.."

  name_prefix         = "tag-governance"
  display_name_prefix = "Tag Governance"
  assignment_location = "usgovvirginia"

  # Start in Audit while you clean up drift. Switch to Deny once the reports are boring.
  required_tag_effect    = "Audit"
  vm_required_tag_effect = "Audit"
  allowed_values_effect  = "Audit"
  date_stamp_effect      = "Audit"
}
