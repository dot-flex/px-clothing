$ErrorActionPreference = 'Stop'
$resourceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$entries = @()
$textExtensions = @('.lua', '.js', '.mjs', '.css', '.html', '.json', '.ps1')
$imageExtensions = @('.png', '.webp', '.jpg', '.jpeg')
$utf8 = [System.Text.UTF8Encoding]::new($false)
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    foreach ($file in (Get-ChildItem -LiteralPath $resourceRoot -File -Recurse | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($resourceRoot.Length + 1).Replace('\', '/')
        if ($relative -eq 'config.lua' -or $relative -eq 'data/integrity.json') { continue }
        if ($relative -ne 'fxmanifest.lua' -and $relative -notmatch '^(client|server|shared|locales|scripts|web|data)/') { continue }
        $extension = $file.Extension.ToLowerInvariant()
        if ($imageExtensions -contains $extension) {
            $entries += [ordered]@{ path = $relative; mode = 'size'; bytes = $file.Length }
        } elseif ($textExtensions -contains $extension -or $extension -in @('.woff2', '.ttf')) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $mode = 'binary'
            if ($textExtensions -contains $extension) {
                $text = $utf8.GetString($bytes).TrimStart([char]0xfeff).Replace([string][char]13 + [char]10, [string][char]10)
                $bytes = $utf8.GetBytes($text)
                $mode = 'text'
            }
            $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
            $entries += [ordered]@{ path = $relative; mode = $mode; sha256 = $hash }
        }
    }
} finally {
    $sha.Dispose()
}
$catalog = [ordered]@{ schema = 1; files = @($entries) } | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $resourceRoot 'data/integrity.json'), $catalog + [Environment]::NewLine, $utf8)
Write-Output ('Integrity catalog updated: {0} files.' -f $entries.Count)
