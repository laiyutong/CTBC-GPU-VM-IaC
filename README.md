# Azure GPU VM（Terraform）

# 專案目標

以 Terraform 建置 **Azure GPU VM**（Linux／Windows 可並存、可多台）。

可安裝 **NVIDIA GPU VM Extension**；可選開機診斷設定（Storage Account）、備份（Recovery Services Vault）、Public IP、Data Disk、加速網路與多種 Linux 登入方式（密碼／SSH）。

Azure Resource Group、VNet、Subnet 為預建，本專案僅以 `data` 引用；**不包含** NSG、Azure Firewall 與網路連線測試（連線驗證請見 [`scripts/README.md`](scripts/README.md)）。

## 目錄結構

```
├── modules/
│   ├── vm-linux/                    # Linux VM
│   ├── vm-windows/                  # Windows VM
│   └── gpu-extension/               # NVIDIA GPU Driver Extension
├── environments/
│   └── deploy/                      # 部署根目錄（單一 state）
│       ├── providers.tf
│       ├── data.tf                  # 既有 RG／VNet／Subnet
│       ├── main.tf
│       ├── locals.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example # 複製為 terraform.tfvars 後填入（勿提交版控）
└── scripts/                         # 部署後連線驗證（非 Terraform）
    ├── README.md
    ├── bash/                        # macOS / Linux
    │   ├── README.md
    │   ├── nsg-connect-test.sh / .sh.txt
    │   └── public-ip-nsg-connect-test.sh / .sh.txt
    └── powershell/                  # Windows
        ├── README.md
        ├── nsg-connect-test.ps1 / .ps1.txt
        └── public-ip-nsg-connect-test.ps1 / .ps1.txt
```

## 部署

```bash
cd environments/deploy
# 編輯 terraform.tfvars：subscription_id、location、既有網路、根層級 boot_diagnostics_storage_mode、backup_recovery_vault_mode、linux_vms / windows_vms

terraform init
terraform plan
terraform apply

# 本機管理員密碼（勿用 -json：<、> 會變成 \u003c 等，僅為 JSON 顯示規則）
terraform output linux_vm_admin_passwords
terraform output windows_vm_admin_passwords

# 若一定要用 JSON 再還原成畫面上的真實字元，可用 jq -r，例如：
# terraform output -json linux_vm_admin_passwords | jq -r 'to_entries[] | .key as $g | .value | to_entries[] | "\($g) \(.key): \(.value)"'

# Linux SSH（generate 模式）下載私鑰
terraform output -json linux_ssh_private_key_pem
```

同一環境可同時部署多組 Linux 與 Windows VM（於 `terraform.tfvars` 的 `linux_vms`、`windows_vms` map 中定義）。

此 stack 的 Azure Region 由根變數 `location` 指定（在 `terraform.tfvars` 設定，例如 `japaneast`）。`location` 須與 `existing_vnet_name`、`existing_subnet_name` 所在 region 一致，否則 NIC 無法使用該 Subnet。若需對照既有 RG 在 Portal 上的 metadata 區域，可執行 `terraform output resource_group_metadata_location`。

## 開機診斷 Storage

根變數 `boot_diagnostics_storage_mode`：

- `per_vm_stack`（預設）：每個 `linux_vms`／`windows_vms` 條目各自建立 Storage Account；命名語意為 `ctbc-jpe-linux-vm-sa-XX` 與 `ctbc-jpe-win-vm-sa-XX`（Windows 前綴不可用 `windows`，否則 Azure 會以保留字拒絕；實際名稱為去掉連字號之小寫）。序號可由各條目選填 `boot_diagnostics_storage_account_sequence` 覆寫，否則依 map key 排序自動編號。
- `shared`：建立單一共用帳戶，語意為 `ctbc-jpe-shared-vm-sa-XX`（序號 `shared_boot_diagnostics_storage_account_sequence`），所有啟用開機診斷的 Linux／Windows 模組共用同一 Blob 端點。

## 備份 Recovery Services Vault

根變數 `backup_recovery_vault_mode`（與開機診斷概念相同，寫在 `terraform.tfvars` 根層）：

- `per_vm_stack`（預設）：每個 `linux_vms`／`windows_vms` 條目在 `backup_enabled = true` 且未指定既有 `backup_policy_id` 時，於子模組內自建 RSV 與 VM 備份原則；排程可在各組 tfvars 設定 `backup_policy_name`（留空則 `{recovery_vault_name}-vm-policy`）、`backup_policy_frequency`、`backup_policy_time`、`backup_policy_retention_daily_count`（及 Weekly 時的 `backup_policy_weekdays`）。
- `shared`：在 `environments/deploy/main.tf` 建立單一共用 RSV 與一條 VM 備份原則；排程由根層 `shared_backup_policy_*` 變數設定。可選 `shared_recovery_vault_name`（留空則 `ctbc-jpe-shared-vm-rsv-XX`）、`shared_recovery_vault_sequence`、`shared_recovery_vault_resource_group`。

## 連線 VM

前置：`terraform apply` 完成，且 NSG 已放行對應埠（Linux 22、Windows 3389）。若 `public_ip_enabled = false`，需透過 VNet 內跳板或 VPN 連線，並改用私人 IP。

以下假設 `linux_vms` / `windows_vms` 的 map key 分別為 `gpu-linux`、`gpu-win`；請依實際 key 替換。

### 查詢 VM 名稱、IP 與帳號

```bash
cd environments/deploy

# VM 名稱（依 tfvars 的 linux_vms / windows_vms map key 分組）
terraform output linux_virtual_machine_names
terraform output windows_virtual_machine_names

# Public IP（有啟用 public_ip_enabled 時）
terraform output linux_public_ip_addresses
terraform output windows_public_ip_addresses

# Private IP
terraform output linux_network_interface_private_ips
terraform output windows_network_interface_private_ips
```

### Linux（四種登入方式）


| 模式                   | tfvars 設定                                                                         |
| -------------------- | --------------------------------------------------------------------------------- |
| 1. 密碼                | `authentication_type = "password"` + `generate_admin_password` / `admin_password` |
| 2. SSH 自動產生金鑰        | `authentication_type = "ssh_key"` + `ssh_public_key_source = "generate"`          |
| 3. SSH 使用 Azure 既有公鑰 | `authentication_type = "ssh_key"` + `ssh_public_key_source = "azure_existing"`    |
| 4. SSH 貼上公鑰          | `authentication_type = "ssh_key"` + `ssh_public_key_source = "public_key"`        |


#### 1. 密碼登入

```bash
# 取得密碼（generate_admin_password = true）
# 使用一般 output 即可直接看到 <、> 等字元；不要用 -json（否則會變 \u003c 等形式）
terraform output linux_vm_admin_passwords

# 連線（將 <IP> 換成 Public IP 或私人 IP）
ssh azureadmin@<IP>
# 貼上 output 中 gpu-linux → VM 名稱 對應的密碼
```

#### 2. SSH：自動產生金鑰（generate）

```bash
# 匯出私鑰（apply 後僅能由此取得，請妥善保存）
terraform output -json linux_ssh_private_key_pem | python3 -c "
import sys, json
print(json.load(sys.stdin)['gpu-linux'])
" > ~/.ssh/gpu-linux-key.pem

chmod 600 ~/.ssh/gpu-linux-key.pem
ssh -i ~/.ssh/gpu-linux-key.pem -o IdentitiesOnly=yes azureadmin@<IP>
```

#### 3. SSH：Azure 既有公鑰

Terraform 不會保存私鑰；請使用當初建立 `ssh_azure_key_name` 時持有的私鑰檔。

```bash
ssh -i ~/.ssh/<你的既有私鑰> -o IdentitiesOnly=yes azureadmin@<IP>
```

#### 4. SSH：貼上公鑰（public_key）

使用與 `ssh_public_key` 欄位配對的私鑰。

```bash
ssh -i ~/.ssh/<與 tfvars 公鑰配對的私鑰> -o IdentitiesOnly=yes azureadmin@<IP>
```

> Linux `ssh_key` 模式已停用密碼登入（`disable_password_authentication = true`），請勿使用密碼連線。

### Windows（密碼 + RDP，一種）

Windows 僅支援本機管理員密碼（`generate_admin_password` 或 `admin_password`）。

```bash
# 取得密碼（與 Linux 相同：勿用 -json 才會直接顯示 <、> 等字元）
terraform output windows_vm_admin_passwords

# macOS：開啟 Microsoft Remote Desktop，新增 PC
#   PC name : <IP>
#   User    : azureadmin（或 tfvars 的 admin_username）
#   Password: output 中 gpu-win → VM 名稱 對應的密碼

# Windows 本機（遠端桌面連線）
mstsc /v:<IP>
```

### 疑難排解：REMOTE HOST IDENTIFICATION HAS CHANGED

VM 重建、`terraform destroy` 後再 `apply`、或更換登入模式但 Public IP 不變時，本機 `~/.ssh/known_hosts` 仍保留舊 VM 的 host key，SSH 會拒絕連線並顯示：

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
Host key verification failed.
```

##### 步驟 1：刪除該 IP 的舊 host key 紀錄

```bash
ssh-keygen -R <IP>
# 範例
ssh-keygen -R 40.115.209.181
```

執行後會更新 `~/.ssh/known_hosts`，舊內容備份為 `~/.ssh/known_hosts.old`。

##### 步驟 2：重新連線並信任新主機

```bash
# Linux（依登入模式擇一）
ssh azureadmin@<IP>
# 或
ssh -i ~/.ssh/gpu-linux-key.pem -o IdentitiesOnly=yes azureadmin@<IP>
```

首次連線會提示：

```text
The authenticity of host '<IP>' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

輸入 `yes` 後按 Enter（此為正常流程，表示寫入新 VM 的 host key）。

##### 步驟 3（generate 模式且 VM 已重建）：重新匯出私鑰

destroy / 重建後，舊的 `~/.ssh/gpu-linux-key.pem` 無法登入新 VM，請重新執行：

```bash
cd environments/deploy
terraform output -json linux_ssh_private_key_pem | python3 -c "
import sys, json
print(json.load(sys.stdin)['gpu-linux'])
" > ~/.ssh/gpu-linux-key.pem
chmod 600 ~/.ssh/gpu-linux-key.pem
```

##### 常見後續訊息


| 訊息                                   | 處理方式                                  |
| ------------------------------------ | ------------------------------------- |
| `Permission denied (publickey)`      | 私鑰與 VM 公鑰不一致 → 執行步驟 3 或確認 tfvars 登入模式 |
| `Connection timed out`               | 檢查 NSG 是否放行 TCP 22、Public IP 是否正確     |
| 再次 `HOST IDENTIFICATION HAS CHANGED` | 對該 IP 再執行一次 `ssh-keygen -R <IP>`      |


## 機敏資訊

勿將含 `admin_password` 或 `ssh_public_key` 的 `terraform.tfvars` 提交至 Git。建議將 `terraform.tfvars` 加入 `.gitignore`。