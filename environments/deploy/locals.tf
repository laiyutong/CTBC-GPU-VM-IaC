locals {
  linux_vm_keys_sorted   = sort(keys(var.linux_vms))
  windows_vm_keys_sorted = sort(keys(var.windows_vms))

  shared_recovery_vault_rg_effective = coalesce(var.shared_recovery_vault_resource_group, data.azurerm_resource_group.vm.name)

  shared_recovery_vault_name_effective = trimspace(var.shared_recovery_vault_name) != "" ? trimspace(var.shared_recovery_vault_name) : format("ctbc-jpe-shared-vm-rsv-%02d", var.shared_recovery_vault_sequence)

  # 根層 backup_policy_id：有填且非空白才視為「使用既有原則」（否則與 null 同等）
  root_backup_policy_id_effective = (
    var.backup_policy_id != null && length(trimspace(var.backup_policy_id)) > 0 ? trimspace(var.backup_policy_id) : null
  )

  # 各條目 backup_policy_id：null／省略 → ""；有值則 trim（不可 coalesce(null,"")：兩者對 coalesce 皆無效會報錯）
  linux_vm_backup_policy_id_trimmed = {
    for key, cfg in var.linux_vms : key => (
      try(cfg.backup_policy_id, null) == null ? "" : trimspace(cfg.backup_policy_id)
    )
  }

  windows_vm_backup_policy_id_trimmed = {
    for key, cfg in var.windows_vms : key => (
      try(cfg.backup_policy_id, null) == null ? "" : trimspace(cfg.backup_policy_id)
    )
  }

  linux_uses_shared_backup_rsv = {
    for key, cfg in var.linux_vms : key => (
      cfg.backup_enabled &&
      var.backup_recovery_vault_mode == "shared" &&
      length(local.linux_vm_backup_policy_id_trimmed[key]) == 0 &&
      local.root_backup_policy_id_effective == null
    )
  }

  windows_uses_shared_backup_rsv = {
    for key, cfg in var.windows_vms : key => (
      cfg.backup_enabled &&
      var.backup_recovery_vault_mode == "shared" &&
      length(local.windows_vm_backup_policy_id_trimmed[key]) == 0 &&
      local.root_backup_policy_id_effective == null
    )
  }

  any_shared_backup_enabled = (
    length([for k, cfg in var.linux_vms : k if local.linux_uses_shared_backup_rsv[k]]) > 0 ||
    length([for k, cfg in var.windows_vms : k if local.windows_uses_shared_backup_rsv[k]]) > 0
  )

  shared_backup_policy_id_candidates = flatten(azurerm_backup_policy_vm.shared_backup[*].id)
  shared_backup_policy_id = (
    length(local.shared_backup_policy_id_candidates) > 0 ? local.shared_backup_policy_id_candidates[0] : null
  )

  # per_vm_stack：各組優先自己的 backup_policy_id，否則根層，皆無則 null（子模組自建 RSV）
  linux_per_stack_backup_policy_id = {
    for key, cfg in var.linux_vms : key => (
      length(local.linux_vm_backup_policy_id_trimmed[key]) > 0 ? local.linux_vm_backup_policy_id_trimmed[key] : local.root_backup_policy_id_effective
    )
  }

  windows_per_stack_backup_policy_id = {
    for key, cfg in var.windows_vms : key => (
      length(local.windows_vm_backup_policy_id_trimmed[key]) > 0 ? local.windows_vm_backup_policy_id_trimmed[key] : local.root_backup_policy_id_effective
    )
  }

  linux_backup_policy_id_for_module = {
    for key, cfg in var.linux_vms : key => (
      !cfg.backup_enabled ? null : (
        local.linux_uses_shared_backup_rsv[key] ? local.shared_backup_policy_id : local.linux_per_stack_backup_policy_id[key]
      )
    )
  }

  windows_backup_policy_id_for_module = {
    for key, cfg in var.windows_vms : key => (
      !cfg.backup_enabled ? null : (
        local.windows_uses_shared_backup_rsv[key] ? local.shared_backup_policy_id : local.windows_per_stack_backup_policy_id[key]
      )
    )
  }

  any_boot_diagnostics_enabled = (
    (length(var.linux_vms) > 0 && contains([for v in var.linux_vms : v.boot_diagnostics_enabled], true)) ||
    (length(var.windows_vms) > 0 && contains([for v in var.windows_vms : v.boot_diagnostics_enabled], true))
  )

  shared_boot_diag_uri_candidates = flatten(azurerm_storage_account.shared_bootdiag[*].primary_blob_endpoint)
  shared_boot_diagnostics_blob_endpoint = (
    length(local.shared_boot_diag_uri_candidates) > 0 ? local.shared_boot_diag_uri_candidates[0] : null
  )

  # per_vm_stack：各 linux_vms／windows_vms 模組獨立 SA，序號各自由 1 起編（命名前綴已區分 OS）。
  linux_boot_diag_seq_default = {
    for i, k in local.linux_vm_keys_sorted : k => i + 1
  }
  windows_boot_diag_seq_default = {
    for i, k in local.windows_vm_keys_sorted : k => i + 1
  }

  linux_vm_tags = {
    for key, cfg in var.linux_vms : key => merge(var.default_tags, cfg.tags)
  }

  windows_vm_tags = {
    for key, cfg in var.windows_vms : key => merge(var.default_tags, cfg.tags)
  }
}
