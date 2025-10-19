# Script chuẩn bị Master Key

$workDir = "C:\RemoteLab-Setup"
$keyName = "remote-lab-master"

Write-Host "`n=== Remote Lab Master Key Setup ===" -ForegroundColor Cyan

# Tạo thư mục làm việc
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
Set-Location $workDir

# Kiểm tra OpenSSH
try {
    ssh -V 2>$null | Out-Null
} catch {
    Write-Host "ERROR: OpenSSH not installed!" -ForegroundColor Red
    Write-Host "Install: Settings > Apps > Optional Features > OpenSSH Client" -ForegroundColor Yellow
    exit 1
}

# Tạo Master Key
Write-Host "`n[1/5] Generating Master Key..." -ForegroundColor Green
ssh-keygen -t ed25519 -f ".\$keyName" -N '""' -C "$keyName-key" | Out-Null

# Tạo cấu trúc .ssh
Write-Host "[2/5] Creating .ssh directory structure..." -ForegroundColor Green
New-Item -ItemType Directory -Path ".\.ssh" -Force | Out-Null
Move-Item ".\$keyName" ".\.ssh\id_ed25519" -Force
Move-Item ".\$keyName.pub" ".\.ssh\id_ed25519.pub" -Force

# Tạo ssh.zip
Write-Host "[3/5] Creating ssh.zip..." -ForegroundColor Green
Compress-Archive -Path ".\.ssh" -DestinationPath ".\ssh.zip" -Force

# Hiển thị public key
Write-Host "[4/5] Public Key generated:" -ForegroundColor Green
Write-Host "`n========================================" -ForegroundColor Yellow
Get-Content ".\.ssh\id_ed25519.pub"
Write-Host "========================================`n" -ForegroundColor Yellow

# Tạo hướng dẫn
$instructions = @"
[5/5] Next Steps:

1. Add the public key above to server:
   ssh remote@103.218.122.188 -p 8030
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   echo "PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys

2. Copy these files to each Lab PC:
   - init.ps1
   - ssh-5985.xml
   - ssh.zip (JUST CREATED)
   - remote-lab-camera.zip

3. Run on each Lab PC:
   .\init.ps1

Files created in: $workDir
"@

Write-Host $instructions -ForegroundColor Cyan

# Mở thư mục
explorer.exe $workDir
