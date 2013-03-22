<#
    Author: Michael West
    Blog: http://michaellwest.blogspot.com/
    Date: 03.21.2013
#>

Import-Module WebAdministration

Write-Verbose -Message "Add the json mimeType"
Add-WebConfigurationProperty //staticContent -Name collection -Value @{fileExtension='.json';mimeType='application/json'}

Write-Verbose -Message "Add the less mimeType"
Add-WebConfigurationProperty //staticContent -Name collection -Value @{fileExtension='.less';mimeType='text/less'}

Write-Verbose -Message "Add the font mimeType"
Add-WebConfigurationProperty //staticContent -Name collection -Value @{fileExtension='.woff';mimeType='application/x-font-woff'}

Add-WebConfigurationProperty //httpCompression/dynamicTypes -Name collection -Value @{mimeType='application/json';enabled='True'}
Add-WebConfigurationProperty //httpCompression/dynamicTypes -Name collection -Value @{mimeType='application/json; charset=UTF-8';enabled='True'}
Add-WebConfigurationProperty //httpCompression/staticTypes -Name collection -Value @{mimeType='application/json';enabled='True'}
Add-WebConfigurationProperty //httpCompression/staticTypes -Name collection -Value @{mimeType='application/json; charset=UTF-8';enabled='True'}