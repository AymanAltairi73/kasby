$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
}

$spec = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/" -Method Get -Headers $headers
$txnProps = $spec.definitions.transactions.properties
Write-Output "=== TRANSACTIONS COLUMNS ==="
$txnProps.PSObject.Properties | ForEach-Object {
    Write-Output "$($_.Name): $($_.Value.type) ($($_.Value.format))"
}
