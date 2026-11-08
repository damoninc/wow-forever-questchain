param(
    [string]$QuestieDBPath = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\QuestieDB'
)

$ErrorActionPreference = 'Stop'
$questieTypes = Join-Path $QuestieDBPath 'Types'
if (-not (Test-Path -LiteralPath (Join-Path $questieTypes 'LibQuestieDB.t.lua'))) {
    throw 'QuestieDB declarations are missing. Pass the installed QuestieDB addon directory with -QuestieDBPath.'
}

$cache = Join-Path (Split-Path -Parent $PSScriptRoot) '.wow-types'
$forever = Join-Path $cache 'forever'
$frameXml = Join-Path $cache 'framexml'
$questie = Join-Path $cache 'questiedb'
New-Item -ItemType Directory -Force -Path $forever, $frameXml, $questie | Out-Null

# Forever 1.60.1.70790 client export. A checkout keeps only the setup recipe.
$foreverRevision = '1b8fa2898e15d20dfbffdcdaf6264df3d708f225'
$foreverUrl = "https://raw.githubusercontent.com/Atraeau/WoW-Addons/$foreverRevision/types/WowForeverAPI.lua"
Invoke-WebRequest -UseBasicParsing $foreverUrl -OutFile (Join-Path $forever 'WowForeverAPI.lua')

# Use the shared widget types and helpers alongside the Forever namespaces.
$version = '0.22.3'
$archivePath = Join-Path $cache "vscode-wow-api-$version.zip"
Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/Ketho/vscode-wow-api/zip/refs/tags/$version" -OutFile $archivePath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $prefix = "vscode-wow-api-$version/Annotations/Core/"
    $filePattern = '^' + [regex]::Escape($prefix) + '(Widget/[\w/-]+\.lua|Type/BlizzardType\.lua|FrameXML/Blizzard_(SharedXML/Backdrop|FrameXML/UIParent)\.lua)$'
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match $filePattern) {
            $destination = Join-Path $frameXml $Matches[1]
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        }
    }
    $license = $archive.GetEntry("vscode-wow-api-$version/LICENSE")
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($license, (Join-Path $frameXml 'LICENSE'), $true)
} finally {
    $archive.Dispose()
    Remove-Item -LiteralPath $archivePath
}

Get-ChildItem -LiteralPath $questieTypes -File -Filter '*.t.lua' |
    Copy-Item -Destination $questie
Write-Output "Installed LuaLS declarations in $cache"
