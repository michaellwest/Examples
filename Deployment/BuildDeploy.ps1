<#
    Author: Michael West
    Blog: http://michaellwest.blogspot.com/
    Date: 03.21.2013
#>

#http://msdn.microsoft.com/en-us/library/ms164311(v=vs.90).aspx

param([string]$name="",[string]$project="",[string]$buildscript,[string]$server,[switch]$publish)

$msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"
$currentDirectory = (Split-Path -Path $Script:MyInvocation.MyCommand.Path)
			
Write-Host "Building $($name)"
(& $msbuild $buildscript /property:Name=$name /property:Project=$project /nologo /verbosity:n)
			
if ($publish) {
	Write-Host "Publishing the build"
	(& { 
        . (Join-Path -Path $currentDirectory -ChildPath "PublishApplication.ps1")
        Publish-WebApplication -ComputerName $server -Name "$Name" -Path "C:\Inetpub\wwwroot\$Project\Build\$Name" -ApplicationPool "$Name" -Verbose
    })
}