output "operating_system" {
  description = "客體作業系統。"
  value       = "linux"
}

output "virtual_machine_ids" {
  description = "已建立之 Linux VM 資源 ID 清單。"
  value       = [for vm in azurerm_linux_virtual_machine.main : vm.id]
}

output "virtual_machine_names" {
  description = "已建立之 VM 名稱清單。"
  value       = [for vm in azurerm_linux_virtual_machine.main : vm.name]
}

output "network_interface_private_ips" {
  description = "各 NIC 的私人 IP。"
  value       = [for nic in azurerm_network_interface.main : nic.private_ip_address]
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
  description = "各 NIC 資源 ID。"
  value       = [for nic in azurerm_network_interface.main : nic.id]
}

output "system_assigned_principal_ids" {
  description = "各 VM 的 System Assigned principal_id。"
  value = [
    for vm in azurerm_linux_virtual_machine.main :
    try(vm.identity[0].principal_id, null)
  ]
}

output "boot_diagnostics_storage_account_name" {
  description = "開機診斷 Storage Account 名稱。"
  value       = try(azurerm_storage_account.bootdiag[0].name, null)
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
  description = "各 VM 本機密碼（key 為 VM 名稱）。"
  sensitive   = true
  value = {
    for i, name in local.vm_names : name => local.vm_admin_password[i]
    if local.vm_admin_password[i] != null
  }
}

output "vm_admin_usernames" {
  description = "各 VM 本機帳號。"
  value = {
    for name in local.vm_names : name => var.admin_username
  }
}

output "ssh_public_key_source" {
  description = "SSH 公鑰來源模式（generate / azure_existing / public_key）。"
  value       = local.ssh_auth_enabled ? var.ssh_public_key_source : null
}

output "ssh_key_type" {
  description = "產生金鑰時使用的演算法（RSA / Ed25519）。"
  value       = local.ssh_generate_enabled ? var.ssh_key_type : null
}

output "ssh_key_pair_name" {
  description = "Azure 上的 SSH 公鑰資源名稱（generate 或 azure_existing）。"
  value = local.ssh_auth_enabled ? (
    local.ssh_generate_enabled ? azurerm_ssh_public_key.generated[0].name : (
      local.ssh_azure_existing_enabled ? data.azurerm_ssh_public_key.selected[0].name : null
    )
  ) : null
}

output "ssh_public_key_id" {
  description = "Azure SSH 公鑰資源 ID（generate 或 azure_existing）。"
  value = local.ssh_auth_enabled ? (
    local.ssh_generate_enabled ? azurerm_ssh_public_key.generated[0].id : (
      local.ssh_azure_existing_enabled ? data.azurerm_ssh_public_key.selected[0].id : null
    )
  ) : null
}

output "ssh_public_key_openssh" {
  description = "寫入 VM 的 OpenSSH 公鑰字串。"
  value       = local.ssh_auth_enabled ? local.ssh_public_key_for_vm : null
  sensitive   = true
}

output "ssh_private_key_pem" {
  description = "generate 模式產生的私鑰（PEM）。apply 後請 terraform output -raw ssh_private_key_pem 下載保存。"
  value       = local.ssh_generate_enabled ? tls_private_key.generated[0].private_key_pem : null
  sensitive   = true
}
