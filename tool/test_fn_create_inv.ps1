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

# Silver plan ID
$silverPlanId = "3f5970b6-b0c1-4bdd-9a1c-bc8ec45a401e"
$amount = 50.0
$idempotencyKey = [System.Guid]::NewGuid().ToString()

Write-Output "Testing /rpc/fn_create_investment with user token..."
$fnBody = @{
    "p_user_id" = $userId
    "p_plan_id" = $silverPlanId
    "p_amount" = $amount
    "p_idempotency_key" = $idempotencyKey
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/fn_create_investment" -Method Post -Headers $userHeaders -Body $fnBody
    Write-Output "fn_create_investment Response:"
    Write-Output ($res | ConvertTo-Json -Depth 5)
} catch {
    Write-Output "fn_create_investment Failed!"
    Write-Output "Message: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Output "Response body: $($reader.ReadToEnd())"
    }
}
