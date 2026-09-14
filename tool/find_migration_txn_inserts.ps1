Get-ChildItem -Path 'supabase/migrations' -Filter '*.sql' | ForEach-Object {
    $file = $_
    $content = Get-Content $file.FullName -Raw
    $matches = [regex]::Matches($content, 'INSERT\s+INTO\s+(public\.)?transactions\s*\(([^\)]+)\)\s*VALUES\s*\(([^\)]+)\)', 'IgnoreCase')
    foreach ($m in $matches) {
        Write-Output "FILE: $($file.Name)"
        Write-Output "COLS: $($m.Groups[2].Value.Trim())"
        Write-Output "VALS: $($m.Groups[3].Value.Trim())"
        Write-Output "---"
    }
}
