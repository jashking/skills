[CmdletBinding()]
param(
  [ValidateSet("repo", "claude", "codex", "agents")]
  [string]$Target = "repo",

  [string]$HomePath = $HOME
)

$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$SkillRoot = Join-Path $Repo "skills"

$Destinations = @{
  claude = Join-Path $HomePath ".claude\skills"
  codex  = Join-Path $HomePath ".codex\skills"
  agents = Join-Path $HomePath ".agents\skills"
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

  return "[windows reparse point]"
}

if ($Target -eq "repo") {
  Get-ChildItem -LiteralPath $SkillRoot -Filter "SKILL.md" -Recurse -File |
    Where-Object {
      $_.FullName -notmatch '[\\/]node_modules[\\/]'
    } |
    Sort-Object FullName |
    ForEach-Object {
      $_.FullName.Substring($Repo.Length + 1).Replace("\", "/")
    }

  return
}

$destPath = $Destinations[$Target]
if (-not (Test-Path -LiteralPath $destPath)) {
  Write-Error "No skills directory found: $destPath"
  exit 1
}

Get-ChildItem -LiteralPath $destPath -Force |
  Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md")
  } |
  Sort-Object Name |
  ForEach-Object {
    $linkTarget = Get-ReparseTarget -Item $_

    if ($linkTarget) {
      "$($_.Name) -> $linkTarget"
    } else {
      $_.Name
    }
  }
