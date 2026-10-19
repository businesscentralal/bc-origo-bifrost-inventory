param(
    [string[]] $AppFile,
    [string] $AppType,
    [hashtable] $CompilationParams
)

# Run-AlPipeline passes returned package, app type and FINAL parameters positionally.
# Alpaca translation precompiles do not invoke this hook and cannot satisfy it.
& (Join-Path $env:GITHUB_WORKSPACE 'tools/Assert-AppSourceBuild.ps1') `
    -Stage PostCompile -AppFile $AppFile -AppType $AppType -CompilationParams $CompilationParams

# Icelandic xlf parity (#32). The final compile has just written "<App>.g.xlf" into the app's Translations
# folder (createTranslations is off, so Alpaca leaves the committed is-IS.xlf alone). The guard compares the
# committed is-IS.xlf with what tools/Update-IcelandicXlf.ps1 generates from that g.xlf and fails the build
# on any orphan, missing, reordered or changed unit. It works on a temporary copy and writes nothing here.
if ($AppType -eq 'app') {
    $translations = Join-Path $CompilationParams.appProjectFolder 'Translations'
    # The guard ends without exit on success, so clear an exit code left by an earlier native command.
    $global:LASTEXITCODE = 0
    &(Join-Path $env:GITHUB_WORKSPACE 'tools/Test-IcelandicXlfInSync.ps1') -TranslationsFolder $translations
    if ($LASTEXITCODE -ne 0) {
        throw 'The committed is-IS.xlf is not what tools/Update-IcelandicXlf.ps1 generates from this build (#32).'
    }
}
