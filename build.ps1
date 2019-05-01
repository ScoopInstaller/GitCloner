Push-Location $PSScriptRoot

# Prepare
$build = "$PSScriptRoot\build"
$dist = "$PSScriptRoot\dist"
New-Item -ItemType Directory -Path $build -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $dist -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$build\*" -Recurse -Force | Out-Null
Remove-Item "$dist\*" -Recurse -Force | Out-Null

# Build
Copy-Item "$PSScriptRoot\src\gitcloner.ps1" $build
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp\lib\net46\LibGit2Sharp.dll" $build
New-Item -ItemType Directory -Path "$build\lib\win32\x64\" -ErrorAction SilentlyContinue | Out-Null
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp.NativeBinaries\runtimes\win-x64\native\git2-*.dll" "$build\lib\win32\x64\"
New-Item -ItemType Directory -Path "$build\lib\win32\x86\" -ErrorAction SilentlyContinue | Out-Null
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp.NativeBinaries\runtimes\win-x86\native\git2-*.dll" "$build\lib\win32\x86\"

# Checksums
Write-Output 'Computing checksums ...'
Get-ChildItem "$build\*" -Include *.ps1,*.dll -Recurse | ForEach-Object {
    $checksum = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    "$checksum *$($_.FullName.Replace($build, '').TrimStart('\'))" | Tee-Object -FilePath "$build\checksums.sha256" -Append
}

# Package
7z a "$dist\gitcloner.zip" "$build\*"
Get-ChildItem "$dist\*" | ForEach-Object {
    $checksum = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    "$checksum *$($_.Name)" | Tee-Object -FilePath "$dist\$($_.Name).sha256" -Append
}
Pop-Location
