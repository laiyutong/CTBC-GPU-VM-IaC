variable "virtual_machine_ids" {
  type        = list(string)
  description = "要安裝 GPU Driver Extension 的 VM 資源 ID 清單。"
}

variable "operating_system" {
  type        = string
  description = "linux 或 windows，決定 Extension 類型。"
  nullable    = false

  validation {
    condition     = contains(["linux", "windows"], lower(var.operating_system))
    error_message = "operating_system 必須為 linux 或 windows。"
  }
}

variable "enabled" {
  type        = bool
  description = "是否建立 GPU Driver Extension。"
  default     = true
}
