#AzureVnetExtras.ps1
Set-StrictMode -Version 4

#CommandType     Name                                               Version    Source                                                                                                           
#-----------     ----                                               -------    ------                                                                                                           
#Cmdlet          Get-AzureVNetConfig                                0.8.11     Azure                                                                                                            
#Cmdlet          Get-AzureVNetConnection                            0.8.11     Azure                                                                                                            
#Cmdlet          Get-AzureVNetGateway                               0.8.11     Azure                                                                                                            
#Cmdlet          Get-AzureVNetGatewayDiagnostics                    0.8.11     Azure                                                                                                            
#Cmdlet          Get-AzureVNetGatewayKey                            0.8.11     Azure                                                                                                            
#Cmdlet          Get-AzureVNetSite                                  0.8.11     Azure                                                                                                            
#Cmdlet          New-AzureVNetGateway                               0.8.11     Azure                                                                                                            
#Cmdlet          Remove-AzureVNetConfig                             0.8.11     Azure                                                                                                            
#Cmdlet          Remove-AzureVNetGateway                            0.8.11     Azure                                                                                                            
#Cmdlet          Remove-AzureVNetGatewayDefaultSite                 0.8.11     Azure                                                                                                            
#Cmdlet          Resize-AzureVNetGateway                            0.8.11     Azure                                                                                                            
#Cmdlet          Set-AzureVNetConfig                                0.8.11     Azure                                                                                                            
#Cmdlet          Set-AzureVNetGateway                               0.8.11     Azure                                                                                                            
#Cmdlet          Set-AzureVNetGatewayDefaultSite                    0.8.11     Azure                                                                                                            
#Cmdlet          Set-AzureVNetGatewayKey                            0.8.11     Azure                                                                                                            
#Cmdlet          Start-AzureVNetGatewayDiagnostics                  0.8.11     Azure                                                                                                            
#Cmdlet          Stop-AzureVNetGatewayDiagnostics                   0.8.11     Azure  

           
#### New-AzureVnetConfig
#### Export-AzureVnetConfig
####
#### Get-AzureVnetVirtualNetworkSite 
#### Set-AzureVnetVirtualNetworkSite
#### New-AzureVnetVirtualNetworkSite
#### Remove-AzureVnetVirtualNetworkSite
####
#### Get-AzureVnetLocalNetworkSite    
#### Set-AzureVnetLocalNetworkSite
#### New-AzureVnetLocalNetworkSite
#### Remove-AzureVnetLocalNetworkSite
####
#### Get-AzureVnetDNSserver   
#### Set-AzureVnetDNSserver 
#### New-AzureVnetDNSserver 
#### Remove-AzureVnetDNSserver 


Function Check-AzurePowerShellModule 
{
    [CmdletBinding()]
    PARAM([Parameter(Mandatory)] $minVer)

    Write-Host  -Object 'Checking if the Azure PowerShell module is installed...'

    $minVersion = $minVer -Split '\.'
    $minMajor = $minVersion[0]
    $minMinor = $minVersion[1]
    $minBuild = $minVersion[2]

    if (Get-Module -ListAvailable  -Name 'Azure') 
    {
        Write-Host  -Object 'Loading Azure module...'
        Import-Module  -Name 'Azure' -Force
        $ModVer = (Get-Module -Name 'Azure').Version
        Write-Verbose  -Message "Version installed: $ModVer  Minimum required: $minVer"
        $minimumBuild = (($ModVer.Major -gt $minMajor) -OR ($ModVer.Minor -gt $minMinor) -OR (($ModVer.Minor -eq $minMinor) -AND ($ModVer.Build -ge $minBuild)))
        if ($minimumBuild) 
        {
            return $true
        }
        else 
        {
            Write-Host  -Object "The Azure PowerShell module is NOT a current build. You will now be directed to the download location. `n" -ForegroundColor Yellow
            Start-Process -FilePath 'http://go.microsoft.com/fwlink/p/?linkid=320376&clcid=0x409'
            return $false
        }
    }
    else 
    {
        Write-Host  -Object "The Azure PowerShell module is NOT installed you will now be directed to the download location. `n" -ForegroundColor Yellow
        Start-Process -FilePath 'http://go.microsoft.com/fwlink/p/?linkid=320376&clcid=0x409'
        return $false
    }
}

Function Get-CurrentSubscription 
{
    [CmdletBinding()]
    PARAM()

    Get-AzureSubscription | Where-Object  -FilterScript { $_.IsCurrent -eq $true }
}

Function Select-AzureLocation 
{
    [CmdletBinding()]
    PARAM()

    $locations = Get-AzureLocation
    $locationPrompt = New-UserPromptChoice -options $locations.Name
    $locationChoice = $Host.UI.PromptForChoice('Location','Please choose a location',$locationPrompt,0) 
} 

Function New-UserPromptChoice 
{
    PARAM($options)

    $arrOptions = @()
    $i = 1

    foreach ($option in $options)
    {
        $optionDesc = New-Object  -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList ("&$i - $option")
        $arrOptions += $optionDesc
        $i++
    }

    return [System.Management.Automation.Host.ChoiceDescription[]]($arrOptions)
}


Function New-AzureVnetConfig 
{
    <#
        .Synopsis
        Creates a Network config XML file to pass into Azure.
        .DESCRIPTION
        As described by the Azure Virtual Network Configuration Schema, construct the appropriate file.
        This generated file is then passed into 'Set-AzureVNetConfig -ConfigurationPath <XMLfilename>',
        which updates the network configuration of the current Microsoft Azure subscription 
        .FUNCTIONALITY
        A series of calls to base XML functions to generate a network config.
        .LINK
        http://msdn.microsoft.com/en-us/library/azure/jj157100.aspx
    #>
    [CmdletBinding()]
    PARAM ([Parameter(Mandatory = $true)] [string] $VnetName,
                                          [string] $Location = (Select-AzureLocation),
                            [System.Net.IPAddress] $StartingIP = '10.0.0.0',
                                             [int] $VnetCIDR = '8',
                                          [string] $VnetSubnetname = 'Subnet-1',
                                             [int] $SubNetCIDR = '11',
                                          [string] $DNSname,
                            [System.Net.IPAddress] $DNSipAddress = '8.8.8.8'
    )

    if (Get-AzureVNetConfig) 
    {
        Write-Warning -Message 'AzureVnetConfig already exists.'
    }
    else 
    {
        $nsVnet = 'http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration'

        # create a new base xml document
        $xmlDoc = New-Object -TypeName System.Xml.XmlDocument

        # create & insert xml declaration
        $xmlDec = $xmlDoc.CreateXmlDeclaration('1.0','utf-8', $null)
        $root = $xmlDoc.DocumentElement
        [void]$xmlDoc.InsertBefore($xmlDec, $root)

        # create the Networkconfiguration root element & attributes
        $netConfig = $xmlDoc.CreateElement('NetworkConfiguration')

        $attr = $xmlDoc.CreateAttribute('xmlns:xsd')
        $attr.Value = 'http://www.w3.org/2001/XMLSchema'
        [void]$netConfig.Attributes.Append($attr)

        $attr = $xmlDoc.CreateAttribute('xmlns:xsi')
        $attr.Value = 'http://www.w3.org/2001/XMLSchema-instance'
        [void]$netConfig.Attributes.Append($attr)

        $attr = $xmlDoc.CreateAttribute('xmlns')
        $attr.Value = 'http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration'
        [void]$netConfig.Attributes.Append($attr)

        # create the VirtualNetworkconfiguration root element & attributes
        $vnetConfig = $xmlDoc.CreateElement('VirtualNetworkConfiguration',$nsVnet)

        # create the LocalNetworkSites, VirtualNetworkSites root elements
        $locNetSites = $xmlDoc.CreateElement('LocalNetworkSites',$nsVnet)
        $virNetSites = $xmlDoc.CreateElement('VirtualNetworkSites',$nsVnet)

        # create the virtual network site element
        $virNetSite = $xmlDoc.CreateElement('VirtualNetworkSite',$nsVnet)

        # create some virtual network site attributes
        $xmlAttr = $xmlDoc.CreateAttribute('name')
        $xmlAttr.Value = $VnetName
        [void]$virNetSite.Attributes.Append($xmlAttr)

        $xmlAttr = $xmlDoc.CreateAttribute('Location')
        $xmlAttr.Value = $Location
        [void]$virNetSite.Attributes.Append($xmlAttr)

        $addressSpace = $xmlDoc.CreateElement('AddressSpace',$nsVnet)
        $addressPrefix = $xmlDoc.CreateElement('AddressPrefix',$nsVnet)
        $addressPrefix.InnerText = "$StartingIP" + '/' + "$VnetCIDR"
        [void]$addressSpace.AppendChild($addressPrefix)
        [void]$virNetSite.AppendChild($addressSpace)

        $subnets = $xmlDoc.CreateElement('Subnets',$nsVnet)
        # add and define virtual network site subnets
        $subnet = $xmlDoc.CreateElement('Subnet',$nsVnet)
        $xmlAttr = $xmlDoc.CreateAttribute('name')
        $xmlAttr.Value = $VnetSubnetname
        [void]$subnet.Attributes.Append($xmlAttr)
        $addressPrefix = $xmlDoc.CreateElement('AddressPrefix',$nsVnet)
        $addressPrefix.InnerText = "$StartingIP" + '/' + "$SubNetCIDR"
        [void]$subnet.AppendChild($addressPrefix)
        [void]$subnets.AppendChild($subnet)
        [void]$virNetSite.AppendChild($subnets)  

        [void]$virNetSites.AppendChild($virNetSite)

        # create the DNS & DNServers elements
        $dns = $xmlDoc.CreateElement('Dns',$nsVnet)
        $dnsServers = $xmlDoc.CreateElement('DnsServers',$nsVnet)
        if ($DNSname -ne $null) 
        {
            $DNSserver = $xmlDoc.CreateElement('DnsServer',$nsVnet)
            $xmlAttr = $xmlDoc.CreateAttribute('name')
            $xmlAttr.Value = $DNSname
            [void]$DNSserver.Attributes.Append($xmlAttr)

            $xmlAttr = $xmlDoc.CreateAttribute('IPAddress')
            $xmlAttr.Value = $DNSipAddress
            [void]$DNSserver.Attributes.Append($xmlAttr)

            [void]$dnsServers.AppendChild($DNSserver)
        }
        [void]$dns.AppendChild($dnsServers)

        [void]$vnetConfig.AppendChild($dns)
        [void]$vnetConfig.AppendChild($locNetSites)
        [void]$vnetConfig.AppendChild($virNetSites)
        [void]$netConfig.AppendChild($vnetConfig)
        [void]$xmlDoc.AppendChild($netConfig)

        $xmlTempPath = [System.IO.Path]::GetTempPath()
        $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'

        $xmlDoc.Save($SaveFilePath)

        Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
    }

    Get-AzureVNetConfig
}

Function Export-AzureVnetConfig 
{
    [CmdletBinding()]
    PARAM ([Parameter(Mandatory = $true)] [string] $VnetConfigOutputFile)

    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        $VNetConfigObject.ExportToFile($VnetConfigOutputFile)
    }
}


Function Get-AzureVnetVirtualNetworkSite 
{
    [CmdletBinding()]
    PARAM ( [string] $VnetName)

    $Vnetsites = Get-AzureVNetSite

    if ($VnetName) 
    {
        $Vnetsites | Where-Object -FilterScript { $_.Name -eq $VnetName }
    }
    else 
    {
        $Vnetsites
    }
}

Function New-AzureVnetVirtualNetworkSite 
{
    [CmdletBinding()]
    PARAM ([Parameter(Mandatory = $true)] [string] $VnetName,
                                          [string] $Location = (Select-AzureLocation),
                            [System.Net.IPAddress] $StartingIP = '10.0.0.0',
                                             [int] $VnetCIDR = '8',
                                          [string] $VnetSubnetname = 'Subnet-1',
                                             [int] $SubNetCIDR = '11',
                                          [string] $DNSname,
                            [System.Net.IPAddress] $DNSipAddress = '8.8.8.8'
    )

    # need to validate VnetCIDR if IPaddress is provided

    $VnetSite = Get-AzureVnetVirtualNetworkSite -VnetName $VnetName 
    if ($VnetSite) 
    {
        Write-Error  -Message "The VnetVirtualNetworkSite '$VnetName' already exists."
    }
    else
    {
        $VNetConfigObject = Get-AzureVNetConfig

        if ($VNetConfigObject)
        {
            # are there ANY networks configured?

            try 
            {
                [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration

                $nsVnet = 'http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration'

                $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
                $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)


                $xpath = '//myns:Dns'
                $dns = $vnetConfig.SelectSingleNode($xpath,$nsmgr)
                
                $xpath = '//myns:DnsServers'
                $dnsServers = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

                if ($DNSname -ne $null) 
                {
                    $exists = $dnsServers.DnsServer | Where-Object  -FilterScript { $_.Name -eq $DNSname }
                    if (-NOT $exists) 
                    {
                        $DNSserver = $vnetConfig.CreateElement('DnsServer',$nsVnet)
                        $xmlAttr = $vnetConfig.CreateAttribute('name')
                        $xmlAttr.Value = $DNSname
                        [void]$DNSserver.Attributes.Append($xmlAttr)

                        $xmlAttr = $vnetConfig.CreateAttribute('IPAddress')
                        $xmlAttr.Value = $DNSipAddress
                        [void]$DNSserver.Attributes.Append($xmlAttr)
                        [void]$dnsServers.AppendChild($DNSserver)
                        [void]$dns.AppendChild($dnsServers)
                    }
                }

                $xpath = '//myns:VirtualNetworkSites'
                $VirtualNetSites = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

                $VirtualNetSite = $vnetConfig.CreateElement('VirtualNetworkSite',$nsVnet)
                $xmlAttr = $vnetConfig.CreateAttribute('name')
                $xmlAttr.Value = $VnetName
                [void]$VirtualNetSite.Attributes.Append($xmlAttr)

                $xmlAttr = $vnetConfig.CreateAttribute('Location')
                $xmlAttr.Value = $Location
                [void]$VirtualNetSite.Attributes.Append($xmlAttr)

                $addressSpace = $vnetConfig.CreateElement('AddressSpace',$nsVnet)
                $addressPrefix = $vnetConfig.CreateElement('AddressPrefix',$nsVnet)
                $addressPrefix.InnerText = "$StartingIP" + '/' + "$VnetCIDR"
                [void]$addressSpace.AppendChild($addressPrefix)

                $subnets = $vnetConfig.CreateElement('Subnets',$nsVnet)
                $subnet  = $vnetConfig.CreateElement('Subnet',$nsVnet)
                $xmlAttr = $vnetConfig.CreateAttribute('name')
                $xmlAttr.Value = $VnetSubnetname
                [void]$subnet.Attributes.Append($xmlAttr)

                $addressPrefix2 = $vnetConfig.CreateElement('AddressPrefix',$nsVnet)
                $addressPrefix2.InnerText = "$StartingIP" + '/' + "$SubNetCIDR"
                [void]$subnet.AppendChild($addressPrefix2)

                [void]$subnets.AppendChild($subnet)

                if ($DNSname -ne $null) 
                {
                    $DnsServersRef = $vnetConfig.CreateElement('DnsServersRef',$nsVnet)
                    $DnsServerRef  = $vnetConfig.CreateElement('DnsServerRef',$nsVnet)
                    $xmlAttr       = $vnetConfig.CreateAttribute('name')
                    $xmlAttr.Value = $DNSname
                    [void]$DnsServerRef.Attributes.Append($xmlAttr)
                    [void]$DnsServersRef.AppendChild($DnsServerRef)
                }

                [void]$VirtualNetSite.AppendChild($addressSpace)
                [void]$VirtualNetSite.AppendChild($subnets)
                [void]$VirtualNetSite.AppendChild($DnsServersRef)
                [void]$VirtualNetSites.AppendChild($VirtualNetSite)

                $xmlTempPath = [System.IO.Path]::GetTempPath()
                $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'
                $vnetConfig.Save($SaveFilePath)

                $null = Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
            }
            catch 
            {
                Write-Error  -Message 'Evil happened...'
            }
        }
        else 
        {
            $params = @{
                VnetName       = $VnetName
                Location       = $Location
                StartingIP     = $StartingIP
                VnetCIDR       = $VnetCIDR
                VnetSubnetname = $VnetSubnetname
                SubNetCIDR     = $SubNetCIDR
                DNSname        = $DNSname
                DNSipAddress   = $DNSipAddress
            }



            New-AzureVnetConfig  -VnetName @params
        }
    }
}

function Set-AzureVnetVirtualNetworkSite
{
}

function Remove-AzureVnetVirtualNetworkSite
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)] [string] $VnetName)

    if (Get-AzureVnetVirtualNetworkSite  -VnetName $VnetName) 
    {
        # remove it
    }
    else 
    {
        Write-Error -Message "The VirtualNetworkSite $VnetName was not found."
    }
}


Function Get-AzureVnetLocalNetworkSite 
{
    [CmdletBinding()]
    PARAM ( [string] $LocalNetworkSiteName)

    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration 

        $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
        $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)

        $xpath = '//myns:LocalNetworkSites'
        $LocalNetworkSites = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        if ($LocalNetworkSiteName) 
        {
            $LocalNetworkSites.LocalNetworkSite | Where-Object -FilterScript { $_.Name -eq $LocalNetworkSiteName }
        }
        else 
        {
            $LocalNetworkSites.LocalNetworkSite
        }
    }
}

function New-AzureVnetLocalNetworkSite 
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)] [string] $LocalNetworkSiteName,
                            [System.Net.IPAddress] $StartingIP,
                                             [int] $VnetCIDR,
                            [System.Net.IPAddress] $VPNGatewayAddress
    )

    # need to validate VnetCIDR if IPaddress is provided

    $LocalNetworkSite = Get-AzureVnetLocalNetworkSite -LocalNetworkSiteName $LocalNetworkSiteName 
    if ($LocalNetworkSite) 
    {
        Write-Error  -Message "The LocalNetworkSite '$LocalNetworkSiteName' already exists."
    }
    else
    {
        $VNetConfigObject = Get-AzureVNetConfig

        if ($VNetConfigObject)
        {
            # are there ANY networks configured?

            try 
            {
                [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration

                $nsVnet = 'http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration'

                $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
                $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)


                $xpath = '//myns:LocalNetworkSites'
                $LocalNetworkSites = $vnetConfig.SelectSingleNode($xpath,$nsmgr)
                if (-NOT ($LocalNetworkSites.HasChildNodes)) 
                {
                    Write-Verbose -Message 'create LocalNetworkSites node'
                    $VirtualNetworkConfiguration = $xmlVnetConfig.SelectSingleNode('//myns:VirtualNetworkConfiguration',$nsmgr)
                    $LocalNetworkSites = $xmlVnetConfig.CreateElement('LocalNetworkSites')
                    $VirtualNetworkConfiguration.AppendChild($LocalNetworkSites)
                }
                Write-Verbose -Message 'create LocalNetworkSite node'
                $LocalNetworkSite = $vnetConfig.CreateElement('LocalNetworkSite',$nsVnet)
                $xmlAttr = $vnetConfig.CreateAttribute('name')
                $xmlAttr.Value = $LocalNetworkSiteName
                [void]$LocalNetworkSite.Attributes.Append($xmlAttr)

                Write-Verbose -Message 'create AddressSpace node'
                $addressSpace = $vnetConfig.CreateElement('AddressSpace',$nsVnet)
                $addressPrefix = $vnetConfig.CreateElement('AddressPrefix',$nsVnet)
                $addressPrefix.InnerText = "$StartingIP" + '/' + "$VnetCIDR"
                [void]$addressSpace.AppendChild($addressPrefix)
                [void]$LocalNetworkSite.AppendChild($addressSpace)

                Write-Verbose -Message 'test for VPNGatewayAddress'
                if ($VPNGatewayAddress -ne $null) 
                {
                    Write-Verbose -Message 'create VPNGatewayAddress node'
                    $GatewayAddr = $vnetConfig.CreateElement('VPNGatewayAddress',$nsVnet)
                    $GatewayAddr.InnerText = $VPNGatewayAddress
                    [void]$LocalNetworkSite.Attributes.Append($GatewayAddr)
                }

                [void]$LocalNetworkSites.AppendChild($LocalNetworkSite)
                
                $xmlTempPath = [System.IO.Path]::GetTempPath()
                $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'
                $vnetConfig.Save($SaveFilePath)

                $null = Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
            }
            catch
            {
                Write-Error  -Message 'Evil happened...'
            }
        }
    }
}

function Set-AzureVnetLocalNetworkSite 
{
}

function Remove-AzureVnetLocalNetworkSite
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)] [string] $LocalNetworkSiteName)

    if (Get-AzureVnetLocalNetworkSite  -LocalNetworkSiteName $LocalNetworkSiteName) 
    {
        # remove it
    }
    else 
    {
        Write-Error -Message "The LocalNetworkSite $LocalNetworkSiteName was not found."
    }
}



Function Get-AzureVnetDNSserver 
{
    [CmdletBinding()]
    Param ( [string] $DNSserverName)

    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration 

        $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
        $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)

        $xpath = '//myns:DnsServers'
        $dnsServers = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        if ($DNSserverName) 
        {
            $dnsServers.DnsServer | Where-Object -FilterScript { $_.Name -eq $DNSserverName }
        }
        else 
        {
            $dnsServers.DnsServer
        }
    }
}

Function Set-AzureVnetDNSserver
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)]               [string] $DNSserverName,
           [Parameter(Mandatory = $true)] [System.Net.IPAddress] $IPAddress
    )

    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration 

        $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
        $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)

        $xpath = '//myns:DnsServers'
        $dnsServers = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        $DnsServer=$dnsServers.DnsServer | Where-Object -FilterScript { $_.Name -eq $DNSserverName }
        if ($DnsServer -ne $null)
        {
         Write-Verbose -Message "Setting '$DNSserverName' to '$IPaddress'"
         $DnsServer.IPAddress="$IPAddress"

         $xmlTempPath = [System.IO.Path]::GetTempPath()
         $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'
         $vnetConfig.Save($SaveFilePath)

         $null = Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
        }
        else
        {
          Write-Error -Message "The DnsServer $DNSserverName was not found."
        }
    }
} 

Function Remove-AzureVnetDNSserver
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)] [string] $DNSserverName
    )

    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration 

        $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
        $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)

        $xpath = '//myns:DnsServers'
        $dnsServers = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        $DnsServer=$dnsServers.DnsServer | Where-Object -FilterScript { $_.Name -eq $DNSserverName }
        if ($DnsServer -ne $null)
        {
           Write-Verbose -Message "Checking for references to '$DNSserverName'"

           $xpath = '//myns:VirtualNetworkSites'
           $VirtualNetSites = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

           foreach ($Vnet in $VirtualNetSites.VirtualNetworkSite) {
             $referenced=$Vnet.dnsserversref.dnsserverref | Where-Object {$_.name -eq $DNSserverName}
             if ($referenced -ne $null) {
                break
             }
           }

           if (-NOT ($referenced) )
           {
             Write-Verbose -Message "Removing '$DNSserverName'"
             [void]$dnsServers.RemoveChild($DnsServer)

             $xmlTempPath = [System.IO.Path]::GetTempPath()
             $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'
             $vnetConfig.Save($SaveFilePath)

             $null = Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
           }
           else
           {
             Write-Error "DNS server '$DNSserverName' is referenced by virtual network '$($Vnet.name)' and cannot be removed"
           }
        }
        else
        {
          Write-Error -Message "The DnsServer $DNSserverName was not found."
        }
    }

    #RemoveChild
}

Function New-AzureVnetDNSserver
{
    [CmdletBinding()]
    Param ([Parameter(Mandatory = $true)]               [string] $DNSserverName,
           [Parameter(Mandatory = $true)] [System.Net.IPAddress] $IPAddress
    )


    $VNetConfigObject = Get-AzureVNetConfig

    if ($VNetConfigObject) 
    {
        [XML]$vnetConfig = $VNetConfigObject.XMLConfiguration 

        $nsVnet = 'http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration'

        $nsmgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList ($vnetConfig.NameTable)
        $nsmgr.AddNamespace('myns', $vnetConfig.NetworkConfiguration.xmlns)

        $xpath = '//myns:Dns'
        $dns = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        $xpath = '//myns:DnsServers'
        $dnsServers = $vnetConfig.SelectSingleNode($xpath,$nsmgr)

        $exists = $dnsServers.DnsServer | Where-Object  -FilterScript { $_.Name -eq $DNSserverName }
        if (-NOT $exists) 
        {
            Write-Verbose -Message "Creating DnsServer node '$DNSserverName'"
            $DNSserver = $vnetConfig.CreateElement('DnsServer',$nsVnet)
            $xmlAttr = $vnetConfig.CreateAttribute('name')
            $xmlAttr.Value = $DNSserverName
            [void]$DNSserver.Attributes.Append($xmlAttr)

            $xmlAttr = $vnetConfig.CreateAttribute('IPAddress')
            $xmlAttr.Value = $IPAddress
            [void]$DNSserver.Attributes.Append($xmlAttr)
            [void]$dnsServers.AppendChild($DNSserver)
            [void]$dns.AppendChild($dnsServers)

            $xmlTempPath = [System.IO.Path]::GetTempPath()
            $SaveFilePath = Join-Path -Path $xmlTempPath -ChildPath 'VNetConfig.netcfg'
            $vnetConfig.Save($SaveFilePath)

            $null = Set-AzureVNetConfig -ConfigurationPath $SaveFilePath
        }
        else
        {
          Write-Error -Message "The DnsServer $DNSserverName already exists."
        }

    }
} 



Check-AzurePowerShellModule  -minVer '0.8.11' 
