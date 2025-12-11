# --- Your existing script starts here ---

    # Servers to check
    $servers = Get-Content "C:\HealthCheck\ServerList.txt" | Where-Object { $_ -ne "" }

    # Email settings (no MFA)
    $smtpServer = "smtp.office365.com"
    $smtpPort   = 587
    $from       = "serverhealth.monitor@intercountyappliance.com"
    $to         = @("pramachandran@intercountyappliance.com", "splimmer@intercountyappliance.com")
    $subject    = "Server Health Alert"
    $smtpUser   = "serverhealth.monitor@intercountyappliance.com"
    $smtpPass   = "10National!"

    # Convert password
    $secure = ConvertTo-SecureString $smtpPass -AsPlainText -Force
    $cred   = New-Object System.Management.Automation.PSCredential ($smtpUser, $secure)

    # Email body
    $body = ""

    # Loop through servers
    foreach ($server in $servers) {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {

            # Disk check
            $disks = Get-CimInstance Win32_LogicalDisk -ComputerName $server -Filter "DriveType=3"
            foreach ($disk in $disks) {
                $free = [math]::Round(($disk.FreeSpace / $disk.Size) * 100,2)
                if ($free -lt 20) {
                    $body += "$server - Drive $($disk.DeviceID) low on space: $free% free.`n"
                }
            }

            # CPU usage
            $cpuLoad = Get-CimInstance Win32_Processor -ComputerName $server | 
               Measure-Object -Property LoadPercentage -Average |
               Select-Object -ExpandProperty Average

            if ($cpuLoad -gt 85) {
                $body += "$server - High CPU usage: $cpuLoad%`n"
            }

            # Memory usage
            $os = Get-CimInstance Win32_OperatingSystem -ComputerName $server
            if ($os) {
                $memUse = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100,2)
                if ($memUse -gt 85) { $body += "$server - High Memory usage: $memUse%`n" }
            }

        } else {
            $body += "$server is OFFLINE or unreachable!`n"
        }
    }

    # Send email if any alerts
    if ($body -ne "") {
        Send-MailMessage `
            -SmtpServer $smtpServer `
            -Port $smtpPort `
            -UseSsl `
            -Credential $cred `
            -From $from `
            -To $to `
            -Subject $subject `
            -Body $body
    }

    # --- Your existing script ends here ---