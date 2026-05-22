variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID（GUID）。"
  nullable    = false
}

variable "existing_resource_group_name" {
  type        = string
  description = "VM 等資源所在的 Resource Group 名稱（須已存在）。RG 本身在 Azure 有 metadata location，與資源實際部署 region 無強制相同；本模組資源 region 由變數 location 指定。"
  nullable    = false
}

variable "existing_vnet_name" {
  type        = string
  description = "既有 Virtual Network 名稱。"
  nullable    = false
}

variable "existing_vnet_resource_group" {
  type        = string
  description = "VNet 所在 Resource Group。"
  nullable    = false
}

variable "existing_subnet_name" {
  type        = string
  description = "NIC 連接的 Subnet 名稱。"
  nullable    = false
}

variable "location" {
  type        = string
  description = "本 stack 建立之 VM、Storage、RSV 等資源使用的 Azure Region（例如 japaneast）。須與 Subnet／VNet 所在 region 一致，否則 VM NIC 無法連線。"
  nullable    = false
}

variable "backup_policy_id" {
  type        = string
  description = "選用：既有 VM 備份原則完整資源 ID。若設定，所有未單獨指定 backup_policy_id 的 VM 組別會使用此原則且不適用 backup_recovery_vault_mode = shared 的共用自建 RSV。"
  default     = null
  nullable    = true
}

variable "default_tags" {
  type        = map(string)
  description = "套用到所有 VM 與共用開機診斷 SA 的預設標籤；預設為空（不套用任何 tag）。需要時於 tfvars 填入鍵值。"
  default     = {}
}

variable "boot_diagnostics_storage_mode" {
  type        = string
  description = "開機診斷 Storage：per_vm_stack 為每個 linux_vms／windows_vms 各建一個 SA；shared 為全環境單一共用 SA（Linux 與 Windows 同一個）。"
  default     = "per_vm_stack"
  nullable    = false

  validation {
    condition     = contains(["per_vm_stack", "shared"], var.boot_diagnostics_storage_mode)
    error_message = "boot_diagnostics_storage_mode 必須為 per_vm_stack 或 shared。"
  }
}

variable "shared_boot_diagnostics_storage_account_sequence" {
  type        = number
  description = "boot_diagnostics_storage_mode = shared 時，共用 SA 語意名稱 ctbc-jpe-shared-vm-sa-XX 的序號（1–99）。"
  default     = 1
  nullable    = false

  validation {
    condition     = var.shared_boot_diagnostics_storage_account_sequence >= 1 && var.shared_boot_diagnostics_storage_account_sequence <= 99
    error_message = "shared_boot_diagnostics_storage_account_sequence 必須介於 1 與 99。"
  }
}

variable "backup_recovery_vault_mode" {
  type        = string
  description = "備份 RSV：per_vm_stack 為每個 linux_vms／windows_vms 模組各自建立 RSV（預設）；shared 為全環境單一共用 RSV＋預設 VM 備份原則（未指定根或各組 backup_policy_id 時）。"
  default     = "per_vm_stack"
  nullable    = false

  validation {
    condition     = contains(["per_vm_stack", "shared"], var.backup_recovery_vault_mode)
    error_message = "backup_recovery_vault_mode 必須為 per_vm_stack 或 shared。"
  }
}

variable "shared_recovery_vault_name" {
  type        = string
  description = "backup_recovery_vault_mode = shared 時的 RSV 名稱；留空則使用 ctbc-jpe-shared-vm-rsv-XX（XX 見 shared_recovery_vault_sequence）。"
  default     = ""
  nullable    = false
}

variable "shared_recovery_vault_sequence" {
  type        = number
  description = "共用 RSV 預設命名 ctbc-jpe-shared-vm-rsv-XX 的序號（1–99）；僅在 shared_recovery_vault_name 留空時生效。"
  default     = 1
  nullable    = false

  validation {
    condition     = var.shared_recovery_vault_sequence >= 1 && var.shared_recovery_vault_sequence <= 99
    error_message = "shared_recovery_vault_sequence 必須介於 1 與 99。"
  }
}

variable "shared_recovery_vault_resource_group" {
  type        = string
  description = "共用 RSV 所在 RG；留空則使用 existing_resource_group_name（與 VM 相同 RG）。"
  default     = null
  nullable    = true
}

variable "shared_backup_policy_name" {
  type        = string
  description = "backup_recovery_vault_mode = shared 時自建共用 VM 備份原則名稱；留空則為 {共用 RSV 名稱}-vm-policy。"
  default     = ""
  nullable    = false
}

variable "shared_backup_policy_frequency" {
  type        = string
  description = "backup_recovery_vault_mode = shared 且由 deploy 自建共用備份原則時之排程頻率：Daily 或 Weekly。"
  default     = "Daily"
  nullable    = false

  validation {
    condition     = contains(["Daily", "Weekly"], var.shared_backup_policy_frequency)
    error_message = "shared_backup_policy_frequency 必須為 Daily 或 Weekly。"
  }
}

variable "shared_backup_policy_time" {
  type        = string
  description = "共用備份原則執行時間（HH:mm）。"
  default     = "23:00"
  nullable    = false

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.shared_backup_policy_time))
    error_message = "shared_backup_policy_time 須為 HH:mm 格式（00:00～23:59）。"
  }
}

variable "shared_backup_policy_weekdays" {
  type        = list(string)
  description = "shared_backup_policy_frequency = Weekly 時的備份星期。"
  default     = ["Sunday"]
  nullable    = false

  validation {
    condition = alltrue([
      for d in var.shared_backup_policy_weekdays : contains(
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        d
      )
    ])
    error_message = "shared_backup_policy_weekdays 須為 Sunday～Saturday 其中之一或多個。"
  }
}

variable "shared_backup_policy_retention_daily_count" {
  type        = number
  description = "共用備份原則之每日還原點保留天數。"
  default     = 30
  nullable    = false

  validation {
    condition     = var.shared_backup_policy_retention_daily_count >= 1 && var.shared_backup_policy_retention_daily_count <= 9999
    error_message = "shared_backup_policy_retention_daily_count 必須介於 1 與 9999。"
  }
}

variable "linux_vms" {
  type = map(object({
    vm_name                      = string
    vm_count                     = optional(number, 1)
    vm_size                      = optional(string, "NV6ads_A10_v5")
    os_disk_type                 = optional(string, "StandardSSD_LRS")
    os_disk_size_gb              = optional(number, 128)
    source_image_publisher       = optional(string, "Canonical")
    source_image_offer           = optional(string, "0001-com-ubuntu-server-jammy")
    source_image_sku             = optional(string, "22_04-lts-gen2")
    source_image_version         = optional(string, "latest")
    enable_gpu_driver_extension  = optional(bool, true)
    accelerated_networking       = optional(bool, true)
    public_ip_enabled            = optional(bool, false)
    public_ip_name               = optional(string, "")
    nic_name                     = optional(string, "")
    public_ip_sku                = optional(string, "Standard")
    public_ip_allocation_method  = optional(string, "Static")
    private_ip_allocation        = optional(string, "Dynamic")
    private_ip_address           = optional(string)
    data_disk_enabled            = optional(bool, false)
    data_disk_count              = optional(number, 1)
    data_disk_size_gb            = optional(number, 128)
    data_disk_type               = optional(string, "Standard_LRS")
    authentication_type          = optional(string, "password")
    admin_username               = optional(string, "azureadmin")
    generate_admin_password      = optional(bool, true)
    admin_password               = optional(string)
    ssh_public_key_source        = optional(string, "public_key")
    ssh_key_type                 = optional(string, "RSA")
    ssh_key_pair_name            = optional(string, "")
    ssh_azure_key_name           = optional(string, "")
    ssh_azure_key_resource_group = optional(string)
    ssh_public_key               = optional(string, "")
    enable_aad_login             = optional(bool, false)
    identity_type                = optional(string)
    user_assigned_identity_ids   = optional(list(string), [])
    role_assignments = optional(list(object({
      scope                = string
      role_definition_name = string
    })), [])
    availability_zone                         = optional(list(string), ["1"])
    enable_availability_set                   = optional(bool, false)
    boot_diagnostics_enabled                  = optional(bool, true)
    boot_diagnostics_storage_account_sequence = optional(number, null)
    auto_shutdown_enabled                     = optional(bool, false)
    auto_shutdown_time                        = optional(string, "2000")
    auto_shutdown_timezone                    = optional(string, "UTC")
    backup_enabled                            = optional(bool, false)
    recovery_vault_name                       = optional(string, "")
    recovery_vault_resource_group             = optional(string)
    backup_policy_id                          = optional(string)
    backup_policy_name                        = optional(string, "")
    backup_policy_frequency                   = optional(string, "Daily")
    backup_policy_time                        = optional(string, "23:00")
    backup_policy_weekdays                    = optional(list(string), ["Sunday"])
    backup_policy_retention_daily_count       = optional(number, 30)
    tags                                      = optional(map(string), {})
  }))
  description = "Linux GPU VM 部署清單（key 為邏輯名稱）。"
  default     = {}
}

variable "windows_vms" {
  type = map(object({
    vm_name                     = string
    vm_count                    = optional(number, 1)
    vm_size                     = optional(string, "NV6ads_A10_v5")
    os_disk_type                = optional(string, "StandardSSD_LRS")
    os_disk_size_gb             = optional(number, 128)
    source_image_publisher      = optional(string, "MicrosoftWindowsDesktop")
    source_image_offer          = optional(string, "windows-11")
    source_image_sku            = optional(string, "win11-25h2-pro")
    source_image_version        = optional(string, "latest")
    enable_gpu_driver_extension = optional(bool, true)
    accelerated_networking      = optional(bool, true)
    public_ip_enabled           = optional(bool, false)
    public_ip_name              = optional(string, "")
    nic_name                    = optional(string, "")
    public_ip_sku               = optional(string, "Standard")
    public_ip_allocation_method = optional(string, "Static")
    private_ip_allocation       = optional(string, "Dynamic")
    private_ip_address          = optional(string)
    data_disk_enabled           = optional(bool, false)
    data_disk_count             = optional(number, 1)
    data_disk_size_gb           = optional(number, 128)
    data_disk_type              = optional(string, "Standard_LRS")
    admin_username              = optional(string, "azureadmin")
    generate_admin_password     = optional(bool, true)
    admin_password              = optional(string)
    enable_aad_login            = optional(bool, false)
    identity_type               = optional(string)
    user_assigned_identity_ids  = optional(list(string), [])
    role_assignments = optional(list(object({
      scope                = string
      role_definition_name = string
    })), [])
    availability_zone                         = optional(list(string), ["1"])
    enable_availability_set                   = optional(bool, false)
    boot_diagnostics_enabled                  = optional(bool, true)
    boot_diagnostics_storage_account_sequence = optional(number, null)
    auto_shutdown_enabled                     = optional(bool, false)
    auto_shutdown_time                        = optional(string, "2000")
    auto_shutdown_timezone                    = optional(string, "UTC")
    backup_enabled                            = optional(bool, false)
    recovery_vault_name                       = optional(string, "")
    recovery_vault_resource_group             = optional(string)
    backup_policy_id                          = optional(string)
    backup_policy_name                        = optional(string, "")
    backup_policy_frequency                   = optional(string, "Daily")
    backup_policy_time                        = optional(string, "23:00")
    backup_policy_weekdays                    = optional(list(string), ["Sunday"])
    backup_policy_retention_daily_count       = optional(number, 30)
    tags                                      = optional(map(string), {})
  }))
  description = "Windows GPU VM 部署清單（key 為邏輯名稱）。"
  default     = {}
}
