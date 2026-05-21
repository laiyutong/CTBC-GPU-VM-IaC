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

variable "enable_azure_monitor_agent" {
  type    = bool
  default = false
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
  description = "既有 VM 備份原則資源 ID。留空則於新建的 Vault 內建立預設每日備份原則。"
  default     = null
  nullable    = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
