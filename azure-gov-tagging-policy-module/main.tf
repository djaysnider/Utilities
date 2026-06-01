data "azurerm_subscription" "current" {}

locals {
  subscription_tag_schema = var.subscription_tag_schema
  vm_tag_schema           = var.vm_tag_schema

  subscription_tag_names = toset(keys(local.subscription_tag_schema))
  vm_tag_names           = toset(keys(local.vm_tag_schema))

  subscription_allowed_value_tags = {
    for tag, spec in local.subscription_tag_schema : tag => spec.allowed_values
    if length(spec.allowed_values) > 0
  }

  vm_allowed_value_tags = {
    for tag, spec in local.vm_tag_schema : tag => spec.allowed_values
    if length(spec.allowed_values) > 0
  }

  subscription_date_tags = toset([
    for tag, spec in local.subscription_tag_schema : tag
    if lower(spec.type) == "date stamp"
  ])

  definition_scope_id = var.management_group_id != null ? var.management_group_id : data.azurerm_subscription.current.id
}

resource "azurerm_policy_definition" "inherit_subscription_tag" {
  name                = "${var.name_prefix}-inherit-subscription-tag"
  display_name        = "${var.display_name_prefix}: inherit subscription tag"
  description         = "Adds or replaces a resource tag with the value from the subscription tag of the same name."
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = var.management_group_id

  metadata = jsonencode({
    category = "Tags"
    source   = "Terraform"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag name"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          value     = "[subscription().tags[parameters('tagName')]]"
          notEquals = ""
        },
        {
          anyOf = [
            {
              field     = "[concat('tags[', parameters('tagName'), ']')]"
              exists    = false
            },
            {
              field     = "[concat('tags[', parameters('tagName'), ']')]"
              notEquals = "[subscription().tags[parameters('tagName')]]"
            }
          ]
        }
      ]
    }
    then = {
      effect = "modify"
      details = {
        roleDefinitionIds = var.modify_role_definition_ids
        operations = [
          {
            operation = "addOrReplace"
            field     = "[concat('tags[', parameters('tagName'), ']')]"
            value     = "[subscription().tags[parameters('tagName')]]"
          }
        ]
      }
    }
  })
}

resource "azurerm_policy_definition" "require_resource_tag" {
  name                = "${var.name_prefix}-require-resource-tag"
  display_name        = "${var.display_name_prefix}: require resource tag"
  description         = "Audits or denies resources missing a required tag."
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = var.management_group_id

  metadata = jsonencode({
    category = "Tags"
    source   = "Terraform"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag name"
      }
    }
    effect = {
      type = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue = var.required_tag_effect
      metadata = {
        displayName = "Effect"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      field  = "[concat('tags[', parameters('tagName'), ']')]"
      exists = false
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_policy_definition" "require_vm_tag" {
  name                = "${var.name_prefix}-require-vm-tag"
  display_name        = "${var.display_name_prefix}: require VM tag"
  description         = "Audits or denies virtual machines missing a required VM-specific tag."
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = var.management_group_id

  metadata = jsonencode({
    category = "Tags"
    source   = "Terraform"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "VM tag name"
      }
    }
    effect = {
      type = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue = var.vm_required_tag_effect
      metadata = {
        displayName = "Effect"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field  = "[concat('tags[', parameters('tagName'), ']')]"
          exists = false
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_policy_definition" "allowed_tag_values" {
  name                = "${var.name_prefix}-allowed-tag-values"
  display_name        = "${var.display_name_prefix}: allowed tag values"
  description         = "Audits or denies resources whose tag value is outside the approved list."
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = var.management_group_id

  metadata = jsonencode({
    category = "Tags"
    source   = "Terraform"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag name"
      }
    }
    allowedValues = {
      type = "Array"
      metadata = {
        displayName = "Allowed values"
      }
    }
    effect = {
      type = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue = var.allowed_values_effect
      metadata = {
        displayName = "Effect"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "[concat('tags[', parameters('tagName'), ']')]"
          exists = true
        },
        {
          field = "[concat('tags[', parameters('tagName'), ']')]"
          notIn = "[parameters('allowedValues')]"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_policy_definition" "date_stamp_format" {
  name                = "${var.name_prefix}-date-stamp-format"
  display_name        = "${var.display_name_prefix}: date stamp format"
  description         = "Audits or denies date stamp tags that are not formatted as YYYY-MM-DD."
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = var.management_group_id

  metadata = jsonencode({
    category = "Tags"
    source   = "Terraform"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Date tag name"
      }
    }
    effect = {
      type = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue = var.date_stamp_effect
      metadata = {
        displayName = "Effect"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "[concat('tags[', parameters('tagName'), ']')]"
          exists = true
        },
        {
          field    = "[concat('tags[', parameters('tagName'), ']')]"
          notMatch = "####-##-##"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_subscription_policy_assignment" "inherit_subscription_tags" {
  for_each             = var.enable_inheritance ? local.subscription_tag_names : toset([])
  name                 = "${var.name_prefix}-inherit-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: inherit ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.inherit_subscription_tag.id
  location             = var.assignment_location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  non_compliance_message {
    content = "Resource tag '${each.key}' does not match the subscription tag value or is missing."
  }
}

resource "azurerm_role_assignment" "inherit_tag_modifier" {
  for_each             = azurerm_subscription_policy_assignment.inherit_subscription_tags
  scope                = data.azurerm_subscription.current.id
  role_definition_name = var.modify_role_definition_name
  principal_id         = each.value.identity[0].principal_id
}

resource "azurerm_subscription_policy_assignment" "required_subscription_tags" {
  for_each             = local.subscription_tag_names
  name                 = "${var.name_prefix}-required-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: required ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.require_resource_tag.id

  parameters = jsonencode({
    tagName = { value = each.key }
    effect  = { value = var.required_tag_effect }
  })

  non_compliance_message {
    content = "Required inherited subscription tag '${each.key}' is missing."
  }
}

resource "azurerm_subscription_policy_assignment" "required_vm_tags" {
  for_each             = local.vm_tag_names
  name                 = "${var.name_prefix}-vm-required-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: VM required ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.require_vm_tag.id

  parameters = jsonencode({
    tagName = { value = each.key }
    effect  = { value = var.vm_required_tag_effect }
  })

  non_compliance_message {
    content = "Required VM tag '${each.key}' is missing."
  }
}

resource "azurerm_subscription_policy_assignment" "subscription_allowed_values" {
  for_each             = local.subscription_allowed_value_tags
  name                 = "${var.name_prefix}-allowed-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: allowed values ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.allowed_tag_values.id

  parameters = jsonencode({
    tagName       = { value = each.key }
    allowedValues = { value = each.value }
    effect        = { value = var.allowed_values_effect }
  })

  non_compliance_message {
    content = "Tag '${each.key}' has a value outside the approved list: ${join(", ", each.value)}."
  }
}

resource "azurerm_subscription_policy_assignment" "vm_allowed_values" {
  for_each             = local.vm_allowed_value_tags
  name                 = "${var.name_prefix}-vm-allowed-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: VM allowed values ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.allowed_tag_values.id

  parameters = jsonencode({
    tagName       = { value = each.key }
    allowedValues = { value = each.value }
    effect        = { value = var.allowed_values_effect }
  })

  non_compliance_message {
    content = "VM tag '${each.key}' has a value outside the approved list: ${join(", ", each.value)}."
  }
}

resource "azurerm_subscription_policy_assignment" "date_stamp_format" {
  for_each             = local.subscription_date_tags
  name                 = "${var.name_prefix}-date-${lower(each.key)}"
  display_name         = "${var.display_name_prefix}: date format ${each.key}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.date_stamp_format.id

  parameters = jsonencode({
    tagName = { value = each.key }
    effect  = { value = var.date_stamp_effect }
  })

  non_compliance_message {
    content = "Date tag '${each.key}' must be formatted as YYYY-MM-DD."
  }
}
