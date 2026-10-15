param(
    [string]$Scanner = (Join-Path $PSScriptRoot '../Test-ContractParameterKeys.ps1'),
    [string]$CasesPath = (Join-Path $PSScriptRoot 'fixtures/request-payload-proof.json'),
    [string]$OutputPath = ''
)
$ErrorActionPreference='Stop'
$scannerSource=Get-Content -Raw -LiteralPath $Scanner
$main=$scannerSource.IndexOf('if ($SelfTest)')
if($main -lt 0){throw 'Scanner function-library boundary not found'}
$library=[scriptblock]::Create($scannerSource.Substring(0,$main))
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('andvari-payload-fixtures-'+[guid]::NewGuid().ToString('N'))
$results=[System.Collections.Generic.List[object]]::new()
try{
    [void](New-Item -ItemType Directory -Path "$fixtureRoot/src" -Force)
    . $library -AppFolder $fixtureRoot -AllowListPath (Join-Path $fixtureRoot 'empty.txt')
    $cases=Get-Content -Raw -LiteralPath $CasesPath | ConvertFrom-Json
    foreach($case in $cases){
        Set-Content -LiteralPath "$fixtureRoot/src/Impl.al" -Value $case.source
        $dependencyFile=Join-Path $fixtureRoot 'src/Argument.al'
        if($null -ne $case.dependency){Set-Content -LiteralPath $dependencyFile -Value $case.dependency}
        elseif(Test-Path -LiteralPath $dependencyFile){Remove-Item -LiteralPath $dependencyFile}
        $objects=Read-Source "$fixtureRoot/src"
        $engine=Get-SourcePayloadReadProof $objects 'Provenance Impl'
        $sites=@($engine.Sites.Values | Where-Object {$_.Key -ceq 'extraKey'})
        $actual=@($sites | Where-Object {$_.Possible}).Count -gt 0
        $passed=$sites.Count -gt 0 -and $actual -eq $case.expectedPossible
        $result=@{name=$case.name;passed=$passed;expectedPossible=$case.expectedPossible;actualPossible=$actual;sites=$sites.Count;invocations=$engine.Invocations}
        if(-not $passed){$result.unresolved=@($engine.Unresolved);$result.source=$case.source}
        $results.Add($result)
    }
}finally{if(Test-Path -LiteralPath $fixtureRoot){Remove-Item -LiteralPath $fixtureRoot -Recurse -Force}}
$cleanup=-not (Test-Path -LiteralPath $fixtureRoot)
$report=@{kind='source proof regression fixtures; not AL/runtime acceptance';executed=$results.Count;passed=@($results | Where-Object {$_.passed}).Count;failed=@($results | Where-Object {-not $_.passed}).Count;skipped=0;ownedFixtureCleanupVerified=$cleanup;scannerSha256=(Get-FileHash -LiteralPath $Scanner -Algorithm SHA256).Hash.ToLowerInvariant();results=@($results)}
$json=$report | ConvertTo-Json -Depth 15
if($OutputPath){Set-Content -LiteralPath $OutputPath -Value $json}
Write-Output $json
if($report.failed -or -not $cleanup){exit 1}
