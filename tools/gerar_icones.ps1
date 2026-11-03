# Regenera icones preservando os ajustes booleanos do Xcode.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$xcodeProject = Join-Path $projectRoot 'ios/Runner.xcodeproj/project.pbxproj'
$swiftPattern = '(?m)^([ \t]*ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS[ \t]*=[ \t]*)([^;\r\n]+)(;[ \t]*)$'
$original = [IO.File]::ReadAllText($xcodeProject)
$swiftValues = @([regex]::Matches($original, $swiftPattern) | ForEach-Object { $_.Groups[2].Value })
Push-Location -LiteralPath $projectRoot
try {
    & flutter pub run flutter_launcher_icons
    $generationExit = $LASTEXITCODE
    # A versao 0.14.4 altera este flag para AppIcon. Preservar o valor original.
    $generated = [IO.File]::ReadAllText($xcodeProject)
    if ([regex]::Matches($generated, $swiftPattern).Count -ne $swiftValues.Count) {
        throw 'A estrutura dos ajustes Xcode mudou; confira o project.pbxproj.'
    }
    $swiftCounter = @{ index = 0 }
    $restored = [regex]::Replace($generated, $swiftPattern, {
        param($match)
        $value = $swiftValues[$swiftCounter.index]
        $swiftCounter.index++
        return $match.Groups[1].Value + $value + $match.Groups[3].Value
    })
    [IO.File]::WriteAllText($xcodeProject, $restored, (New-Object Text.UTF8Encoding($false)))
    if ($generationExit -ne 0) { throw 'A geracao de icones nao foi concluida.' }
} finally {
    Pop-Location
}
