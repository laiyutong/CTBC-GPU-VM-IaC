locals {
  extension_name = lower(var.operating_system) == "linux" ? "NvidiaGpuDriverLinux" : "NvidiaGpuDriverWindows"
  publisher      = "Microsoft.HpcCompute"
  extension_type = lower(var.operating_system) == "linux" ? "NvidiaGpuDriverLinux" : "NvidiaGpuDriverWindows"
}

resource "azurerm_virtual_machine_extension" "gpu_driver" {
  count = var.enabled ? length(var.virtual_machine_ids) : 0

  name                       = local.extension_name
  virtual_machine_id         = var.virtual_machine_ids[count.index]
  publisher                  = local.publisher
  type                       = local.extension_type
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
}
