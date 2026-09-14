Get-ChildItem -Path @('supabase', 'sql') -Recurse -Filter '*.sql' | ForEach-Object {
    $file = $_
    $lines = Get-Content $file.FullName
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match 'INTO\s+(public\.)?transactions\b') {
            $snippet = ($lines[[Math]::Max(0, $i-2)..[Math]::Min($lines.Length-1, $i+8)]) -join "`n"
            Write-Output "=== FILE: $($file.Name):$($i+1) ==="
            Write-Output $snippet
            Write-Output ""
        }
    }
}
