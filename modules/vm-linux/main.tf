resource "azurerm_storage_account" "bootdiag" {
  count = local.boot_diagnostics_create_storage_account ? 1 : 0

  # 語意命名 ctbc-jpe-linux-vm-sa-XX；Azure SA 僅允許小寫英數 → 移除連字號後如 ctbcjpelinuxvmsa01。
  name = substr(
    replace(lower(format("ctbc-jpe-linux-vm-sa-%02d", var.boot_diagnostics_storage_account_sequence)), "-", ""),
    0,
    24
  )

  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = var.tags
}

resource "azurerm_availability_set" "main" {
  count = var.enable_availability_set ? 1 : 0

  name                         = "${var.vm_name}-avs"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !var.enable_availability_set || length(local.effective_availability_zones) == 0
      error_message = "enable_availability_set 為 true 時，請將 availability_zone 設為 []。"
    }
  }
}

resource "azurerm_public_ip" "main" {
  count = var.public_ip_enabled ? var.vm_count : 0

  name                = local.public_ip_names[count.index]
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.public_ip_allocation_method
  sku                 = var.public_ip_sku
  zones               = local.zone_for_vm[count.index] != null ? [local.zone_for_vm[count.index]] : null

  tags = var.tags
}

resource "azurerm_network_interface" "main" {
  count = var.vm_count

  name                = local.nic_names[count.index]
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_allocation
    private_ip_address              = var.private_ip_allocation == "Static" ? var.private_ip_address : null
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.main[count.index].id : null
  }

  accelerated_networking_enabled = var.accelerated_networking

  tags = var.tags
}

resource "azurerm_managed_disk" "data" {
  for_each = { for spec in local.data_disk_specs : spec.key => spec }

  name                 = each.value.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb

  tags = var.tags
}

resource "random_password" "vm_admin" {
  count = local.use_random_admin_password ? var.vm_count : 0

  length      = 16
  special     = true
  upper       = true
  lower       = true
  numeric     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

######################################################################
# SSH public key source（對應 Portal 三種選項）                        #
######################################################################

locals {
  ssh_auth_enabled              = lower(var.authentication_type) == "ssh_key"
  ssh_generate_enabled          = local.ssh_auth_enabled && var.ssh_public_key_source == "generate"
  ssh_azure_existing_enabled    = local.ssh_auth_enabled && var.ssh_public_key_source == "azure_existing"
  ssh_public_key_inline_enabled = local.ssh_auth_enabled && var.ssh_public_key_source == "public_key"

  ssh_azure_key_rg = coalesce(var.ssh_azure_key_resource_group, var.resource_group_name)

  ssh_key_pair_name_effective = trimspace(var.ssh_key_pair_name) != "" ? var.ssh_key_pair_name : "${var.vm_name}-ssh-key"

  ssh_public_key_for_vm = local.ssh_auth_enabled ? (
    local.ssh_public_key_inline_enabled ? trimspace(var.ssh_public_key) : (
      local.ssh_azure_existing_enabled ? data.azurerm_ssh_public_key.selected[0].public_key : (
        local.ssh_generate_enabled ? tls_private_key.generated[0].public_key_openssh : ""
      )
    )
  ) : ""
}

# 選項 1：Generate new key pair
resource "tls_private_key" "generated" {
  count = local.ssh_generate_enabled ? 1 : 0

  algorithm = var.ssh_key_type == "Ed25519" ? "ED25519" : "RSA"
  rsa_bits  = var.ssh_key_type == "RSA" ? 4096 : null
}

resource "azurerm_ssh_public_key" "generated" {
  count = local.ssh_generate_enabled ? 1 : 0

  name                = local.ssh_key_pair_name_effective
  resource_group_name = var.resource_group_name
  location            = var.location
  public_key          = tls_private_key.generated[0].public_key_openssh

  tags = var.tags
}

# 選項 2：Use existing key stored in Azure
data "azurerm_ssh_public_key" "selected" {
  count = local.ssh_azure_existing_enabled ? 1 : 0

  name                = var.ssh_azure_key_name
  resource_group_name = local.ssh_azure_key_rg
}

# 選項 3：Use existing public key → var.ssh_public_key（見 local.ssh_public_key_for_vm）

resource "azurerm_linux_virtual_machine" "main" {
  count = var.vm_count

  name                  = local.vm_names[count.index]
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.main[count.index].id]

  availability_set_id = var.enable_availability_set ? azurerm_availability_set.main[0].id : null
  zone                = local.zone_for_vm[count.index]

  disable_password_authentication = lower(var.authentication_type) == "ssh_key"

  dynamic "admin_ssh_key" {
    for_each = local.ssh_auth_enabled ? [1] : []
    content {
      username   = var.admin_username
      public_key = local.ssh_public_key_for_vm
    }
  }

  admin_password = lower(var.authentication_type) == "password" ? local.vm_admin_password[count.index] : null

  source_image_reference {
    publisher = var.source_image_publisher
    offer     = var.source_image_offer
    sku       = var.source_image_sku
    version   = var.source_image_version
  }

  os_disk {
    name                 = "${local.vm_names[count.index]}-os"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  dynamic "identity" {
    for_each = local.enable_managed_identity ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  dynamic "boot_diagnostics" {
    for_each = var.boot_diagnostics_enabled && local.boot_diagnostics_blob_uri != null ? [1] : []
    content {
      storage_account_uri = local.boot_diagnostics_blob_uri
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !local.enable_managed_identity || !strcontains(var.identity_type, "UserAssigned") || length(var.user_assigned_identity_ids) > 0
      error_message = "identity_type 含 UserAssigned 時，必須提供 user_assigned_identity_ids。"
    }

    precondition {
      condition = (
        !var.backup_enabled ||
        local.manage_backup_in_module ||
        (length(trimspace(var.recovery_vault_name)) > 0 && var.backup_policy_id != null)
      )
      error_message = "backup_enabled 且使用既有 Vault/原則時，必須設定 recovery_vault_name 與 backup_policy_id。"
    }

    precondition {
      condition     = lower(var.authentication_type) != "password" || local.vm_admin_password[count.index] != null
      error_message = "authentication_type=password 時須提供 admin_password 或啟用 generate_admin_password。"
    }

    precondition {
      condition     = !var.boot_diagnostics_enabled || local.boot_diagnostics_blob_uri != null
      error_message = "boot_diagnostics_enabled 為 true 時，須由根模組傳入 boot_diagnostics_storage_uri（共用模式），或由模組建立專用 Storage Account（勿同時留空）。"
    }

    precondition {
      condition = (
        !local.ssh_auth_enabled ||
        (
          local.ssh_public_key_inline_enabled && length(local.ssh_public_key_for_vm) > 0 &&
          (startswith(local.ssh_public_key_for_vm, "ssh-rsa") || startswith(local.ssh_public_key_for_vm, "ssh-ed25519"))
        ) ||
        (local.ssh_generate_enabled && length(local.ssh_public_key_for_vm) > 0) ||
        (local.ssh_azure_existing_enabled && length(local.ssh_public_key_for_vm) > 0)
      )
      error_message = "authentication_type=ssh_key 時請依 ssh_public_key_source 提供有效 SSH 設定（public_key 須為 ssh-rsa 或 ssh-ed25519）。"
    }

    precondition {
      condition     = !local.ssh_azure_existing_enabled || length(trimspace(var.ssh_azure_key_name)) > 0
      error_message = "ssh_public_key_source=azure_existing 時必須設定 ssh_azure_key_name。"
    }
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  for_each = { for spec in local.data_disk_specs : spec.key => spec }

  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.main[each.value.vm_index].id
  lun                = each.value.lun
  caching            = "ReadWrite"

  depends_on = [azurerm_linux_virtual_machine.main]
}

resource "azurerm_virtual_machine_extension" "aad_ssh" {
  count = var.enable_aad_login ? var.vm_count : 0

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.main[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_linux_virtual_machine.main]
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "shutdown" {
  count = var.auto_shutdown_enabled ? var.vm_count : 0

  virtual_machine_id    = azurerm_linux_virtual_machine.main[count.index].id
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled         = false
    time_in_minutes = "30"
    email           = ""
    webhook_url     = ""
  }

  depends_on = [
    azurerm_linux_virtual_machine.main,
    azurerm_virtual_machine_data_disk_attachment.data,
  ]
}

resource "azurerm_role_assignment" "vm" {
  for_each = local.role_assignment_matrix

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_linux_virtual_machine.main[each.value.vm_idx].identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.main]
}

resource "azurerm_recovery_services_vault" "main" {
  count = local.manage_backup_in_module ? 1 : 0

  name                = local.recovery_vault_name_effective
  location            = var.location
  resource_group_name = local.recovery_vault_rg
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_backup_policy_vm" "main" {
  count = local.manage_backup_in_module ? 1 : 0

  name                = local.backup_policy_name_effective
  resource_group_name = local.recovery_vault_rg
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  backup {
    frequency = var.backup_policy_frequency
    time      = var.backup_policy_time
    weekdays  = var.backup_policy_frequency == "Weekly" ? var.backup_policy_weekdays : null
  }

  retention_daily {
    count = var.backup_policy_retention_daily_count
  }

  depends_on = [azurerm_recovery_services_vault.main]
}

resource "azurerm_backup_protected_vm" "vm" {
  count = var.backup_enabled ? var.vm_count : 0

  resource_group_name = local.recovery_vault_rg
  recovery_vault_name = local.recovery_vault_name_for_vm
  source_vm_id        = azurerm_linux_virtual_machine.main[count.index].id
  backup_policy_id    = local.effective_backup_policy_id

  depends_on = [
    azurerm_linux_virtual_machine.main,
    azurerm_virtual_machine_data_disk_attachment.data,
    azurerm_recovery_services_vault.main,
    azurerm_backup_policy_vm.main,
  ]
}
