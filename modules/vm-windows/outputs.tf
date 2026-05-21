output "operating_system" {
  value       = "windows"
  description = "客體作業系統。"
}

output "virtual_machine_ids" {
  value       = [for vm in azurerm_windows_virtual_machine.main : vm.id]
  description = "Windows VM 資源 ID 清單。"
}

output "virtual_machine_names" {
  value       = [for vm in azurerm_windows_virtual_machine.main : vm.name]
  description = "VM 名稱清單。"
}

output "network_interface_private_ips" {
  value       = [for nic in azurerm_network_interface.main : nic.private_ip_address]
  description = "各 NIC 私人 IP。"
}

output "public_ip_addresses" {
  description = "各 VM 的 Public IP（未啟用則為空清單）。"
  value       = var.public_ip_enabled ? [for pip in azurerm_public_ip.main : pip.ip_address] : []
}

output "public_ip_ids" {
  description = "各 VM 的 Public IP 資源 ID。"
  value       = var.public_ip_enabled ? [for pip in azurerm_public_ip.main : pip.id] : []
}

output "network_interface_ids" {
  value       = [for nic in azurerm_network_interface.main : nic.id]
  description = "各 NIC 資源 ID。"
}

output "system_assigned_principal_ids" {
  value = [
    for vm in azurerm_windows_virtual_machine.main :
    try(vm.identity[0].principal_id, null)
  ]
  description = "System Assigned principal_id。"
}

output "boot_diagnostics_storage_account_name" {
  value       = try(azurerm_storage_account.bootdiag[0].name, null)
  description = "開機診斷 Storage Account 名稱。"
}

output "recovery_vault_id" {
  description = "Recovery Services Vault 資源 ID（backup_enabled 且由模組建立時）。"
  value       = try(azurerm_recovery_services_vault.main[0].id, null)
}

output "recovery_vault_name" {
  description = "Recovery Services Vault 名稱。"
  value       = var.backup_enabled ? local.recovery_vault_name_for_vm : null
}

output "backup_policy_id" {
  description = "VM 備份原則資源 ID。"
  value       = var.backup_enabled ? local.effective_backup_policy_id : null
}

output "vm_admin_passwords" {
  sensitive = true
  value = {
    for i, name in local.vm_names : name => local.vm_admin_password[i]
    if local.vm_admin_password[i] != null
  }
  description = "各 VM 本機管理員密碼。"
}

output "vm_admin_usernames" {
  value = {
    for name in local.vm_names : name => var.admin_username
  }
  description = "各 VM 本機管理員帳號。"
}
