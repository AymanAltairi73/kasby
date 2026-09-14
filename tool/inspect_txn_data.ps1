$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
}

Write-Output "=== 1. Distinct currencies in transactions ==="
$currRes = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?select=currency&limit=500" -Method Get -Headers $headers
$currRes | Select-Object -ExpandProperty currency -Unique

Write-Output "=== 2. Distinct types in transactions ==="
$typeRes = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?select=type&limit=500" -Method Get -Headers $headers
$typeRes | Select-Object -ExpandProperty type -Unique

Write-Output "=== 3. Sample 5 transactions ==="
$txSample = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?select=id,user_id,type,amount,fee,currency,status,description,created_at&order=created_at.desc&limit=5" -Method Get -Headers $headers
$txSample | Format-Table -AutoSize

Write-Output "=== 4. Sample 5 point_history ==="
$ptSample = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/point_history?select=*&order=created_at.desc&limit=5" -Method Get -Headers $headers
$ptSample | Format-Table -AutoSize
