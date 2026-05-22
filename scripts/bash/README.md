# Bash 連線驗證腳本

需已安裝 Azure CLI（`az login`）、`ssh`；Linux 密碼測試可選 `sshpass` / `expect`；Windows RDP 測試需本機 `xfreerdp`（`brew install freerdp`）。

## 腳本一覽

| 腳本 | 適用情境 |
|------|----------|
| `nsg-connect-test.sh` | VM **已有** Public IP |
| `public-ip-nsg-connect-test.sh` | VM **沒有** Public IP（暫建 PIP，測完刪除） |

## nsg-connect-test

1. 建立／更新 `{vmName}-nsg`，開放 TCP 22 或 3389  
2. 以**既有**公用 IP 做連線驗證  
3. 測試後還原 NIC NSG，並刪除本次建立的測試 NSG（條件符合時）

```bash
cd scripts/bash
cp nsg-connect-test.sh.txt nsg-connect-test.local.sh
# 編輯 .local.sh
chmod +x nsg-connect-test.local.sh
./nsg-connect-test.local.sh
```

## public-ip-nsg-connect-test

1. 建立 `{vmName}-pip-test` 並綁定 NIC  
2. 執行與 `nsg-connect-test` 相同的 NSG + SSH/RDP 測試  
3. 卸載並刪除測試 PIP，還原／刪除測試 NSG  

額外變數：`PUBLIC_IP_SKU`、`PUBLIC_IP_ALLOCATION`、`PUBLIC_IP_ZONE`（Standard 時 `--zone`）、`PUBLIC_IP_REMOVE_AFTER_TEST`、`PUBLIC_IP_SUFFIX`（預設 `-pip-test`）。

```bash
cd scripts/bash
chmod +x public-ip-nsg-connect-test.sh   # 僅首次
./public-ip-nsg-connect-test.sh
```

## 測試後還原 NSG

| 變數 | 預設 | 說明 |
|------|------|------|
| `NSG_REMOVE_AFTER_TEST` | `true` | `false` 則保留 NIC 上的測試 NSG |

還原時卸載 NSG 使用 `az network nic update --set networkSecurityGroup=null`（Azure CLI 2.83+）。

## Linux SSH：密碼 vs 金鑰

| 順序 | 條件 | 行為 |
|------|------|------|
| 1 | `VM_TEST_SSH_KEY_PATH` 有效 | `ssh -i` 金鑰登入 |
| 2 | `VM_TEST_PASSWORD` 有填 | `sshpass` / `expect` 密碼登入 |
| 3 | 皆無 | 僅測 TCP 22 |

`terraform output` 匯出私鑰（generate 模式）：

```bash
cd environments/deploy
mkdir -p keys
terraform output -raw 'linux_ssh_private_key_pem["gpu-linux"]' > keys/gpu-linux.pem
chmod 600 keys/gpu-linux.pem
```

## 共用變數

| 變數 | 說明 |
|------|------|
| `AZURE_RESOURCE_GROUP` | 資源群組 |
| `AZURE_VM_NAME` | VM 名稱陣列 |
| `VM_TEST_USER` / `VM_TEST_PASSWORD` | 登入帳密；`CHANGE_ME_PASSWORD` 表示不測密碼 |
| `VM_TEST_SSH_KEY_PATH` | Linux 私鑰；`CHANGE_ME_SSH_KEY` 表示不測金鑰 |
| `VM_TEST_SSH_KEY_SOURCE` | `generate` / `azure_existing` / `public_key` |
| `NSG_SOURCE_PREFIX` | 規則來源，預設 `*` |

陣列可 1 筆共用或與 VM 數量相同。

## 查詢 VM 名稱

```bash
cd environments/deploy
terraform output linux_virtual_machine_names
terraform output windows_virtual_machine_names
```

PowerShell 版說明見 [`../powershell/README.md`](../powershell/README.md)。
