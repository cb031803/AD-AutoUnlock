# Script to find locked accounts in Employees OU and unlock them.

param (
    [string]$SearchBase = "OU=Employees,DC=domain,DC=org",             # Put in your domain information and which OU the accounts are in it needs to scan. YOU NEED TO CHANGE THESE
    [string]$LogFilePath = "C:\Logs\UnlockAccounts.log",                          # Were do you want the userlog to be located. (Tells which accounts and time they where unlocked.
    [int]$ScanIntervalSeconds = 300 # 5 minutes
)

$script:ScanCount = 0
$script:NextScanTime = Get-Date

# Ensure the log directory exists
if (!(Test-Path -Path (Split-Path $LogFilePath) -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path (Split-Path $LogFilePath) | Out-Null
    }
    catch {
        Write-Error "Failed to create log directory: $($_.Exception.Message)"
        return # Exit if log directory creation fails.
    }
}

function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    try {
        Add-Content -Path $LogFilePath -Value $LogEntry -ErrorAction Stop
    }
    catch {
        Write-Host "Error writing to log file: $($_.Exception.Message)"
        Write-Host "Log message: $LogEntry"
    }
}

function Unlock-LockedAccounts {
    $script:ScanCount++
    $CurrentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $unlockedAccounts = @()

    try {
        $users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties LockedOut
        if ($users) {
            foreach ($user in $users) {
                Write-Host "[$CurrentTime] Checking account: $($user.SamAccountName)"
                if ($user.LockedOut) {
                    Write-Host "[$CurrentTime] Account $($user.SamAccountName) is locked. Unlocking..."
                    Unlock-ADAccount -Identity $user.SamAccountName -ErrorAction SilentlyContinue
                    if ($?) {
                        Write-Host "[$CurrentTime] Account $($user.SamAccountName) unlocked successfully."
                        $unlockedAccounts += $user.SamAccountName
                    } else {
                        Write-Host "[$CurrentTime] Failed to unlock account $($user.SamAccountName)."
                    }
                } else {
                    Write-Host "[$CurrentTime] Account $($user.SamAccountName) is not locked."
                }
            }
        }
        if ($unlockedAccounts.Count -gt 0) {
            Write-Log "Unlocked $($unlockedAccounts.Count) accounts: $($unlockedAccounts -join ', ')"
            Write-Host "[$CurrentTime] Unlocked $($unlockedAccounts.Count) accounts: $($unlockedAccounts -join ', ')"
        } else {
            Write-Host "[$CurrentTime] No accounts unlocked this scan."
        }
    } catch {
        Write-Log "An error occurred: $($_.Exception.Message)"
        Write-Host "[$CurrentTime] An error occurred: $($_.Exception.Message)"
    }
    $script:NextScanTime = (Get-Date).AddSeconds($ScanIntervalSeconds)
}

# Initial run
Unlock-LockedAccounts

# Loop every ScanIntervalSeconds
while ($true) {
    $RemainingSeconds = ($script:NextScanTime - (Get-Date)).TotalSeconds
    if ($RemainingSeconds -gt 0) {
        Write-Host "Next scan in $($RemainingSeconds.ToString('F0')) seconds. Scan count: $($script:ScanCount)"
        if($RemainingSeconds -gt 1){
            Start-Sleep -Seconds ($RemainingSeconds - 1)
        }
    } else {
        Unlock-LockedAccounts
    }
}