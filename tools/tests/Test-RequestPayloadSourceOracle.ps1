param([string]$Scanner,[string]$CasesPath,[string]$Output)
$ErrorActionPreference='Stop'
$scannerSource=Get-Content -Raw -LiteralPath $Scanner
$main=$scannerSource.IndexOf('if ($SelfTest)')
if($main -lt 0){throw 'Scanner function-library boundary not found'}
$library=[scriptblock]::Create($scannerSource.Substring(0,$main))
. $library -AppFolder $PSScriptRoot -AllowListPath (Join-Path $PSScriptRoot 'empty.txt')
$programs=Get-Content -Raw -LiteralPath $CasesPath | ConvertFrom-Json
$root=Join-Path ([IO.Path]::GetTempPath()) ('andvari-source-oracle-'+[guid]::NewGuid().ToString('N'))
$checks=0;$matched=0;$missing=0;$excluded=0;$concretePositive=0;$violations=[System.Collections.Generic.List[object]]::new();$programCount=0
try{
 [void](New-Item -ItemType Directory -Path "$root/src" -Force)
 foreach($program in $programs){
  $programCount++
  Set-Content -LiteralPath "$root/src/Impl.al" -Value $program.source
  Set-Content -LiteralPath "$root/src/Argument.al" -Value $program.dependency
  $objects=Read-Source "$root/src";$engine=Get-SourcePayloadReadProof $objects 'Provenance Impl'
  foreach($read in $program.reads){
   $checks++;$id='Provenance Impl::executebifrosttask::'+$read.offset+'::'+$read.variable+'::'+$read.key
   # An absent decision preserves the original scanner's read, never excludes it.
   if($engine.Sites.ContainsKey($id)){$matched++}else{$missing++}
   $possible=-not $engine.Sites.ContainsKey($id) -or $engine.Sites[$id].Possible
   if(-not $possible){$excluded++};if($read.concretePossible){$concretePositive++}
   if($read.concretePossible -and -not $possible){$violations.Add(@{seed=$program.seed;read=$read;site=$engine.Sites[$id];trace=@($engine.State.Trace);source=$program.source})}
  }
 }
}finally{if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}
$cleanup=-not (Test-Path -LiteralPath $root)
@{kind='independent bounded concrete source-program oracle; no AL/runtime acceptance';programs=$programCount;readChecks=$checks;matched=$matched;missing=$missing;excluded=$excluded;concretePositive=$concretePositive;unsoundExclusionsFound=$violations.Count;violations=@($violations);ownedFixtureCleanupVerified=$cleanup;passed=($violations.Count -eq 0 -and $cleanup -and $missing -eq 0 -and $excluded -gt 0 -and $concretePositive -gt 0);scannerSha256=(Get-FileHash -LiteralPath $Scanner -Algorithm SHA256).Hash.ToLowerInvariant()} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Output
if($violations.Count -or -not $cleanup -or $missing -gt 0 -or $excluded -eq 0 -or $concretePositive -eq 0){exit 1}
