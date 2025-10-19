# script to init Remote Lab PC
# Can run in background mode when executed as scheduled task

param(
    [switch]$BackgroundMode = $false,
    [string]$LogPath = "$env:USERPROFILE\Desktop\RemoteLabSetup.log",
    [string]$ServerCommand = "",
    [string]$ServerUrl = "http://103.218.122.188:8000/api/commands",
    [int]$PollInterval = 30
)

# Function to write log with timestamp (only in background mode)
function Write-Log {
    param([string]$Message)
    if ($BackgroundMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        Write-Output $logMessage
        Add-Content -Path $LogPath -Value $logMessage
    } else {
        Write-Output $Message
    }
}

# Function to get commands from server
function Get-ServerCommands {
    try {
        $response = Invoke-RestMethod -Uri $ServerUrl -Method GET -TimeoutSec 10
        
        # Validate response structure
        if ($null -eq $response) {
            Write-Log "Server returned null response"
            return $null
        }
        
        # Check if response is an array or single object
        if ($response -is [array]) {
            Write-Log "Server returned array of $($response.Count) commands"
            return $response
        } elseif ($response -is [object]) {
            # If it's a single object, check if it has action property
            if ($response.action) {
                Write-Log "Server returned single command"
                return @($response)
            } else {
                Write-Log "Server returned object without action property: $($response | ConvertTo-Json -Depth 3)"
                return $null
            }
        } else {
            Write-Log "Server returned unexpected response type: $($response.GetType().Name)"
            Write-Log "Response content: $($response | ConvertTo-Json -Depth 3)"
            return $null
        }
    } catch {
        Write-Log "Failed to get commands from server: $($_.Exception.Message)"
        return $null
    }
}

# Function to get admin credentials from server
function Get-AdminCredentials {
    try {
        $response = Invoke-RestMethod -Uri "http://103.218.122.188:8000/api/admin-credentials" -Method GET -TimeoutSec 10
        
        if ($null -eq $response) {
            Write-Log "Server returned null response for admin credentials"
            return $null
        }
        
        if ($response.username -and $response.password) {
            Write-Log "✅ Retrieved admin credentials from server: $($response.username)"
            return @{
                username = $response.username
                password = $response.password
            }
        } else {
            Write-Log "Server response missing username or password: $($response | ConvertTo-Json -Depth 2)"
            return $null
        }
    } catch {
        Write-Log "Failed to get admin credentials from server: $($_.Exception.Message)"
        return $null
    }
}

# Function to send status to server
function Send-StatusToServer {
    param(
        [string]$Status,
        [string]$Message = ""
    )
    try {
        $body = @{
            status = $Status
            message = $Message
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            computer = $env:COMPUTERNAME
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "http://103.218.122.188:8000/api/commands/status" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10
    } catch {
        Write-Log "Failed to send status to server: $($_.Exception.Message)"
    }
}

# Function to execute server commands
function Execute-ServerCommand {
    param([object]$Command)
    
    # Check if Command is null or doesn't have required properties
    if ($null -eq $Command -or $null -eq $Command.action) {
        Write-Log "ERROR: Invalid command received from server. Command is null or missing action property."
        Write-Log "Command object: $($Command | ConvertTo-Json -Depth 3)"
        return
    }
    
    Write-Log "Executing server command: $($Command.action)"
    
    switch ($Command.action.ToLower()) {
        "create_user" {
            Create-User -userName $Command.username -password $Command.password
            Send-StatusToServer -Status "completed" -Message "User $($Command.username) created successfully"
        }
        "enable_rdp" {
            Enable-Remote-Desktop
            Send-StatusToServer -Status "completed" -Message "Remote Desktop enabled"
        }
        "enable_powershell_remoting" {
            Enable-PowerShell-Remoting
            Send-StatusToServer -Status "completed" -Message "PowerShell Remoting enabled"
        }
        "setup_ssh_tunnel" {
            Import-Task-SSH-5985 -userName $Command.username -password $Command.password
            Send-StatusToServer -Status "completed" -Message "SSH tunnel task created"
        }
        "install_software" {
            switch ($Command.software.ToLower()) {
                "vscode" { Install-VSCode }
                "arduino" { Install-Arduino }
                "camera" { Install-Camera }
            }
            Send-StatusToServer -Status "completed" -Message "Software $($Command.software) installed"
        }
        "extract_ssh_keys" {
            Extract-SSH-Key
            Send-StatusToServer -Status "completed" -Message "SSH keys extracted"
        }
        "custom_command" {
            try {
                Invoke-Expression $Command.command
                Send-StatusToServer -Status "completed" -Message "Custom command executed: $($Command.command)"
            } catch {
                Send-StatusToServer -Status "error" -Message "Custom command failed: $($_.Exception.Message)"
            }
        }
        "register_computer" {
            $registrationSuccess = Register-ComputerToServer
            if ($registrationSuccess) {
                Send-StatusToServer -Status "completed" -Message "Computer registered successfully"
            } else {
                Send-StatusToServer -Status "error" -Message "Computer registration failed"
            }
        }
        "create_admin_user" {
            if ($Command.username -and $Command.password) {
                Create-User -userName $Command.username -password $Command.password
                Send-StatusToServer -Status "completed" -Message "Admin user $($Command.username) created successfully"
            } else {
                Write-Log "ERROR: create_admin_user command missing username or password"
                Send-StatusToServer -Status "error" -Message "create_admin_user command missing username or password"
            }
        }
        default {
            Write-Log "Unknown command: $($Command.action)"
            Send-StatusToServer -Status "error" -Message "Unknown command: $($Command.action)"
        }
    }
}

function Download-File {
    param(
        [string]$downloadUrl,
        [string]$destinationPath
    )
    Write-Log "Downloading file from $downloadUrl..."
	$progressPreference = 'SilentlyContinue' # for fixing slow download issue
    Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -UseBasicParsing
    Write-Log "Download completed."
}

function Create-Shortcut {
    param(
        [string]$shortcutPath,
        [string]$targetPath
    )
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Save()
}

function Install-VSCode {
	Write-Log "Installing Visual Studio Code..."

	# Define the download URL and paths
	$downloadUrl  = "https://update.code.visualstudio.com/latest/win32-x64/stable"
	$destinationPath = "$env:USERPROFILE\Downloads\VSCodeSetup.exe"
	Download-File -downloadUrl $downloadUrl -destinationPath $destinationPath

	# Install Visual Studio Code silently
	Write-Log "Installing Visual Studio Code..."
	Start-Process -FilePath $destinationPath -ArgumentList "/silent" -NoNewWindow -Wait

	# Remove the downloaded file
	Write-Log "Removing downloaded file..."
	Remove-Item -Path $destinationPath -Force

	# Create shortcuts for all users
	Write-Log "Creating shortcuts..."
	$shortcutPathDesktop = "$env:PUBLIC\Desktop\Visual Studio Code.lnk"
	$shortcutPathStartMenu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Visual Studio Code.lnk"
	$exePath = "C:\Program Files\Microsoft VS Code\Code.exe"

	Create-Shortcut -shortcutPath $shortcutPathDesktop -targetPath $exePath
	Create-Shortcut -shortcutPath $shortcutPathStartMenu -targetPath $exePath

	Write-Log "Visual Studio Code installed successfully."
}

function Install-Arduino {
	Write-Log "Installing Arduino IDE..."

	# Define the download URL and paths
	$downloadUrl = "https://downloads.arduino.cc/arduino-ide/arduino-ide_latest_Windows_64bit.zip"
	$destinationPath = "$env:USERPROFILE\Downloads\arduino-ide-latest.zip"
	$installPath = "C:\Program Files\Arduino"

	# Download the Arduino ZIP file
	Write-Log "Downloading Arduino IDE..."
	Download-File -downloadUrl $downloadUrl -destinationPath $destinationPath

	# Extract the ZIP to C:\Program Files
	Write-Log "Extracting Arduino IDE..."
	Expand-Archive -Path $destinationPath -DestinationPath $installPath -Force

	# Remove the downloaded file
	Write-Log "Removing downloaded file..."
	Remove-Item -Path $destinationPath -Force

	# Create shortcuts for all users
	Write-Log "Creating shortcuts..."
	$shortcutPathDesktop = "$env:PUBLIC\Desktop\Arduino IDE.lnk"
	$shortcutPathStartMenu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Arduino IDE.lnk"
	$exePath = "$installPath\Arduino IDE.exe"

	Create-Shortcut -shortcutPath $shortcutPathDesktop -targetPath $exePath
	Create-Shortcut -shortcutPath $shortcutPathStartMenu -targetPath $exePath

	Write-Log "Arduino IDE installed system-wide successfully."

	# Note: Arduino IDE will not auto-open when running in background mode
	Write-Log "Arduino IDE installation completed. (Auto-launch disabled for background mode)"
}

function Install-Camera {
	$destinationPath = ".\remote-lab-camera.zip"
	$installPath = "C:\Program Files\remote-lab-camera"

	# Extract the ZIP to C:\Program Files
	Write-Log "Extracting Camera Viewer..."
	Expand-Archive -Path $destinationPath -DestinationPath $installPath -Force

	# Create shortcuts for all users
	Write-Log "Creating shortcuts..."
	$shortcutPathDesktop = "$env:PUBLIC\Desktop\Camera Viewer.lnk"
	$shortcutPathStartMenu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Camera Viewer.lnk"
	$exePath = "$installPath\remote-lab-camera\remote-lab-camera.exe"

	Create-Shortcut -shortcutPath $shortcutPathDesktop -targetPath $exePath
	Create-Shortcut -shortcutPath $shortcutPathStartMenu -targetPath $exePath

	Write-Log "Camera Viewer installed system-wide successfully."

	# Note: Camera Viewer will not auto-open when running in background mode
	Write-Log "Camera Viewer installation completed. (Auto-launch disabled for background mode)"
}

function Create-User {
    param(
        [string]$userName,
        [string]$password
    )

	$secureStr = ConvertTo-SecureString $password -AsPlainText -Force

	Write-Log "Creating user $userName..."

	if (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue) {
		Write-Log "User '$userName' exists, updating password..."
		Set-LocalUser -Name $userName -Password $secureStr
	} else {
		Write-Log "User '$userName' does not exist, creating user..."
		New-LocalUser -Name $userName -Password $secureStr -FullName "Administrator" -Description "Admin User" -AccountNeverExpires
		Add-LocalGroupMember -Group "Administrators" -Member $userName
	}
}

function Enable-Remote-Desktop {
	Write-Log "Enabling Remote Desktop..."

	# Enable Remote Desktop
	Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
	Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

function Enable-PowerShell-Remoting {
	Write-Log "Enabling PowerShell Remoting..."

	# Enable PowerShell Remoting
	Enable-PSRemoting -Force
}

function Extract-SSH-Key {
	$filePath = ".\ssh.zip"
	$extractPath = "C:\Users\Admin\"
	Write-Log "Extracting SSH Keys..."
	Expand-Archive -Path $filePath -DestinationPath $extractPath -Force
	Remove-Item $filePath -Force
	Write-Log "SSH Keys extracted successfully."
}

function Import-Task-SSH-5985 {
    param(
        [string]$userName,
        [string]$password
    )
	Write-Log "Importing Task SSH-5985..."
	schtasks /create /tn "ssh-5985" /xml ".\ssh-5985.xml" /ru $userName /rp $password
	Write-Log "SSH Task imported successfully."
}

# Function to get computer information
function Get-ComputerInfo {
    try {
        $computerName = $env:COMPUTERNAME
        $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
        
        # Get default RDP port (3389)
        $rdpPort = 3389
        
        # Get WinRM port (5985)
        $winrmPort = 5985
        
        # Try to get actual WinRM port from registry
        try {
            $winrmPort = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Listener\Listener_*" -Name Port -ErrorAction SilentlyContinue | Select-Object -First 1).Port
            if (-not $winrmPort) { $winrmPort = 5985 }
        } catch {
            $winrmPort = 5985
        }
        
        return @{
            name = $computerName
            ip_address = $ipAddress
            nat_port_rdp = $rdpPort
            nat_port_winrm = $winrmPort
            description = "Remote Lab PC - $computerName"
        }
    } catch {
        Write-Log "Error getting computer info: $($_.Exception.Message)"
        return $null
    }
}

# Function to register computer to server with retry logic
function Register-ComputerToServer {
    param(
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Log "Collecting computer information (Attempt $attempt/$MaxRetries)..."
            $computerInfo = Get-ComputerInfo
            
            if (-not $computerInfo) {
                Write-Log "Failed to collect computer information"
                if ($attempt -eq $MaxRetries) { return $false }
                Start-Sleep -Seconds $RetryDelay
                continue
            }
            
            Write-Log "Computer Info: $($computerInfo | ConvertTo-Json)"
            
            # Prepare registration data
            $registrationData = @{
                name = $computerInfo.name
                description = $computerInfo.description
                ip_address = $computerInfo.ip_address
                natPortRdp = $computerInfo.nat_port_rdp
                natPortWinRm = $computerInfo.nat_port_winrm
            } | ConvertTo-Json -Depth 3
            
            Write-Log "Registering computer to server (Attempt $attempt/$MaxRetries)..."
            Write-Log "Registration data: $registrationData"
            
            # Send registration request to server
            $response = Invoke-RestMethod -Uri "http://103.218.122.188:8000/api/computer/register" -Method POST -Body $registrationData -ContentType "application/json" -TimeoutSec 30
            
            if ($response.status -eq "success") {
                Write-Log "✅ Computer registered successfully: $($response.message)"
                Write-Log "Computer ID: $($response.data.id)"
                return $true
            } else {
                Write-Log "❌ Registration failed: $($response.message)"
                if ($attempt -eq $MaxRetries) { return $false }
                Write-Log "Retrying in $RetryDelay seconds..."
                Start-Sleep -Seconds $RetryDelay
            }
        } catch {
            Write-Log "❌ Error registering computer (Attempt $attempt/$MaxRetries): $($_.Exception.Message)"
            if ($attempt -eq $MaxRetries) { 
                Write-Log "❌ All registration attempts failed"
                return $false 
            }
            Write-Log "Retrying in $RetryDelay seconds..."
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    return $false
}

# Main execution with error handling
try {
    Write-Log "Starting Remote Lab Setup..."
    if ($BackgroundMode) {
        Write-Log "Running in background mode. Log file: $LogPath"
    }

    # Send initial status to server
    Send-StatusToServer -Status "started" -Message "Remote Lab Setup started"

    # Check if running in server command mode
    if ($ServerCommand -ne "") {
        Write-Log "Running in server command mode: $ServerCommand"
        
        # Parse and execute single command
        $command = @{
            action = $ServerCommand
            username = "remotelab"
            password = "0084"
        }
        Execute-ServerCommand -Command $command
        
    } else {
        if ($BackgroundMode) {
            # Background mode - continuous polling for server commands
            Write-Log "Starting background service mode with $PollInterval second intervals..."
            Write-Log "Press Ctrl+C to stop the service"
            
            $lastRunTime = Get-Date
            $isFirstRun = $true
            
            while ($true) {
                try {
                    $currentTime = Get-Date
                    $timeSinceLastRun = ($currentTime - $lastRunTime).TotalSeconds
                    
                    Write-Log "Checking for server commands... (Last run: $timeSinceLastRun seconds ago)"
                    $serverCommands = Get-ServerCommands
                    
                    if ($serverCommands -and $serverCommands.Count -gt 0) {
                        Write-Log "Found $($serverCommands.Count) server commands, executing..."
                        foreach ($command in $serverCommands) {
                            # Validate each command before executing
                            if ($command -and ($command -is [object]) -and $command.action) {
                                Execute-ServerCommand -Command $command
                            } else {
                                Write-Log "WARNING: Skipping invalid command: $($command | ConvertTo-Json -Depth 3)"
                            }
                        }
                        $lastRunTime = Get-Date
                    } elseif ($isFirstRun) {
                        # Only run default setup on first run
                        Write-Log "No server commands found, running initial setup..."
                        
                        # Try to get admin credentials from server first
                        Write-Log "Attempting to get admin credentials from server..."
                        $adminCredentials = Get-AdminCredentials
                        
                        if ($adminCredentials) {
                            $adminUser = $adminCredentials.username
                            $adminPassword = $adminCredentials.password
                            Write-Log "✅ Using admin credentials from server: $adminUser"
                        } else {
                            # Fallback to default credentials if server is unavailable
                            $adminUser = "Admin"
                            $adminPassword = "lhu@B304"
                            Write-Log "⚠️ Server unavailable, using default credentials: $adminUser"
                        }
                        
                        Write-Log "Creating admin user..."
                        Create-User -userName $adminUser -password $adminPassword
                        
                        Write-Log "Enabling Remote Desktop..."
                        Enable-Remote-Desktop
                        
                        Write-Log "Enabling PowerShell Remoting..."
                        Enable-PowerShell-Remoting
                        
                        Write-Log "Extracting SSH Keys..."
                        Extract-SSH-Key
                        
                        Write-Log "Importing SSH Task..."
                        Import-Task-SSH-5985 -userName $adminUser -password $adminPassword
                        
                        Write-Log "Installing Camera Viewer..."
                        Install-Camera
                        
                        Write-Log "Installing Visual Studio Code..."
                        Install-VSCode
                        
                        Write-Log "Installing Arduino IDE..."
                        Install-Arduino
                        
                        # Register computer to server after initial setup
                        Write-Log "Registering computer to server..."
                        $registrationSuccess = Register-ComputerToServer
                        if ($registrationSuccess) {
                            Write-Log "✅ Computer registration completed successfully"
                        } else {
                            Write-Log "⚠️ Computer registration failed, but continuing setup..."
                        }
                        
                        $isFirstRun = $false
                        $lastRunTime = Get-Date
                    } else {
                        Write-Log "No new commands from server. Waiting $PollInterval seconds..."
                    }
                    
                    # Wait for the specified interval
                    Start-Sleep -Seconds $PollInterval
                    
                } catch {
                    Write-Log "ERROR in background loop: $($_.Exception.Message)"
                    Write-Log "Continuing after $PollInterval seconds..."
                    Start-Sleep -Seconds $PollInterval
                }
            }
        } else {
            # Single execution mode - check for server commands once
            Write-Log "Checking for server commands..."
            $serverCommands = Get-ServerCommands
            
            if ($serverCommands -and $serverCommands.Count -gt 0) {
                Write-Log "Found $($serverCommands.Count) server commands, executing..."
                foreach ($command in $serverCommands) {
                    # Validate each command before executing
                    if ($command -and ($command -is [object]) -and $command.action) {
                        Execute-ServerCommand -Command $command
                    } else {
                        Write-Log "WARNING: Skipping invalid command: $($command | ConvertTo-Json -Depth 3)"
                    }
                }
            } else {
                # Fallback to default setup
                Write-Log "No server commands found, running default setup..."
                
                # Try to get admin credentials from server first
                Write-Log "Attempting to get admin credentials from server..."
                $adminCredentials = Get-AdminCredentials
                
                if ($adminCredentials) {
                    $adminUser = $adminCredentials.username
                    $adminPassword = $adminCredentials.password
                    Write-Log "✅ Using admin credentials from server: $adminUser"
                } else {
                    # Fallback to default credentials if server is unavailable
                    $adminUser = "Admin"
                    $adminPassword = "lhu@B304"
                    Write-Log "⚠️ Server unavailable, using default credentials: $adminUser"
                }
                
                Write-Log "Creating admin user..."
                Create-User -userName $adminUser -password $adminPassword
                
                Write-Log "Enabling Remote Desktop..."
                Enable-Remote-Desktop
                
                Write-Log "Enabling PowerShell Remoting..."
                Enable-PowerShell-Remoting
                
                Write-Log "Extracting SSH Keys..."
                Extract-SSH-Key
                
                Write-Log "Importing SSH Task..."
                Import-Task-SSH-5985 -userName $adminUser -password $adminPassword
                
                Write-Log "Installing Camera Viewer..."
                Install-Camera
                
                Write-Log "Installing Visual Studio Code..."
                Install-VSCode
                
                Write-Log "Installing Arduino IDE..."
                Install-Arduino
                
                # Register computer to server after setup
                Write-Log "Registering computer to server..."
                $registrationSuccess = Register-ComputerToServer
                if ($registrationSuccess) {
                    Write-Log "✅ Computer registration completed successfully"
                } else {
                    Write-Log "⚠️ Computer registration failed, but continuing setup..."
                }
            }
        }
    }
    
    Write-Log "Remote Lab Setup completed successfully!"
    Send-StatusToServer -Status "completed" -Message "Remote Lab Setup completed successfully"
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    Send-StatusToServer -Status "error" -Message "Setup failed: $($_.Exception.Message)"
    
    if ($BackgroundMode) {
        exit 1
    } else {
        throw
    }
}

Write-Log "Script execution finished."