<#
    Author: Michael West
    Blog: http://michaellwest.blogspot.com/
    Date: 03.21.2013
#>

$ScriptBlock = {

    #Requires -Version 2

    Import-Module -Name WebAdministration
    #Import-Module -Name FileSystem

    function Write-Message {
        [CmdletBinding()]
        param(
	        [string]$Message=$(throw "Message parameter required"),
            [string]$Group
        ) 
        [string]$output = "[$(Get-Date) $($ENV:COMPUTERNAME)] "
        if ($Group) {
            $output += "$($Group): "
        }
        $output += "$($Message)"
        Write-Verbose -Message $output
    }

    function Install-WebApplication {
        <#
        .SYNOPSIS
            Installs a new or updated IIS Web Application.

        .DESCRIPTION
            Installs a new or updated IIS Web Application. If the Site parameter is not specified, 
            the Default Web Site will be used.

        .PARAMETER Site
            The name of the site on which the application is created.

        .PARAMETER Name
            The name of the web application to create or update.

        .PARAMETER Destination
            The physical path to the Web application files.

        .PARAMETER ApplicationPool
            The name of the application pool in which the new Web application executes.

        .EXAMPLE
            Install-WebApplication -Name "DEMO-DEV" -Path "C:\temp\Builds\Demo-DEV" -ApplicationPool "DEMO-DEV"
        #>
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$Site="Default Web Site",

            [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true, HelpMessage="Enter the name of the application.")]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$ApplicationPool
        )
    
        [string]$root = "C:\inetpub\wwwroot"
        [string]$backup = "$($root)\ApplicationBackup"
        [string]$destination = "$($root)\$($Name)"

        if (-not (Test-Path -Path "IIS:\AppPools\$($ApplicationPool)")) {
            Write-Message -Message "Creating $($ApplicationPool)" -Group "AppPool"
            New-WebAppPool -Name $ApplicationPool
            #Set-ItemProperty -Path "IIS:\AppPools\$($ApplicationPool)" -Name "ProcessModel" -Value @{ IdentityType="SpecificUser";Username="domain\service.web";Password="password";}
            Set-ItemProperty -Path "IIS:\AppPools\$($ApplicationPool)" -Name "ManagedRuntimeVersion" -Value "v4.0"
        } else {
           Write-Message -Message "$($ApplicationPool) exists" -Group "AppPool"
        }

        if ((Get-WebAppPoolState -Name $ApplicationPool).Value -ne "Stopped") {
            Write-Message -Message "Stopping $($ApplicationPool)" -Group "AppPool"
            while((Get-WebAppPoolState -Name $ApplicationPool).Value -ne "Stopped") {
	    	Stop-WebAppPool -Name $ApplicationPool
		Start-Sleep -Seconds 2
	    }
        } else {
            Write-Message -Message "$($ApplicationPool) stopped" -Group "AppPool"
        }

        if (Test-Path $destination) {
            Write-Message -Message "Skip creating $($destination)" -Group "Application"
            <#
            [string]$date = (Get-Date -Format "yyyyMMdd")
            if (-not (Test-Path $backup)) {
                Write-Message -Message "Creating $($backup)" -Group "Backup"
                New-Item -Path $backup -ItemType directory
            }
            [string]$zip = "$($backup)\$($Name)-$($date).zip"
            if (Test-Path $zip) {
                Write-Message -Message "Removing $($zip)" -Group "Backup"
                Remove-Item -Path $zip
            }
            Write-Message -Message "Creating $($zip)" -Group "Backup"
            Copy-ToZip -File $Destination -ZipFile $zip
            #>
            Remove-Item -Path $destination -Recurse -Force
        }

        Copy-Item -Path $Path -Destination $root -Recurse -Force

        if ((Get-WebApplication -Name $Name) -eq $null) {
            Write-Message -Message "Creating $($Name)" -Group "Application"
            New-WebApplication -Site $Site -Name $Name -PhysicalPath $destination -ApplicationPool $ApplicationPool
        } else {
            Write-Message -Message "$($Name) exists" -Group "Application"
        }

        Write-Message -Message "Starting $($ApplicationPool)" -Group "AppPool"
        $startCount = 0
        do {
            Start-WebAppPool -Name $ApplicationPool -ErrorAction SilentlyContinue
            $status = (Get-WebAppPoolState -Name $ApplicationPool).Value
            Write-Message -Message "Application Pool status $($status)" -Group "AppPool"
            $startCount += 1
            Start-Sleep -Seconds 2
        } while(($status -ne 'Running' -and $status -ne 'Started') -and $startCount -lt 10)

        $body = "The build for $($Name) completed successfully."
        $subject = "$($Name) Deployment Completed On $($Env:COMPUTERNAME) - EOM"
        if ($startCount -lt 10) {
            Write-Message -Message "Deployment completed successfully"
        } else {
            Write-Message -Message "Deployment failed"
            $body = "The build for $($Name) failed."
            $subject = "$($Name) Deployment Failed On $($Env:COMPUTERNAME) - EOM"
        }
        
        $props = @{
            To='Michael.West@nonexistenturl.com'
            From='Development Team <development@nonexistenturl.com>'
            Subject=$subject
            SmtpServer='mail.nonexistenturl.com'
            Body=$body
        }
        #Send-MailMessage @props
    }
}

function Publish-WebApplication {
    <#
        .SYNOPSIS
            Publishes an application to remote servers.

        .DESCRIPTION
            Publishes an application to remote servers. A new application and application pool are created if they do not exist.

        .EXAMPLE
            Publish-WebApplication -ComputerName "web01","web02" -Name "Demo" -Path "C:\Inetpub\wwwroot\Demo\" -ApplicationPool "Demo"
    #>
    [CmdletBinding()]
    param(
	    [string[]]$ComputerName=$(throw "ComputerName parameter required"),
        [string]$Name=$(throw "Name parameter required"),
	    [string]$Path=$(throw "Path parameter required"),
        [string]$ApplicationPool=$(throw "ApplicationPool parameter required"),
        [switch]$Browse
    ) 

    Write-Verbose -Message "Preparing new session"
    $session = New-PSSession -ComputerName $ComputerName

    try {
        foreach ($computer in $ComputerName) {
            # Holding directory for the application code before executing script on remote server.
            $buildsPath = "\\$($computer)\C$\Builds\"
            # Create build directory if it is missing.
            if (-not (Test-Path -Path $buildsPath)) {
                Write-Verbose -Message "Creating $($buildsPath)"
                New-Item -Path $buildsPath -ItemType directory
            }
            # Remove the application directory if it exists.
            if (Test-Path -Path $($buildsPath + $Name)) {
                Write-Verbose -Message "Removing $($buildsPath)$($Name)"
                Remove-Item -Path "$($buildsPath)$($Name)" -Recurse
            }
            Write-Verbose -Message "Copying $($Path) to $($buildsPath)"
            Copy-Item -Path $Path -Destination "$($buildsPath)" -Recurse
        }

        $buildPath = "C:\Builds\$($Name)"
    
        Invoke-Command -Session $session -ScriptBlock $ScriptBlock -Verbose
        Invoke-Command -Session $session -ScriptBlock { 
                param($Name,$buildPath,$ApplicationPool)
                Write-Verbose -Message "Beginning the installation process."
                Install-WebApplication -Name $Name -Path $buildPath -ApplicationPool $ApplicationPool -Verbose 
            } -ArgumentList $Name, $buildPath, $ApplicationPool
    
    } catch {
        $Error
    }
    Remove-PSSession -Session $session
    if ($Browse) {	
        foreach ($computer in $ComputerName) {
            Start-Process iexplore.exe "http://$($computer)/$($Name)"
        }
    }
}
