function Get-GSUserLicenseInfo {
    [cmdletbinding()]
    Param
    (
      [parameter(Mandatory=$true)]
      [string]
      $User,
      [parameter(ParameterSetName='CheckSpecific',Mandatory=$true)]
      [ValidateSet("Google-Apps-Unlimited","Google-Apps-For-Business","Google-Apps-For-Postini","Google-Apps-Lite","Google-Drive-storage-20GB","Google-Drive-storage-50GB","Google-Drive-storage-200GB","Google-Drive-storage-400GB","Google-Drive-storage-1TB","Google-Drive-storage-2TB","Google-Drive-storage-4TB","Google-Drive-storage-8TB","Google-Drive-storage-16TB","Google-Vault","Google-Vault-Former-Employee")]
      [string]
      $License,
      [parameter(ParameterSetName='CheckAll',Mandatory=$true)]
      [switch]
      $CheckAllLicenseTypes,
      [parameter(Mandatory=$false)]
      [String]
      $AccessToken,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $P12KeyPath = $Script:PSGSuite.P12KeyPath,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $AppEmail = $Script:PSGSuite.AppEmail,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $AdminEmail = $Script:PSGSuite.AdminEmail
    )
if (!$AccessToken)
    {
    $AccessToken = Get-GSToken -P12KeyPath $P12KeyPath -Scopes "https://www.googleapis.com/auth/apps.licensing" -AppEmail $AppEmail -AdminEmail $AdminEmail
    }
$header = @{
    Authorization="Bearer $AccessToken"
    }
if ($CheckAllLicenseTypes)
    {
    $Licenses = @("Google-Apps-Unlimited","Google-Apps-For-Business","Google-Apps-For-Postini","Google-Apps-Lite","Google-Vault","Google-Vault-Former-Employee","Google-Drive-storage-20GB","Google-Drive-storage-50GB","Google-Drive-storage-200GB","Google-Drive-storage-400GB","Google-Drive-storage-1TB","Google-Drive-storage-2TB","Google-Drive-storage-4TB","Google-Drive-storage-8TB","Google-Drive-storage-16TB")
    foreach ($License in $Licenses)
        {
        Write-Verbose "Checking $user for $License license"
        $productId = if($License -like "Google-Apps*"){"Google-Apps"}elseif($License -like "Google-Drive-storage*"){"Google-Drive-storage"}elseif($License -like "Google-Vault*"){"Google-Vault"}
        $URI = "https://www.googleapis.com/apps/licensing/v1/product/$productId/sku/$License/user/$User"
        try
            {
            $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $header -ContentType "application/json" -ErrorAction SilentlyContinue -Verbose:$false | ForEach-Object {if($_.kind -like "*#*"){$_.PSObject.TypeNames.Insert(0,$(Convert-KindToType -Kind $_.kind));$_}else{$_}}
            }
        catch
            {}
        if ($response)
            {
            break
            }
        }
    if (!$response)
        {
        Write-Error "No license found for $User!"
        }
    }
elseif ($License)
    {
    $productId = if($License -like "Google-Apps*"){"Google-Apps"}elseif($License -like "Google-Drive-storage*"){"Google-Drive-storage"}elseif($License -like "Google-Vault*"){"Google-Vault"}
    $URI = "https://www.googleapis.com/apps/licensing/v1/product/$productId/sku/$License/user/$User"
    try
        {
        $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $header -ContentType "application/json" | ForEach-Object {if($_.kind -like "*#*"){$_.PSObject.TypeNames.Insert(0,$(Convert-KindToType -Kind $_.kind));$_}else{$_}}
        }
    catch
        {
        try
            {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $resp = $reader.ReadToEnd()
            $response = $resp | ConvertFrom-Json | 
                Select-Object @{N="Error";E={$Error[0]}},@{N="Code";E={$_.error.Code}},@{N="Message";E={$_.error.Message}},@{N="Domain";E={$_.error.errors.domain}},@{N="Reason";E={$_.error.errors.reason}}
            Write-Error "$(Get-HTTPStatus -Code $response.Code): $($response.Domain) / $($response.Message) / $($response.Reason)"
            return
            }
        catch
            {
            Write-Error $resp
            return
            }
        }
    }
else
    {
    Write-Error "CheckAllLicenseTypes not set to True and License type not specified! Please use either parameter to check for a user's license."
    }
return $response
}