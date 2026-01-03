#!/usr/bin/env pwsh
<#
Creates a new Zig project under ./projects/<name>:

- Creates folder
- Runs `zig init` inside it (if build.zig not already present)
- Adds .vscode/tasks.json and .vscode/launch.json from templates
- Replaces placeholders in launch.json:
    __EXE_NAME__         -> exe name (default: folder name)
    __PROGRAM_SUFFIX__   -> ".exe" on Windows, "" otherwise
- (Optional) creates a per-project .code-workspace
- (Optional) opens VS Code

Examples:
  pwsh ./.dev/new-project.ps1 -Name project_two -Open
  pwsh ./.dev/new-project.ps1 -Name dsp_lab -ExeName dsp_lab -Workspace
  pwsh ./.dev/new-project.ps1 -Name foo -Force
#>

param(
  [Parameter(Mandatory=$true)]
  [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_\-]*$')]
  [string] $Name,

  # Optional explicit exe name; default is project folder name
  [string] $ExeName,

  # Create a per-project workspace file: <project>/<name>.code-workspace
  [switch] $Workspace,

  # Open the project folder in VS Code (requires `code` on PATH)
  [switch] $Open,

  # If folder exists, do not error; overwrite template-generated VS Code files
  [switch] $Force
)

$ErrorActionPreference = "Stop"

function Assert-CommandExists([string] $cmd, [string] $hint) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required command '$cmd' not found. $hint"
  }
}

# Repo root is parent of .dev
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") | Select-Object -ExpandProperty Path
$projectsRoot = Join-Path $repoRoot "projects"
$projectDir = Join-Path $projectsRoot $Name

$templateDir = Join-Path $repoRoot ".vstemplate"
$templateTasks = Join-Path $templateDir "tasks.json"
$templateLaunch = Join-Path $templateDir "launch.json"

Assert-CommandExists "zig" "Install Zig and ensure it's on PATH."
if ($Open) { Assert-CommandExists "code" "Install VS Code and enable the 'code' command on PATH." }

if (-not (Test-Path -LiteralPath $projectsRoot)) {
  New-Item -ItemType Directory -Force -Path $projectsRoot | Out-Null
}

if (Test-Path -LiteralPath $projectDir) {
  if (-not $Force) {
    throw "Project folder already exists: $projectDir (use -Force to overwrite template files)"
  }
} else {
  New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
}

if (-not (Test-Path -LiteralPath $templateTasks)) { throw "Missing template: $templateTasks" }
if (-not (Test-Path -LiteralPath $templateLaunch)) { throw "Missing template: $templateLaunch" }

if ([string]::IsNullOrWhiteSpace($ExeName)) {
  $ExeName = $Name
}

# Windows suffix for LLDB "program" path
$programSuffix = if ($IsWindows) { ".exe" } else { "" }

Write-Host "Creating Zig project:"
Write-Host "  Repo:      $repoRoot"
Write-Host "  Project:   $projectDir"
Write-Host "  ExeName:   $ExeName"
Write-Host "  Suffix:    $programSuffix"

# Initialize Zig project (only if build.zig doesn't exist)
Push-Location $projectDir
try {
  $buildZig = Join-Path $projectDir "build.zig"
  if (-not (Test-Path -LiteralPath $buildZig -PathType Leaf)) {
    & zig init | Out-Host
  } else {
    Write-Host "build.zig already exists; skipping 'zig init'."
  }
}
finally {
  Pop-Location
}

# Create .vscode folder
$vscodeDir = Join-Path $projectDir ".vscode"
New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

# Write tasks.json
Copy-Item -LiteralPath $templateTasks -Destination (Join-Path $vscodeDir "tasks.json") -Force

# Write launch.json with placeholders replaced
$launchText = Get-Content -LiteralPath $templateLaunch -Raw
$launchText = $launchText.Replace("__EXE_NAME__", $ExeName)
$launchText = $launchText.Replace("__PROGRAM_SUFFIX__", $programSuffix)
Set-Content -LiteralPath (Join-Path $vscodeDir "launch.json") -Value $launchText -NoNewline

Write-Host "VS Code files created:"
Write-Host "  $($vscodeDir)\tasks.json"
Write-Host "  $($vscodeDir)\launch.json"

# Optional: create a per-project workspace file
if ($Workspace) {
  $wsPath = Join-Path $projectDir "$Name.code-workspace"
  $wsJson = @"
{
  "folders": [
    { "path": "." }
  ],
  "settings": {},
  "extensions": {
    "recommendations": [
      "vadimcn.vscode-lldb"
    ]
  }
}
"@
  Set-Content -LiteralPath $wsPath -Value $wsJson -NoNewline
  Write-Host "Workspace created:"
  Write-Host "  $wsPath"
}

if ($Open) {
  Write-Host "Opening in VS Code..."
  & code $projectDir
}
