param(
    [switch]$VerifyOnly,
    [ValidateSet('ot3_ffa_epic', 'ot3_ffa_epic_draft', 'ot3_ffa_draft')]
    [string]$TargetMap = 'ot3_ffa_epic'
)

$ErrorActionPreference = 'Stop'
$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sourceMap = 'ot3_necropolis_ffa'
$sourcePackage = Join-Path $addonRoot "maps/$sourceMap.vpk"
$targetPackage = Join-Path $addonRoot "maps/$targetMap.vpk"
$sourceOverview = Join-Path $addonRoot "resource/overviews/$sourceMap.txt"
$targetOverview = Join-Path $addonRoot "resource/overviews/$targetMap.txt"
# The engine loads minimap calibration by the actual map name, outside its VPK.
# Keep the original terrain material and projection; only rename the KV root.
$overview = [System.IO.File]::ReadAllText($sourceOverview)
if (-not $overview.StartsWith($sourceMap)) { throw 'Unexpected source overview root' }
$overview = $targetMap + $overview.Substring($sourceMap.Length)

if (-not ('EpicOnlyMapPackage' -as [type])) {
    Add-Type -Path @((Join-Path $PSScriptRoot 'MapPackage.cs'), (Join-Path $PSScriptRoot 'MapResourceAliases.cs'))
}

if ($VerifyOnly) {
    [EpicOnlyMapPackage]::VerifyClone($sourcePackage, $targetPackage, $sourceMap, $targetMap)
    if (-not (Test-Path -LiteralPath $targetOverview) -or [System.IO.File]::ReadAllText($targetOverview) -cne $overview) {
        throw "Missing or incorrect minimap overview: $targetOverview"
    }
} else {
    [EpicOnlyMapPackage]::Build($sourcePackage, $targetPackage, $sourceMap, $targetMap)
    [System.IO.File]::WriteAllText($targetOverview, $overview, (New-Object System.Text.UTF8Encoding($false)))
}
Write-Output "Verified minimap overview: $targetMap inherits FFA terrain material, position and scale."
