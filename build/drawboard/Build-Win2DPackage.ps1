<#
.SYNOPSIS
  Builds Drawboard's Win2D.uwp package and checks it: the native DLL for x86, x64 and ARM64 with their PDBs,
  the C#/WinRT projection for modern .NET, the IntelliSense docs, and the .nupkg.

.DESCRIPTION
  .pipelines\Drawboard-Package.yml runs this, and it runs the same way on a developer machine, from any
  PowerShell: it finds Visual Studio 2022 and enters its developer shell itself.

  Needs Visual Studio 2022 (Build Tools will do) with the v143 C++ toolset and its Universal Windows Platform
  support, including ARM64 (Microsoft.VisualStudio.Component.UWP.VC.ARM64), a Windows 10/11 SDK, the .NET SDK,
  and, for the docs, the .NET Framework 4.7.2 targeting pack. The build expects Windows SDK 19041; without it,
  this builds against the newest SDK installed instead.

  The version is build\nuget\VERSION (plus build\nuget\VERSION-PRERELEASE, if set).

.PARAMETER IntellisenseXml
  Package this Microsoft.Graphics.Canvas.xml instead of building the docs, on a machine without the .NET
  Framework 4.7.2 targeting pack. The lib\uap10.0\Microsoft.Graphics.Canvas.xml in Microsoft's Win2D.uwp package of
  the version this fork is merged up to (build\nuget\VERSION's first three parts) is the same file, since the fork
  hasn't changed winrt\docsrc.

.PARAMETER Clean
  Delete bin\ and obj\ first.

.OUTPUTS
  The path of the package, bin\Win2D.uwp.<version>.nupkg.
#>
param(
  [string]$IntellisenseXml,
  [switch]$Clean
)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$version = (Get-Content (Join-Path $repo 'build\nuget\VERSION') -TotalCount 1).Trim()
$preRelease = (Get-Content (Join-Path $repo 'build\nuget\VERSION-PRERELEASE') -TotalCount 1 -ErrorAction SilentlyContinue)
if ($preRelease) { $version = "$version-$($preRelease.Trim())" }
Write-Host "Win2D.uwp $version from $repo"

# The reason this fork exists (Win2D #954). A merge from upstream must not quietly drop it.
$baseControl = Join-Path $repo 'winrt\lib\xaml\BaseControl.h'
if (-not (Select-String -Path $baseControl -SimpleMatch '--m_loadedCount < 1' -Quiet))
{
  throw "$baseControl no longer has the fix for Win2D #954 (BaseControl::OnUnloaded: '--m_loadedCount < 1')."
}

# --- Tools ---

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = & $vswhere -products * -version '[17.0,18.0)' -latest -property installationPath `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.Tools.ARM64 Microsoft.VisualStudio.Component.UWP.VC.ARM64
if (-not $vsPath)
{
  throw 'No Visual Studio 2022 with the v143 C++ tools for x64 and ARM64 and their UWP support (Microsoft.VisualStudio.Component.UWP.VC.ARM64).'
}
Import-Module (Join-Path $vsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments '-arch=amd64 -host_arch=amd64' | Out-Null
Write-Host "Visual Studio: $vsPath"

# Win2D.proj and build-nupkg.cmd both call nuget from PATH
$nugetDir = Join-Path $repo 'build\nuget'
if (-not (Get-Command nuget -ErrorAction SilentlyContinue))
{
  if (-not (Test-Path (Join-Path $nugetDir 'nuget.exe')))
  {
    Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile (Join-Path $nugetDir 'nuget.exe')
  }
  $env:PATH = "$nugetDir;$env:PATH"
}

# Without SDK 19041, build against the newest one installed. mdmerge also needs that SDK's
# Windows.Foundation.UniversalApiContract version (winrt\lib\winrt.lib.uap.vcxproj).
$kitsRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' -ErrorAction SilentlyContinue).KitsRoot10
if (-not $kitsRoot) { $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10' }
$sdkArgs = @()
if (-not (Test-Path (Join-Path $kitsRoot 'References\10.0.19041.0')))
{
  $sdk = Get-ChildItem (Join-Path $kitsRoot 'References') -Directory |
    Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'Windows.Foundation.UniversalApiContract')) } |
    Sort-Object { [version]$_.Name } | Select-Object -Last 1
  if (-not $sdk) { throw "No Windows 10/11 SDK under $kitsRoot." }
  $contract = Get-ChildItem (Join-Path $sdk.FullName 'Windows.Foundation.UniversalApiContract') -Directory |
    Sort-Object { [version]$_.Name } | Select-Object -Last 1
  $sdkArgs = @("/p:WindowsTargetPlatformVersion=$($sdk.Name)", "/p:UniversalApiContractVersion=$($contract.Name)")
  Write-Host "Windows SDK 19041 isn't installed; building against $($sdk.Name) (UniversalApiContract $($contract.Name))"
}

# --- Build ---

Push-Location $repo
try
{
  if ($Clean) { Remove-Item -Recurse -Force (Join-Path $repo 'bin'), (Join-Path $repo 'obj') -ErrorAction SilentlyContinue }
  $logDir = Join-Path $repo 'bin\logs'
  New-Item -ItemType Directory -Force $logDir | Out-Null

  # The projection is AnyCPU, and Win2D.proj doesn't restore AnyCPU projects itself
  $env:Platform = 'AnyCPU'
  $env:Configuration = 'Release'
  try { nuget restore Win2D.uap.sln -NonInteractive | Out-Host } finally { Remove-Item env:Platform, env:Configuration }
  if ($LASTEXITCODE -ne 0) { throw "nuget restore failed (exit $LASTEXITCODE)." }

  # Win32 also builds the winmd and the header the package takes; ARM64 builds in its own pass. A response file
  # keeps the semicolons in the platform list away from PowerShell's argument quoting.
  $rsp = Join-Path $logDir 'Win2D.rsp'
  @(
    'Win2D.proj'
    '/m'
    '/nr:false'
    '/v:m'
    '/p:BuildTests=false'
    '/p:BuildTools=false'
    '/p:BuildDocs=false'
    '/p:RunTests=false'
    '/p:BuildPlatforms="Win32;AnyCPU;x64;ARM64"'
    '/p:BuildConfigurations=Release'
    $sdkArgs
    "/bl:`"$logDir\Win2D.binlog`""
  ) | Set-Content -Encoding ascii $rsp
  msbuild "@$rsp" | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Win2D.proj failed (exit $LASTEXITCODE); see $logDir\Win2D.binlog." }

  $intellisenseDir = Join-Path $repo 'bin\intellisense'
  if ($IntellisenseXml)
  {
    New-Item -ItemType Directory -Force $intellisenseDir | Out-Null
    Copy-Item $IntellisenseXml (Join-Path $intellisenseDir 'Microsoft.Graphics.Canvas.xml') -Force
  }
  else
  {
    msbuild tools\docs\BuildDocs.proj /nologo /v:m /p:IntellisenseOnly=true | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "The IntelliSense docs failed (exit $LASTEXITCODE). Without the .NET Framework 4.7.2 targeting pack, pass -IntellisenseXml." }
  }

  # No argument: a release version. build.cmd passes 'local', which makes a -local prerelease.
  & cmd /c (Join-Path $repo 'build\nuget\build-nupkg.cmd') | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "build-nupkg.cmd failed (exit $LASTEXITCODE)." }
}
finally
{
  Pop-Location
}

$package = Join-Path $repo "bin\Win2D.uwp.$version.nupkg"
& (Join-Path $PSScriptRoot 'Test-Win2DPackage.ps1') -Package $package -Version $version -GitHash (git -C $repo rev-parse HEAD) | Out-Host
$package
