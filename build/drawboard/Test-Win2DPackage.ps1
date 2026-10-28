<#
.SYNOPSIS
  Checks a Win2D.uwp package before it's published to the Drawboard.Win2D feed.

.DESCRIPTION
  Fails on what has gone wrong before: our 1.28.3 shipped a 5 KB Microsoft.Graphics.Canvas.Interop.dll with
  nothing in it (the projection had no winmd to read), so .NET apps couldn't use the package. It also checks
  that every platform the apps ship has its DLL and PDB, of the right CPU type, built from this version and commit.

.PARAMETER Package
  The .nupkg.

.PARAMETER Version
  The package version expected, build\nuget\VERSION (plus -VERSION-PRERELEASE).

.PARAMETER GitHash
  The commit the package should be built from. Omit to skip that check.
#>
param(
  [Parameter(Mandatory = $true)][string]$Package,
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$GitHash
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$failures = New-Object System.Collections.Generic.List[string]
function Check([bool]$ok, [string]$what)
{
  if ($ok) { Write-Host "  ok    $what" } else { Write-Host "  FAIL  $what"; $failures.Add($what) }
}

function Read-Entry($zip, [string]$name)
{
  $reader = New-Object System.IO.StreamReader($zip.GetEntry($name).Open())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

# IMAGE_FILE_HEADER.Machine, after the PE signature that e_lfanew points to
function Get-PeMachine([byte[]]$bytes)
{
  $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
  return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

Write-Host "Checking $Package"
$Package = (Resolve-Path $Package).Path
$zip = [System.IO.Compression.ZipFile]::OpenRead($Package)
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory $scratch | Out-Null
try
{
  $entries = @{}
  foreach ($entry in $zip.Entries) { $entries[$entry.FullName] = $entry }

  $nuspec = [xml](Read-Entry $zip 'Win2D.uwp.nuspec')
  Check ($nuspec.package.metadata.version -eq $Version) "version $($nuspec.package.metadata.version) is $Version"

  $packagedHash = (Read-Entry $zip 'Win2d.githash.txt').Trim()
  if ($GitHash) { Check ($packagedHash -eq $GitHash) "built from $GitHash (Win2d.githash.txt: $packagedHash)" }

  $required = @(
    'include/Microsoft.Graphics.Canvas.h'
    'include/Microsoft.Graphics.Canvas.native.h'
    'lib/uap10.0/Microsoft.Graphics.Canvas.winmd'
    'lib/uap10.0/Microsoft.Graphics.Canvas.xml'
    'lib/net45/Microsoft.Graphics.Canvas.winmd'
    'lib/net45/Microsoft.Graphics.Canvas.xml'
    'lib/net8.0-windows10.0.19041.0/Microsoft.Graphics.Canvas.Interop.dll'
    'lib/net8.0-windows10.0.19041.0/Microsoft.Graphics.Canvas.Interop.xml'
  )
  foreach ($name in $required) { Check $entries.ContainsKey($name) $name }

  # The real projection is over 1 MB; the empty one was 5 KB
  $projection = $entries['lib/net8.0-windows10.0.19041.0/Microsoft.Graphics.Canvas.Interop.dll']
  if ($projection) { Check ($projection.Length -gt 1MB) "the .NET projection is $([int]($projection.Length / 1KB)) KB (an empty one is about 5 KB)" }

  # The DLL's version resource comes from build\nuget\VERSION alone, without the prerelease part
  $dllVersion = $Version.Split('-')[0]
  $machines = [ordered]@{ 'x86' = 0x14C; 'x64' = 0x8664; 'arm64' = 0xAA64 }
  foreach ($arch in $machines.Keys)
  {
    $dll = "runtimes/win-$arch/native/Microsoft.Graphics.Canvas.dll"
    $pdb = "runtimes/win-$arch/native/Microsoft.Graphics.Canvas.pdb"
    Check $entries.ContainsKey($pdb) $pdb
    if (-not $entries.ContainsKey($dll)) { Check $false $dll; continue }

    $file = Join-Path $scratch "$arch.dll"
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entries[$dll], $file)
    $machine = Get-PeMachine ([System.IO.File]::ReadAllBytes($file))
    Check ($machine -eq $machines[$arch]) ("$dll is {0} (0x{1:X})" -f $arch, $machine)
    $productVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file).ProductVersion
    Check ($productVersion -eq "$dllVersion ($packagedHash)") "$dll is version '$productVersion'"
  }
}
finally
{
  $zip.Dispose()
  Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) { throw "$($failures.Count) package check(s) failed: $($failures -join '; ')" }
Write-Host 'The package looks right.'
