locals {
  boot_diagnostics_external_uri_trimmed   = var.boot_diagnostics_storage_uri != null ? trimspace(var.boot_diagnostics_storage_uri) : ""
  boot_diagnostics_use_external_uri       = var.boot_diagnostics_enabled && local.boot_diagnostics_external_uri_trimmed != ""
  boot_diagnostics_create_storage_account = var.boot_diagnostics_enabled && !local.boot_diagnostics_use_external_uri
  boot_diagnostics_blob_uri               = local.boot_diagnostics_use_external_uri ? local.boot_diagnostics_external_uri_trimmed : try(azurerm_storage_account.bootdiag[0].primary_blob_endpoint, null)

  enable_managed_identity = var.identity_type != null && trimspace(var.identity_type) != ""

  use_random_admin_password = var.generate_admin_password && var.admin_password == null

  vm_admin_password = {
    for i in range(var.vm_count) : i => (
      var.admin_password != null ? var.admin_password : (
        local.use_random_admin_password ? random_password.vm_admin[i].result : null
      )
    )
  }

  recovery_vault_rg = coalesce(var.recovery_vault_resource_group, var.resource_group_name)

  manage_backup_in_module = var.backup_enabled && var.backup_policy_id == null

  recovery_vault_name_effective = local.manage_backup_in_module ? (
    length(trimspace(var.recovery_vault_name)) > 0 ? trimspace(var.recovery_vault_name) : "${replace(lower(var.vm_name), "_", "-")}-rsv"
  ) : trimspace(var.recovery_vault_name)

  backup_policy_name_effective = (
    length(trimspace(var.backup_policy_name)) > 0 ? trimspace(var.backup_policy_name) : "${local.recovery_vault_name_effective}-vm-policy"
  )

  effective_backup_policy_id = local.manage_backup_in_module ? azurerm_backup_policy_vm.main[0].id : var.backup_policy_id

  recovery_vault_name_for_vm = local.manage_backup_in_module ? azurerm_recovery_services_vault.main[0].name : local.recovery_vault_name_effective

  vm_names = [
    for i in range(var.vm_count) : format("%s-%02d", var.vm_name, i + 1)
  ]

  public_ip_names = [
    for i in range(var.vm_count) : (
      length(trimspace(var.public_ip_name)) > 0 ? trimspace(var.public_ip_name) : "${local.vm_names[i]}-pip"
    )
  ]

  nic_names = [
    for i in range(var.vm_count) : (
      length(trimspace(var.nic_name)) > 0 ? trimspace(var.nic_name) : "${local.vm_names[i]}-nic"
    )
  ]

  effective_availability_zones = [
    for z in var.availability_zone : trimspace(z) if trimspace(z) != ""
  ]

  zone_for_vm = [
    for i in range(var.vm_count) : (
      var.enable_availability_set || length(local.effective_availability_zones) == 0
      ? null
      : local.effective_availability_zones[i % length(local.effective_availability_zones)]
    )
  ]

  data_disk_specs = var.data_disk_enabled ? flatten([
    for vm_index in range(var.vm_count) : [
      for disk_index in range(var.data_disk_count) : {
        key        = "${vm_index}-${disk_index}"
        vm_index   = vm_index
        disk_index = disk_index
        name       = format("%s-dd-%02d", local.vm_names[vm_index], disk_index + 1)
        lun        = disk_index
      }
    ]
  ]) : []

  role_assignment_matrix = length(var.role_assignments) > 0 && local.enable_managed_identity && strcontains(var.identity_type, "SystemAssigned") ? {
    for pair in flatten([
      for vm_idx in range(var.vm_count) : [
        for ra_idx, ra in var.role_assignments : {
          key    = "${vm_idx}-${ra_idx}"
          vm_idx = vm_idx
          scope  = ra.scope
          role   = ra.role_definition_name
        }
      ]
    ]) : pair.key => pair
  } : {}
}
