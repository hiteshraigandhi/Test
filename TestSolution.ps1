#Import-Module AWSPowerShell

# Configuration Variables

# For OMS Workspace
$OmsWorkspaceId = "3f4f80e6-df70-49d3-9d0b-e79266a9b33d" #Get-AutomationVariable -Name "OmsWorkspaceId"
$OmsSecretKey = 'UFuR3nVMxJ5oogx5DolC+1+7/+hQL21ONXWNsSOuB5hkTEn7ySHULZQHHOvoU6eBaaWarAXWQ0bvAtz7akE2FQ==' #Get-AutomationVariable -Name "OmsSecretKey"
$OmsLogtype = "hiteshtest" #Get-AutomationVariable -Name "OmsLogtype"
$OmsApiVersion = "2016-04-01"
$OmsResource = "/api/logs"
$OmsTimestampField = "Timestamp"

# for all instances and all metrics, combine instance properties and metric values
# and send each to OMS
Function PostRecordsToOMS 
{
    $o = @{FN="Litesh"; LN="Raigandhi"; Age=42; Computer = "hiteshrdev"}

    $Jo = $o | ConvertTo-Json

    # send to OMS
    PostData -customerId $OmsWorkspaceId -sharedKey $OmsSecretKey -body $Jo `
                                -logType $OmsLogtype -resource $OmsResource -apiVersion $OmsApiVersion -timestampField $OmsTimestampField
}





# From the OMS IngestionApiClient

# Builds the authorization token.
Function BuildSignature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource){
  $xHeaders = "x-ms-date:" + $date
  $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
  $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
  $keyBytes = [Convert]::FromBase64String($sharedKey)
  $sha256 = New-Object System.Security.Cryptography.HMACSHA256
  $sha256.Key = $keyBytes
  $calculatedHash = $sha256.ComputeHash($bytesToHash)
  $encodedHash = [Convert]::ToBase64String($calculatedHash)
  $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
  return $authorization
}

#Build & send request to POST API
Function PostData([string]$customerId, [string]$sharedKey, [string]$body, [string]$logType, [string]$resource, [string]$apiVersion, [string]$timestamp) {
  $method = "POST"
  $contentType = "application/json"
  $rfc1123date = [DateTime]::UtcNow.ToString("r")
  $contentLength = $body.Length
  $signature = BuildSignature -customerId $customerId -sharedKey $sharedKey -date $rfc1123date -contentLength $contentLength -method $method -contentType $contentType -resource $resource

  $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=" + $apiVersion

  $headers = @{
    "Authorization" = $signature;
    "Log-Type" = $logType;
    "x-ms-date" = $rfc1123date;
    "time-generated-field" = $timestamp;
  }

  $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing

  if ($response.StatusCode -ne 202){    
    write-output $response.BaseResponse
    write-output $response.RawContent
  }
}

# Validates the time stamp field.
Function ValidateTimestampField([string]$timestampField, [object]$timestampFieldValue)
{
    if(-not [string]::IsNullOrWhiteSpace($timestampField) -and $timestampFieldValue -eq $null)
    {
        throw [System.ArgumentException] "The timestamp field specified is not part of the incoming payload", "$timestampField"
    }

    if(-not [string]::IsNullOrWhiteSpace($timestampField) -and $timestampFieldValue -ne $null)
    {
        try
        {
            $dtFormatInfo = [System.Threading.Thread]::CurrentThread.CurrentCulture.DateTimeFormat;
        
            $rfcDate = [System.Convert]::ToDateTime($timestampFieldValue).ToString($dtFormatInfo.RFC1123Pattern);        

            Write-Debug $rfcDate
        }
        catch [System.Exception]
        {   
            Write-Debug $_.Exception.Message
                    
            throw [System.ArgumentException] "The timestamp field specified is not in RFC1123 format", "$timestampField"
        }
    }
}

#Build & send request to POST API - Dictionary Parameter
Function PostDataDictionary([string]$customerId, [string]$sharedKey, [System.Collections.Generic.Dictionary[string, string]]$body, 
    [string]$logType, [string]$resource, [string]$apiVersion, [string]$timestampField)
{    
    if($body -eq $null)
    {
        throw [System.ArgumentException] "payload"        
    }
    
    $jsonBody = $body | ConvertTo-Json
    $timestampFieldValue = if($body.ContainsKey("$timestampField")){ $body["$timestampField"] } else { $null }
    
    #validting timestamp field
    ValidateTimestampField -timestampField $timestampField -timestampFieldValue $timestampFieldValue

    #calling main PostData method
    PostData -customerId $customerId -sharedKey $sharedKey -body $jsonBody -logType $logType -resource $resource -apiVersion $apiVersion -timestampField $timestampFieldId
}

#Build & send request to POST API - List[Dictionary] Parameter
Function PostDataList([string]$customerId, [string]$sharedKey, [system.collections.generic.list[System.Collections.Generic.Dictionary[string, string]]]$body, 
    [string]$logType, [string]$resource, [string]$apiVersion, [string]$timestampField)
{    
    if($body -eq $null)
    {
        throw [System.ArgumentException] "payload"
    }

    foreach($item in $body)
    {
        $timestampFieldValue = if($item.ContainsKey("$timestampField")){ $item["$timestampField"] } else { $null }
        $jsonBody = $item | ConvertTo-Json
    
        #validting timestamp filed
        ValidateTimestampField -timestampField $timestampField -timestampFieldValue $timestampFieldValue        
    }

    #calling main PostData method
    PostData -customerId $customerId -sharedKey $sharedKey -body $jsonBody -logType $logType -resource $resource -apiVersion $apiVersion -timestampField $timestampFieldId
}

# Invoke the code
PostRecordsToOMS
