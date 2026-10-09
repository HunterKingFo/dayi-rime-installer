# DaYi IME for RIME on Linux Mint / Ubuntu

這個專案會在 Linux Mint 或 Ubuntu 上安裝以下組合：

```text
Fcitx5 → RIME → 大易四碼（DaYi IME）
```

安裝器使用固定版本的公開 `dayi4.cin` 碼表，轉換成 RIME 字典，加入 Fcitx5，並設定登入時自動啟動。

## 一鍵安裝

建議先下載並檢查腳本，再執行：

```bash
git clone https://github.com/HunterKingFo/dayi-rime-installer.git
cd dayi-rime-installer
bash install-dayi-rime.sh
```

腳本會在安裝系統套件時要求 `sudo` 密碼。請以一般使用者執行，不要使用 `sudo bash install-dayi-rime.sh`。

安裝完成後登出再登入，按 `Ctrl+Space` 切換至 RIME 大易四碼。

## 驗證

切換到大易四碼後測試：

```text
/. + Space → 的
```

數字鍵 `0–9` 與符號鍵 `, . / ;` 都是大易取碼鍵。真正要輸入英數或標點時，可用 `Ctrl+Space` 切回英文鍵盤。

## 已處理的問題

- 安裝 `fcitx5`、`fcitx5-rime`、設定工具及 `im-config`。
- 若 Linux Mint 使用失效的 `http://ubuntu.cs.nctu.edu.tw/ubuntu` 鏡像並出現 `403 Forbidden`，會先備份來源設定，再切換至 Ubuntu HTTPS 官方鏡像。
- 將數字 `0–9` 納入大易取碼，避免直接輸出數字。
- 將 `, . / ;` 保留給大易取碼，不載入 RIME 的標點處理器。
- 移除 RIME 預設的句號翻頁快捷鍵，修正 `/.` 無法輸出「的」的問題。
- 避免預設 URL/Email recognizer 攔截含 `.` 或 `/` 的大易碼。
- 使用 `' [ ] - \\` 作為候選字選擇鍵，避免與數字取碼衝突。
- 在組字區顯示大易字根，而非只有英數鍵碼。
- 保留既有設定備份，並支援重複執行而不重複加入 RIME。
- 設定 Fcitx5 登入時自動啟動。

## 設定與備份位置

- RIME 使用者資料：`~/.local/share/fcitx5/rime/`
- Fcitx5 profile：`~/.config/fcitx5/profile`
- Fcitx5 自動啟動：`~/.config/autostart/fcitx5.desktop`
- 安裝器備份：`~/.local/share/dayi-rime-installer/backups/`

## 測試安裝器

在已安裝 `rime_deployer` 的系統上執行：

```bash
bash tests/test-installer.sh
```

測試會在 `/tmp` 建立隔離的設定目錄，連續安裝兩次，檢查 RIME 編譯產物、`/. → 的`、數字符號取碼、句號翻頁修正，以及安裝冪等性；不會修改真正的使用者設定。

測試會自動下載並驗證固定版本的碼表；離線時可以用 `DAYI_TEST_CIN_FILE=/path/to/dayi4.cin bash tests/test-installer.sh` 指定本機檔案。這些測試驗證方案編譯與設定，沒有模擬實際桌面的按鍵輸入，也沒有驗證全新系統上的 apt 安裝。

## 碼表來源與授權說明

碼表來源：[chinese-opendesktop/cin-tables 的 dayi4.cin](https://github.com/chinese-opendesktop/cin-tables/blob/ea28d61b50950b3738e3f401e5828478d303d0fe/dayi4.cin)。

原始檔說明該表格由太易資訊公司授權使用，允許轉換格式以適用於其他平台或輸入法軟體，但不得任意更改每個字的編碼規則後重新散布。本安裝器只做格式轉換，不改變字碼規則。
