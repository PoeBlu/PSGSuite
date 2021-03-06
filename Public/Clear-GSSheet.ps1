function Clear-GSSheet {
    [cmdletbinding()]
    Param
    (      
      [parameter(Mandatory=$true,Position=0)]
      [String]
      $SpreadsheetId,
      [parameter(Mandatory=$true)]
      [ValidateNotNullOrEmpty()]
      [string]
      $SpecifyRange,
      [parameter(Mandatory=$false)]
      [String]
      $SheetName,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $Owner = $Script:PSGSuite.AdminEmail,
      [parameter(Mandatory=$false)]
      [switch]
      $Raw,
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
    $AccessToken = Get-GSToken -P12KeyPath $P12KeyPath -Scopes "https://www.googleapis.com/auth/drive" -AppEmail $AppEmail -AdminEmail $Owner
    }
$header = @{
    Authorization="Bearer $AccessToken"
    }
if ($SheetName)
    {
    if ($SpecifyRange -like "'*'!*")
        {
        Write-Error "SpecifyRange formatting error! When using the SheetName parameter, please exclude the SheetName when formatting the SpecifyRange value (i.e. 'A1:Z1000')"
        return
        }
    elseif ($SpecifyRange)
        {
        $SpecifyRange = "'$($SheetName)'!$SpecifyRange"
        }
    else
        {
        $SpecifyRange = "$SheetName"
        }
    }
$URI = "https://sheets.googleapis.com/v4/spreadsheets/$SpreadsheetId/values/$SpecifyRange`:clear"
try
    {
    $response = Invoke-RestMethod -Method Post -Uri $URI -Headers $header -ContentType "application/json" | ForEach-Object {if($_.kind -like "*#*"){$_.PSObject.TypeNames.Insert(0,$(Convert-KindToType -Kind $_.kind));$_}else{$_}}
    if (!$Raw)
        {
        $i=0
        $datatable = New-Object System.Data.Datatable
        if ($Headers)
            {
            foreach ($col in $Headers)
                {
                [void]$datatable.Columns.Add("$col")
                }
            $i++
            }
        $(if ($RowStart){$response.valueRanges.values | Select-Object -Skip $([int]$RowStart -1)}else{$response.valueRanges.values}) | % {
            if ($i -eq 0)
                {
                foreach ($col in $_)
                    {
                    [void]$datatable.Columns.Add("$col")
                    }
                }
            else
                {
                [void]$datatable.Rows.Add($_)
                }
            $i++
            }
        Write-Verbose "Created DataTable object with $($i - 1) Rows"
        return $datatable
        }
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
        }
    catch
        {
        $response = $resp
        }
    }
return $response
}