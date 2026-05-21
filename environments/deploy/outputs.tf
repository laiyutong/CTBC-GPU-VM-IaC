output "resource_group_name" {
  description = "VM 部署目標 Resource Group。"
  value       = data.azurerm_resource_group.vm.name
}

output "deployment_location" {
  description = "本 stack 指定之 Azure Region（tfvars 變數 location）。"
  value       = var.location
}

output "resource_group_metadata_location" {
  description = "既有 VM Resource Group 在 Azure 上的 metadata location（僅供對照；資源實際 region 以 deployment_location 為準）。"
  value       = data.azurerm_resource_group.vm.location
}

output "subnet_id" {
  description = "使用的 Subnet 資源 ID。"
  value       = data.azurerm_subnet.main.id
}

output "shared_boot_diagnostics_storage_account_name" {
  description = "共用開機診斷 Storage Account 名稱（boot_diagnostics_storage_mode = shared 且至少一組 VM 啟用開機診斷時）。"
  value       = length(azurerm_storage_account.shared_bootdiag) > 0 ? azurerm_storage_account.shared_bootdiag[0].name : null
}

output "shared_boot_diagnostics_blob_endpoint" {
  description = "共用開機診斷 Blob 端點（同上條件）。"
  value       = local.shared_boot_diagnostics_blob_endpoint
}

output "shared_recovery_vault_name" {
  description = "共用備份 RSV 名稱（backup_recovery_vault_mode = shared 且至少一組 VM 使用共用備份時）。"
  value       = length(azurerm_recovery_services_vault.shared_backup) > 0 ? azurerm_recovery_services_vault.shared_backup[0].name : null
}

output "shared_backup_policy_vm_id" {
  description = "共用 RSV 內預設 VM 備份原則資源 ID（同上條件）。"
  value       = local.shared_backup_policy_id
}

output "linux_virtual_machine_ids" {
  description = "Linux VM 資源 ID（依部署 key 分組）。"
  value       = { for key, mod in module.linux : key => mod.virtual_machine_ids }
}

output "windows_virtual_machine_ids" {
  description = "Windows VM 資源 ID（依部署 key 分組）。"
  value       = { for key, mod in module.windows : key => mod.virtual_machine_ids }
}

output "linux_virtual_machine_names" {
  description = "Linux VM 名稱（依部署 key 分組）。"
  value       = { for key, mod in module.linux : key => mod.virtual_machine_names }
}

output "windows_virtual_machine_names" {
  description = "Windows VM 名稱（依部署 key 分組）。"
  value       = { for key, mod in module.windows : key => mod.virtual_machine_names }
}

output "linux_network_interface_private_ips" {
  description = "Linux NIC 私人 IP。"
  value       = { for key, mod in module.linux : key => mod.network_interface_private_ips }
}

output "windows_network_interface_private_ips" {
  description = "Windows NIC 私人 IP。"
  value       = { for key, mod in module.windows : key => mod.network_interface_private_ips }
}

output "linux_public_ip_addresses" {
  description = "Linux Public IP 位址。"
  value       = { for key, mod in module.linux : key => mod.public_ip_addresses }
}

output "windows_public_ip_addresses" {
  description = "Windows Public IP 位址。"
  value       = { for key, mod in module.windows : key => mod.public_ip_addresses }
}

output "linux_vm_admin_passwords" {
  description = "Linux VM 本機密碼。"
  sensitive   = true
  value       = { for key, mod in module.linux : key => mod.vm_admin_passwords }
}

output "windows_vm_admin_passwords" {
  description = "Windows VM 本機密碼。"
  sensitive   = true
  value       = { for key, mod in module.windows : key => mod.vm_admin_passwords }
}

output "linux_ssh_private_key_pem" {
  description = "generate 模式 SSH 私鑰；terraform output -json linux_ssh_private_key_pem"
  sensitive   = true
  value       = { for key, mod in module.linux : key => mod.ssh_private_key_pem }
}

output "linux_ssh_public_key_id" {
  description = "Azure SSH 公鑰資源 ID。"
  value       = { for key, mod in module.linux : key => mod.ssh_public_key_id }
}

output "linux_ssh_key_pair_name" {
  description = "SSH Key pair 名稱。"
  value       = { for key, mod in module.linux : key => mod.ssh_key_pair_name }
}

output "linux_recovery_vault_names" {
  description = "Linux 備份 Recovery Services Vault 名稱（依部署 key）。"
  value       = { for key, mod in module.linux : key => mod.recovery_vault_name }
}

output "linux_backup_policy_ids" {
  description = "Linux VM 備份原則資源 ID（依部署 key）。"
  value       = { for key, mod in module.linux : key => mod.backup_policy_id }
}

output "windows_recovery_vault_names" {
  description = "Windows 備份 Recovery Services Vault 名稱（依部署 key）。"
  value       = { for key, mod in module.windows : key => mod.recovery_vault_name }
}

output "windows_backup_policy_ids" {
  description = "Windows VM 備份原則資源 ID（依部署 key）。"
  value       = { for key, mod in module.windows : key => mod.backup_policy_id }
}
