[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet("all", "claude", "codex", "agents")]
  [string[]]$Target = @("all"),

  [string]$HomePath = $HOME
)

$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$SkillRoot = Join-Path $Repo "skills"

$Destinations = [ordered]@{
  claude = Join-Path $HomePath ".claude\skills"
  codex  = Join-Path $HomePath ".codex\skills"
  agents = Join-Path $HomePath ".agents\skills"
}

function Test-IsUnderPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Parent
  )

  $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $fullParent = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

  return $fullPath.Equals($fullParent, [StringComparison]::OrdinalIgnoreCase) -or
    $fullPath.StartsWith("$fullParent$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase) -or
    $fullPath.StartsWith("$fullParent$([IO.Path]::AltDirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)
}

function Get-ReparseTarget {
  param(
    [Parameter(Mandatory = $true)]
    [IO.FileSystemInfo]$Item
  )

  if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
    return $null
  }

  if ($Item.Target) {
    if ($Item.Target -is [array]) {
      return ($Item.Target -join ", ")
    }

    return $Item.Target
  }

  if ($Item.LinkTarget) {
    return $Item.LinkTarget
  }

  return $null
}

function Remove-LinkOrDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $item = Get-Item -LiteralPath $Path -Force

  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Remove-Item -LiteralPath $item.FullName -Force
    return
  }

  Remove-Item -LiteralPath $item.FullName -Recurse -Force
}

function Get-SelectedDestinations {
  if ($Target -contains "all") {
    return $Destinations.GetEnumerator()
  }

  $seen = @{}
  foreach ($name in $Target) {
    if ($seen.ContainsKey($name)) {
      continue
    }

    $seen[$name] = $true
    [pscustomobject]@{
      Key   = $name
      Value = $Destinations[$name]
    }
  }
}

$skills = Get-ChildItem -LiteralPath $SkillRoot -Filter "SKILL.md" -Recurse -File |
  Where-Object {
    $_.FullName -notmatch '[\\/](node_modules|deprecated)[\\/]'
  } |
  Sort-Object FullName |
  ForEach-Object {
    [pscustomobject]@{
      Name   = $_.Directory.Name
      Source = $_.Directory.FullName
    }
  }

$duplicates = $skills | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($duplicates) {
  $names = ($duplicates | ForEach-Object { $_.Name }) -join ", "
  throw "Duplicate skill directory names would collide in the destination: $names"
}

foreach ($dest in Get-SelectedDestinations) {
  $destPath = $dest.Value

  if (Test-Path -LiteralPath $destPath) {
    $destItem = Get-Item -LiteralPath $destPath -Force
    $destTarget = Get-ReparseTarget -Item $destItem

    if ($destTarget) {
      $resolvedDest = (Resolve-Path -LiteralPath $destPath).Path
      if (Test-IsUnderPath -Path $resolvedDest -Parent $Repo) {
        throw "$destPath is a link into this repository ($resolvedDest). Remove it and rerun this script."
      }
    }
  } elseif ($PSCmdlet.ShouldProcess($destPath, "Create skills directory")) {
    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
  }

  if (-not (Test-Path -LiteralPath $destPath)) {
    continue
  }

  foreach ($skill in $skills) {
    $targetPath = Join-Path $destPath $skill.Name

    if ($PSCmdlet.ShouldProcess($targetPath, "Link to $($skill.Source)")) {
      Remove-LinkOrDirectory -Path $targetPath
      New-Item -ItemType Junction -Path $targetPath -Target $skill.Source | Out-Null
      Write-Output "linked $($skill.Name) -> $($skill.Source) ($destPath)"
    }
  }
}
