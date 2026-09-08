[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$supabaseUrl = "https://majnuiypsgosbzsaeefc.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzA5NzUsImV4cCI6MjA4NzY0Njk3NX0.M9OIGMQVdF4EACNae8G4pObbumB1fz_kR_xOz1G7chc"

$loginHeaders = @{
    "apikey" = $anonKey
    "Content-Type" = "application/json"
}
$loginBody = @{
    "email" = "broayman422@gmail.com"
    "password" = 'Ayman$_73'
} | ConvertTo-Json

$loginRes = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $loginHeaders -Body $loginBody
$token = $loginRes.access_token
$userId = $loginRes.user.id

$userHeaders = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json; charset=utf-8"
}

Write-Output "=== Investment Plans Details ==="
$plans = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/investment_plans?select=*" -Method Get -Headers $userHeaders
foreach ($p in $plans) {
    Write-Output "Plan ID: $($p.id)"
    Write-Output "Title: $($p.title)"
    Write-Output "Description: $($p.description)"
    Write-Output "Min Amount: $($p.min_amount)"
    Write-Output "Max Amount: $($p.max_amount)"
    Write-Output "Expected Return Rate: $($p.expected_return_rate)%"
    Write-Output "Duration: $($p.duration_days) days"
    Write-Output "Active: $($p.is_active)"
    Write-Output "-----------------------------------"
}
