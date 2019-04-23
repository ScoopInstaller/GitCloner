Push-Location $PSScriptRoot

Get-ChildItem env:

# Prepare
$build = "$PSScriptRoot\build"
$dist = "$PSScriptRoot\dist"
New-Item -ItemType Directory -Path $build -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $dist -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$build\*" -Recurse -Force | Out-Null
Remove-Item "$dist\*" -Recurse -Force | Out-Null

# Build
Copy-Item "$PSScriptRoot\scoop-clone.ps1" $build
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp\lib\net46\LibGit2Sharp.dll" $build
New-Item -ItemType Directory -Path "$build\lib\win32\x64\" -ErrorAction SilentlyContinue | Out-Null
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp.NativeBinaries\runtimes\win-x64\native\git2-*.dll" "$build\lib\win32\x64\"
New-Item -ItemType Directory -Path "$build\lib\win32\x86\" -ErrorAction SilentlyContinue | Out-Null
Copy-Item "$PSScriptRoot\packages\LibGit2Sharp.NativeBinaries\runtimes\win-x86\native\git2-*.dll" "$build\lib\win32\x86\"

# Checksums
Write-Output 'Computing checksums ...'
Get-ChildItem "$build\*" -Include *.ps1,*.dll -Recurse | ForEach-Object {
    $checksum = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $line = "$checksum *$($_.FullName.Replace($build, '').TrimStart('\'))"
    Write-Output $line
    $line | Out-File "$build\checksums.sha256" -Append -Encoding oem
}

# Package
7z a "$dist\scoop-clone.zip" "$build\*"
Get-ChildItem "$dist\*" | ForEach-Object {
    $checksum = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $line = "$checksum *$($_.Name)"
    Write-Output $line
    $line | Out-File "$dist\$($_.Name).sha256" -Append -Encoding oem
}
Pop-Location

Write-Output 'Generating release notes ...'
#region GitHub release notes
$previousRelease = (Invoke-RestMethod -Uri "https://api.github.com/repos/$env:APPVEYOR_REPO_NAME/releases/latest?access_token=$env:GITHUB_ACCESS_TOKEN")
$compare = (Invoke-RestMethod -Uri "https://api.github.com/repos/$env:APPVEYOR_REPO_NAME/compare/$($previousRelease.target_commitish)...$env:APPVEYOR_REPO_COMMIT`?access_token=$env:GITHUB_ACCESS_TOKEN")
$releaseNotes = "## Release Notes`n#### Version [$env:APPVEYOR_REPO_TAG_NAME](https://github.com/$env:APPVEYOR_REPO_NAME/tree/$env:APPVEYOR_REPO_TAG_NAME)`n"

if($null -ne $compare.commits -and $compare.commits.Length -gt 0) {
    $releaseNotes += "`nCommit | Description`n--- | ---`n"
    $contributions = @{}
    $compare.commits | Sort-Object -Property @{Expression={$_.commit.author.date};} -Descending | ForEach-Object {
        $commitMessage = $_.commit.message.Replace("`r`n"," ").Replace("`n"," ");
        if ($commitMessage.ToLower().StartsWith('merge') -or
            $commitMessage.ToLower().StartsWith('merging') -or
            $commitMessage.ToLower().StartsWith('private')) {
                continue
        }
        $releaseNotes += "[``$($_.sha.Substring(0, 7))``](https://github.com/$env:APPVEYOR_REPO_NAME/tree/$($_.sha)) | $commitMessage`n"
        $contributions.$($_.author.login)++
    }
    $releaseNotes += "`nContributor | Commits`n--- | ---`n"
    $contributions.GetEnumerator() | Sort-Object -Property @{Expression={$_.Value}} -Descending | ForEach-Object {
        $releaseNotes += "@$($_.Name) | $($_.Value)`n"
    }
} else {
    $releaseNotes += "There are no new items for this release."
}

$env:GITHUB_RELEASE_NOTES = $releaseNotes
Write-Output $releaseNotes
#endregion
