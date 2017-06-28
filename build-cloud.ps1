Function CreateEnvironment()
{
    #ResourceGroup settings
    $resourceGroupName = "GftTestResourceGroup"
    $location = "WestEurope"
    
    #WebApp settings
    $webApp = "GFTWebAppTest"

    #Database settings
    $databaseServerName = "gft-database-server-test$(Get-Random)"
    $databaseName = "test-db"
    $databaseAdminLogin = "GftAdminUser"
    $databaseAdminPassword = "F/wmd9V%E^53>Vph"
    $databaseHost = "$($databaseServerName).database.windows.net"

    #Build settings
    $solutionPath = ".\src\GFT.DatabaseConnect.Web"
    $scriptsPath = ".\"
    $localIP = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip

    #Deploy settings
    $webAppLocalPath = ".\dist\GFT.DatabaseConnect.Web\"

    Login-AzureRmAccount

    DeleteResourceGroup `
        -resourceGroupName $resourceGroupName `
        -location $location

    CreateResourceGroup `
        -resourceGroupName $resourceGroupName `
        -location $location
    
    CreateWebApp `
        -webAppName $webApp `
        -location $location `
        -resourceGroupName $resourceGroupName

    CreateDatabase `
        -databaseServerName $databaseServerName `
        -databaseName $databaseName `
        -location $location `
        -resourceGroupName $resourceGroupName `
        -adminLogin $databaseAdminLogin `
        -password $databaseAdminPassword

    SetupWebApp `        -resourceGroupName $resourceGroupName `
        -webAppName $webApp `
        -databaseHost $databaseHost `
        -databaseName $databaseName `
        -databaseAdminLogin $databaseAdminLogin `
        -databaseAdminPassword $databaseAdminPassword

    SetupDatabaseFirewall `
        -databaseServerName $databaseServerName `
        -webAppName $webApp `
        -location $location `
        -resourceGroupName $resourceGroupName
    
    RunMigrations `
        -solutionPath $solutionPath `
        -databaseHost $databaseHost `
        -databaseName $databaseName `
        -databaseAdminLogin $databaseAdminLogin `
        -databaseAdminPassword $databaseAdminPassword

    BuildWebApp `
        -solutionPath $solutionPath

    DeployWebApp `
        -resourceGroupName $resourceGroupName `
        -webAppName $webApp `
        -webAppLocalPath $webAppLocalPath
}

Function RunMigrations()
{
    param(
        [String]$solutionPath,
        [String]$databaseHost,
        [String]$databaseName,
        [String]$databaseAdminLogin,
        [String]$databaseAdminPassword
    )

    Invoke-Expression "& .\build.ps1 -Target Migrations -ScriptArgs --dbHost=`"$($databaseHost)`",--dbName=`"$($databaseName)`",--dbUser=`"$($databaseAdminLogin)`",--dbPass=`"$($databaseAdminPassword)`""
}

Function BuildWebApp()
{
    param(
        [String]$solutionPath
    )
    
    & ".\build.ps1"
}

Function DeleteResourceGroup()
{
    param(
        [String]$resourceGroupName,
        [String]$location
    )

    $resourceGroup = Get-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $location `
        -ErrorAction SilentlyContinue `
        
    if($resourceGroup -ne $null)
    {
        Remove-AzureRmResourceGroup `
            -Name $resourceGroupName `
            -Verbose `
            -Force
    }
}

Function CreateResourceGroup()
{
    param(
        [String]$resourceGroupName,
        [String]$location
    )

    New-AzureRmResourceGroup `
        -Name $resourceGroupName `
        -Location $location
}


Function CreateWebApp()
{
    param(
        [String]$webAppName,
        [String]$location,
        [String]$resourceGroupName
    )

    New-AzureRmAppServicePlan `
        -Name $webAppName `
        -Location $location `
        -ResourceGroupName $resourceGroupName `
        -Tier Free

    New-AzureRmWebApp `
        -Name $webAppName `
        -Location $location `
        -AppServicePlan $webAppName `
        -ResourceGroupName $resourceGroupName
}

Function CreateDatabase()
{
    param(
        [String]$databaseServerName,
        [String]$databaseName,
        [String]$location,
        [String]$resourceGroupName,
        [String]$adminLogin,
        [String]$password
    )

    $securePassword = ConvertTo-SecureString `
        -String $password `
        -AsPlainText -Force
    
    $credentials = New-Object `
        -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $adminLogin, $securePassword
    
    New-AzureRmSqlServer `
        -ResourceGroupName $resourceGroupName `
        -ServerName $databaseServerName `
        -Location $location `
        -SqlAdministratorCredentials $credentials
       
    New-AzureRmSqlDatabase `
        -ResourceGroupName $resourceGroupName `
        -ServerName $databaseServerName `
        -DatabaseName $databaseName `
        -RequestedServiceObjectiveName "S0"
}

Function SetupDatabaseFirewall()
{
    param(
        [String]$databaseServerName,
        [String]$webAppName,
        [String]$location,
        [String]$resourceGroupName
    )

    $azureWebApp = Get-AzureRmWebApp `
        -ResourceGroupName $resourceGroupName `
        -Name $webAppName

    $outboundIpList = $azureWebApp.OutboundIpAddresses
    $ips = $outboundIpList.Split(',')

    $oldRules = Get-AzureRmSqlServerFirewallRule `
        -ResourceGroupName $resourceGroupName `
        -ServerName $databaseServerName `

    ForEach($rule in $oldRules) 
    {
        Write-Host "removing old rule $($rule.FirewallRuleName)"
        Remove-AzureRmSqlServerFirewallRule `
            -ResourceGroupName $resourceGroupName `
            -ServerName $databaseServerName `
            -FirewallRuleName $rule.FirewallRuleName
    }

    ForEach($ip in $ips) {
        Write-Host "setting firewall rule for $($ip)"
        New-AzureRmSqlServerFirewallRule `
            -ResourceGroupName $resourceGroupName `
            -ServerName $databaseServerName `
            -FirewallRuleName "allow-$($ip)" `
            -StartIpAddress $ip `
            -EndIpAddress $ip `
    }

    Write-Host "setting firewall rule for $($localIP)"
    New-AzureRmSqlServerFirewallRule `
        -ResourceGroupName $resourceGroupName `
        -ServerName $databaseServerName `
        -FirewallRuleName "allow-$($localIP)" `
        -StartIpAddress $localIP `
        -EndIpAddress $localIP `
    
}

Function SetupWebApp()
{
    param(
        [String]$resourceGroupName,
        [String]$webAppName,
        [String]$databaseHost,
        [String]$databaseName,
        [String]$databaseAdminLogin,
        [String]$databaseAdminPassword
    )

    $webApp = Get-AzureRmWebAppSlot `
        -ResourceGroupName $resourceGroupName `
        -Name $webAppName `
        -Slot production

    $existingConnectionStrings = $webApp.SiteConfig.ConnectionStrings
    $hash = @{}

    ForEach($connString in $existingConnectionString) {
        $hash[$connString.Name] = @{ 
            Type = $connString.Type.ToString(); 
            Value = $connString.ConnectionString 
        }
    }

    $hash["AppConnString"] = @{ 
        Type = "SqlAzure"; 
        Value = "Server=$($databaseHost);Database=$($databaseName);User Id=$($databaseAdminLogin);Password=$($databaseAdminPassword);" 
    }

    Set-AzureRmWebAppSlot `
        -ResourceGroupName $resourceGroupName `
        -Name $webAppName `
        -Slot production `
        -ConnectionStrings $hash
}

Function DeployWebApp()
{
    param(
        [String]$resourceGroupName,
        [String]$webAppName,
        [String]$webAppLocalPath
    )

    Add-Type -Path ".\apps\WinSCPnet.dll"
    $xml = [xml](Get-AzureRmWebAppPublishingProfile -Name $webAppName `
        -ResourceGroupName $resourceGroupName `
        -OutputFile null)

    $username = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userName").value
    $password = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userPWD").value
    $url = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@publishUrl").value
    $uriURL = ([System.Uri]$url)
    $ftp = "$($uriURL.Scheme)://$($uriURL.Host)"
    $path = Resolve-Path $webAppLocalPath

    $webclient = New-Object -TypeName System.Net.WebClient
    $webclient.Credentials = New-Object System.Net.NetworkCredential($username,$password)

    $files = Get-ChildItem -Path $webAppLocalPath -Recurse | Where-Object{!($_.PSIsContainer)}

    $sessionOptions = New-Object WinSCP.SessionOptions
    $sessionOptions.ParseUrl($ftp)
    $sessionOptions.UserName = $username
    $sessionOptions.Password = $password

    $session = New-Object WinSCP.Session
    $session.Open($sessionOptions)

    $session.RemoveFiles("/site/wwwroot/*")
    $session.PutFiles($path, "/site/wwwroot").Check()
    $session.Dispose()
}

CreateEnvironment