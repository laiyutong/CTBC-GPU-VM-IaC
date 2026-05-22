# 當 boot_diagnostics_storage_mode = shared 且至少一組 VM 啟用開機診斷時，建立單一共用 Storage Account。
resource "azurerm_storage_account" "shared_bootdiag" {
  count = var.boot_diagnostics_storage_mode == "shared" && local.any_boot_diagnostics_enabled ? 1 : 0

  # 語意 ctbc-jpe-shared-vm-sa-XX（Linux／Windows 共用）；Azure 名稱為移除連字號後小寫。
  name = substr(
    replace(lower(format("ctbc-jpe-shared-vm-sa-%02d", var.shared_boot_diagnostics_storage_account_sequence)), "-", ""),
    0,
    24
  )

  resource_group_name      = data.azurerm_resource_group.vm.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = var.default_tags
}

# 當 backup_recovery_vault_mode = shared 且至少一組 VM 啟用備份、且未指定既有 backup_policy_id 時，建立單一共用 RSV 與預設 VM 備份原則。
resource "azurerm_recovery_services_vault" "shared_backup" {
  count = var.backup_recovery_vault_mode == "shared" && local.any_shared_backup_enabled ? 1 : 0

  name                = local.shared_recovery_vault_name_effective
  location            = var.location
  resource_group_name = local.shared_recovery_vault_rg_effective
  sku                 = "Standard"

  tags = var.default_tags
}

resource "azurerm_backup_policy_vm" "shared_backup" {
  count = var.backup_recovery_vault_mode == "shared" && local.any_shared_backup_enabled ? 1 : 0

  name                = local.shared_backup_policy_name_effective
  resource_group_name = local.shared_recovery_vault_rg_effective
  recovery_vault_name = azurerm_recovery_services_vault.shared_backup[0].name

  backup {
    frequency = var.shared_backup_policy_frequency
    time      = var.shared_backup_policy_time
    weekdays  = var.shared_backup_policy_frequency == "Weekly" ? var.shared_backup_policy_weekdays : null
  }

  retention_daily {
    count = var.shared_backup_policy_retention_daily_count
  }

  depends_on = [azurerm_recovery_services_vault.shared_backup]
}

module "linux" {
  source   = "../../modules/vm-linux"
  for_each = var.linux_vms

  resource_group_name = data.azurerm_resource_group.vm.name
  location            = var.location
  subnet_id           = data.azurerm_subnet.main.id

  vm_name                      = each.value.vm_name
  vm_count                     = each.value.vm_count
  vm_size                      = each.value.vm_size
  os_disk_type                 = each.value.os_disk_type
  os_disk_size_gb              = each.value.os_disk_size_gb
  source_image_publisher       = each.value.source_image_publisher
  source_image_offer           = each.value.source_image_offer
  source_image_sku             = each.value.source_image_sku
  source_image_version         = each.value.source_image_version
  accelerated_networking       = each.value.accelerated_networking
  public_ip_enabled            = each.value.public_ip_enabled
  public_ip_name               = each.value.public_ip_name
  nic_name                     = each.value.nic_name
  public_ip_sku                = each.value.public_ip_sku
  public_ip_allocation_method  = each.value.public_ip_allocation_method
  private_ip_allocation        = each.value.private_ip_allocation
  private_ip_address           = try(each.value.private_ip_address, null)
  data_disk_enabled            = each.value.data_disk_enabled
  data_disk_count              = each.value.data_disk_count
  data_disk_size_gb            = each.value.data_disk_size_gb
  data_disk_type               = each.value.data_disk_type
  authentication_type          = each.value.authentication_type
  admin_username               = each.value.admin_username
  generate_admin_password      = each.value.generate_admin_password
  admin_password               = try(each.value.admin_password, null)
  ssh_public_key_source        = each.value.ssh_public_key_source
  ssh_key_type                 = each.value.ssh_key_type
  ssh_key_pair_name            = each.value.ssh_key_pair_name
  ssh_azure_key_name           = each.value.ssh_azure_key_name
  ssh_azure_key_resource_group = try(each.value.ssh_azure_key_resource_group, null)
  ssh_public_key               = each.value.ssh_public_key
  enable_aad_login             = each.value.enable_aad_login
  identity_type                = try(each.value.identity_type, null)
  user_assigned_identity_ids   = each.value.user_assigned_identity_ids
  role_assignments             = each.value.role_assignments
  availability_zone            = each.value.availability_zone
  enable_availability_set      = each.value.enable_availability_set
  boot_diagnostics_enabled     = each.value.boot_diagnostics_enabled
  boot_diagnostics_storage_uri = (
    var.boot_diagnostics_storage_mode == "shared" && each.value.boot_diagnostics_enabled
  ) ? local.shared_boot_diagnostics_blob_endpoint : null
  boot_diagnostics_storage_account_sequence = coalesce(
    each.value.boot_diagnostics_storage_account_sequence,
    local.linux_boot_diag_seq_default[each.key]
  )
  auto_shutdown_enabled         = each.value.auto_shutdown_enabled
  auto_shutdown_time            = each.value.auto_shutdown_time
  auto_shutdown_timezone        = each.value.auto_shutdown_timezone
  backup_enabled                = each.value.backup_enabled
  recovery_vault_name           = local.linux_uses_shared_backup_rsv[each.key] ? local.shared_recovery_vault_name_effective : each.value.recovery_vault_name
  recovery_vault_resource_group = local.linux_uses_shared_backup_rsv[each.key] ? local.shared_recovery_vault_rg_effective : try(each.value.recovery_vault_resource_group, null)
  backup_policy_id                    = local.linux_backup_policy_id_for_module[each.key]
  backup_policy_name                  = each.value.backup_policy_name
  backup_policy_frequency             = each.value.backup_policy_frequency
  backup_policy_time                  = each.value.backup_policy_time
  backup_policy_weekdays              = each.value.backup_policy_weekdays
  backup_policy_retention_daily_count = each.value.backup_policy_retention_daily_count
  tags                                = local.linux_vm_tags[each.key]
}

module "windows" {
  source   = "../../modules/vm-windows"
  for_each = var.windows_vms

  resource_group_name = data.azurerm_resource_group.vm.name
  location            = var.location
  subnet_id           = data.azurerm_subnet.main.id

  vm_name                     = each.value.vm_name
  vm_count                    = each.value.vm_count
  vm_size                     = each.value.vm_size
  os_disk_type                = each.value.os_disk_type
  os_disk_size_gb             = each.value.os_disk_size_gb
  source_image_publisher      = each.value.source_image_publisher
  source_image_offer          = each.value.source_image_offer
  source_image_sku            = each.value.source_image_sku
  source_image_version        = each.value.source_image_version
  accelerated_networking      = each.value.accelerated_networking
  public_ip_enabled           = each.value.public_ip_enabled
  public_ip_name              = each.value.public_ip_name
  nic_name                    = each.value.nic_name
  public_ip_sku               = each.value.public_ip_sku
  public_ip_allocation_method = each.value.public_ip_allocation_method
  private_ip_allocation       = each.value.private_ip_allocation
  private_ip_address          = try(each.value.private_ip_address, null)
  data_disk_enabled           = each.value.data_disk_enabled
  data_disk_count             = each.value.data_disk_count
  data_disk_size_gb           = each.value.data_disk_size_gb
  data_disk_type              = each.value.data_disk_type
  admin_username              = each.value.admin_username
  generate_admin_password     = each.value.generate_admin_password
  admin_password              = try(each.value.admin_password, null)
  enable_aad_login            = each.value.enable_aad_login
  identity_type               = try(each.value.identity_type, null)
  user_assigned_identity_ids  = each.value.user_assigned_identity_ids
  role_assignments            = each.value.role_assignments
  availability_zone           = each.value.availability_zone
  enable_availability_set     = each.value.enable_availability_set
  boot_diagnostics_enabled    = each.value.boot_diagnostics_enabled
  boot_diagnostics_storage_uri = (
    var.boot_diagnostics_storage_mode == "shared" && each.value.boot_diagnostics_enabled
  ) ? local.shared_boot_diagnostics_blob_endpoint : null
  boot_diagnostics_storage_account_sequence = coalesce(
    each.value.boot_diagnostics_storage_account_sequence,
    local.windows_boot_diag_seq_default[each.key]
  )
  auto_shutdown_enabled         = each.value.auto_shutdown_enabled
  auto_shutdown_time            = each.value.auto_shutdown_time
  auto_shutdown_timezone        = each.value.auto_shutdown_timezone
  backup_enabled                = each.value.backup_enabled
  recovery_vault_name           = local.windows_uses_shared_backup_rsv[each.key] ? local.shared_recovery_vault_name_effective : each.value.recovery_vault_name
  recovery_vault_resource_group = local.windows_uses_shared_backup_rsv[each.key] ? local.shared_recovery_vault_rg_effective : try(each.value.recovery_vault_resource_group, null)
  backup_policy_id                    = local.windows_backup_policy_id_for_module[each.key]
  backup_policy_name                  = each.value.backup_policy_name
  backup_policy_frequency             = each.value.backup_policy_frequency
  backup_policy_time                  = each.value.backup_policy_time
  backup_policy_weekdays              = each.value.backup_policy_weekdays
  backup_policy_retention_daily_count = each.value.backup_policy_retention_daily_count
  tags                                = local.windows_vm_tags[each.key]
}

module "linux_gpu_extension" {
  source   = "../../modules/gpu-extension"
  for_each = { for key, cfg in var.linux_vms : key => cfg if cfg.enable_gpu_driver_extension }

  virtual_machine_ids = module.linux[each.key].virtual_machine_ids
  operating_system    = "linux"
  enabled             = true

  depends_on = [module.linux]
}

module "windows_gpu_extension" {
  source   = "../../modules/gpu-extension"
  for_each = { for key, cfg in var.windows_vms : key => cfg if cfg.enable_gpu_driver_extension }

  virtual_machine_ids = module.windows[each.key].virtual_machine_ids
  operating_system    = "windows"
  enabled             = true

  depends_on = [module.windows]
}
