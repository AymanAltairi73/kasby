$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
}

Write-Output "=== Checking transactions with checkin/spin ==="
$tx = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?or=(type.ilike.*spin*,type.ilike.*check*,type.ilike.*daily*,description.ilike.*spin*,description.ilike.*check*)&limit=20" -Method Get -Headers $headers
Write-Output "Found in transactions: $($tx.Count)"
$tx | Select-Object id, type, amount, currency, status, description | Format-Table -AutoSize

Write-Output "`n=== Checking point_history with checkin/spin ==="
$ph = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/point_history?order=created_at.desc&limit=20" -Method Get -Headers $headers
Write-Output "Found in point_history: $($ph.Count)"
$ph | Select-Object id, points, type, description, reference_id, created_at | Format-Table -AutoSize
