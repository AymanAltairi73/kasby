$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

Write-Output "Testing direct INSERT into user_investments..."
$testInv = @{
    "user_id" = "7ce89452-c4d8-4867-8343-558148cc2bd9"
    "plan_id" = "3f5970b6-b0c1-4bdd-9a1c-bc8ec45a401e"
    "amount" = 50.0
    "profit_percentage" = 6.0
    "expected_profit" = 3.0
    "status" = "active"
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/user_investments" -Method Post -Headers $headers -Body $testInv
    Write-Output "Direct user_investments insert succeeded!"
    Write-Output ($res | ConvertTo-Json)
    $delUri = "$supabaseUrl/rest/v1/user_investments?id=eq." + $res.id
    Invoke-RestMethod -Uri $delUri -Method Delete -Headers $headers
    Write-Output "Cleaned up user_investments test record."
} catch {
    Write-Output "Direct user_investments insert failed!"
    Write-Output "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Output "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Output "Response body: $($reader.ReadToEnd())"
    }
}
