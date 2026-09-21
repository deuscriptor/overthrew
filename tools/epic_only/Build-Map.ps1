param(
    [switch]$VerifyOnly,
    [ValidateSet('ot3_necropolis_ffa_epic_only', 'ot3_necropolis_ffa_epic_only_single_draft', 'ot3_necropolis_ffa_single_draft')]
    [string]$TargetMap = 'ot3_necropolis_ffa_epic_only'
)

$ErrorActionPreference = 'Stop'
$addonRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sourceMap = 'ot3_necropolis_ffa'
$sourcePackage = Join-Path $addonRoot "maps/$sourceMap.vpk"
$targetPackage = Join-Path $addonRoot "maps/$targetMap.vpk"

if (-not ('EpicOnlyMapPackage' -as [type])) {
    Add-Type -Path @((Join-Path $PSScriptRoot 'MapPackage.cs'), (Join-Path $PSScriptRoot 'MapResourceAliases.cs'))
}

if ($VerifyOnly) {
    [EpicOnlyMapPackage]::VerifyClone($sourcePackage, $targetPackage, $sourceMap, $targetMap)
} else {
    [EpicOnlyMapPackage]::Build($sourcePackage, $targetPackage, $sourceMap, $targetMap)
}
