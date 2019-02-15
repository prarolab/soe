Param(
  [string] [Parameter(Mandatory=$true)] $alias,
  [string] [Parameter(Mandatory=$true)] $adminpassword
)


$outputpath =".\hydrationoutput.txt"

Write-Host 'Please log into Azure now' -foregroundcolor Green;
Login-AzureRmAccount

$Subscription = (Get-AzureRmSubscription) |Select Name, Id | Out-GridView -Title "Select Azure Subscription " -PassThru

$sub=Select-AzureRmSubscription -SubscriptionName $Subscription.Name

$aadAppName =$alias +"msreadylabapp"

$defaultHomePage ="http://"+"$aadAppName"
$IDENTIFIERURI =[string]::Format("http://localhost:8080/{0}",[Guid]::NewGuid().ToString("N"));
$keyvaultrg =$alias+'-keyvault-rg'
$networkrg =$alias+'-network-rg'
$keyvaultName =$alias +'-akeyvault'
#$omsname=$alias+'-omsready'
#$omsrg= $alias+'-oms-rg'
$location ="East US"
$aadClientSecret = “abc123”
$vmimagerg =$alias+'-vmimages-rg'
$imagegalname = $alias+'imagegallery'
$imagegaldeflin= $alias +'-imagedef-linux'
$imagegaldefwin= $alias +'-imagedef-win'
$imagepub =$alias +'-myimages'

######-Account Variables
$aztenantid=$sub.Subscription.TenantId
$azsubid=$sub.Subscription.Id

$aadClientSecret = "abc123";
        $aadClientsecureSecret=ConvertTo-SecureString -String $aadClientSecret -AsPlainText -Force

Register-AzureRmProviderFeature -FeatureName GalleryPreview -ProviderNamespace Microsoft.Compute
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute




$function =@("keyvault","network","vmimages","jumpbox")

        foreach ($rg in $function)

            {

                $rgname = $alias +'-'+ $rg+'-rg'
                New-AzureRmResourceGroup -Name $rgname -Location $Location -Force | Out-Null
                Write-Host "Created Resource Group $rgname" -BackgroundColor Green -ForegroundColor DarkBlue 

            }

New-AzureRmResourceGroup -Name "managed-images" -Location $Location -Force | Out-Null

# Check if AAD app with $aadAppName was already created
    $SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName);
    if(-not $SvcPrincipals)
    {
        # Create a new AD application if not created before
        
        $now = [System.DateTime]::Now;
        $oneYearFromNow = $now.AddYears(1);
        

        Write-Host "Creating new AAD application ($aadAppName)";
        $ADApp = New-AzureRmADApplication -DisplayName $aadAppName -HomePage $defaultHomePage -IdentifierUris $identifierUri  -StartDate $now -EndDate $oneYearFromNow -Password $aadClientsecureSecret;
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $ADApp.ApplicationId;
        $SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName);
        if(-not $SvcPrincipals)
        {
            # AAD app wasn't created 
            Write-Error "Failed to create AAD app $aadAppName. Please log-in to Azure using Login-AzureRmAccount  and try again";
            return;
        }
        $aadClientID = $servicePrincipal.ApplicationId;
        Write-Host "Created a new AAD Application ($aadAppName) with ID: $aadClientID ";
    }
    else
    {


       $aadClientID = $SvcPrincipals[0].ApplicationId;
    }



 Try
        {
            $resGroup = Get-AzureRmResourceGroup -Name $keyvaultrg -ErrorAction SilentlyContinue;
        }
    Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find resource group:  ($keyvaultrg)";
            $resGroup = $null;
        }
    
    #Create a new resource group if it doesn't exist
    if (-not $resGroup)
        {
            Write-Host "Creating new resource group:  ($keyvaultrg)";
            $resGroup = New-AzureRmResourceGroup -Name $keyvaultrg -Location $location;
            Write-Host "Created a new resource group named $keyvaultrg to place keyVault";
        }
    
    Try
        {
            $keyVault = Get-AzureRmKeyVault -VaultName $keyvaultName -ErrorAction SilentlyContinue;
        }
    Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find Key Vault: $keyVaultName";
            $keyVault = $null;
        }
    
    #Create a new vault if vault doesn't exist
    if (-not $keyVault)
        {
            Write-Host "Creating new key vault:  ($keyVaultName)";
            $keyVault = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $keyvaultrg -Sku Standard -Location $location;
            Write-Host "Created a new KeyVault named $keyVaultName to store encryption keys";
        }
    # Specify privileges to the vault for the AAD application - https://msdn.microsoft.com/en-us/library/mt603625.aspx
    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $aadClientID -PermissionsToKeys wrapKey -PermissionsToSecrets set;

    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -EnabledForDiskEncryption -EnabledForTemplateDeployment;

    $diskEncryptionKeyVaultUrl = $keyVault.VaultUri;
	$keyVaultResourceId = $keyVault.ResourceId;

    $seckey1=ConvertTo-SecureString -String $adminpassword -AsPlainText -Force
    Set-AzureKeyVaultSecret -Name adminpassword -SecretValue $seckey1 -VaultName $keyvaultName 




    Try
        {
            $resGroup = Get-AzureRmResourceGroup -Name $vmimagerg -ErrorAction SilentlyContinue;
        }
    Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find resource group:  ($vmimagerg)";
            $resGroup = $null;
        }
    
    #Create a new resource group if it doesn't exist
    if (-not $resGroup)
        {
            Write-Host "Creating new resource group:  ($vmimagerg)";
            $resGroup = New-AzureRmResourceGroup -Name $vmimagerg -Location $location;
            Write-Host "Created a new resource group named $vmimagerg to place keyVault";
        }
    
    Try
        {
            $imagegal = Get-AzureRmGallery -ResourceGroupName $vmimagerg -Name $imagegalname -ErrorAction SilentlyContinue
        }
    Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find Shared Image Gallery: $imagegalname";
            $imagegal = $null;
        }
    
     #Create a new Shared Image Gallery if vault doesn't exist
    if (-not $imagegal)
        {
            Write-Host "Creating new Shared Image Gallery:  ($imagegalname)";
          
              $gallery = New-AzureRmGallery `
                           -GalleryName $imagegalname `
                           -ResourceGroupName $vmimagerg `
                           -Location $location `
                           -Description 'Shared Image Gallery for my organization'
            
            Write-Host "Created a new Shared Image Gallery named $imagegalname to store VM Images";
        }


        Try
        {
            $imagegaldef1 = Get-AzureRmGalleryImageDefinition -ResourceGroupName  $vmimagerg -GalleryName $imagegalname -Name $imagegaldeflin -ErrorAction SilentlyContinue
        }
            Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find Gallery Definition: $imagegaldeflin";
            $imagegaldef1 = $null;
        }
    
     #Create a new Shared Image Gallery if vault doesn't exist
    if (-not $imagegaldef1)
        {
            Write-Host "Creating new Shared Image Gallery Definition for Linux:  ($imagegaldeflin)";
                          $galleryImagelinux = New-AzureRmGalleryImageDefinition `
                                               -GalleryName $imagegalname `
                                               -ResourceGroupName $vmimagerg `
                                               -Location $location `
                                               -Name $imagegaldeflin `
                                               -OsState generalized `
                                               -OsType Linux `
                                               -Publisher $imagepub `
                                               -Offer 'rhel75' `
                                               -Sku 'gold'
            
            Write-Host "Created a new Shared Image Gallery Definittion named $imagegaldeflin to store VM Images";
        }

         Try
        {
            $imagegaldef2 = Get-AzureRmGalleryImageDefinition -ResourceGroupName  $vmimagerg -GalleryName $imagegalname -Name $imagegaldefwin -ErrorAction SilentlyContinue
        }
            Catch [System.ArgumentException]
        {
            Write-Host "Couldn't find Gallery Definition: $imagegaldefwin";
            $imagegaldef2 = $null;
        }
    
     #Create a new Shared Image Gallery if vault doesn't exist
    if (-not $imagegaldef2)
        {
            Write-Host "Creating new Shared Image Gallery Definition for Linux:  ($imagegaldefwin)";
                          $galleryImagewin = New-AzureRmGalleryImageDefinition `
                                               -GalleryName $imagegalname `
                                               -ResourceGroupName $vmimagerg `
                                               -Location $location `
                                               -Name $imagegaldefwin `
                                               -OsState generalized `
                                               -OsType Linux `
                                               -Publisher $imagepub `
                                               -Offer 'win16' `
                                               -Sku 'gold'
            
            Write-Host "Created a new Shared Image Gallery Definittion named $imagegaldefwin to store VM Images";
        }

$scope2 = '/subscriptions/' + $azsubid
New-AzureRmRoleAssignment  -ApplicationId $aadClientID -RoleDefinitionName Contributor -Scope $scope2





New-AzureRmResourceGroupDeployment -Name "Vnet-Deployment" -ResourceGroupName $networkrg -TemplateUri 'https://msreadylabs.blob.core.windows.net/workshop/azuredeployCopy.json' -TemplateParameterObject @{"alias"=$alias}

New-AzureRmResourceGroupDeployment -Name "devopsagent" -ResourceGroupName $networkrg -TemplateUri 'https://msreadylabs.blob.core.windows.net/workshop/azuredevopsagent.json' -TemplateParameterObject @{"alias"=$alias}



    if((Test-Path  $outputpath) -eq 'True' )
        {
            Clear-Content $outputpath
        }
        Write-Output "aadClientID ----------" |Out-File $outputpath -Append 
        $aadClientID.Guid |Out-File $outputpath -Append
        Write-Output "`t`r`n AzureAD Client Secret ---------->>" |Out-File $outputpath -Append
        $aadClientSecret|Out-File $outputpath -Append
         Write-Output "`t`r`n Subscription Id---------->>" |Out-File $outputpath -Append
        $azsubid|Out-File $outputpath -Append
        Write-Output "`t`r`n Azure Tenant Id---------->>" |Out-File $outputpath -Append
        $aztenantid|Out-File $outputpath -Append
        Write-Output "`r`n Keyvault Name  ---------->>>>" |Out-File $outputpath -Append
        $keyvaultName|Out-File $outputpath -Append

Start $outputpath

Write-Host "Please note  AzureADClientId, ,ClientSecret, Subcription and Tenant detail. Refer $outputpath  " -foregroundcolor Green;
    Write-Host "`t aadClientID: $aadClientID" -foregroundcolor Green;
 Write-Host "`t aadClientSecret: $aadClientSecret " -foregroundcolor Green;
 Write-Host "`t TenantId: $aztenantid" -foregroundcolor Green;
 Write-Host "`t SubscriptionId: $azsubid" -foregroundcolor Green;
    Write-Host "`t keyVaultNAme: $keyvaultName" -foregroundcolor Green;