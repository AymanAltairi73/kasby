$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5EoQZEgv9HmYLYIlF14vzd6u3qNX9LmJB-RtzE4sA1Q"

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
}

Write-Output "Testing PATCH on transactions..."
$patchBody = @{
    "description" = "Updated test description"
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/transactions?id=eq.f8cd0b3a-7f7b-4229-9965-42596b5396c4" -Method Patch -Headers $headers -Body $patchBody
    Write-Output "PATCH succeeded!"
} catch {
    Write-Output "PATCH failed!"
    Write-Output "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Output "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Output "Response body: $($reader.ReadToEnd())"
    }
}
