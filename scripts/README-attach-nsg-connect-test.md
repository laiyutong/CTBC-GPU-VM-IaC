# attach-nsg-connect-test 腳本說明

## 目的

對指定 Azure VM 建立／更新 NSG、依 OS 開放 SSH（22）或 RDP（3389），並嘗試從本機用公用 IP 做連線驗證。**每台 VM 測試結束後會自動還原 NIC 上的 NSG**（預設開啟）。

## 測試後還原 NSG

| 設定 | Bash | PowerShell |
|------|------|------------|
| 測試後卸載 NIC 上的測試 NSG | `NSG_REMOVE_AFTER_TEST=true`（預設） | `$NsgRemoveAfterTest = $true`（預設） |
| 保留掛載（不還原） | `NSG_REMOVE_AFTER_TEST=false` | `$NsgRemoveAfterTest = $false` |

行為說明：

1. 綁定測試 NSG **之前**會記錄 NIC 上原本的 NSG（若有）。
2. 測試完成後（**成功或失敗皆會執行**）先還原 NIC：
   - 測試前 NIC **沒有** NSG → 自 NIC **移除** `{vmName}-nsg`
   - 測試前 NIC **已有** NSG → **還原**為該 NSG
3. **若本次腳本新建** `{vmName}-nsg`（測試前不存在）→ 還原 NIC 後 **刪除該 NSG 資源**。
4. **若測試前 NSG 已存在**（腳本僅沿用並更新規則）→ **不刪除** NSG 資源，避免誤刪既有資源。
5. 設 `NSG_REMOVE_AFTER_TEST=false` / `$NsgRemoveAfterTest = $false` 時，不還原 NIC、也不刪除 NSG。

## 本機先決條件

| 用途 | 需要 |
|------|------|
| Windows RDP 帳密（已填密碼時） | `xfreerdp`（Windows 請用 Chocolatey：`choco install freerdp`，見下方；macOS：`brew install freerdp`） |
| Linux SSH **密碼** | `sshpass` 或 `expect`（macOS 常內建 expect） |
| Linux SSH **金鑰** | 系統 `ssh`（macOS／Linux 通常已有；Windows 10+ 請啟用 OpenSSH Client） |
| Azure 操作 | `az login`、Azure CLI |

### Windows：安裝 FreeRDP（`xfreerdp`）

`winget install FreeRDP.FreeRDP` 目前已不可用；請改用 **Chocolatey**：

```powershell
# 1) 安裝 Chocolatey（若尚未安裝）
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2) 安裝 FreeRDP
choco install freerdp -y
```

安裝後重新開啟 PowerShell，確認：`xfreerdp /version`（或 `C:\ProgramData\chocolatey\bin\xfreerdp.exe`）。

## Linux SSH：密碼 vs 金鑰（三種 Portal 模式）

Terraform `authentication_type = ssh_key` 時，Portal 三選項在 VM 上都是 **公鑰登入、關閉密碼**；腳本測試方式相同，差在 **私鑰檔從哪來**：

| Portal / `ssh_public_key_source` | 私鑰怎麼取得 | 腳本設定 |
|--------------------------------|--------------|----------|
| **Generate new key pair** (`generate`) | `terraform apply` 後從 output 存檔 | `VM_TEST_SSH_KEY_PATH` + 建議 `VM_TEST_SSH_KEY_SOURCE=("generate")` |
| **Use existing key stored in Azure** (`azure_existing`) | 你當初建立該 Azure SSH 公鑰時的本機私鑰 | 填私鑰路徑 + `azure_existing` |
| **Use existing public key** (`public_key`) | 你貼公鑰時對應的本機私鑰 | 填私鑰路徑 + `public_key` |

**Linux 連線測試：腳本怎麼選方式？**

腳本會依你在變數裡**有沒有填、路徑／密碼是否可用**，由上而下擇一執行（不會同時試三種）：

| 判斷順序 | 你要滿足的條件 | 腳本實際做的事 |
|----------|----------------|----------------|
| 優先 | `VM_TEST_SSH_KEY_PATH` 有填，且檔案存在、可讀 | **金鑰登入**：`ssh -i <私鑰>` 嘗試連線 |
| 其次 | 上面不符合，但 `VM_TEST_PASSWORD` 有填且非空 | **密碼登入**：用 `sshpass` 或 `expect` 嘗試連線 |
| 最後 | 私鑰與密碼都沒設好 | **只測埠**：不登入，只檢查公用 IP 的 TCP 22 是否通（確認 NSG 有放行） |

不論最後採金鑰、密碼或只測埠，腳本都會先幫 VM 掛上測試用 NSG；差別只在有沒有真的 SSH 登入成功。

> **常見情況**：Terraform 設 `authentication_type = ssh_key` 時，VM 不接受密碼，請用**金鑰登入**並填對 `VM_TEST_SSH_KEY_PATH`；只填密碼多半會失敗；**只測埠**只能證明 22 有開，不能證明你能登入。

`VM_TEST_SSH_KEY_SOURCE` 只用在成功／失敗訊息裡標註金鑰來源（generate / azure_existing / public_key），**不會**向 Azure 下載私鑰。

### generate：從 Terraform 匯出私鑰

在 `environments/deploy`（已 apply）：

```bash
mkdir -p keys
# 將 gpu-linux 換成你 main.tf 裡 module.linux 的 key
terraform output -raw 'linux_ssh_private_key_pem["gpu-linux"]' > keys/gpu-linux.pem
chmod 600 keys/gpu-linux.pem
```

腳本設定範例：

```bash
AZURE_VM_NAME=("ctbc-jpe-gpu-linux-vm-01")
VM_TEST_USER=("azureadmin")
VM_TEST_PASSWORD=('CHANGE_ME_PASSWORD')   # ssh_key 模式可不改密碼
VM_TEST_SSH_KEY_PATH=("$HOME/.../keys/gpu-linux.pem")
VM_TEST_SSH_KEY_SOURCE=("generate")
```

### azure_existing / public_key

```bash
VM_TEST_SSH_KEY_PATH=("/path/to/your-private-key.pem")
VM_TEST_SSH_KEY_SOURCE=("azure_existing")   # 或 public_key
```

私鑰權限過寬時 OpenSSH 會拒絕：macOS/Linux `chmod 600 key.pem`；Windows 可用 `icacls`（腳本失敗訊息會提示）。

## 設定變數

| Bash | PowerShell | 說明 |
|------|------------|------|
| `AZURE_RESOURCE_GROUP` | `$ResourceGroup` | 資源群組 |
| `AZURE_VM_NAME` | `$AZURE_VM_NAME` | VM 名稱陣列 |
| `VM_TEST_USER` | `$VM_TEST_USER` | 登入帳號（1 筆可共用） |
| `VM_TEST_PASSWORD` | `$VM_TEST_PASSWORD` | 密碼；`CHANGE_ME_PASSWORD` 表示不測密碼 |
| `VM_TEST_SSH_KEY_PATH` | `$VM_TEST_SSH_KEY_PATH` | Linux 私鑰路徑；空或 `CHANGE_ME_SSH_KEY` 表示不測金鑰 |
| `VM_TEST_SSH_KEY_SOURCE` | `$VM_TEST_SSH_KEY_SOURCE` | 選填：`generate` / `azure_existing` / `public_key` |
| `NSG_SOURCE_PREFIX` | `$NsgSourcePrefix` | NSG 規則來源，預設 `*` |
| `NSG_REMOVE_AFTER_TEST` | `$NsgRemoveAfterTest` | 測試後還原 NIC NSG，預設 `true` |

陣列可 **1 筆共用** 或 **與 VM 數量相同** 多筆對齊。

### 範例：Linux 金鑰 + Windows 密碼（兩台）

```bash
AZURE_RESOURCE_GROUP="my-rg"
AZURE_VM_NAME=("vm-linux-01" "vm-win-01")
VM_TEST_USER=("azureadmin" "azureadmin")
VM_TEST_PASSWORD=('CHANGE_ME_PASSWORD' 'Win密碼')
VM_TEST_SSH_KEY_PATH=("$HOME/keys/vm-linux-01.pem" "")
VM_TEST_SSH_KEY_SOURCE=("generate" "")
```

## 使用方式

### Bash（macOS / Linux）

```bash
cd scripts
chmod +x attach-nsg-connect-test.sh   # 僅首次
./attach-nsg-connect-test.sh
```

### PowerShell（Windows）

```powershell
cd scripts
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\attach-nsg-connect-test.ps1
```

或：`powershell -ExecutionPolicy Bypass -File .\attach-nsg-connect-test.ps1`

需已安裝 [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows) 並 `az login`。

### Windows：Linux SSH 私鑰路徑與權限

- `$VM_TEST_SSH_KEY_PATH` 請填**私鑰**完整路徑，例如：`$env:USERPROFILE\.ssh\id_rsa`（勿填 `.pub`）。
- 若出現 `UNPROTECTED PRIVATE KEY FILE`，在 PowerShell 執行（將路徑改成你的私鑰）：

```powershell
icacls "$env:USERPROFILE\.ssh\id_rsa" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

- 若錯誤為 `Permission denied (publickey)`：私鑰與 VM 上公鑰不配對，或帳號 `$VM_TEST_USER` 錯誤；請對照 `terraform.tfvars` 的 `admin_username` 與 `ssh_public_key`。
- 舊版腳本在 Windows 可能把 `Warning: Permanently added...` 誤報成 SSH 失敗；請使用含 `Test-SshKeyEchoOk` 修正的最新 `.ps1`。

## 訊息說明（Linux SSH 金鑰）

| 訊息 | 意義 |
|------|------|
| `SSH 金鑰驗證: 成功` | 私鑰登入成功，遠端執行 `echo OK` |
| `私鑰檔不存在` | `VM_TEST_SSH_KEY_PATH` 路徑錯誤 |
| `私鑰檔權限過寬` | 請 `chmod 600`（或 Windows `icacls`） |
| `私鑰與 VM 上公鑰不配對` | 常見於填錯金鑰或 `azure_existing` 用錯私鑰 |
| `未設定 VM_TEST_SSH_KEY_PATH` | ssh_key 模式卻沒填私鑰；訊息會依 `VM_TEST_SSH_KEY_SOURCE` 提示三種模式 |
| `SSH 帳密驗證: 失敗` | 密碼錯誤，或 VM 僅允許金鑰（請改填 `VM_TEST_SSH_KEY_PATH`） |
| `RDP 帳密驗證: 失敗（本機未安裝 xfreerdp）` | 已填 Windows 密碼但本機無 FreeRDP；請依上方 **Windows：安裝 FreeRDP** 用 `choco install freerdp` 安裝後重跑 |
| `RDP 帳密驗證: 失敗（xfreerdp 結束碼 …）` | 帳密錯誤或 NLA 參數問題；請核對 `windows_vm_admin_passwords` |

## 需自行確認的事項

1. **NSG 掛在 NIC**：預設第一張 NIC；Subnet 另有 NSG 時規則會合併。  
2. **無公用 IP**：無法從外部測連。  
3. **Windows RDP**：腳本已填 `$VM_TEST_PASSWORD`（Windows）時，須本機有 `xfreerdp` 且 RDP 帳密驗證成功才算通過；未安裝會**失敗**（僅 TCP 3389 不足）。Windows 請用 Chocolatey 安裝（`winget` 套件已下架）。未填帳密時則僅以 TCP 3389 為成功條件。  
4. **勿 commit 私鑰／密碼**；可參考去機敏範例：`attach-nsg-connect-test.sh.txt`、`attach-nsg-connect-test.ps1.txt`（複製為 `.local.sh` / `.local.ps1` 後再填入實際值）。  
5. **多台 VM**：任一台失敗則腳本結束碼非 0 並列出失敗清單。

## 查詢 VM 名稱

```bash
cd environments/deploy
terraform output linux_virtual_machine_names
terraform output windows_virtual_machine_names
```
