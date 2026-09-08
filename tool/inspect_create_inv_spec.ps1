$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
}

$spec = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/" -Method Get -Headers $headers
Write-Output "=== /rpc/create_investment ==="
Write-Output ($spec.paths."/rpc/create_investment".post.parameters | ConvertTo-Json -Depth 5)

Write-Output "`n=== /rpc/fn_create_investment ==="
Write-Output ($spec.paths."/rpc/fn_create_investment".post.parameters | ConvertTo-Json -Depth 5)
