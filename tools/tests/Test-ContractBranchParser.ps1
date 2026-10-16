param([string]$Scanner=(Join-Path $PSScriptRoot '../Test-ContractParameterKeys.ps1'),[string]$OutputPath='')
$ErrorActionPreference='Stop'
$source=Get-Content -Raw -LiteralPath $Scanner
$main=$source.IndexOf('if ($SelfTest)')
if($main -lt 0){throw 'Scanner function-library boundary not found'}
$library=[scriptblock]::Create($source.Substring(0,$main))
. $library -AppFolder $PSScriptRoot -AllowListPath (Join-Path $PSScriptRoot 'empty.txt')
$cases=@(
 @{name='last-if-terminated-before-case-else';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b'); else Read('default'); end;";expected=@('b')},
 @{name='last-block-terminated-before-case-else';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then begin Read('b'); end; else Read('default'); end;";expected=@('b')},
 @{name='inner-if-else-without-terminator';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b') else Read('inner'); else Read('default'); end;";expected=@('b','inner')},
 @{name='inner-block-else-without-terminator';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then begin Read('b'); end else begin Read('inner'); end; else Read('default'); end;";expected=@('b','inner')},
 @{name='nested-if-dangling-else';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then if Other then Read('b') else Read('inner'); else Read('default'); end;";expected=@('b','inner')},
 @{name='first-arm-selected';mode='A';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b'); else Read('default'); end;";expected=@('a')},
 @{name='default-selected';mode='C';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b'); else Read('default'); end;";expected=@('default')},
 @{name='no-default-no-match';mode='C';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b'); end;";expected=@()},
 @{name='if-true-nested-case-else';mode='B';flag=$true;code="case Mode of 'A': Read('a'); 'B': if Flag then Read('b'); else Read('default'); end;";expected=@('b')},
 @{name='if-false-nested-case-else';mode='B';flag=$false;code="case Mode of 'A': Read('a'); 'B': if Flag then Read('b'); else Read('default'); end;";expected=@()},
 @{name='if-true-owned-else';mode='B';flag=$true;code="case Mode of 'A': Read('a'); 'B': if Flag then Read('b') else Read('inner'); else Read('default'); end;";expected=@('b')},
 @{name='if-false-owned-else';mode='B';flag=$false;code="case Mode of 'A': Read('a'); 'B': if Flag then Read('b') else Read('inner'); else Read('default'); end;";expected=@('inner')}
 ,@{name='outer-if-preserves-dangling-else';mode='B';flag=$false;code="if Unknown then if Flag then Read('a') else Read('b') else Read('outer');";expected=@('b','outer')}
 ,@{name='outer-if-preserves-then-choice';mode='B';flag=$true;code="if Unknown then if Flag then Read('a') else Read('b') else Read('outer');";expected=@('a','outer')}
 ,@{name='case-without-terminator-under-if';mode='B';code="if Unknown then case Mode of 'A': Read('a'); 'B': Read('b'); end else Read('outer');";expected=@('b','outer')}
 ,@{name='empty-case-without-terminator-under-if';mode='C';code="if Unknown then case Mode of 'A': Read('a'); 'B': Read('b'); end else Read('outer');";expected=@('outer')}
 ,@{name='case-in-else-arm';mode='B';code="if Unknown then Read('outer') else case Mode of 'A': Read('a'); 'B': Read('b'); end;";expected=@('b','outer')}
 ,@{name='comment-does-not-close-if';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b') /* ; else */ else Read('inner'); else Read('default'); end;";expected=@('b','inner')}
 ,@{name='quoted-terminator-is-data';mode='B';code="case Mode of 'A': Read('a'); 'B': if Unknown then Read('b; else') else Read('inner'); else Read('default'); end;";expected=@('b; else','inner')}
 ,@{name='multiple-case-labels';mode='B';code="case Mode of 'A','B': if Unknown then Read('b'); else Read('default'); end;";expected=@('b')}

 ,@{name='case-for-loop-arm';mode='B';code="case Mode of 'A': Read('a'); 'B': for Index := 1 to 3 do if Unknown then Read('b'); else Read('default'); end;";expected=@('b')}
 ,@{name='case-foreach-loop-arm';mode='B';code="case Mode of 'A': Read('a'); 'B': foreach Entry in Values do begin Read('b'); end; else Read('default'); end;";expected=@('b')}
 ,@{name='case-while-loop-arm';mode='B';code="case Mode of 'A': Read('a'); 'B': while Unknown do if Other then Read('b') else Read('inner'); else Read('default'); end;";expected=@('b','inner')}
 ,@{name='if-owns-for-loop-else';mode='B';code="if Unknown then for Index := 1 to 3 do Read('b') else Read('outer');";expected=@('b','outer')}
 ,@{name='known-if-owns-foreach-else';mode='B';flag=$false;code="if Flag then foreach Entry in Values do Read('a') else Read('b');";expected=@('b')}
 ,@{name='case-inside-for-loop';mode='B';code="for Index := 1 to 3 do case Mode of 'A': Read('a'); 'B': Read('b'); else Read('default'); end;";expected=@('b')}

)
$results=@()
foreach($case in $cases){
 $body="procedure Demo(Mode: Text)`nbegin`n$($case.code)`nend;"
 $bindings=@{mode=$case.mode};if($case.ContainsKey('flag')){$bindings.flag=$case.flag}
 $actual=Select-KnownRuntimeBranches $body $bindings
 $reads=@([regex]::Matches($actual,"Read\('([^']+)'\)") | ForEach-Object {$_.Groups[1].Value} | Sort-Object -Unique)
 $expected=@($case.expected | Sort-Object -Unique)
 $pass=($reads -join '|') -ceq ($expected -join '|')
 $results+=@{name=$case.name;passed=$pass;actual=$reads;expected=$expected;prunedSource=$actual}
}
$report=@{kind='isolated AL branch parser source controls; not runtime acceptance';executed=$results.Count;passed=@($results | Where-Object passed).Count;failed=@($results | Where-Object {-not $_.passed}).Count;skipped=0;results=$results}
$json=$report | ConvertTo-Json -Depth 10
if($OutputPath){Set-Content -LiteralPath $OutputPath -Value $json}
Write-Output $json
if($report.failed -gt 0){exit 1}
