# 部署後連線驗證腳本

Terraform 部署完成後，從本機驗證 VM 對外連線（NSG + SSH/RDP）。**非** Terraform 資源，請手動執行。

## 選哪一支？

| 腳本 | 適用情境 |
|------|----------|
| `nsg-connect-test` | VM **已有** Public IP（`public_ip_enabled = true`） |
| `public-ip-nsg-connect-test` | VM **沒有** Public IP（暫建 `{vmName}-pip-test`，測完刪除） |

## 選哪個目錄？

| 目錄 | 平台 |
|------|------|
| [`bash/`](bash/README.md) | macOS / Linux（`.sh`） |
| [`powershell/`](powershell/README.md) | Windows（`.ps1`） |

## 目錄結構

```
scripts/
├── README.md
├── bash/
│   ├── README.md
│   ├── nsg-connect-test.sh / .sh.txt
│   └── public-ip-nsg-connect-test.sh / .sh.txt
└── powershell/
    ├── README.md
    ├── nsg-connect-test.ps1 / .ps1.txt
    └── public-ip-nsg-connect-test.ps1 / .ps1.txt
```

含真實 RG／VM／密碼的 `.sh` / `.ps1` 請勿提交版控；請用 `.txt` 範本或複製為 `.local.*` 後填入。
