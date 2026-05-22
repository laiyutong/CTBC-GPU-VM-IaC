variable "resource_group_name" {
  type        = string
  description = "VM／NIC／Disk 等資源所在的 Resource Group 名稱。"
  nullable    = false
}

variable "location" {
  type        = string
  description = "部署區域。"
  nullable    = false
}

variable "subnet_id" {
  type        = string
  description = "NIC 所連接的 Subnet 資源 ID。"
  nullable    = false
}

variable "vm_name" {
  type        = string
  description = "VM 名稱基底。"
  default     = "vm-gpu-win"
}

variable "vm_count" {
  type        = number
  description = "建立的 VM 數量。"
  default     = 1

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10
    error_message = "vm_count 必須介於 1 與 10 之間。"
  }
}

variable "vm_size" {
  type        = string
  description = "VM SKU。"
  default     = "NV6ads_A10_v5"
}

variable "os_disk_type" {
  type    = string
  default = "StandardSSD_LRS"
}

variable "os_disk_size_gb" {
  type    = number
  default = 128
}

variable "source_image_publisher" {
  type    = string
  default = "MicrosoftWindowsDesktop"
}

variable "source_image_offer" {
  type    = string
  default = "windows-11"
}

variable "source_image_sku" {
  type    = string
  default = "win11-25h2-pro"
}

variable "source_image_version" {
  type    = string
  default = "latest"
}

variable "accelerated_networking" {
  type    = bool
  default = true
}

variable "public_ip_enabled" {
  type        = bool
  description = "是否為每部 VM 建立 Public IP 並關聯至 NIC。"
  default     = false
}

variable "public_ip_sku" {
  type        = string
  description = "Public IP SKU：Standard 或 Basic。"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Basic"], var.public_ip_sku)
    error_message = "public_ip_sku 必須為 Standard 或 Basic。"
  }
}

variable "public_ip_allocation_method" {
  type        = string
  description = "Public IP 配置方式：Static 或 Dynamic。"
  default     = "Static"

  validation {
    condition     = contains(["Static", "Dynamic"], var.public_ip_allocation_method)
    error_message = "public_ip_allocation_method 必須為 Static 或 Dynamic。"
  }
}

variable "public_ip_name" {
  type        = string
  description = "Public IP 資源名稱；留空則每部 VM 為 {vm_name}-01-pip、{vm_name}-02-pip…（與 VM 序號一致）。自訂名稱僅支援 vm_count = 1。"
  default     = ""

  validation {
    condition     = trimspace(var.public_ip_name) == "" || var.vm_count == 1
    error_message = "public_ip_name 自訂名稱僅支援 vm_count = 1；多部 VM 請留空以使用 {vm_name}-01-pip 格式。"
  }
}

variable "nic_name" {
  type        = string
  description = "NIC 資源名稱；留空則每部 VM 為 {vm_name}-01-nic、{vm_name}-02-nic…（與 VM 序號一致）。自訂名稱僅支援 vm_count = 1。"
  default     = ""

  validation {
    condition     = trimspace(var.nic_name) == "" || var.vm_count == 1
    error_message = "nic_name 自訂名稱僅支援 vm_count = 1；多部 VM 請留空以使用 {vm_name}-01-nic 格式。"
  }
}

variable "private_ip_allocation" {
  type        = string
  description = "NIC 私人 IP 配置方式：Dynamic 或 Static。"
  default     = "Dynamic"

  validation {
    condition     = contains(["Dynamic", "Static"], var.private_ip_allocation)
    error_message = "private_ip_allocation 必須為 Dynamic 或 Static。"
  }

  validation {
    condition     = var.private_ip_allocation != "Static" || var.vm_count == 1
    error_message = "Static 私人 IP 目前僅支援 vm_count = 1；多部 VM 請使用 Dynamic 或分開部署。"
  }
}

variable "private_ip_address" {
  type        = string
  description = "private_ip_allocation = Static 時指定的私人 IP（須在 Subnet 範圍內且未被占用）。"
  default     = null
  nullable    = true

  validation {
    condition = (
      var.private_ip_allocation != "Static" ||
      (var.private_ip_address != null && trimspace(var.private_ip_address) != "")
    )
    error_message = "private_ip_allocation = Static 時必須設定 private_ip_address。"
  }
}

variable "data_disk_enabled" {
  type    = bool
  default = false
}

variable "data_disk_count" {
  type    = number
  default = 1

  validation {
    condition     = var.data_disk_count >= 1 && var.data_disk_count <= 32
    error_message = "data_disk_count 必須介於 1 與 32 之間。"
  }
}

variable "data_disk_size_gb" {
  type    = number
  default = 128
}

variable "data_disk_type" {
  type    = string
  default = "Standard_LRS"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "generate_admin_password" {
  type    = bool
  default = true
}

variable "admin_password" {
  type      = string
  sensitive = true
  default   = null

  validation {
    condition     = var.generate_admin_password || var.admin_password != null
    error_message = "generate_admin_password = false 時必須設定 admin_password。"
  }
}

variable "enable_aad_login" {
  type    = bool
  default = false
}

variable "identity_type" {
  type     = string
  default  = null
  nullable = true

  validation {
    condition = (
      var.identity_type == null || trimspace(var.identity_type) == "" ||
      contains(
        ["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned", "UserAssigned, SystemAssigned"],
        trimspace(var.identity_type)
      )
    )
    error_message = "identity_type 無效。"
  }
}

variable "user_assigned_identity_ids" {
  type    = list(string)
  default = []
}

variable "role_assignments" {
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

variable "availability_zone" {
  type        = list(string)
  description = "可用性區域清單；不部署到 Zone 請設為 []。不可使用 [\"\"]。"
  default     = ["1"]

  validation {
    condition     = alltrue([for z in var.availability_zone : trimspace(z) != ""])
    error_message = "availability_zone 不可包含空字串；不部署到 Zone 請設為 []。"
  }
}

variable "enable_availability_set" {
  type    = bool
  default = false
}

variable "boot_diagnostics_enabled" {
  type    = bool
  default = true
}

variable "boot_diagnostics_storage_uri" {
  type        = string
  description = "開機診斷用 Blob 端點。若非 null 且非空白，則不建立模組內專用 Storage Account。"
  default     = null
  nullable    = true
}

variable "boot_diagnostics_storage_account_sequence" {
  type        = number
  description = "模組內自建開機診斷 Storage 時的序號；語意為 ctbc-jpe-win-vm-sa-XX（實際 Azure 名稱不含連字號；前綴避開 Azure 保留字 windows）。"
  default     = 1

  validation {
    condition     = var.boot_diagnostics_storage_account_sequence >= 1 && var.boot_diagnostics_storage_account_sequence <= 99
    error_message = "boot_diagnostics_storage_account_sequence 必須介於 1 與 99。"
  }
}

variable "auto_shutdown_enabled" {
  type    = bool
  default = false
}

variable "auto_shutdown_time" {
  type    = string
  default = "2000"
}

variable "auto_shutdown_timezone" {
  type    = string
  default = "UTC"
}

variable "backup_enabled" {
  type        = bool
  description = "是否啟用 VM 備份。為 true 且未指定 backup_policy_id 時，模組會建立 Recovery Services Vault 與預設 VM 備份原則。"
  default     = false
}

variable "recovery_vault_name" {
  type        = string
  description = "Recovery Services Vault 名稱。backup_enabled 且由模組建立 Vault 時可留空，預設為 {vm_name}-rsv。"
  default     = ""
}

variable "recovery_vault_resource_group" {
  type        = string
  description = "Vault 所在 RG；留空則使用 resource_group_name。"
  default     = null
}

variable "backup_policy_id" {
  type        = string
  description = "既有 VM 備份原則資源 ID。留空則於新建的 Vault 內建立 VM 備份原則（排程由下列 backup_policy_* 變數決定）。"
  default     = null
  nullable    = true
}

variable "backup_policy_name" {
  type        = string
  description = "模組自建 VM 備份原則名稱；留空則為 {recovery_vault_name}-vm-policy。"
  default     = ""
}

variable "backup_policy_frequency" {
  type        = string
  description = "模組自建備份原則之排程頻率：Daily 或 Weekly。"
  default     = "Daily"

  validation {
    condition     = contains(["Daily", "Weekly"], var.backup_policy_frequency)
    error_message = "backup_policy_frequency 必須為 Daily 或 Weekly。"
  }
}

variable "backup_policy_time" {
  type        = string
  description = "模組自建備份原則之每日／每週執行時間（24 小時制 HH:mm，例如 23:00）。"
  default     = "23:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_policy_time))
    error_message = "backup_policy_time 須為 HH:mm 格式（00:00～23:59）。"
  }
}

variable "backup_policy_weekdays" {
  type        = list(string)
  description = "backup_policy_frequency = Weekly 時的備份星期（例如 Sunday、Monday）。"
  default     = ["Sunday"]

  validation {
    condition = alltrue([
      for d in var.backup_policy_weekdays : contains(
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        d
      )
    ])
    error_message = "backup_policy_weekdays 須為 Sunday～Saturday 其中之一或多個。"
  }
}

variable "backup_policy_retention_daily_count" {
  type        = number
  description = "模組自建備份原則之每日還原點保留天數。"
  default     = 30

  validation {
    condition     = var.backup_policy_retention_daily_count >= 1 && var.backup_policy_retention_daily_count <= 9999
    error_message = "backup_policy_retention_daily_count 必須介於 1 與 9999。"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
