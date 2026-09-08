$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
}

$endpoints = @(
    "/pg/query",
    "/rest/v1/rpc/exec_sql",
    "/api/pg-meta/default/query"
)

foreach ($ep in $endpoints) {
    try {
        $body = @{ "query" = "SELECT 1" } | ConvertTo-Json
        $res = Invoke-RestMethod -Uri "$supabaseUrl$ep" -Method Post -Headers $headers -Body $body
        Write-Output "$ep SUCCESS: $($res | ConvertTo-Json)"
    } catch {
        Write-Output "$ep FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Message)"
    }
}
