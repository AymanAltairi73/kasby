$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
}

# 1. Test with a real transaction id from transactions table
$tx = (Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?limit=1" -Headers $headers)[0]
Write-Output "Testing with transaction id $($tx.id)..."
$body1 = @{ "p_transaction_id" = $tx.id } | ConvertTo-Json
$res1 = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/fn_get_transaction_details" -Method Post -Headers $headers -Body $body1
Write-Output "Result for transactions: $($res1 | ConvertTo-Json)"

# 2. Test with a point_history id
$ph = (Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/point_history?limit=1" -Headers $headers)[0]
Write-Output "`nTesting with point_history id $($ph.id)..."
$body2 = @{ "p_transaction_id" = $ph.id } | ConvertTo-Json
try {
    $res2 = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/fn_get_transaction_details" -Method Post -Headers $headers -Body $body2
    Write-Output "Result for point_history: $($res2 | ConvertTo-Json)"
} catch {
    Write-Output "Error for point_history: $($_.Exception.Message)"
}
