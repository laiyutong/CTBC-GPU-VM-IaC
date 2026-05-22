# PowerShell 連線驗證腳本

需已安裝 [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)（`az login`）、OpenSSH Client；Windows RDP 測試需 `xfreerdp`（`choco install freerdp`）。

## 腳本一覽

| 腳本 | 適用情境 |
|------|----------|
| `nsg-connect-test.ps1` | VM **已有** Public IP |
| `public-ip-nsg-connect-test.ps1` | VM **沒有** Public IP（暫建 PIP，測完刪除） |

## nsg-connect-test

```powershell
cd scripts\powershell
Copy-Item nsg-connect-test.ps1.txt nsg-connect-test.local.ps1
# 編輯 .local.ps1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\nsg-connect-test.local.ps1
```

## public-ip-nsg-connect-test

```powershell
cd scripts\powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\public-ip-nsg-connect-test.ps1
```

額外變數：`$PublicIpSku`、`$PublicIpAllocation`、`$PublicIpZone`、`$PublicIpRemoveAfterTest`、`$PublicIpSuffix`。

**Linux 私鑰路徑**（勿用 Bash 陣列語法）：

```powershell
$VM_TEST_SSH_KEY_PATH = @(
    (Join-Path $env:USERPROFILE '.ssh\id_rsa')
    ''
)
```

`az` 查詢「資源不存在」時請用腳本內建的 `Invoke-AzQuiet`（勿僅靠 `2>$null`，否則可能觸發終止錯誤）。

## 安裝 FreeRDP

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install freerdp -y
```

## 測試後還原

| 變數 | 預設 |
|------|------|
| `$NsgRemoveAfterTest` | `$true` |
| `$PublicIpRemoveAfterTest` | `$true` |

清理使用 `--set networkSecurityGroup=null`、`--set publicIPAddress=null`。

## 共用變數

| PowerShell | 說明 |
|------------|------|
| `$ResourceGroup` | 資源群組 |
| `$AZURE_VM_NAME` | VM 名稱陣列 |
| `$VM_TEST_USER` / `$VM_TEST_PASSWORD` | 登入帳密 |
| `$VM_TEST_SSH_KEY_PATH` | Linux 私鑰路徑 |
| `$NsgSourcePrefix` | NSG 來源，預設 `*` |

私鑰權限過寬時：

```powershell
icacls "$env:USERPROFILE\.ssh\id_rsa" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

Bash 版說明見 [`../bash/README.md`](../bash/README.md)。
