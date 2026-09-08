$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

Write-Output "Testing direct INSERT into transactions..."
$testTxn = @{
    "user_id" = "7ce89452-c4d8-4867-8343-558148cc2bd9"
    "wallet_id" = "9cd63374-53d6-44d6-a632-31c37d9a873f"
    "type" = "investment"
    "amount" = 0.01
    "status" = "completed"
    "description" = "Test transaction"
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions" -Method Post -Headers $headers -Body $testTxn
    Write-Output "Direct insert succeeded!"
    Write-Output ($res | ConvertTo-Json)
    # clean up test record
    $delUri = "$supabaseUrl/rest/v1/transactions?id=eq." + $res.id
    Invoke-RestMethod -Uri $delUri -Method Delete -Headers $headers
    Write-Output "Cleaned up test record."
} catch {
    Write-Output "Direct insert failed!"
    Write-Output "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Output "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Output "Response body: $($reader.ReadToEnd())"
    }
}
