variable "resource_group_name" {
  type        = string
  description = "VM／NIC／Disk 等資源所在的 Resource Group 名稱。"
  nullable    = false
}

variable "location" {
  type        = string
  description = "部署區域，需與 RG 所在 Region 一致。"
  nullable    = false
}

variable "subnet_id" {
  type        = string
  description = "NIC 所連接的 Subnet 資源 ID。"
  nullable    = false
}

variable "vm_name" {
  type        = string
  description = "VM 名稱基底（不含序號）。實際資源名稱為 {vm_name}-01、{vm_name}-02…。"
  default     = "vm-gpu-linux"
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
  description = "VM SKU（GPU 或一般 VM）。"
  default     = "NV6ads_A10_v5"
}

variable "os_disk_type" {
  type        = string
  description = "OS 磁碟 SKU。"
  default     = "StandardSSD_LRS"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS 磁碟大小（GB）。"
  default     = 128
}

variable "source_image_publisher" {
  type        = string
  description = "Marketplace 映像 Publisher。"
  default     = "Canonical"
}

variable "source_image_offer" {
  type        = string
  description = "Marketplace 映像 Offer。"
  default     = "0001-com-ubuntu-server-jammy"
}

variable "source_image_sku" {
  type        = string
  description = "Marketplace 映像 SKU。"
  default     = "22_04-lts-gen2"
}

variable "source_image_version" {
  type        = string
  description = "映像版本。"
  default     = "latest"
}

variable "accelerated_networking" {
  type        = bool
  description = "NIC 是否啟用加速網路。"
  default     = true
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
  type        = bool
  description = "是否建立並掛載額外 Data Disk。"
  default     = false
}

variable "data_disk_count" {
  type        = number
  description = "每部 VM 掛載的 Data Disk 數量。"
  default     = 1

  validation {
    condition     = var.data_disk_count >= 1 && var.data_disk_count <= 32
    error_message = "data_disk_count 必須介於 1 與 32 之間。"
  }
}

variable "data_disk_size_gb" {
  type        = number
  description = "每顆 Data Disk 大小（GB）。"
  default     = 128
}

variable "data_disk_type" {
  type        = string
  description = "Data Disk SKU。"
  default     = "Standard_LRS"
}

variable "authentication_type" {
  type        = string
  description = "ssh_key 或 password。"
  default     = "password"

  validation {
    condition     = contains(["ssh_key", "password"], lower(var.authentication_type))
    error_message = "authentication_type 必須為 ssh_key 或 password。"
  }
}

variable "admin_username" {
  type        = string
  description = "本機管理員／SSH 使用者名稱。"
  default     = "azureadmin"
}

variable "generate_admin_password" {
  type        = bool
  description = "password 模式且 admin_password 為 null 時自動產生密碼。"
  default     = true
}

variable "admin_password" {
  type        = string
  description = "本機密碼；若設定則所有 VM 共用。"
  sensitive   = true
  default     = null

  validation {
    condition     = lower(var.authentication_type) == "ssh_key" || var.generate_admin_password || var.admin_password != null
    error_message = "authentication_type=password 且 generate_admin_password=false 時必須設定 admin_password。"
  }
}

variable "ssh_public_key_source" {
  type        = string
  description = <<-EOT
    authentication_type=ssh_key 時必填。對應 Azure Portal「SSH public key source」：
    - generate：產生新金鑰對（tls + azurerm_ssh_public_key）
    - azure_existing：使用訂閱內既有 azurerm_ssh_public_key
    - public_key：貼上既有公鑰字串
  EOT
  default     = "public_key"

  validation {
    condition     = contains(["generate", "azure_existing", "public_key"], var.ssh_public_key_source)
    error_message = "ssh_public_key_source 必須為 generate、azure_existing 或 public_key。"
  }
}

variable "ssh_key_type" {
  type        = string
  description = "ssh_public_key_source=generate 時的金鑰演算法。對應 Portal「SSH Key Type」。"
  default     = "RSA"

  validation {
    condition     = contains(["RSA", "Ed25519"], var.ssh_key_type)
    error_message = "ssh_key_type 必須為 RSA 或 Ed25519。"
  }
}

variable "ssh_key_pair_name" {
  type        = string
  description = "ssh_public_key_source=generate 時寫入 Azure 的 Key pair 名稱；留空則為 {vm_name}-ssh-key。"
  default     = ""
}

variable "ssh_azure_key_name" {
  type        = string
  description = "ssh_public_key_source=azure_existing 時，既有 SSH 公鑰資源名稱。"
  default     = ""
}

variable "ssh_azure_key_resource_group" {
  type        = string
  description = "ssh_public_key_source=azure_existing 時，SSH 公鑰所在 RG；留空則使用 resource_group_name。"
  default     = null
}

variable "ssh_public_key" {
  type        = string
  description = "ssh_public_key_source=public_key 時必填：完整 OpenSSH 公鑰（ssh-rsa 或 ssh-ed25519 開頭）。"
  sensitive   = true
  default     = ""
}

variable "enable_aad_login" {
  type        = bool
  description = "是否安裝 AADSSHLoginForLinux。"
  default     = false
}

variable "identity_type" {
  type        = string
  description = "Managed Identity 類型；null 或空字串表示不啟用。"
  default     = null
  nullable    = true

  validation {
    condition = (
      var.identity_type == null || trimspace(var.identity_type) == "" ||
      contains(
        ["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned", "UserAssigned, SystemAssigned"],
        trimspace(var.identity_type)
      )
    )
    error_message = "identity_type 須為 null、空字串，或 SystemAssigned / UserAssigned / SystemAssigned, UserAssigned。"
  }
}

variable "user_assigned_identity_ids" {
  type        = list(string)
  description = "User Assigned Managed Identity 資源 ID。"
  default     = []
}

variable "role_assignments" {
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  description = "於每部 VM 的 System Assigned Principal 上建立 RBAC。"
  default     = []
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
  type        = bool
  description = "是否使用 Availability Set（與 availability_zone 互斥）。"
  default     = false
}

variable "boot_diagnostics_enabled" {
  type        = bool
  description = "是否啟用開機診斷。"
  default     = true
}

variable "boot_diagnostics_storage_uri" {
  type        = string
  description = "開機診斷用 Blob 端點（如 https://<account>.blob.core.windows.net/）。若非 null 且非空白，則不建立模組內專用 Storage Account，改使用此 URI（與根模組共用模式搭配）。"
  default     = null
  nullable    = true
}

variable "boot_diagnostics_storage_account_sequence" {
  type        = number
  description = "模組內自建開機診斷 Storage 時的序號；語意為 ctbc-jpe-linux-vm-sa-XX（Azure 實際名稱為移除連字號後之小寫字串）。"
  default     = 1

  validation {
    condition     = var.boot_diagnostics_storage_account_sequence >= 1 && var.boot_diagnostics_storage_account_sequence <= 99
    error_message = "boot_diagnostics_storage_account_sequence 必須介於 1 與 99。"
  }
}

variable "enable_azure_monitor_agent" {
  type        = bool
  description = "是否安裝 AzureMonitorLinuxAgent。"
  default     = false
}

variable "auto_shutdown_enabled" {
  type        = bool
  description = "是否啟用每日自動關機。"
  default     = false
}

variable "auto_shutdown_time" {
  type        = string
  description = "每日關機時間（HHmm）。"
  default     = "2000"
}

variable "auto_shutdown_timezone" {
  type        = string
  description = "自動關機排程的時區。"
  default     = "UTC"
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
  type        = map(string)
  description = "套用到本模組建立之資源的標籤。"
  default     = {}
}
