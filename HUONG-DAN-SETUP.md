# 🚀 HƯỚNG DẪN SETUP VÀ KIỂM TRA REMOTE LAB

## 📋 Tổng quan dự án

**Remote Lab Setup** là hệ thống tự động thiết lập và quản lý các máy tính phòng lab từ xa, cho phép:
- Tự động thiết lập máy lab
- Kết nối SSH tunnel để truy cập từ xa
- Cài đặt phần mềm cần thiết
- Quản lý tập trung qua server trung tâm

## 🗂️ Cấu trúc dự án

```
setup-remote/
├── init.ps1                    # Script chính
├── prepare-master-key.ps1      # Tạo SSH keys
├── run-init-as-admin.bat       # Launcher với quyền admin
├── ssh-5985.xml               # SSH tunnel task
├── remote-lab-camera.zip      # Camera viewer
└── HUONG-DAN-SETUP.md         # File hướng dẫn này
```

## 🛠️ HƯỚNG DẪN SETUP

### Bước 1: Chuẩn bị môi trường

#### 1.1 Cài đặt OpenSSH Client
```powershell
# Chạy với quyền Administrator
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

#### 1.2 Kiểm tra kết nối mạng
```powershell
# Test kết nối đến server trung tâm
Test-NetConnection -ComputerName 103.218.122.188 -Port 8000
```

### Bước 2: Tạo SSH Keys (Tùy chọn)

```powershell
# Chạy script tạo master key
.\prepare-master-key.ps1
```

**Lưu ý**: Script sẽ tạo thư mục `C:\RemoteLab-Setup` với SSH keys.

### Bước 3: Khởi động Remote Lab Service

#### Cách 1: Sử dụng Batch File (Khuyến nghị)
```cmd
.\run-init-as-admin.bat
```
- Chọn chế độ: Single run, Background service, hoặc Custom interval

#### Cách 2: Chạy trực tiếp PowerShell
```powershell
# Chạy một lần
.\init.ps1

# Chạy background service (30 giây interval)
.\init.ps1 -BackgroundMode -PollInterval 30

# Chạy với tên process tùy chỉnh
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -Command `$Host.UI.RawUI.WindowTitle = \"RemoteLabService\"; Set-Location \"$PWD\"; & \".\init.ps1\" -BackgroundMode -PollInterval 30' -Verb RunAs"
```

## 🔍 KIỂM TRA HOẠT ĐỘNG

### 1. Kiểm tra Process đang chạy

```powershell
# Xem tất cả process PowerShell
Get-Process powershell | Select-Object Id, ProcessName, StartTime

# Xem process với tên tùy chỉnh
Get-Process | Where-Object {$_.MainWindowTitle -like "*RemoteLab*"}
```

### 2. Kiểm tra Log File

```powershell
# Xem log realtime
Get-Content "$env:USERPROFILE\Desktop\RemoteLabSetup.log" -Wait -Tail 10

# Xem log cuối cùng
Get-Content "$env:USERPROFILE\Desktop\RemoteLabSetup.log" -Tail 20
```

### 3. Kiểm tra kết nối Server

```powershell
# Test API endpoint
try {
    $response = Invoke-RestMethod -Uri "http://103.218.122.188:8000/api/commands" -Method GET -TimeoutSec 5
    Write-Host "✅ Server connection: SUCCESS" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 2)"
} catch {
    Write-Host "❌ Server connection: FAILED - $($_.Exception.Message)" -ForegroundColor Red
}
```

### 4. Kiểm tra các Service đã được kích hoạt

```powershell
# Kiểm tra Remote Desktop
Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections"

# Kiểm tra PowerShell Remoting
Get-PSSessionConfiguration | Where-Object {$_.Enabled -eq $true}

# Kiểm tra User Admin
Get-LocalUser -Name "Admin" -ErrorAction SilentlyContinue

# Kiểm tra SSH Task
schtasks /query /tn "ssh-5985"
```

### 5. Kiểm tra phần mềm đã cài đặt

```powershell
# Kiểm tra VS Code
Test-Path "C:\Program Files\Microsoft VS Code\Code.exe"

# Kiểm tra Arduino IDE
Test-Path "C:\Program Files\Arduino\Arduino IDE.exe"

# Kiểm tra Camera Viewer
Test-Path "C:\Program Files\remote-lab-camera\remote-lab-camera\remote-lab-camera.exe"
```

## 📊 TRẠNG THÁI HOẠT ĐỘNG

### ✅ Trạng thái Bình thường
```
[2025-10-19 15:35:08] Checking for server commands... (Last run: 30.0002284 seconds ago)
[2025-10-19 15:35:08] Found 1 server commands, executing...
[2025-10-19 15:35:08] WARNING: Skipping invalid command: "Server returned array of 0 commands"
```

### 🔧 Các lệnh Server có thể nhận
- `create_user` - Tạo user admin
- `create_admin_user` - Tạo admin user với thông tin từ server
- `enable_rdp` - Bật Remote Desktop
- `enable_powershell_remoting` - Bật PowerShell Remoting
- `setup_ssh_tunnel` - Thiết lập SSH tunnel
- `install_software` - Cài đặt phần mềm (vscode, arduino, camera)
- `extract_ssh_keys` - Giải nén SSH keys
- `custom_command` - Chạy lệnh tùy chỉnh
- `register_computer` - Đăng ký máy tính với server

### 🔐 Admin Credentials từ Server
- **Endpoint**: `http://103.218.122.188:8000/api/admin-credentials`
- **Format Response**:
  ```json
  {
    "username": "Admin",
    "password": "YourPassword"
  }
  ```
- **Fallback**: Nếu server không khả dụng, sử dụng credentials mặc định

## 🚨 XỬ LÝ SỰ CỐ

### 1. Service không chạy
```powershell
# Dừng tất cả process PowerShell cũ
Get-Process powershell | Where-Object {$_.Id -ne $PID} | Stop-Process -Force

# Khởi động lại service
.\init.ps1 -BackgroundMode -PollInterval 30
```

### 2. Không kết nối được Server
```powershell
# Kiểm tra firewall
Get-NetFirewallRule -DisplayGroup "Remote Desktop"

# Kiểm tra kết nối mạng
Test-NetConnection -ComputerName 103.218.122.188 -Port 8000
```

### 3. Log file bị lỗi
```powershell
# Xóa log cũ và tạo mới
Remove-Item "$env:USERPROFILE\Desktop\RemoteLabSetup.log" -Force -ErrorAction SilentlyContinue
```

### 4. Dừng Service
```powershell
# Tìm và dừng process
Get-Process powershell | Where-Object {$_.MainWindowTitle -like "*RemoteLab*"} | Stop-Process -Force

# Hoặc sử dụng Task Manager
# Ctrl+Shift+Esc → Tìm "RemoteLabService" → End Task
```

## 📝 GHI CHÚ QUAN TRỌNG

1. **Quyền Admin**: Script cần chạy với quyền Administrator
2. **Firewall**: Đảm bảo firewall không chặn port 8000 và 5985
3. **Network**: Cần kết nối internet để giao tiếp với server
4. **SSH Keys**: Chỉ cần tạo một lần, sau đó copy đến các máy lab khác
5. **Background Mode**: Service sẽ chạy liên tục, tự động restart nếu bị lỗi

## 🎯 KẾT QUẢ MONG ĐỢI

Sau khi setup thành công:
- ✅ Remote Lab Service chạy với tên "RemoteLabService"
- ✅ Kết nối được đến server trung tâm
- ✅ Log file được tạo và ghi liên tục
- ✅ Sẵn sàng nhận lệnh từ server
- ✅ Các service cần thiết đã được kích hoạt

---
**📞 Hỗ trợ**: Nếu gặp vấn đề, kiểm tra log file hoặc liên hệ admin hệ thống.
