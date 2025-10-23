# 🧪 Test Scripts - Remote Lab Create User Commands

Các script test để gửi lệnh tạo tài khoản từ server Linux đến máy Windows đang chạy Background Service.

## 📁 Files

- `test-create-user.sh` - Bash script với menu tương tác
- `test-create-user.py` - Python script với cả interactive và command-line mode
- `README-test.md` - File hướng dẫn này

## 🚀 Cách sử dụng

### Bash Script (test-create-user.sh)

```bash
# Cấp quyền thực thi
chmod +x test-create-user.sh

# Chạy script
./test-create-user.sh
```

**Menu options:**
1. Tạo user thường
2. Tạo admin user  
3. Kiểm tra trạng thái server
4. Test với dữ liệu mẫu
5. Thoát

### Python Script (test-create-user.py)

#### Interactive Mode:
```bash
python3 test-create-user.py
```

#### Command Line Mode:
```bash
# Test với dữ liệu mẫu
python3 test-create-user.py test

# Tạo user thường
python3 test-create-user.py user <username> <password>

# Tạo admin user
python3 test-create-user.py admin <username> <password>

# Kiểm tra server
python3 test-create-user.py status
```

## 📋 Dependencies

### Bash Script:
- `curl` - Để gửi HTTP requests
- `jq` - Để format JSON (optional)

```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq
```

### Python Script:
- `requests` - Để gửi HTTP requests

```bash
pip3 install requests
```

## 🔧 Cấu hình

Scripts sử dụng API endpoint: `http://103.218.122.188:8000/api/commands`

Để thay đổi server, sửa biến `API_ENDPOINT` trong các file script.

## 📊 Các loại lệnh được hỗ trợ

### 1. create_user
```json
{
    "action": "create_user",
    "username": "testuser",
    "password": "TestPass123!"
}
```

### 2. create_admin_user
```json
{
    "action": "create_admin_user", 
    "username": "testadmin",
    "password": "AdminPass123!"
}
```

## 🎯 Test Cases

### Test 1: Tạo user thường
- Username: `testuser`
- Password: `TestPass123!`

### Test 2: Tạo admin user
- Username: `testadmin` 
- Password: `AdminPass123!`

## 📝 Log Monitoring

Để theo dõi kết quả trên máy Windows:

```powershell
# Xem log realtime
Get-Content "$env:USERPROFILE\Desktop\RemoteLabSetup.log" -Wait -Tail 10

# Xem log cuối cùng
Get-Content "$env:USERPROFILE\Desktop\RemoteLabSetup.log" -Tail 20
```

## ✅ Expected Results

Khi lệnh được gửi thành công, bạn sẽ thấy trong log Windows:

```
[2025-10-23 10:30:00] Found 1 server commands, executing...
[2025-10-23 10:30:00] Executing server command: create_user
[2025-10-23 10:30:00] Creating user testuser...
[2025-10-23 10:30:01] User 'testuser' does not exist, creating user...
[2025-10-23 10:30:01] User created successfully
```

## 🚨 Troubleshooting

### Lỗi kết nối:
- Kiểm tra server có đang chạy không
- Kiểm tra firewall và network
- Test với: `curl http://103.218.122.188:8000/api/commands`

### Lỗi authentication:
- Đảm bảo máy Windows đang chạy Background Service
- Kiểm tra log file để xem lệnh có được nhận không

### Lỗi tạo user:
- Kiểm tra quyền admin trên máy Windows
- Xem chi tiết lỗi trong log file

## 📞 Support

Nếu gặp vấn đề:
1. Kiểm tra log file trên máy Windows
2. Test kết nối server trước
3. Đảm bảo Background Service đang chạy
4. Kiểm tra quyền admin trên máy Windows
