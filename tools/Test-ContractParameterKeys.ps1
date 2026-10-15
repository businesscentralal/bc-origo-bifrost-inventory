<#
.SYNOPSIS
    Fails when a message type's contract and its code disagree about the request parameter names (#357, #146 rule 6).

.DESCRIPTION
    A contract lists the parameter names a caller may send under data (the "parameters" chapter). Nothing used to
    compare that list with the keys the implementation reads, so a key renamed in the contract only, or read in the
    code and never documented, stayed unnoticed. This guard reads the AL source under app/src and, for every message
    type that has a contract:

      declared-not-read  A parameter the contract declares, whose name appears as a string literal nowhere in the code
                         the implementation reaches (its own procedures, the codeunits it calls and the procedures
                         of "Message Argument ori" it calls).
                         A literal counts only outside message text (#459). A translatable Label (one that is not
                         Locked = true) and the statement of Error, StrSubstNo, Message, Confirm, RespondWith*,
                         AddError and AddWarning are left out, so a key that appears only there is not a read.
                         A Locked = true label declared in a reached procedure still counts.
                         A parameter that a Parts procedure declares only when a Boolean argument is true
                         ('if WithX then ...', 'if not WithX then exit;') is not declared by a type whose call
                         passes the literal false (#401). Every call has to be understood for that: a call the
                         guard cannot read (an argument that is itself a call, a receiver it cannot resolve)
                         counts as a call that may pass true, so the parameter stays declared (#590). The part
                         after 'if not WithX then exit;' that is cut is the rest of the block that holds the exit.
      read-not-declared  A key the implementation itself reads from the request. The request is any
                         JsonObject variable assigned from GetRequestJson(), the name RequestJson, or a
                         parameter a reached procedure receives when a caller passes that request in.
                         A read is RequestJson.Get/Contains, or any call whose first argument is such a
                         variable and whose second argument is a string literal. A key the parameters and
                         target chapters do not declare is an offender.
                         Also the request: a JsonObject taken from the records of the request data
                         (GetRequestDataArray, then Token.AsObject()), and a variable passed in any argument
                         position of a reached procedure. Message Argument is entered only through its
                         readers: evaluate*, tryevaluate*, apply*, GetTableIdFromRequestJson,
                         GetDateTimeRangeFromRequestJson and FindBankAccReconciliation (ArgumentReaders).
                         A target entry 'data.a + data.b' declares a and b; 'data.x.y' also declares y.
      no-reads-seen      The contract declares at least one parameter and the guard sees no request read.
                         Listed as Type|no-reads-seen|* until a follow-up makes the read visible.

    Shared chapter calls with a literal selector are narrowed to that case. JsonArray literal declarations and
    attached parameter JsonObjects count only on the chapter output; clearing or replacing that output removes
    earlier entries. Foundation typed readers read their literal key from the known request argument. Malformed
    arrays and unresolved selectors/readers remain explicit offenders, never allow-list exemptions.

    Why a source guard and not a runtime recorder (#146 AMB-1): JsonObject.Get is a platform method, so a
    recorder on "Message Argument ori" never sees the direct reads, which are most of them, and a probe request only
    reaches the reads before its first error. The source sees every read on every path.

    The allow-list (tools/ContractParameterKeys.AllowList.txt) holds the offenders that exist today, one
    "Type|rule|key" per line, each with a follow-up issue in a comment line above it. Rules are declared-not-read,
    read-not-declared and no-reads-seen (Type|no-reads-seen|*). It may only shrink: an offender that is
    not listed fails, and so does a listed entry that no longer applies.

.PARAMETER AppFolder
    The AL app folder (default: ../app next to this script).

.PARAMETER AllowListPath
    The allow-list file (default: ContractParameterKeys.AllowList.txt next to this script).

.PARAMETER DependencyAppFolders
    Optional app folders containing the exact dependency source used by the candidate.
    Dependency objects resolve helper calls; only the selected app's message types are scanned.
    Retain dependency commit/artifact provenance with the invocation. Missing source is
    never replaced by a list of assumed keys.

.PARAMETER Explain
    A message type name. Prints the parameters its contract declares, the target keys and the keys the code reads, and
    exits 0 without comparing the allow-list. A name that is not a message type with a contract says so and exits 1.

.PARAMETER SelfTest
    Runs the guard against small synthetic apps and checks that it reports a declared-not-read key, a
    read-not-declared key, a new offender and a stale allow-list entry. Exits 1 when it does not.

.EXAMPLE
    ./tools/Test-ContractParameterKeys.ps1
#>
param(
    [string]$AppFolder = (Join-Path $PSScriptRoot '..\app'),
    [string]$AllowListPath = (Join-Path $PSScriptRoot 'ContractParameterKeys.AllowList.txt'),
    [string[]]$DependencyAppFolders = @(),
    [switch]$SelfTest,
    [string]$Explain = ''
)

$ErrorActionPreference = 'Stop'

# The procedures of "Message Argument ori" that read keys from the request, by name (lower case): the evaluate*, tryevaluate* and
# apply* readers, the table and date range readers, and FindBankAccReconciliation (systemId, recordSystemId, bankAccountNo, statementNo).
$script:ArgumentReaders = '^(evaluate|tryevaluate|apply|gettableidfromrequestjson$|getdatetimerangefromrequestjson$|findbankaccreconciliation$)'

# Keys the platform reads for every call or that are not parameters under data.
$script:NeverParameters = @('data', 'subject', 'type', 'version')

$procedureStart = [regex]::new('^\s*(\[[^\]]*\]\s*)*((local|internal|protected)\s+)?(procedure|trigger)\s+("[^"]+"|\w+)', 'IgnoreCase')
$objectStart = [regex]::new('^\s*(codeunit|table|page|enum|enumextension|interface)\s+\d*\s*"([^"]+)"', 'IgnoreCase')
$varDeclaration = [regex]::new('(?<![\w])(\w+)\s*:\s*(?:Codeunit|Record|Interface)\s+"([^"]+)"', 'IgnoreCase')
$callQualified = [regex]::new('\b(\w+)\.(\w+)\(', 'IgnoreCase')
$codeunitReference = [regex]::new('Codeunit::"([^"]+)"', 'IgnoreCase')
$callUnqualified = [regex]::new('(?<![\.\w])(\w+)\(', 'IgnoreCase')
$labelLiteral = [regex]::new("Label\s+'((?:[^']|'')*)'", 'IgnoreCase')
$stringLiteral = [regex]::new("'((?:[^']|'')*)'")
$targetLiteral = [regex]::new("TargetEntry\(\s*'data\.([^']+)'", 'IgnoreCase')
# A key spec such as 'bankAccountNo=no,bankAccountId=guid' (FindRecordByIdentifiers): the names left of the '=' are request keys.
$keySpec = [regex]::new("'((?:\w+=\w+,?)+)'")
$addRangeTail = '\.AddRange\(\s*((?:''[^'']+''\s*,?\s*)+)\)'
$parameterLiteral = [regex]::new("\.Parameter\(\s*'([^']+)'", 'IgnoreCase')
# Var := Argument.GetRequestJson() (or GetRequestJson()) makes Var the request.
$assignRequest = [regex]::new('(?<![.\w])(\w+)\s*:=\s*(?:\w+\.)?GetRequestJson\(\)', 'IgnoreCase')
# The first parameter of a procedure, so a request passed into it stays the request inside.
$firstParam = [regex]::new('(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(\s*(?:var\s+)?(\w+)\s*:', 'IgnoreCase')
# An unqualified call that passes the request as its first argument: ReadInside(RequestJson) or ReadInside(RequestJson, ...).
$passRequest = [regex]::new('(?<![.\w])(\w+)\s*\(\s*(?:(?<var>\w+)|(?:\w+\.)?GetRequestJson\(\))\s*[,)]', 'IgnoreCase')
# The same, qualified: Argument.TryReadInteger(ReqJson, ...) or Helper.Read(GetRequestJson(), ...).
$passRequestQualified = [regex]::new('\b(\w+)\.(\w+)\s*\(\s*(?:(?<var>\w+)|(?:\w+\.)?GetRequestJson\(\))\s*[,)]', 'IgnoreCase')
# Any call, with its argument list (no nested calls): the request can be passed in any position, not only the first (#431).
$callWithArgs = [regex]::new('(?<![.\w])(?:(?<receiver>\w+)\.)?(?<callee>\w+)\s*\((?<args>[^()]*)\)', 'IgnoreCase')
# Every call, whatever its arguments: the same start as $callWithArgs, or a call through a chain ('GetParts().AddBase(' or 'A.B.C(').
$anyCall = [regex]::new('(?<![.\w])(?:(?<receiver>\w+)\.)?(?<callee>\w+)\s*\(|(?<=[\w)\]]\s*\.\s*)(?<chained>\w+)\s*\(', 'IgnoreCase')
# A JsonObject taken out of an array of records: Obj := Token.AsObject(). In a procedure that calls GetRequestDataArray the
# array is the request data, so Obj is one record of it and its keys are request keys (#431).
$assignRecordObject = [regex]::new('(?<![.\w])(\w+)\s*:=\s*\w+\.AsObject\(\)', 'IgnoreCase')
# Any call whose first argument is the request and whose second is a literal key.
$callRead = [regex]::new("(?:(?<receiver>\b\w+)\.)?(?<callee>\b\w+)\s*\(\s*(?:(?<var>\w+)|(?:\w+\.)?GetRequestJson\(\))\s*,\s*'(?<key>[^']+)'", 'IgnoreCase')
# RequestJson.Get('k'...) / ReqJson.Contains('k'...) / GetRequestJson().Contains('k') (#431).
$memberRead = [regex]::new("(?:\b(?<var>\w+)|GetRequestJson\(\))\.(?:Get|Contains)\(\s*'(?<key>[^']+)'", 'IgnoreCase')

function Read-Source([string]$AppSrc) {
    $objects = @{}
    foreach ($file in Get-ChildItem -LiteralPath $AppSrc -Recurse -Filter '*.al') {
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        $objectName = $null
        $kind = $null
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $m = $objectStart.Match($lines[$i])
            if ($m.Success) { $kind = $m.Groups[1].Value.ToLowerInvariant(); $objectName = $m.Groups[2].Value; $objectLine = $i; break }
        }
        if (-not $objectName) { continue }
        if (-not $objects.ContainsKey($objectName)) {
            $header = ($lines | Select-Object -Skip $objectLine -First 4) -join ' '
            $implements = @()
            $im = [regex]::Match($header, 'implements\s+(.*?)(?:\{|$)', 'IgnoreCase')
            if ($im.Success) { foreach ($n in [regex]::Matches($im.Groups[1].Value, '"([^"]+)"')) { $implements += $n.Groups[1].Value } }
            $tableNoMatch = [regex]::Match(($lines | Select-Object -First 40) -join ' ', 'TableNo\s*=\s*"([^"]+)"')
            $objects[$objectName] = @{ TableNo = $(if ($tableNoMatch.Success) { $tableNoMatch.Groups[1].Value } else { '' }); Implements = $implements; Name = $objectName; Kind = $kind; File = $file.FullName; Lines = $lines; Procedures = @{}; Variables = @{}; Labels = @(); Text = ($lines -join "`n") }
        }
        $object = $objects[$objectName]
        $starts = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($procedureStart.IsMatch($lines[$i])) { $starts += $i }
            foreach ($v in $varDeclaration.Matches($lines[$i])) {
                $varName = $v.Groups[1].Value.ToLowerInvariant()
                if (-not $object.Variables.ContainsKey($varName)) { $object.Variables[$varName] = @() }
                if ($object.Variables[$varName] -notcontains $v.Groups[2].Value) { $object.Variables[$varName] += $v.Groups[2].Value }
            }
            foreach ($l in $labelLiteral.Matches($lines[$i])) { $object.Labels += $l.Groups[1].Value.Replace("''", "'") }
        }
        for ($p = 0; $p -lt $starts.Count; $p++) {
            $name = $procedureStart.Match($lines[$starts[$p]]).Groups[5].Value.Trim('"').ToLowerInvariant()
            $to = if ($p + 1 -lt $starts.Count) { $starts[$p + 1] } else { $lines.Count }
            $body = ($lines[$starts[$p]..($to - 1)] | Where-Object { -not $_.TrimStart().StartsWith('//') }) -join "`n"
            if (-not $object.Procedures.ContainsKey($name)) { $object.Procedures[$name] = @() }
            $object.Procedures[$name] += $body
        }
    }
    return $objects
}

# In ReadMode the walk enters "Message Argument ori" only through the procedures that read the request (see the comment
# at Get-Reach). Everything else in that table is a record lookup or a response writer.
function Test-FollowCall([bool]$ReadMode, [string]$ObjectName, [string]$Callee) {
    if (-not $ReadMode -or $ObjectName -ne 'Message Argument ori') { return $true }
    return $Callee -match $script:ArgumentReaders
}

# The procedures (object, name) reachable from one procedure, following calls through typed codeunit variables and
# Codeunit::"X" references (a codeunit that is run). In ReadMode the walk enters "Message Argument ori" only through
# the evaluate*/tryevaluate*/apply* readers, which read fixed keys; the record lookups of that table read identifier
# keys that the target chapter declares. An unqualified call inside that table is followed only for those readers, so
# Evaluate* forwarding the request into TryEvaluate* still counts as a read.
function Get-Reach($Objects, [string]$ObjectName, [string]$ProcedureName, $Seen, [bool]$ReadMode = $false) {
    $key = "$ObjectName::$ProcedureName"
    if ($Seen.ContainsKey($key)) { return }
    $object = $Objects[$ObjectName]
    if (-not $object -or -not $object.Procedures.ContainsKey($ProcedureName)) { return }
    $Seen[$key] = $true
    foreach ($body in $object.Procedures[$ProcedureName]) {
        foreach ($c in $callQualified.Matches($body)) {
            $target = $c.Groups[1].Value.ToLowerInvariant()
            $callee = $c.Groups[2].Value.ToLowerInvariant()
            if ($target -eq 'rec' -and $object.TableNo) {
                # A codeunit with TableNo: Rec is that record (the Message Argument the task runs it with).
                if (Test-FollowCall $ReadMode $object.TableNo $callee) {
                    Get-Reach $Objects $object.TableNo $callee $Seen $ReadMode
                }
                continue
            }
            if ($target -in @('this', 'rec')) {
                if (Test-FollowCall $ReadMode $ObjectName $callee) { Get-Reach $Objects $ObjectName $callee $Seen $ReadMode }
                continue
            }
            if (-not $object.Variables.ContainsKey($target)) { continue }
            foreach ($t in $object.Variables[$target]) {
                if (-not $Objects.ContainsKey($t) -or $Objects[$t].Kind -eq 'interface') {
                    # An interface variable: follow the call into every codeunit that implements it.
                    foreach ($implementer in $Objects.Values) {
                        if ($implementer.Implements -contains $t) { Get-Reach $Objects $implementer.Name $callee $Seen $ReadMode }
                    }
                    continue
                }
                if (-not (Test-FollowCall $ReadMode $t $callee)) { continue }
                Get-Reach $Objects $t $callee $Seen $ReadMode
                if ($callee -eq 'run') { Get-Reach $Objects $t 'onrun' $Seen $ReadMode }
            }
        }
        foreach ($c in $callUnqualified.Matches($body)) {
            $callee = $c.Groups[1].Value.ToLowerInvariant()
            if (-not (Test-FollowCall $ReadMode $ObjectName $callee)) { continue }
            if ($object.Procedures.ContainsKey($callee)) { Get-Reach $Objects $ObjectName $callee $Seen $ReadMode }
        }
        foreach ($c in $codeunitReference.Matches($body)) {
            $t = $c.Groups[1].Value
            if ($Objects.ContainsKey($t)) { Get-Reach $Objects $t 'onrun' $Seen $ReadMode }
        }
    }
}

function Get-Types($Objects) {
    # message type name -> @{ Interface = codeunit; Contract = codeunit }
    $types = [ordered]@{}
    foreach ($object in $Objects.Values) {
        if ($object.Kind -notin @('enum', 'enumextension')) { continue }
        $text = $object.Text
        $valueMatches = [regex]::Matches($text, 'value\(\s*\d+\s*;\s*"([^"]+)"\s*\)\s*\{(.*?)\n\s*\}', 'Singleline')
        foreach ($vm in $valueMatches) {
            $implementation = [regex]::Match($vm.Groups[2].Value, 'Implementation\s*=\s*(.*?);', 'Singleline')
            if (-not $implementation.Success) { continue }
            $interfaceMatch = [regex]::Match($implementation.Groups[1].Value, '"Msg Interface ori"\s*=\s*"([^"]+)"')
            $contractMatch = [regex]::Match($implementation.Groups[1].Value, '"Msg Contract ori"\s*=\s*"([^"]+)"')
            if (-not $interfaceMatch.Success -or -not $contractMatch.Success) { continue }
            $types[$vm.Groups[1].Value] = @{ Interface = $interfaceMatch.Groups[1].Value; Contract = $contractMatch.Groups[1].Value }
        }
    }
    return $types
}

# The Boolean parameters of a procedure: lower-case name -> zero-based position.
function Get-BooleanParameters([string]$Body) {
    $result = @{}
    $signature = [regex]::Match($Body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
    if (-not $signature.Success) { return $result }
    $index = 0
    foreach ($param in $signature.Groups[1].Value.Split(';')) {
        $m = [regex]::Match($param, '(?i)^\s*(?:var\s+)?(\w+)\s*:\s*Boolean\s*$')
        if ($m.Success) { $result[$m.Groups[1].Value.ToLowerInvariant()] = $index }
        $index++
    }
    return $result
}

# The Boolean parameters that every reached call site passes as the literal false, per reached procedure
# (key "Object::procedure" -> set of lower-case names). A call that passes anything else keeps the parameter out (#401).
function Get-FalseFlags($Objects, $Seen) {
    $values = @{}
    foreach ($entry in $Seen.Keys) {
        $objectName = ($entry -split '::', 2)[0]
        $object = $Objects[$objectName]
        foreach ($body in $object.Procedures[($entry -split '::', 2)[1]]) {
            $parsedStarts = @{}
            foreach ($call in $callWithArgs.Matches($body)) {
                $parsedStarts[$call.Index] = $true
                # Not a call: the declaration of a procedure.
                if ($body.Substring(0, $call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
                $callee = $call.Groups['callee'].Value.ToLowerInvariant()
                $targets = @()
                if ($receiver -eq '' -or $receiver -in @('this', 'rec')) { $targets = @($objectName) }
                elseif ($object.Variables.ContainsKey($receiver)) { $targets = @($object.Variables[$receiver]) }
                $argumentList = @($call.Groups['args'].Value.Split(','))
                foreach ($targetName in $targets) {
                    $targetKey = "${targetName}::${callee}"
                    if (-not $Seen.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                    foreach ($calleeBody in $Objects[$targetName].Procedures[$callee]) {
                        $flags = Get-BooleanParameters $calleeBody
                        foreach ($name in $flags.Keys) {
                            $position = $flags[$name]
                            $argument = if ($position -lt $argumentList.Count) { $argumentList[$position].Trim().ToLowerInvariant() } else { '?' }
                            if (-not $values.ContainsKey("$targetKey|$name")) { $values["$targetKey|$name"] = @() }
                            $values["$targetKey|$name"] += $argument
                        }
                    }
                }
            }
            # A call the pass above could not read counts as a call that may pass true (#590): one parsed call that passes false
            # must not prune a parameter that a second, unread call declares.
            foreach ($call in $anyCall.Matches($body)) {
                if ($body.Substring(0, $call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                $chained = $call.Groups['chained'].Success
                $calleeName = if ($chained) { $call.Groups['chained'].Value.ToLowerInvariant() } else { $call.Groups['callee'].Value.ToLowerInvariant() }
                $receiverName = $call.Groups['receiver'].Value.ToLowerInvariant()
                $readable = $false
                $unreadTargets = @()
                if (-not $chained) {
                    if ($receiverName -eq '' -or $receiverName -in @('this', 'rec')) { $unreadTargets = @($objectName); $readable = $true }
                    elseif ($object.Variables.ContainsKey($receiverName)) { $unreadTargets = @($object.Variables[$receiverName]); $readable = $true }
                    if ($readable -and $parsedStarts.ContainsKey($call.Index)) { continue }
                }
                if (-not $readable) {
                    # A receiver the guard cannot resolve: any reached procedure of that name may be the one called.
                    $unreadTargets = @($Seen.Keys | Where-Object { $_.EndsWith("::$calleeName") } | ForEach-Object { ($_ -split '::', 2)[0] })
                }
                foreach ($targetName in $unreadTargets) {
                    $targetKey = "${targetName}::${calleeName}"
                    if (-not $Seen.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                    foreach ($calleeBody in $Objects[$targetName].Procedures[$calleeName]) {
                        foreach ($name in (Get-BooleanParameters $calleeBody).Keys) {
                            if (-not $values.ContainsKey("$targetKey|$name")) { $values["$targetKey|$name"] = @() }
                            $values["$targetKey|$name"] += '?'
                        }
                    }
                }
            }
        }
    }
    $result = @{}
    foreach ($key in $values.Keys) {
        if (@($values[$key] | Where-Object { $_ -ne 'false' }).Count -ne 0) { continue }
        $parts = $key -split '\|', 2
        if (-not $result.ContainsKey($parts[0])) { $result[$parts[0]] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$result[$parts[0]].Add($parts[1])
    }
    return $result
}

# The index just after the AL statement that starts at $Start: a begin ... end block, or the text up to the next ';' (or an
# 'else', or the 'end' that closes the enclosing block) outside string literals, comments and parentheses.
# With $ToBlockEnd it is the index of the 'end' that closes the block $Start is in: the statements that follow are scanned,
# nested begin ... end blocks and case statements are skipped whole, and no ';' or 'else' ends the scan (#590).
function Get-StatementEnd([string]$Text, [int]$Start, [bool]$ToBlockEnd = $false) {
    $i = $Start
    $depth = 0
    $parens = 0
    $length = $Text.Length
    while ($i -lt $length) {
        $c = $Text[$i]
        if ($c -eq "'") {
            $i++
            while ($i -lt $length) {
                if ($Text[$i] -eq "'") {
                    if ($i + 1 -lt $length -and $Text[$i + 1] -eq "'") { $i += 2; continue }
                    break
                }
                $i++
            }
            $i++
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $length -and $Text[$i + 1] -eq '/') {
            while ($i -lt $length -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '(') { $parens++ }
        elseif ($c -eq ')') { $parens-- }
        elseif ($c -eq ';' -and $depth -eq 0 -and $parens -eq 0) { if (-not $ToBlockEnd) { return $i + 1 } }
        elseif ([char]::IsLetter($c)) {
            $j = $i
            while ($j -lt $length -and ([char]::IsLetterOrDigit($Text[$j]) -or $Text[$j] -eq '_')) { $j++ }
            $word = $Text.Substring($i, $j - $i).ToLowerInvariant()
            if ($word -eq 'begin' -or $word -eq 'case') { $depth++ }
            elseif ($word -eq 'end') {
                if ($depth -eq 0) { return $i }
                $depth--
                if ($depth -eq 0 -and -not $ToBlockEnd) { return $j }
            }
            elseif ($word -eq 'else' -and $depth -eq 0 -and $parens -eq 0 -and -not $ToBlockEnd) { return $i }
            $i = $j
            continue
        }
        $i++
    }
    return $length
}

# Takes out of a procedure body what a Boolean parameter that is always false switches off: the statement of
# 'if Flag then <statement>' and the rest of the block after 'if not Flag then exit;' (#401, #590).
function Remove-FalseFlagSpans([string]$Body, $FlagNames) {
    $ifFlag = [regex]::new('\bif\s+(?<not>not\s+)?(?<flag>\w+)\s+then\b', 'IgnoreCase')
    $hits = @($ifFlag.Matches($Body) | Where-Object { $FlagNames.Contains($_.Groups['flag'].Value.ToLowerInvariant()) })
    for ($k = $hits.Count - 1; $k -ge 0; $k--) {
        $hit = $hits[$k]
        $after = $hit.Index + $hit.Length
        if ($hit.Groups['not'].Success) {
            $exitStatement = [regex]::Match($Body.Substring($after), '(?is)^\s*exit\b[^;]*;')
            if ($exitStatement.Success) {
                # The exit leaves the procedure, so what follows it in the same block is switched off with the flag. What follows the
                # enclosing block is not: 'if A then begin if not Flag then exit; X; end; Y;' keeps Y (#590).
                $blockEnd = Get-StatementEnd $Body ($after + $exitStatement.Length) $true
                $Body = $Body.Substring(0, $hit.Index) + $Body.Substring($blockEnd)
            }
            continue
        }
        $end = Get-StatementEnd $Body $after
        $Body = $Body.Substring(0, $hit.Index) + $Body.Substring($end)
    }
    return $Body
}

# A copy of the object table in which the procedures that have an always-false flag lost what the flag switches off.
function Get-PrunedObjects($Objects, $FalseFlags) {
    $pruned = @{}
    foreach ($name in $Objects.Keys) { $pruned[$name] = $Objects[$name] }
    foreach ($entry in $FalseFlags.Keys) {
        $parts = $entry -split '::', 2
        $copy = $pruned[$parts[0]].Clone()
        $copy.Procedures = $copy.Procedures.Clone()
        $copy.Procedures[$parts[1]] = @($Objects[$parts[0]].Procedures[$parts[1]] | ForEach-Object { Remove-FalseFlagSpans $_ $FalseFlags[$entry] })
        $pruned[$parts[0]] = $copy
    }
    return $pruned
}

function Get-DeclaredKeys($Objects, [string]$ContractCodeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $ContractCodeunit 'getparameters' $seen
    # A parameter declared only when a Boolean argument is true is not declared where the call passes false (#401).
    $falseFlags = Get-FalseFlags $Objects $seen
    if ($falseFlags.Count -gt 0) {
        $Objects = Get-PrunedObjects $Objects $falseFlags
        $seen = @{}
        Get-Reach $Objects $ContractCodeunit 'getparameters' $seen
    }
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        foreach ($body in $Objects[$parts[0]].Procedures[$parts[1]]) {
            Add-ContractDeclarations $body $keys
            foreach ($m in $parameterLiteral.Matches($body)) { [void]$keys.Add($m.Groups[1].Value) }
            # A parameter declared in a loop over a literal list: AdjustNames.AddRange('a', 'b') ... Parameter(AdjustNames.Get(i), ...)
            foreach ($loop in [regex]::Matches($body, '\.Parameter\(\s*(\w+)\.Get\(')) {
                $listName = [regex]::Escape($loop.Groups[1].Value)
                $rangePattern = $listName + $addRangeTail
                foreach ($range in [regex]::Matches($body, $rangePattern)) {
                    foreach ($literal in $stringLiteral.Matches($range.Groups[1].Value)) { [void]$keys.Add($literal.Groups[1].Value) }
                }
            }
        }
    }
    return ,$keys
}

function Add-TargetText([string]$Text, $Keys) {
    # A comma list declares each key; so does 'data.bankAccountNo + data.statementNo' (a pair). A nested key such as
    # forRecord.tableNo also declares tableNo, the name the code reads from the nested object (#431). The guard compares
    # names only, so a read of a top-level 'tableNo' passes as declared when only 'forRecord.tableNo' is. That is accepted:
    # the guard cannot tell which object a key is read from, and it only ever widens the declared side here (#590).
    foreach ($part in ($Text -split '[,+]')) {
        $key = $part.Trim()
        if ($key.StartsWith('data.')) { $key = $key.Substring(5) }
        if ($key -eq '') { continue }
        [void]$Keys.Add($key)
        if ($key.Contains('.')) { [void]$Keys.Add($key.Substring($key.LastIndexOf('.') + 1)) }
    }
}

# The keys under data that the target chapter names as identifiers (TargetEntry('data.orderNo', ...)). They are declared
# there, not in the parameters chapter. A comma-separated literal declares each key. A key built as 'data.' + Parameter
# declares the literal the caller passed for that parameter (PostedDocumentTarget's NumberKey / IdKey).
function Get-TargetKeys($Objects, [string]$ContractCodeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $ContractCodeunit 'gettarget' $seen
    $concatParam = [regex]::new("'data\.'\s*\+\s*(\w+)", 'IgnoreCase')
    $quotedFragment = [regex]::new("'([^']*)'")
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        $objectName = $parts[0]
        $procedureName = $parts[1]
        foreach ($body in $Objects[$objectName].Procedures[$procedureName]) {
            foreach ($m in $targetLiteral.Matches($body)) { Add-TargetText $m.Groups[1].Value $keys }
            $dynamic = @{}
            foreach ($m in $concatParam.Matches($body)) { $dynamic[$m.Groups[1].Value] = $true }
            if ($dynamic.Count -eq 0) { continue }
            foreach ($fragment in $quotedFragment.Matches($body)) {
                if ($fragment.Groups[1].Value -match 'data\.\w') { Add-TargetText $fragment.Groups[1].Value $keys }
            }
            $signature = [regex]::Match($body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
            if (-not $signature.Success) { continue }
            $paramNames = @()
            foreach ($param in $signature.Groups[1].Value.Split(';')) {
                $name = [regex]::Match($param, '(?i)(?:var\s+)?(\w+)\s*:')
                if ($name.Success) { $paramNames += $name.Groups[1].Value }
            }
            $escaped = [regex]::Escape($procedureName)
            $call = [regex]::new("\b$escaped\s*\(((?:'[^']*'\s*,?\s*)+)\)", 'IgnoreCase')
            foreach ($caller in $seen.Keys) {
                $callerParts = $caller -split '::', 2
                foreach ($callerBody in $Objects[$callerParts[0]].Procedures[$callerParts[1]]) {
                    foreach ($site in $call.Matches($callerBody)) {
                        $literals = @($stringLiteral.Matches($site.Groups[1].Value) | ForEach-Object { $_.Groups[1].Value })
                        for ($i = 0; $i -lt $paramNames.Count -and $i -lt $literals.Count; $i++) {
                            if ($dynamic.ContainsKey($paramNames[$i])) { [void]$keys.Add($literals[$i]) }
                        }
                    }
                }
            }
        }
    }
    return ,$keys
}

# Drops message text before literals are collected (#459): a Label declaration that is not Locked = true, and the
# statement of Error, StrSubstNo, Message, Confirm, RespondWith*, AddError and AddWarning. A Locked = true label in
# the procedure stays, so a key constant still counts. An inner call is part of the outer statement and is removed once.
function Remove-TextStatements([string]$Body) {
    $labelDecl = [regex]::new('(?i):\s*Label\b')
    $labelHits = @($labelDecl.Matches($Body))
    for ($k = $labelHits.Count - 1; $k -ge 0; $k--) {
        $hit = $labelHits[$k]
        $end = Get-StatementEnd $Body $hit.Index
        $statement = $Body.Substring($hit.Index, $end - $hit.Index)
        if ($statement -match '(?i)Locked\s*=\s*true') { continue }
        $start = $Body.LastIndexOf("`n", $hit.Index)
        if ($start -lt 0) { $start = 0 } else { $start++ }
        $Body = $Body.Substring(0, $start) + $Body.Substring($end)
    }

    $call = [regex]::new('(?i)(?:\b(?:Error|StrSubstNo|Message|Confirm)\s*\(|\.(?:RespondWith\w*|AddError|AddWarning)\s*\()')
    $spans = @()
    foreach ($hit in @($call.Matches($Body))) {
        $inside = $false
        foreach ($span in $spans) {
            if ($hit.Index -ge $span.Start -and $hit.Index -lt $span.End) { $inside = $true; break }
        }
        if ($inside) { continue }
        $end = Get-StatementEnd $Body $hit.Index
        $spans += @{ Start = $hit.Index; End = $end }
    }
    for ($k = $spans.Count - 1; $k -ge 0; $k--) {
        $Body = $Body.Substring(0, $spans[$k].Start) + $Body.Substring($spans[$k].End)
    }
    return $Body
}

# Every string literal in the code the implementation reaches from ExecuteBifrostTask, after Remove-TextStatements.
# A Locked = true label in a reached procedure still counts; a translatable label and a message-text call do not (#459).
# The contract procedures are not reached from there, so a parameter name that is only declared does not count as read.
function Get-ReachableLiterals($Objects, [string]$Codeunit) {
    $literals = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $Codeunit 'executebifrosttask' $seen
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        foreach ($body in $Objects[$parts[0]].Procedures[$parts[1]]) {
            $body = Remove-TextStatements $body
            foreach ($m in $stringLiteral.Matches($body)) { [void]$literals.Add($m.Groups[1].Value.Replace("''", "'")) }
            foreach ($m in $keySpec.Matches($body)) {
                foreach ($pair in $m.Groups[1].Value.Split(',')) { [void]$literals.Add($pair.Split('=')[0]) }
            }
        }
    }
    return ,$literals
}

function Get-FirstParam([string]$Body) {
    $match = $firstParam.Match($Body)
    if ($match.Success) { return $match.Groups[1].Value.ToLowerInvariant() }
    return ''
}

# The parameter names of a procedure, in order, in lower case.
function Get-ParameterNames([string]$Body) {
    $names = @()
    $signature = [regex]::Match($Body, '(?i)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
    if (-not $signature.Success) { return ,$names }
    foreach ($param in $signature.Groups[1].Value.Split(';')) {
        $name = [regex]::Match($param, '(?i)^\s*(?:var\s+)?(\w+)\s*:')
        if ($name.Success) { $names += $name.Groups[1].Value.ToLowerInvariant() }
    }
    return ,$names
}

# The zero-based positions in an argument list whose argument is one of the names that hold the request.
function Get-RequestArgumentPositions([string]$Arguments, $RequestNames) {
    $positions = New-Object 'System.Collections.Generic.List[int]'
    $flat = [regex]::Replace($Arguments, "'(?:[^']|'')*'", "''")
    $index = 0
    foreach ($argument in $flat.Split(',')) {
        if ($RequestNames.Contains($argument.Trim().ToLowerInvariant())) { $positions.Add($index) }
        $index++
    }
    return ,$positions
}

# Names, per reached procedure, that hold the request: RequestJson, a variable assigned from GetRequestJson(),
# and the first parameter of a reached procedure when a caller passes the request into it (#430).
function Get-RequestVars($Objects, $Seen) {
    $vars = @{}
    foreach ($entry in $Seen.Keys) {
        $names = New-Object 'System.Collections.Generic.HashSet[string]'
        [void]$names.Add('requestjson')
        $vars[$entry] = $names
    }
    foreach ($entry in @($Seen.Keys)) {
        $objectName = ($entry -split '::', 2)[0]
        $procedureName = ($entry -split '::', 2)[1]
        foreach ($body in $Objects[$objectName].Procedures[$procedureName]) {
            foreach ($assign in $assignRequest.Matches($body)) { [void]$vars[$entry].Add($assign.Groups[1].Value.ToLowerInvariant()) }
            if ($body -match 'GetRequestDataArray\(') {
                foreach ($assign in $assignRecordObject.Matches($body)) { [void]$vars[$entry].Add($assign.Groups[1].Value.ToLowerInvariant()) }
            }
        }
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($entry in @($Seen.Keys)) {
            $objectName = ($entry -split '::', 2)[0]
            $procedureName = ($entry -split '::', 2)[1]
            $object = $Objects[$objectName]
            foreach ($body in $object.Procedures[$procedureName]) {
                foreach ($call in $passRequest.Matches($body)) {
                    if ($call.Groups['var'].Success -and -not $vars[$entry].Contains($call.Groups['var'].Value.ToLowerInvariant())) { continue }
                    $callee = $call.Groups[1].Value.ToLowerInvariant()
                    $targetKey = "${objectName}::${callee}"
                    if (-not $vars.ContainsKey($targetKey)) { continue }
                    foreach ($calleeBody in $object.Procedures[$callee]) {
                        $paramName = Get-FirstParam $calleeBody
                        if ($paramName -ne '' -and $vars[$targetKey].Add($paramName)) { $changed = $true }
                    }
                }
                # The request (or a record of it) passed in any argument position: ProcessRecord(Rec, RecordObject, ...).
                foreach ($call in $callWithArgs.Matches($body)) {
                    $positions = Get-RequestArgumentPositions $call.Groups['args'].Value $vars[$entry]
                    if ($positions.Count -eq 0) { continue }
                    $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
                    $callee = $call.Groups['callee'].Value.ToLowerInvariant()
                    $targets = @()
                    if ($receiver -eq '' -or $receiver -in @('this', 'rec')) { $targets = @($objectName) }
                    elseif ($object.Variables.ContainsKey($receiver)) { $targets = @($object.Variables[$receiver]) }
                    foreach ($targetName in $targets) {
                        $targetKey = "${targetName}::${callee}"
                        if (-not $vars.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                        foreach ($calleeBody in $Objects[$targetName].Procedures[$callee]) {
                            $paramNames = Get-ParameterNames $calleeBody
                            foreach ($position in $positions) {
                                if ($position -lt $paramNames.Count -and $vars[$targetKey].Add($paramNames[$position])) { $changed = $true }
                            }
                        }
                    }
                }
                foreach ($call in $passRequestQualified.Matches($body)) {
                    if ($call.Groups['var'].Success -and -not $vars[$entry].Contains($call.Groups['var'].Value.ToLowerInvariant())) { continue }
                    $receiver = $call.Groups[1].Value.ToLowerInvariant()
                    $callee = $call.Groups[2].Value.ToLowerInvariant()
                    $targets = @()
                    if ($receiver -in @('this', 'rec')) { $targets = @($objectName) }
                    elseif ($object.Variables.ContainsKey($receiver)) { $targets = @($object.Variables[$receiver]) }
                    foreach ($targetName in $targets) {
                        $targetKey = "${targetName}::${callee}"
                        if (-not $vars.ContainsKey($targetKey) -or -not $Objects.ContainsKey($targetName)) { continue }
                        if (-not $Objects[$targetName].Procedures.ContainsKey($callee)) { continue }
                        foreach ($calleeBody in $Objects[$targetName].Procedures[$callee]) {
                            $paramName = Get-FirstParam $calleeBody
                            if ($paramName -ne '' -and $vars[$targetKey].Add($paramName)) { $changed = $true }
                        }
                    }
                }
            }
        }
    }
    return $vars
}

function Add-CallRead($Match, $RequestNames, $Keys) {
    if ($Match.Groups['var'].Success -and -not $RequestNames.Contains($Match.Groups['var'].Value.ToLowerInvariant())) { return }
    [void]$Keys.Add($Match.Groups['key'].Value)
}

# Read balanced argument lists so request values passed as Token.AsObject() are
# not lost by the flat-call matcher. Strings/comments cannot introduce calls.
function Get-SourceCalls([string]$Body) {
    $mask = [regex]::Replace($Body, '''(?:[^'']|'''')*''|"(?:[^"]|"")*"|//[^\r\n]*|/\*[\s\S]*?\*/', { param($m) ' ' * $m.Length })
    foreach ($start in $anyCall.Matches($mask)) {
        if (-not $start.Groups['callee'].Success) { continue }
        if ($start.Groups['callee'].Value -imatch '^(if|not|and|or|xor|in|while|until|case|for|foreach|repeat)$') { continue }
        if ($mask.Substring(0, $start.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
        $depth = 1; $offset = $start.Index + $start.Length; $argumentStart = $offset
        $args = New-Object 'System.Collections.Generic.List[string]'
        for ($i = $offset; $i -lt $mask.Length; $i++) {
            if ($mask[$i] -eq '(') { $depth++ }
            elseif ($mask[$i] -eq ')') {
                $depth--
                if ($depth -eq 0) {
                    $args.Add($Body.Substring($argumentStart, $i - $argumentStart).Trim())
                    break
                }
            } elseif ($mask[$i] -eq ',' -and $depth -eq 1) {
                $args.Add($Body.Substring($argumentStart, $i - $argumentStart).Trim()); $argumentStart = $i + 1
            }
        }
        if ($depth -eq 0) {
            @{ Receiver = $start.Groups['receiver'].Value.ToLowerInvariant(); Callee = $start.Groups['callee'].Value.ToLowerInvariant(); Arguments = @($args) }
        }
    }
}

function Get-ExpressionOrigins([string]$Expression, $Origins) {
    if ($Expression -match '^(?i)(?:\w+\.)?GetRequestJson\(\)$') { return '' }
    if ($Expression -match '^(?i)(\w+)(?:\.(?:AsObject|AsArray)\(\))?$') {
        $name = $Matches[1].ToLowerInvariant()
        if ($Origins.ContainsKey($name)) { foreach ($path in $Origins[$name]) { $path } }
    }
}

function Add-RequestOrigins($Origins, [string]$Name, $Paths) {
    if (-not $Origins.ContainsKey($Name)) { $Origins[$Name] = New-Object 'System.Collections.Generic.HashSet[string]' }
    $changed = $false
    foreach ($path in $Paths) { if ($Origins[$Name].Add([string]$path)) { $changed = $true } }
    return $changed
}

# Retain the top-level request key through JSON extraction, array iteration and
# helper parameters. A nested quantity belongs to entries, not to request.quantity.
# Missing lineage remains unknown and keeps the typed-reader ambiguity diagnostic.
function Get-RequestOrigins($Objects, $Seen, $RequestVars) {
    $origins = @{}
    foreach ($entry in $Seen.Keys) {
        $origins[$entry] = @{}
        foreach ($name in $RequestVars[$entry]) { [void](Add-RequestOrigins $origins[$entry] $name @('')) }
    }
    $changed = $true; $validateUnknown = $false
    while ($changed -or -not $validateUnknown) {
        if (-not $changed) { $validateUnknown = $true }
        $changed = $false
        foreach ($entry in $Seen.Keys) {
            $parts = $entry -split '::', 2; $object = $Objects[$parts[0]]; $local = $origins[$entry]
            foreach ($body in $object.Procedures[$parts[1]]) {
                foreach ($call in @(Get-SourceCalls $body)) {
                    if (($call.Receiver -eq '' -and $call.Callee -eq 'clear' -and $call.Arguments.Count -eq 1 -and $call.Arguments[0] -match '^\w+$')) {
                        if (Add-RequestOrigins $local $call.Arguments[0].ToLowerInvariant() @('?')) { $changed = $true }
                    }
                    if ($call.Receiver -ne '' -and $call.Callee -eq 'readfrom') {
                        if (Add-RequestOrigins $local $call.Receiver @('?')) { $changed = $true }
                    }
                    if ($call.Callee -eq 'get' -and $call.Arguments.Count -eq 2 -and $call.Arguments[1] -match '^\w+$') {
                        $paths = @()
                        foreach ($path in @($local[$call.Receiver] | Where-Object { $null -ne $_ })) {
                            if ($path -ne '') { $paths += $path }
                            elseif ($call.Arguments[0] -match "^'((?:[^']|'')*)'$") { $paths += $Matches[1].Replace("''", "'") }
                        }
                        if ($paths.Count -eq 0 -and $validateUnknown) { $paths = @('?') }
                        if (Add-RequestOrigins $local $call.Arguments[1].ToLowerInvariant() $paths) { $changed = $true }
                    }
                    $targets = @(if ($call.Receiver -eq '' -or $call.Receiver -in @('this','rec')) { $parts[0] }
                        elseif ($object.Variables.ContainsKey($call.Receiver)) { $object.Variables[$call.Receiver] })
                    foreach ($target in $targets) {
                        $targetKey = "${target}::$($call.Callee)"
                        if (-not $origins.ContainsKey($targetKey)) { continue }
                        foreach ($calleeBody in $Objects[$target].Procedures[$call.Callee]) {
                            $parameters = Get-ParameterNames $calleeBody
                            for ($i = 0; $i -lt $parameters.Count -and $i -lt $call.Arguments.Count; $i++) {
                                $paths = @(Get-ExpressionOrigins $call.Arguments[$i] $local)
                                if ($paths.Count -eq 0 -and $validateUnknown) { $paths = @('?') }
                                if (Add-RequestOrigins $origins[$targetKey] $parameters[$i] $paths) { $changed = $true }
                            }
                        }
                    }
                }
                $assignments = [regex]::Matches($body, '(?i)\b(\w+)\s*:=\s*(\w+(?:\.(?:AsObject|AsArray)\(\))?)\s*;|\bforeach\s+(\w+)\s+in\s+(\w+)\s+do\b')
                foreach ($assignment in $assignments) {
                    $name = if ($assignment.Groups[1].Success) { $assignment.Groups[1].Value } else { $assignment.Groups[3].Value }
                    $value = if ($assignment.Groups[2].Success) { $assignment.Groups[2].Value } else { $assignment.Groups[4].Value }
                    $paths = @(Get-ExpressionOrigins $value $local)
                    if ($paths.Count -eq 0 -and $validateUnknown) { $paths = @('?') }
                    if (Add-RequestOrigins $local $name.ToLowerInvariant() $paths) { $changed = $true }
                }
                # Replacing a token/object with a literal, call result or constructor
                # invalidates the earlier extraction proof. Keep all possible origins.
                $syntax = [regex]::Replace($body, '//[^\r\n]*|/\*[\s\S]*?\*/', ' ')
                foreach ($assignment in [regex]::Matches($syntax, '(?im)\b(\w+)\s*:=\s*([^;]+);')) {
                    $value = $assignment.Groups[2].Value.Trim()
                    if ($value -notmatch '^(?i)\w+(?:\.(?:AsObject|AsArray)\(\))?$|^(?:\w+\.)?GetRequestJson\(\)$') {
                        if (Add-RequestOrigins $local $assignment.Groups[1].Value.ToLowerInvariant() @('?')) { $changed = $true }
                    }
                }
            }
        }
    }
    return $origins
}

# A literal passed after the request is not a request key when source proves that
# parameter is used only to select CASE branches. Unknown calls and parameters also
# used as data keep the conservative key check; no method-name exceptions (#30).
function Test-CaseSelectorArgument($Objects, [string]$ObjectName, $Call, [string]$CallerBody = '') {
    # A chained receiver is unresolved, even if this object has a same-name helper.
    if (-not $Call.Groups['receiver'].Success -and $Call.Index -gt 0 -and $CallerBody.Substring(0,$Call.Index) -match '\.\s*$') { return $false }
    $receiver = $Call.Groups['receiver'].Value.ToLowerInvariant()
    $callee = $Call.Groups['callee'].Value.ToLowerInvariant()
    $targets = @(if ($receiver -eq '' -or $receiver -in @('this', 'rec')) { $ObjectName }
        elseif ($Objects[$ObjectName].Variables.ContainsKey($receiver)) { $Objects[$ObjectName].Variables[$receiver] })
    if ($targets.Count -ne 1 -or -not $Objects.ContainsKey($targets[0])) { return $false }
    $target = $Objects[$targets[0]]
    # Branch specialization removes selector uses from the analysis body. Prove
    # the argument's role against the original definition, never that pruned body.
    $definitions = if ($target.ContainsKey('SourceProcedures')) { $target.SourceProcedures } else { $target.Procedures }
    if (-not $definitions.ContainsKey($callee)) { return $false }
    foreach ($body in $definitions[$callee]) {
        $params = Get-ParameterNames $body
        if ($params.Count -lt 2) { return $false }
        $parameter = [regex]::Escape($params[1])
        $syntax = [regex]::Replace($body, "'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/", ' ')
        $cases = [regex]::Matches($syntax, "(?i)\bcase\s+$parameter\s+of\b").Count
        $uses = [regex]::Matches($syntax, "(?i)(?<![\w])$parameter(?![\w])").Count
        # One declaration plus CASE selectors only; any additional use prevents exclusion.
        if ($cases -eq 0 -or $uses -ne $cases + 1) { return $false }
    }
    return $true
}

# The keys the implementation reads from the request in the procedures it reaches from ExecuteBifrostTask.
# A call whose first argument is the request and whose second argument is a literal counts, including a wrapper
# such as GetTextParam(RequestJson, 'dateFilter', ...) and a variable such as ReqJson (#430).
# A JSON reader may be used only to reject an unsupported nonempty value. Prove
# that its request argument is read-only: aliases, unknown consumers and writes
# invalidate that proof, including writes hidden in source-resolved helpers.
function Test-ReadOnlyJsonParameter($Objects, [string]$ObjectName, [string]$ProcedureName, [string]$Parameter, $Seen) {
    $key="$ObjectName::$ProcedureName::$Parameter"
    if ($Seen.ContainsKey($key)) { return $true };$Seen[$key]=$true
    if (-not $Objects.ContainsKey($ObjectName) -or -not $Objects[$ObjectName].Procedures.ContainsKey($ProcedureName)) { return $false }
    $object=$Objects[$ObjectName]
    foreach ($body in $object.Procedures[$ProcedureName]) {
        $syntax=[regex]::Replace($body,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
        $uses=[regex]::Matches($syntax,"(?i)(?<![.\w])$([regex]::Escape($Parameter))(?![\w])").Count
        $accounted=1
        if ($syntax -match '\b\w+\.\w+\s*:=') { return $false }
        $scalarReaders=@{}
        foreach($declaration in [regex]::Matches($body,'(?i)\b(\w+)\s*:\s*(JsonObject|JsonArray|JsonToken|JsonValue|Text)\b')){$scalarReaders[$declaration.Groups[1].Value.ToLowerInvariant()]=$true}
        foreach ($call in @(Get-SourceCalls $body)) {
            if ($call.Receiver -ieq $Parameter) {
                if ($call.Callee -notin @('get','contains','keys','values','count','writeto','clone')) { return $false }
                $accounted++
            }
            $forwardsRequest=$false
            for($position=0;$position -lt $call.Arguments.Count;$position++) {
                if ($call.Arguments[$position] -ine $Parameter) { continue }
                $forwardsRequest=$true
                $targets=@(if($call.Receiver -in @('','this','rec')){$ObjectName}elseif($object.Variables.ContainsKey($call.Receiver)){$object.Variables[$call.Receiver]})
                if($targets.Count -ne 1 -or -not $Objects.ContainsKey($targets[0]) -or -not $Objects[$targets[0]].Procedures.ContainsKey($call.Callee)){return $false}
                foreach($calleeBody in $Objects[$targets[0]].Procedures[$call.Callee]){
                    $params=Get-ParameterNames $calleeBody
                    if($position -ge $params.Count -or -not (Test-ReadOnlyJsonParameter $Objects $targets[0] $call.Callee $params[$position] $Seen)){return $false}
                }
                $accounted++
            }
            if ($call.Receiver -ine $Parameter -and -not $forwardsRequest) {
                $platform=$call.Receiver -eq '' -and $call.Callee -in @('exit','error','strsubstno','copystr','strlen','uppercase','lowercase','format')
                $scalar=$scalarReaders.ContainsKey($call.Receiver) -and $call.Callee -in @('get','contains','keys','values','count','writeto','clone','isvalue','isobject','isarray','asvalue','asobject','asarray','astext','asdecimal','asboolean','startswith')
                if(-not $platform -and -not $scalar){return $false}
            }
        }
        if($accounted -ne $uses){return $false}
    }
    return $true
}

function Test-RejectionOnlyCall($Objects, [string]$ObjectName, $Call, [string]$CallerBody = '') {
    if (-not $Call.Groups['receiver'].Success -and $Call.Index -gt 0 -and $CallerBody.Substring(0,$Call.Index) -match '\.\s*$') { return $false }
    $receiver=$Call.Groups['receiver'].Value.ToLowerInvariant();$callee=$Call.Groups['callee'].Value.ToLowerInvariant()
    $object=$Objects[$ObjectName]
    $targets=@(if($receiver -in @('','this','rec')){$ObjectName}elseif($object.Variables.ContainsKey($receiver)){$object.Variables[$receiver]})
    if($targets.Count -ne 1 -or -not $Objects.ContainsKey($targets[0])){return $false}
    $target=$Objects[$targets[0]]
    if($target.Procedures.ContainsKey('error')){return $false}
    $definitions=if($target.ContainsKey('SourceProcedures')){$target.SourceProcedures}else{$target.Procedures}
    if(-not $definitions.ContainsKey($callee)){return $false}
    foreach($body in $definitions[$callee]){
        $signature=[regex]::Match($body,'(?is)^\s*(?:local\s+|internal\s+|protected\s+)?procedure\s+\w+\s*\([^)]*\)\s*(?=var\b|begin\b)')
        if(-not $signature.Success){return $false}
        $tokens=@(Get-ALTokens $body);$begin=-1
        for($i=0;$i -lt $tokens.Count;$i++){if($tokens[$i].Text -ieq 'begin'){$begin=$i;break}}
        if($begin -lt 0 -or $tokens[$begin+1].Text -ine 'if'){return $false}
        $then=-1;$depth=0
        for($i=$begin+2;$i -lt $tokens.Count;$i++){
            if($tokens[$i].Text -eq '('){$depth++}elseif($tokens[$i].Text -eq ')'){$depth--}
            elseif($depth -eq 0 -and $tokens[$i].Text -ieq 'then'){$then=$i;break}
        }
        if($then -lt 0 -or $tokens[$then+1].Text -ine 'Error' -or $tokens[$then+2].Text -ne '('){return $false}
        $condition=$body.Substring($tokens[$begin+2].Start,$tokens[$then].Start-$tokens[$begin+2].Start).Trim()
        if($condition -notmatch "^\w+\(\s*\w+\s*,\s*\w+(?:\s*,\s*\w+)*\s*\)\s*<>\s*''$"){return $false}
        $next=Get-ALStatementNext $tokens ($then+1)
        if($next -lt 0 -or $tokens[$next].Text -ine 'end'){return $false}
        # Everything after the IF is the procedure/object terminator, not a
        # second statement that could consume the value on a successful path.
        $first=Get-FirstParam $body
        if($first -eq '' -or -not (Test-ReadOnlyJsonParameter $Objects $targets[0] $callee $first @{})){return $false}
    }
    return $true
}

# Isolated PowerShell port of the generation proof. NOT wired into canonical
# scanner. Every path/effect must be source-resolved before emitting safe events.
# Null constraint means unrestricted; an empty set means no possible keys.
function New-ProofKeySet($Values) {
    $set=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach($value in $Values){[void]$set.Add([string]$value)}
    return ,$set
}
function New-RequestPayloadProof {
    return @{Epoch=0;NextIdentity=0;PayloadAllowed=$null;Variables=@{};Reads=[System.Collections.Generic.List[object]]::new();Trace=[System.Collections.Generic.List[object]]::new();UncertainAliasing=$false}
}
function Add-PayloadProofTrace($State,[string]$Operation,$Details=@{}) {
    $entry=@{operation=$Operation;epoch=$State.Epoch}
    foreach($key in $Details.Keys){$entry[$key]=$Details[$key]}
    [void]$State.Trace.Add($entry)
}
function Set-ProofAcquisition($State,[string]$Name,[bool]$SourceProven) {
    $State.NextIdentity++
    $allowed=$null;$origin=$null
    if($SourceProven){$origin=$State.Epoch;if($null -ne $State.PayloadAllowed){$allowed=New-ProofKeySet $State.PayloadAllowed}}
    $State.Variables[$Name]=@{Identity=$State.NextIdentity;PayloadEpoch=$origin;Allowed=$allowed;Removed=(New-ProofKeySet @())}
    Add-PayloadProofTrace $State 'acquire' @{variable=$Name;identity=$State.NextIdentity;sourceProven=$SourceProven}
}
function Set-ProofJsonAlias($State,[string]$Destination,[string]$Source) {
    if($State.Variables.ContainsKey($Source)){
        $State.Variables[$Destination]=$State.Variables[$Source]
        Add-PayloadProofTrace $State 'json-alias' @{destination=$Destination;source=$Source}
    }else{Set-ProofJsonReplacement $State $Destination}
}
function Set-ProofJsonReplacement($State,[string]$Name) {
    Set-ProofAcquisition $State $Name $false
    Add-PayloadProofTrace $State 'replace' @{variable=$Name}
}
function Set-ProofRecordMutation($State,[string]$Reason) {
    $State.Epoch++;$State.PayloadAllowed=$null
    Add-PayloadProofTrace $State 'record-generation-change' @{reason=$Reason}
}
function Set-ProofUnknownEffect($State,[string]$Reason) {
    Set-ProofRecordMutation $State $Reason
    foreach($value in $State.Variables.Values){$value.Allowed=$null;$value.PayloadEpoch=$null;$value.Removed=New-ProofKeySet @()}
    Add-PayloadProofTrace $State 'unknown-alias-or-effect' @{reason=$Reason}
}
function Set-ProofKeyValidation($State,[string]$Name,$Allowed,[bool]$Exhaustive,[bool]$Unconditional) {
    if(-not $State.Variables.ContainsKey($Name) -or -not $Exhaustive -or -not $Unconditional){
        Add-PayloadProofTrace $State 'unproved-validator' @{variable=$Name};return
    }
    $value=$State.Variables[$Name];$constraint=New-ProofKeySet $Allowed
    if($null -ne $value.Allowed){$constraint.IntersectWith($value.Allowed)}
    $value.Allowed=$constraint
    if($null -ne $value.PayloadEpoch -and $value.PayloadEpoch -eq $State.Epoch){
        $original=New-ProofKeySet $constraint;$original.UnionWith($value.Removed)
        if($null -ne $State.PayloadAllowed){$original.IntersectWith($State.PayloadAllowed)}
        $State.PayloadAllowed=$original
    }
    Add-PayloadProofTrace $State 'validate' @{variable=$Name;allowed=@($value.Allowed);payloadProof=($null -ne $value.PayloadEpoch -and $value.PayloadEpoch -eq $State.Epoch)}
}
function Set-ProofJsonMutation($State,[string]$Name,[string]$Operation,$Key=$null) {
    if($Operation -cnotin @('add','replace','remove','ReadFrom','Clear','dynamic-add','dynamic-remove','nested-json-mutation')){
        Set-ProofUnknownEffect $State ('unresolved JSON consumer: '+$Operation);return
    }
    if(-not $State.Variables.ContainsKey($Name)){return}
    if($State.UncertainAliasing){Set-ProofUnknownEffect $State 'joined JSON values may alias on an incoming path';return}
    $value=$State.Variables[$Name]
    if($Operation -cin @('add','replace') -and $null -ne $Key){
        if($null -ne $value.Allowed){[void]$value.Allowed.Add([string]$Key)}
    }elseif($Operation -ceq 'remove' -and $null -ne $Key){
        [void]$value.Removed.Add([string]$Key)
        if($null -ne $value.Allowed){[void]$value.Allowed.Remove([string]$Key)}
    }else{$value.Allowed=$null;$value.PayloadEpoch=$null;$value.Removed=New-ProofKeySet @()}
    Add-PayloadProofTrace $State 'json-mutation' @{variable=$Name;method=$Operation;key=$Key}
}
function Set-ProofResponseEffect($State,[bool]$SourceProven,[bool]$CurrentRecord) {
    if(-not $SourceProven -or -not $CurrentRecord){Set-ProofUnknownEffect $State 'unproved response method or stale record buffer'}
    else{Add-PayloadProofTrace $State 'source-proven-response-only'}
}
function Test-ProofReadPossible($State,[string]$Name,[string]$Key) {
    $possible=$true;$identity=$null;$allowed=$null
    if($State.Variables.ContainsKey($Name)){
        $value=$State.Variables[$Name];$identity=$value.Identity
        if($null -ne $value.Allowed){$possible=$value.Allowed.Contains($Key);$allowed=@($value.Allowed)}
    }
    $read=@{variable=$Name;key=$Key;possible=$possible;epoch=$State.Epoch;identity=$identity;allowed=$allowed}
    [void]$State.Reads.Add($read);Add-PayloadProofTrace $State 'read' $read
    return $possible
}
# Until a source frontend supplies complete incoming paths, joining is deliberately
# unrestricted. It is safe to lose precision; it is unsafe to lose a possible read.
function Merge-RequestPayloadProofConservative($Left,$Right) {
    $state=New-RequestPayloadProof
    $state.Epoch=[Math]::Max($Left.Epoch,$Right.Epoch)+1
    foreach($name in @($Left.Variables.Keys)+@($Right.Variables.Keys)){
        if(-not $state.Variables.ContainsKey($name)){Set-ProofAcquisition $state $name $false}
    }
    foreach($read in @($Left.Reads)+@($Right.Reads)){[void]$state.Reads.Add($read)}
    $state.UncertainAliasing=$true
    Add-PayloadProofTrace $state 'conservative-join'
    return $state
}

# Isolated source frontend. Unsupported syntax or unresolved effects erase proof.
# Requires the scanner tokenizer/statement parser and RequestPayloadProof kernel.
function Get-ProofSlice($Tokens,[int]$Start,[int]$Stop) {
    if($Stop -le $Start){return ,@()};return ,@($Tokens[$Start..($Stop-1)])
}
function Get-ProofWords($Tokens) { return ,@($Tokens | ForEach-Object { $_.Text.ToLowerInvariant() }) }
function Split-ProofTokens($Tokens,[string]$Delimiter) {
    $parts=[System.Collections.Generic.List[object]]::new();$start=0;$depth=0
    for($i=0;$i -lt $Tokens.Count;$i++){
        if($Tokens[$i].Text -in @('(','[')){$depth++}
        elseif($Tokens[$i].Text -in @(')',']')){$depth--}
        elseif($depth -eq 0 -and $Tokens[$i].Text -eq $Delimiter){$parts.Add((Get-ProofSlice $Tokens $start $i));$start=$i+1}
    }
    if($start -lt $Tokens.Count){$parts.Add((Get-ProofSlice $Tokens $start $Tokens.Count))}
    return ,$parts.ToArray()
}
function Get-ProofLiteral($Tokens) {
    if($Tokens.Count -eq 1 -and $Tokens[0].Text -cmatch "^'((?:[^']|'')*)'$"){return $Matches[1].Replace("''", "'")};return $null
}
function Get-ProofProcedureUncached([string]$Body) {
    $t=@(Get-ALTokens $Body);$w=Get-ProofWords $t
    $p=[array]::IndexOf($w,'procedure');if($p -lt 0){$p=[array]::IndexOf($w,'trigger')};if($p -lt 0){return $null}
    $open=$p+2;if($open -ge $t.Count -or $w[$open] -ne '('){return $null}
    $close=$open+1;$depth=1
    while($close -lt $t.Count -and $depth -gt 0){if($w[$close] -eq '('){$depth++};if($w[$close] -eq ')'){$depth--};$close++};$close--
    if($depth -ne 0){return $null}
    $begin=$close+1;while($begin -lt $t.Count -and $w[$begin] -ne 'begin'){$begin++}
    if($begin -ge $t.Count){return $null}
    $end=Get-ALStatementNext $t $begin;if($end -le $begin){return $null}
    $last=$end-1;if($w[$last] -eq ';'){$last--}
    if($w[$last] -ne 'end'){return $null}
    $types=@{};$parameters=[System.Collections.Generic.List[string]]::new();$byvar=@{}
    foreach($part in (Split-ProofTokens (Get-ProofSlice $t ($open+1) $close) ';')){
        $words=Get-ProofWords $part;$colon=[array]::IndexOf($words,':');if($colon -lt 1){return $null}
        $type=(Get-ProofSlice $part ($colon+1) $part.Count).Text -join ' '
        for($i=0;$i -lt $colon;$i++){if($words[$i] -in @('var',',')){continue};$name=$words[$i];$parameters.Add($name);$types[$name]=$type.ToLowerInvariant();$byvar[$name]=$words[0] -eq 'var'}
    }
    $var=$close+1;while($var -lt $begin -and $w[$var] -ne 'var'){$var++}
    if($var -lt $begin){foreach($part in (Split-ProofTokens (Get-ProofSlice $t ($var+1) $begin) ';')){
        $words=Get-ProofWords $part;$colon=[array]::IndexOf($words,':');if($colon -lt 1){continue}
        $type=((Get-ProofSlice $part ($colon+1) $part.Count).Text -join ' ').ToLowerInvariant()
        for($i=0;$i -lt $colon;$i++){if($words[$i] -ne ','){$types[$words[$i]]=$type}}
    }}
    return @{Body=$Body;Tokens=$t;Words=$w;Start=$begin+1;Stop=$last;Types=$types;Parameters=$parameters.ToArray();ByVar=$byvar;ReturnTokens=(Get-ProofSlice $t ($close+1) ([Math]::Min($var,$begin)))}
}
# Cache syntax by the complete body, never by a procedure name or source SHA
# prefix. Runtime branch specializations therefore retain separate metadata.
function Get-ProofProcedure([string]$Body) {
    if($null -eq $script:SourceProofParsedProcedures){$script:SourceProofParsedProcedures=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)}
    if($script:SourceProofParsedProcedures.ContainsKey($Body)){return $script:SourceProofParsedProcedures[$Body]}
    $parsed=Get-ProofProcedureUncached $Body
    if($script:SourceProofParsedProcedures.Count -ge 4096){$script:SourceProofParsedProcedures.Clear()}
    $script:SourceProofParsedProcedures[$Body]=$parsed
    return $parsed
}
function Test-ProofBlobGetter($Proc) {
    if($null -eq $Proc -or $Proc.Parameters.Count -ne 0){return $false}
    $ret=Get-ProofWords $Proc.ReturnTokens
    if($ret.Count -ne 3 -or $ret[1] -ne ':' -or $ret[2] -ne 'jsonobject'){return $false}
    $streams=@($Proc.Types.Keys | Where-Object {$Proc.Types[$_] -eq 'instream'})
    if($streams.Count -ne 1){return $false}
    $r=$ret[0];$s=$streams[0];$blob='"send content"'
    $expected=@('if','not',$blob,'.','hasvalue','(',')','then','exit',';','calcfields','(',$blob,')',';',$blob,'.','createinstream','(',$s,',','textencoding',':',':','utf8',')',';',$r,'.','readfrom','(',$s,')',';')
    $actual=Get-ProofWords (Get-ProofSlice $Proc.Tokens $Proc.Start $Proc.Stop)
    return (($actual -join "`t") -ceq ($expected -join "`t"))
}
function Get-ProofValidator($Proc) {
    $no=@{Proven=$false;Keys=@()}
    if($null -eq $Proc -or $Proc.Parameters.Count -eq 0 -or $Proc.Types[$Proc.Parameters[0]] -ne 'jsonobject'){return $no}
    $t=Get-ProofSlice $Proc.Tokens $Proc.Start $Proc.Stop;$w=Get-ProofWords $t;$i=0
    if($t.Count -lt 15 -or $w[0] -ne 'foreach' -or $w[2] -ne 'in' -or $w[3] -ne $Proc.Parameters[0] -or ($w[4..8] -join ' ') -ne '. keys ( ) do'){return $no}
    $key=$w[1];$i=9;$keys=New-ProofKeySet @()
    while($i -lt $t.Count -and $w[$i] -eq 'if'){
        $i++
        if($w[$i] -eq 'not'){
            $i++;if(($w[$i..($i+3)] -join ' ') -ne "( $key in ["){return $no};$i+=4;$count=0
            while($i -lt $t.Count){$lit=Get-ProofLiteral @($t[$i]);if($null -eq $lit){break};[void]$keys.Add($lit);$count++;$i++;if($w[$i] -ne ','){break};$i++}
            if($count -eq 0 -or ($w[$i..($i+1)] -join ' ') -ne '] )'){return $no};$i+=2
        }else{
            if($w[$i] -ne $key -or $w[$i+1] -ne '<>'){return $no};$lit=Get-ProofLiteral @($t[$i+2]);if($null -eq $lit){return $no};[void]$keys.Add($lit);$i+=3
        }
        if($w[$i] -ne 'then'){return $no};$i++
    }
    if($i+3 -ge $t.Count -or $w[$i] -ne 'error' -or $w[$i+1] -ne '(' -or $w[-2] -ne ')' -or $w[-1] -ne ';'){return $no}
    # Error arguments may contain only constants/identifiers. Nested calls and
    # statements could mutate the request before aborting or catch the error.
    foreach($word in $w[($i+2)..($w.Count-3)]){if($word -in @('(',')',';',':=','begin','end')){return $no}}
    return @{Proven=$true;Keys=@($keys)}
}
function Set-SourceProofUnknown($Engine,[string]$Reason) {
    $Engine.LiteralEpoch++
    [void]$Engine.Unresolved.Add(@{context=$Engine.Context;reason=$Reason})
    Set-ProofUnknownEffect $Engine.State $Reason
}
function Sync-ProofScalars($Engine,$Frame) {
    if($Frame.ScalarEpoch -ne $Engine.LiteralEpoch){$Frame.Scalars.Clear();$Frame.ScalarEpoch=$Engine.LiteralEpoch}
}
function Get-SourceProofTarget($Engine,$Frame,[string]$Receiver,[string]$Method) {
    if($Receiver -eq '' -or $Receiver -eq 'this'){return $Frame.Object}
    if($Receiver -eq 'rec' -and $Engine.Objects[$Frame.Object].TableNo){return $Engine.Objects[$Frame.Object].TableNo}
    if($Frame.Proc.Types.ContainsKey($Receiver)){
        $type=$Frame.Proc.Types[$Receiver]
        if($type -match '^(?:codeunit|record) "([^"]+)"$'){
            $names=@($Engine.Objects.Keys | Where-Object {$_ -ieq $Matches[1]})
            if($names.Count -eq 1){return $names[0]}
        }
    }
    return $null
}
function Add-SourceProofRead($Engine,$Frame,$Token,[string]$Variable,[string]$Key) {
    $name=$Frame.Mapping[$Variable];if(-not $name){$name='unresolved:'+ $Variable}
    $possible=Test-ProofReadPossible $Engine.State $name $Key
    $id=$Frame.Object+'::'+$Frame.Method+'::'+$Token.Start+'::'+$Variable+'::'+$Key
    if(-not $Engine.Sites.ContainsKey($id)){$Engine.Sites[$id]=@{Possible=$false;Visits=0;Contexts=[System.Collections.Generic.List[string]]::new();Object=$Frame.Object;Method=$Frame.Method;Offset=$Token.Start;Variable=$Variable;Key=$Key}}
    $site=$Engine.Sites[$id];$site.Possible=$site.Possible -or $possible -or $Engine.DisableNarrowing -gt 0;$site.Visits++;$site.Contexts.Add($Engine.Context)
}
function Invoke-SourceProofCall($Engine,$Frame,$Head,$Arguments,$Token) {
    Sync-ProofScalars $Engine $Frame
    $h=Get-ProofWords $Head;$receiver='';$method=''
    if($h.Count -eq 5 -and $h[1] -eq '.' -and $h[3] -eq '.'){
        $record=Get-SourceProofTarget $Engine $Frame $h[0] ''
        $field=$Head[2].Text.Trim('"');$matches=@()
        if($null -ne $record -and $Engine.Objects.ContainsKey($record)){
            $pattern='(?i)\bfield\s*\(\s*\d+\s*;\s*"?'+[regex]::Escape($field)+'"?\s*;\s*(Text|Code|Integer|BigInteger|Decimal|Boolean|Guid|Date|DateTime|Time)\b'
            $matches=@([regex]::Matches($Engine.Objects[$record].Text,$pattern))
        }
        foreach($arg in $Arguments){Invoke-SourceProofExpression $Engine $Frame $arg}
        if($matches.Count -eq 1 -and $matches[0].Groups[1].Value -iin @('Text','Code') -and $h[4] -in @('split','contains','startswith','endswith','toupper','tolower','trim','substring','indexof','lastindexof','replace')){return}
        Set-SourceProofUnknown $Engine 'unproved chained record-field method';return
    }
    if($h.Count -eq 1){$method=$h[0].Trim('"').Replace('""','"')}
    elseif($h.Count -eq 3 -and $h[1] -eq '.'){$receiver=$h[0];$method=$h[2].Trim('"').Replace('""','"')}
    else{Set-SourceProofUnknown $Engine 'unresolved chained call';return}
    # Evaluate nested argument effects before trusting a read or validation.
    $fieldSelector=$false
    if($receiver -ne '' -and $Frame.Proc.Types[$receiver] -match '^record\s' -and $method -in @('setrange','setfilter','testfield')){
        $recordTarget=Get-SourceProofTarget $Engine $Frame $receiver $method
        $fieldSelector=$null -eq $recordTarget -or -not $Engine.Objects.ContainsKey($recordTarget) -or -not $Engine.Objects[$recordTarget].Procedures.ContainsKey($method)
    }
    for($argumentIndex=0;$argumentIndex -lt $Arguments.Count;$argumentIndex++){
        $arg=$Arguments[$argumentIndex]
        # Native Record field-selector syntax is a field reference, not an
        # implicit zero-argument function. Other expressions still execute.
        if($fieldSelector -and $argumentIndex -eq 0 -and $arg.Count -eq 1 -and $arg[0].Text -match '^(?:[\p{L}_][\w]*|"(?:[^"]|"")*")$'){continue}
        Invoke-SourceProofExpression $Engine $Frame $arg
    }
    Sync-ProofScalars $Engine $Frame
    if($receiver -ne '' -and $Frame.Proc.Types[$receiver] -eq 'jsonobject'){
        $name=$Frame.Mapping[$receiver];$key=if($Arguments.Count -gt 0){Get-ProofLiteral $Arguments[0]}else{$null}
        if($null -eq $key -and $Arguments.Count -gt 0){$kw=Get-ProofWords $Arguments[0];if($kw.Count -eq 1 -and $Frame.Scalars.ContainsKey($kw[0])){$key=$Frame.Scalars[$kw[0]]}}
        if($method -in @('get','contains') -and $null -ne $key){Add-SourceProofRead $Engine $Frame $Token $receiver $key
            # GET can overwrite output JSON tokens aliased to nested request data.
            if($method -eq 'get' -and $Arguments.Count -gt 1){Set-SourceProofUnknown $Engine 'unresolved JSON Get output alias'}
            return
        }
        if($method -in @('add','remove','replace')){Set-ProofJsonMutation $Engine.State $name $method $key;return}
        if($method -eq 'readfrom'){Set-ProofJsonMutation $Engine.State $name 'ReadFrom';return}
        if($method -eq 'keys' -or $method -eq 'count'){return}
        Set-SourceProofUnknown $Engine ('unresolved JSON method '+$method);return
    }
    if($receiver -eq '' -and $method -eq 'clear' -and $Arguments.Count -eq 1){
        $arg=Get-ProofWords $Arguments[0]
        if($arg.Count -eq 1 -and $Frame.Mapping.ContainsKey($arg[0])){Set-ProofJsonReplacement $Engine.State $Frame.Mapping[$arg[0]];Set-SourceProofUnknown $Engine 'Clear record or JSON aliases';return}
    }
    $target=Get-SourceProofTarget $Engine $Frame $receiver $method
    if($method -eq 'run' -and $null -ne $target -and $Engine.Objects.ContainsKey($target) -and $Engine.Objects[$target].Kind -eq 'codeunit' -and $Engine.Objects[$target].TableNo -and $Engine.Objects[$target].Procedures.ContainsKey('onrun') -and $Arguments.Count -eq 1){
        Invoke-SourceProofProcedure $Engine $target 'onrun' $Arguments $Frame ($Engine.Context+'>'+ $Token.Start)
        Set-SourceProofUnknown $Engine 'codeunit Run return/caught-error boundary';return
    }
    if($null -ne $target -and $Engine.Objects.ContainsKey($target) -and $Engine.Objects[$target].Procedures.ContainsKey($method)){
        $choices=@($Engine.Objects[$target].Procedures[$method])
        if($choices.Count -eq 1){
            $p=Get-ProofProcedure $choices[0];$validator=Get-ProofValidator $p
            $tryFunction=-not (Test-ProofProcedureCanThrow $Engine.Objects[$target].Text $method)
            if($tryFunction){
                Invoke-SourceProofProcedure $Engine $target $method $Arguments $Frame ($Engine.Context+'>'+ $Token.Start)
                Set-SourceProofUnknown $Engine 'TryFunction return/caught-error boundary';return
            }
            if($Engine.DisableNarrowing -eq 0 -and $validator.Proven -and -not $tryFunction -and -not $Engine.Objects[$target].Procedures.ContainsKey('error') -and $Arguments.Count -eq $p.Parameters.Count -and $Arguments.Count -gt 0){
                $arg=Get-ProofWords $Arguments[0]
                if($arg.Count -eq 1 -and $Frame.Mapping.ContainsKey($arg[0])){Set-ProofKeyValidation $Engine.State $Frame.Mapping[$arg[0]] $validator.Keys $true $true;return}
            }
        }
        $bindings=@{}
        if($choices.Count -eq 1 -and $null -ne $p -and $Arguments.Count -eq $p.Parameters.Count){
            for($b=0;$b -lt $Arguments.Count;$b++){
                $lit=Get-ProofLiteral $Arguments[$b];$kw=Get-ProofWords $Arguments[$b]
                if($null -eq $lit -and $kw.Count -eq 1 -and $Frame.Scalars.ContainsKey($kw[0])){$lit=$Frame.Scalars[$kw[0]]}
                if($null -ne $lit -and -not $p.ByVar[$p.Parameters[$b]]){$bindings[$p.Parameters[$b]]=$lit}
                if($p.ByVar[$p.Parameters[$b]] -and $kw.Count -eq 1){$Frame.Scalars.Remove($kw[0])}
            }
            $shape=Get-ProofShapeSummary $Engine.Objects $target $method $bindings
            if($shape.Proven -and ($shape.Adds.Count -gt 0 -or $shape.Removes.Count -gt 0)){
                $pos=[array]::IndexOf($p.Parameters,$shape.Parameter);$arg=Get-ProofWords $Arguments[$pos]
                if($arg.Count -eq 1 -and $Frame.Mapping.ContainsKey($arg[0])){
                    # The body was summarized rather than visited. Prevent any
                    # partial incoming-path proof from excluding reads inside it.
                    $Engine.Blocked[$target+'::'+$method]=$true;$Engine.BlockReasons.Add(@{entry=$target+'::'+$method;reason='shape summary unvisited';context=$Engine.Context})
                    Set-ProofMayShapeEffects $Engine $Frame.Mapping[$arg[0]] $shape;return
                }
            }
            $pure=$false
            foreach($param in $p.Parameters){if($p.Types[$param] -eq 'jsonobject' -and (Test-ProofPureJsonReader $Engine.Objects $target $method $param)){$pure=$true}}
            if($pure){
                $saved=Copy-SourceProofState $Engine.State
                Invoke-SourceProofProcedure $Engine $target $method $Arguments $Frame ($Engine.Context+'>'+ $Token.Start)
                $Engine.State=$saved
                Add-PayloadProofTrace $Engine.State 'source-closed-readonly-helper' @{target=$target;method=$method};return
            }
        }
        $constrained=$null -ne $Engine.State.PayloadAllowed
        foreach($value in $Engine.State.Variables.Values){if($null -ne $value.Allowed){$constrained=$true;break}}
        if(-not $constrained){
            $entry=$target+'::'+$method
            if(-not $Engine.ValidatorReach.ContainsKey($entry)){
                $reach=@{};Get-Reach $Engine.Objects $target $method $reach $true;$hasValidator=$false
                foreach($reached in $reach.Keys){
                    $ep=$reached -split '::',2
                    foreach($source in $Engine.Objects[$ep[0]].Procedures[$ep[1]]){
                        if($source -match '(?is)\bforeach\s+\w+\s+in\s+\w+\.Keys\s*\('){$hasValidator=$true;break}
                    }
                    if($hasValidator){break}
                }
                $Engine.ValidatorReach[$entry]=$hasValidator
            }
            if(-not $Engine.ValidatorReach[$entry]){
                $Engine.Blocked[$entry]=$true;$Engine.BlockReasons.Add(@{entry=$entry;reason='unrestricted skip';context=$Engine.Context})
                $readReach=@{};Get-Reach $Engine.Objects $target $method $readReach $true
                foreach($readEntry in $readReach.Keys){
                    $rp=$readEntry -split '::',2
                    foreach($source in $Engine.Objects[$rp[0]].Procedures[$rp[1]]){foreach($m in $memberRead.Matches($source)){
                        $variable=$m.Groups['var'].Value.ToLowerInvariant();$key=$m.Groups['key'].Value
                        $id=$readEntry+'::'+$m.Index+'::'+$variable+'::'+$key
                        if(-not $Engine.Sites.ContainsKey($id)){$Engine.Sites[$id]=@{Possible=$true;Visits=0;Contexts=[System.Collections.Generic.List[string]]::new();Object=$rp[0];Method=$rp[1];Offset=$m.Index;Variable=$variable;Key=$key}}
                        $site=$Engine.Sites[$id];$site.Possible=$true;$site.Visits++;$site.Contexts.Add($Engine.Context+'>unrestricted:'+ $Token.Start)
                    }}
                }
                Set-SourceProofUnknown $Engine 'unrestricted call without a source validator';return
            }
        }
        Invoke-SourceProofProcedure $Engine $target $method $Arguments $Frame ($Engine.Context+'>'+ $Token.Start);return
    }
    # Closed platform operations on unrelated records do not receive or mutate
    # the Message Argument/JSON identities. No Validate/Modify/trigger writer is
    # included, and a Message Argument record never qualifies here.
    if($receiver -ne '' -and $Frame.Proc.Types.ContainsKey($receiver) -and $Frame.Proc.Types[$receiver] -match '^record\s' -and $Frame.Proc.Types[$receiver] -ne 'record "message argument ori"' -and $method -in @('locktable','isempty','get','getbysystemid','setrange','setfilter','testfield','count')){
        return
    }
    if($Frame.Proc.Types[$receiver] -match '^list of \[ (?:text|code|integer|guid) \]$' -and $method -in @('get','count','contains')){return}
    if($receiver -eq '' -and $method -in @('copystr','strlen','uppercase','lowercase','format','strsubstno','isnullguid')){return}
    if($receiver -eq '' -and $method -eq 'evaluate' -and $Arguments.Count -ge 2){
        $out=Get-ProofWords $Arguments[0]
        if($out.Count -eq 1 -and $Frame.Proc.Types[$out[0]] -match '^(text|code|integer|biginteger|decimal|boolean|date|datetime|time|guid)(?:\s|\[|$)'){$Frame.Scalars.Remove($out[0]);return}
    }
    $Frame.Scalars.Clear()
    foreach($candidate in $Engine.Objects.Keys){
        if($Engine.Objects[$candidate].Procedures.ContainsKey($method)){$Engine.Blocked[$candidate+'::'+$method]=$true}
    }
    Set-SourceProofUnknown $Engine ('unresolved call '+$receiver+'.'+$method)
}
function Invoke-SourceProofExpression($Engine,$Frame,$Tokens) {
    # Walk lexical calls left-to-right. A parsed call owns all nested arguments.
    for($i=0;$i -lt $Tokens.Count;$i++){
        if($Tokens[$i].Text -iin @('if','not','and','or','xor','in','while','until','case','for','foreach','repeat','begin','end','then','else','do')){continue}
        if($Tokens[$i].Text -notmatch '^(?:[\p{L}_][\w]*|"(?:[^"]|"")*")$'){continue}
        $open=$i+1
        if($i+3 -lt $Tokens.Count -and $Tokens[$i+1].Text -eq '.'){$open=$i+3}
        if($i+5 -lt $Tokens.Count -and $Tokens[$i+1].Text -eq '.' -and $Tokens[$i+3].Text -eq '.'){$open=$i+5}
        if($open -ge $Tokens.Count -or $Tokens[$open].Text -ne '('){
            $name=$Tokens[$i].Text.ToLowerInvariant()
            $member=$i -gt 0 -and $Tokens[$i-1].Text -in @('.',':')
            $qualifier=$i+1 -lt $Tokens.Count -and $Tokens[$i+1].Text -in @('.',':')
            if(-not $member -and -not $qualifier -and $name -notin @('true','false','exit','database','codeunit','enum','textencoding') -and -not (Test-ProofKnownScalarSymbol $Engine.Objects $Frame.Object $Frame.Proc $name)){
                Set-SourceProofUnknown $Engine ('implicit or unresolved value/call '+$name)
            }
            if(($member -or (-not $qualifier -and -not $Frame.Proc.Types.ContainsKey($name))) -and $name -notin @('true','false')){
                $implicitTarget=$false
                foreach($obj in $Engine.Objects.Keys){if($Engine.Objects[$obj].Procedures.ContainsKey($name)){$Engine.Blocked[$obj+'::'+$name]=$true;$implicitTarget=$true}}
                if($implicitTarget){Set-SourceProofUnknown $Engine ('implicit source method '+$name)}
            }
            # Parameterless AL record writers must not masquerade as scalar
            # field accesses in assignments or conditions.
            if($member -and $name -in @('modify','insert','delete','deleteall','rename','init','reset','validate','copy','copyfilters','get','findfirst','findlast','findset','next','readfrom','clear')){
                Set-SourceProofUnknown $Engine ('implicit member effect '+$name)
            }
            continue
        }
        $depth=1;$end=$open+1
        while($end -lt $Tokens.Count -and $depth -gt 0){if($Tokens[$end].Text -eq '('){$depth++};if($Tokens[$end].Text -eq ')'){$depth--};$end++}
        if($depth -ne 0){Set-SourceProofUnknown $Engine 'unbalanced expression';return}
        $args=Split-ProofTokens (Get-ProofSlice $Tokens ($open+1) ($end-1)) ','
        Invoke-SourceProofCall $Engine $Frame (Get-ProofSlice $Tokens $i $open) $args $Tokens[$i]
        $i=$end-1
    }
}
function Invoke-SourceProofStatement($Engine,$Frame,$Tokens) {
    Sync-ProofScalars $Engine $Frame
    $originalTokens=$Tokens
    if($Tokens.Count -eq 0){return}
    $w=Get-ProofWords $Tokens
    if($Tokens[-1].Text -eq ';'){$Tokens=Get-ProofSlice $Tokens 0 ($Tokens.Count-1);$w=Get-ProofWords $Tokens}
    if($Tokens.Count -eq 0){return}
    if($w[0] -eq 'begin'){
        $last=$Tokens.Count-1;if($w[$last] -ne 'end'){Set-SourceProofUnknown $Engine 'malformed BEGIN';return}
        Invoke-SourceProofSequence $Engine $Frame $Tokens 1 $last;return
    }
    if($w[0] -eq 'if'){Invoke-SourceProofIf $Engine $Frame $originalTokens;return}
    if($w[0] -in @('case','foreach','for','while','repeat','with')){
        Set-UnrestrictedSourceRegion $Engine $Frame $originalTokens;return
    }
    if($w.Count -ge 3 -and $w[1] -eq ':='){
        $dest=$w[0];$expr=Get-ProofSlice $Tokens 2 $Tokens.Count;$e=Get-ProofWords $expr
        if($Frame.Proc.Types[$dest] -eq 'jsonobject' -and $e.Count -eq 5 -and $e[1] -eq '.' -and $e[3] -eq '(' -and $e[4] -eq ')'){
            $target=Get-SourceProofTarget $Engine $Frame $e[0] $e[2];$proven=$false
            if($Frame.RecordLinks.ContainsKey($e[0]) -and $Frame.RecordLinks[$e[0]] -and $target -eq 'Message Argument ori' -and $Engine.Objects.ContainsKey($target) -and $Engine.Objects[$target].Procedures.ContainsKey($e[2])){
                $choices=@($Engine.Objects[$target].Procedures[$e[2]])
                if($choices.Count -eq 1){$proven=Test-ProofBlobGetter (Get-ProofProcedure $choices[0])}
            }
            if(-not $proven){Set-SourceProofUnknown $Engine 'unproved payload getter'}
            Set-ProofAcquisition $Engine.State $Frame.Mapping[$dest] $proven;return
        }
        if($Frame.Proc.Types[$dest] -eq 'jsonobject' -and $e.Count -eq 1 -and $Frame.Proc.Types[$e[0]] -eq 'jsonobject'){
            Set-ProofJsonAlias $Engine.State $Frame.Mapping[$dest] $Frame.Mapping[$e[0]];return
        }
        Invoke-SourceProofExpression $Engine $Frame $expr
        if($Frame.Proc.Types[$dest] -match '^(text|code|integer|biginteger|decimal|boolean|date|datetime|time|guid)(?:\s|\[|$)|^list of \[ (?:text|code|integer|guid) \]$'){
            Sync-ProofScalars $Engine $Frame
            $Frame.Scalars.Remove($dest);$literal=Get-ProofLiteral $expr
            if($null -ne $literal){$Frame.Scalars[$dest]=$literal};return
        }
        # A nontrivial assignment can escape a record, replace a JSON variable or
        # invoke an AL getter. Keep unknown effects explicit.
        Set-SourceProofUnknown $Engine 'unresolved assignment or record replacement'
        if($Frame.Mapping.ContainsKey($dest)){Set-ProofJsonReplacement $Engine.State $Frame.Mapping[$dest]};return
    }
    if($w[0] -in @('exit','error') -and -not $Engine.Objects[$Frame.Object].Procedures.ContainsKey($w[0])){
        if($Tokens.Count -gt 2 -and $w[1] -eq '('){Invoke-SourceProofExpression $Engine $Frame (Get-ProofSlice $Tokens 2 ($Tokens.Count-1))}
        $Frame.Exits.Add((Copy-SourceProofState $Engine.State));$Frame.Terminated=$true;return
    }
    Invoke-SourceProofExpression $Engine $Frame $Tokens
    # A statement must be a complete simple call to have closed effects.
    if($w.Count -lt 3 -or $w[-1] -ne ')' -or ($w[1] -ne '(' -and ($w.Count -lt 5 -or $w[1] -ne '.' -or $w[3] -ne '('))){Set-SourceProofUnknown $Engine 'unsupported statement'}
}
function Invoke-SourceProofProcedure($Engine,[string]$Object,[string]$Method,$Arguments,$Caller,[string]$Context) {
    $entry=$Object+'::'+$Method
    $Engine.Calls.Add(@{entry=$entry;context=$Context;payloadAllowed=$Engine.State.PayloadAllowed;epoch=$Engine.State.Epoch})
    if($Engine.Stack -contains $entry -or $Engine.Stack.Count -ge 32 -or $Engine.Invocations -ge 1000){$Engine.Blocked[$entry]=$true;$Engine.BlockReasons.Add(@{entry=$entry;reason='procedure refusal';context=$Context});Set-SourceProofUnknown $Engine 'recursive or bounded call graph';return}
    if(-not $Engine.Objects.ContainsKey($Object) -or -not $Engine.Objects[$Object].Procedures.ContainsKey($Method)){$Engine.Blocked[$entry]=$true;$Engine.BlockReasons.Add(@{entry=$entry;reason='procedure refusal';context=$Context});Set-SourceProofUnknown $Engine 'missing source';return}
    $choices=@($Engine.Objects[$Object].Procedures[$Method]);if($choices.Count -ne 1){$Engine.Blocked[$entry]=$true;$Engine.BlockReasons.Add(@{entry=$entry;reason='procedure refusal';context=$Context});Set-SourceProofUnknown $Engine 'overloaded procedure';return}
    $p=Get-ProofProcedure $choices[0];if($null -ne $p -and $Method -eq 'onrun' -and $Engine.Objects[$Object].TableNo){$p=$p.Clone();$p.Types=$p.Types.Clone();$p.ByVar=$p.ByVar.Clone();$p.Parameters=@('rec');$p.Types['rec']='record "'+$Engine.Objects[$Object].TableNo.ToLowerInvariant()+'"';$p.ByVar['rec']=$true};if($null -eq $p){$Engine.Blocked[$entry]=$true;$Engine.BlockReasons.Add(@{entry=$entry;reason='procedure refusal';context=$Context});Set-SourceProofUnknown $Engine 'unsupported declaration';return}
    $Engine.Invocations++;$scope=[string]$Engine.Invocations+':';$mapping=@{};$recordLinks=@{};$scalars=@{}
    foreach($name in $p.Types.Keys){$mapping[$name]=$scope+$name}
    if($null -eq $Caller){
        $records=@($p.Parameters | Where-Object {$p.Types[$_] -eq 'record "message argument ori"'})
        if($records.Count -eq 1){$recordLinks[$records[0]]=$true}
    }
    if($null -ne $Caller){
        Sync-ProofScalars $Engine $Caller
        if($Arguments.Count -ne $p.Parameters.Count){Set-SourceProofUnknown $Engine 'argument arity mismatch';$Engine.Blocked[$entry]=$true}
        for($i=0;$i -lt [Math]::Min($Arguments.Count,$p.Parameters.Count);$i++){
            $param=$p.Parameters[$i];$arg=Get-ProofWords $Arguments[$i]
            $lit=Get-ProofLiteral $Arguments[$i]
            if($null -eq $lit -and $arg.Count -eq 1 -and $Caller.Scalars.ContainsKey($arg[0])){$lit=$Caller.Scalars[$arg[0]]}
            if($null -ne $lit -and -not $p.ByVar[$param]){$scalars[$param]=$lit}
            if($arg.Count -eq 1 -and $Caller.Mapping.ContainsKey($arg[0])){
                if($p.ByVar[$param]){
                    $mapping[$param]=$Caller.Mapping[$arg[0]]
                    if($Caller.RecordLinks.ContainsKey($arg[0])){$recordLinks[$param]=$Caller.RecordLinks[$arg[0]]}
                }
                elseif($p.Types[$param] -eq 'jsonobject'){Set-ProofJsonAlias $Engine.State $mapping[$param] $Caller.Mapping[$arg[0]]}
            }elseif($p.Types[$param] -eq 'jsonobject'){Set-SourceProofUnknown $Engine 'unresolved JSON argument'}
        }
    }
    $frame=@{Object=$Object;Method=$Method;Proc=$p;Mapping=$mapping;RecordLinks=$recordLinks;Scalars=$scalars;ScalarEpoch=$Engine.LiteralEpoch;Terminated=$false;Exits=[System.Collections.Generic.List[object]]::new()}
    $oldContext=$Engine.Context;$Engine.Context=$Context;$Engine.Stack+=,$entry;$Engine.Visited[$entry]=$true
    Invoke-SourceProofSequence $Engine $frame $p.Tokens $p.Start $p.Stop
    if(-not $frame.Terminated){$frame.Exits.Add((Copy-SourceProofState $Engine.State))}
    if($frame.Exits.Count -gt 0){
        $result=$frame.Exits[0]
        for($r=1;$r -lt $frame.Exits.Count;$r++){$result=Merge-SourceProofStates $result $frame.Exits[$r]}
        $Engine.State=$result
    }
    foreach($name in @($Engine.State.Variables.Keys)){if($name.StartsWith($scope)){$Engine.State.Variables.Remove($name)}}
    $Engine.Stack=@($Engine.Stack | Select-Object -SkipLast 1);$Engine.Context=$oldContext
}
function Get-SourcePayloadReadProof($Objects,[string]$Root,[string]$EntryMethod='executebifrosttask') {
    $engine=@{Objects=$Objects;State=(New-RequestPayloadProof);Sites=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal);Visited=@{};Blocked=@{};ValidatorReach=@{};BlockReasons=[System.Collections.Generic.List[object]]::new();Calls=[System.Collections.Generic.List[object]]::new();Stack=@();Invocations=0;Context='entry';DisableNarrowing=0;LiteralEpoch=0;Unresolved=[System.Collections.Generic.List[object]]::new()}
    Invoke-SourceProofProcedure $engine $Root $EntryMethod @() $null 'entry'
    # Any blocked source entry invalidates descendant-site exclusions. An unknown
    # incoming invocation cannot inherit another invocation's validated payload.
    $blockedReach=@{}
    foreach($entry in $engine.Blocked.Keys){$parts=$entry -split '::',2;Get-Reach $Objects $parts[0] $parts[1] $blockedReach $true}
    foreach($entry in $blockedReach.Keys){
        $ep=$entry -split '::',2
        foreach($source in $Objects[$ep[0]].Procedures[$ep[1]]){foreach($m in $memberRead.Matches($source)){
            $variable=$m.Groups['var'].Value.ToLowerInvariant();$key=$m.Groups['key'].Value
            $id=$entry+'::'+$m.Index+'::'+$variable+'::'+$key
            if(-not $engine.Sites.ContainsKey($id)){$engine.Sites[$id]=@{Possible=$true;Visits=0;Contexts=[System.Collections.Generic.List[string]]::new();Object=$ep[0];Method=$ep[1];Offset=$m.Index;Variable=$variable;Key=$key}}
            $site=$engine.Sites[$id];$site.Possible=$true;$site.Visits++;$site.Contexts.Add('unresolved-incoming:'+ $entry)
        }}
    }
    foreach($site in $engine.Sites.Values){if($blockedReach.ContainsKey($site.Object+'::'+$site.Method)){$site.Possible=$true}}
    return $engine
}

# Closed, path-insensitive MAY effects on one JSON parameter. Every use/call and
# assignment is checked. Missing source, aliases, escapes and dynamic mutations
# reject the summary; rejection falls back to the conservative source interpreter.
function Test-ProofPureJsonReader($Objects,[string]$Object,[string]$Method,[string]$Parameter) {
    if(-not $Objects.ContainsKey($Object) -or -not $Objects[$Object].Procedures.ContainsKey($Method)){return $false}
    $bodies=@($Objects[$Object].Procedures[$Method]);if($bodies.Count -ne 1){return $false}
    $p=Get-ProofProcedure $bodies[0];if($null -eq $p -or -not (Test-ProofNoImplicitEffects $Objects $Object $p)){return $false}
    # This summary cannot hide whole-record writes or global assignments merely
    # because the request parameter itself is read-only.
    for($i=$p.Start;$i -lt $p.Stop;$i++){
        if($p.Words[$i] -ne ':='){continue}
        $lhs=$p.Words[$i-1]
        if($i -gt 1 -and $p.Words[$i-2] -eq '.'){return $false}
        if(-not $p.Types.ContainsKey($lhs) -or $p.Types[$lhs] -notmatch '^(text|code|integer|biginteger|decimal|boolean|date|datetime|time|guid)(?:\s|\[|$)'){return $false}
    }
    foreach($type in $p.Types.Values){if($type -match '^(record|codeunit|interface|variant|instream|outstream)\b'){return $false}}
    # Existing reader recognizer closes all calls, parameter uses and JSON effects.
    return (Test-ReadOnlyJsonParameter $Objects $Object $Method $Parameter @{})
}
function Get-ProofShapeSummary($Objects,[string]$Object,[string]$Method,$Bindings) {
    $no=@{Proven=$false;Adds=@();Removes=@()}
    if(-not $Objects.ContainsKey($Object) -or -not $Objects[$Object].Procedures.ContainsKey($Method)){return $no}
    $bodies=@($Objects[$Object].Procedures[$Method]);if($bodies.Count -ne 1){return $no}
    $p=Get-ProofProcedure $bodies[0];if($null -eq $p -or -not (Test-ProofNoImplicitEffects $Objects $Object $p)){return $no}
    foreach($type in $p.Types.Values){if($type -match '^(codeunit|interface|variant|instream|outstream)\b'){return $no}}
    $json=@($p.Parameters | Where-Object {$p.Types[$_] -eq 'jsonobject'})
    if($json.Count -ne 1){return $no};$request=$json[0]
    # Key binding is usable only if no assignment can replace the scalar and no
    # unresolved use can expose it by var. Every called procedure is closed below.
    for($i=$p.Start;$i -lt $p.Stop;$i++){
        if($p.Words[$i] -ne ':='){continue}
        $lhs=$p.Words[$i-1]
        if($i -gt 1 -and $p.Words[$i-2] -eq '.'){return $no}
        if(-not $p.Types.ContainsKey($lhs) -or $Bindings.ContainsKey($lhs) -or $p.Types[$lhs] -notmatch '^(text|code|integer|biginteger|decimal|boolean|date|datetime|time|guid)(?:\s|\[|$)'){return $no}
    }
    $syntax=[regex]::Replace($p.Body,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
    $uses=[regex]::Matches($syntax,"(?i)(?<![.\w])$([regex]::Escape($request))(?![\w])").Count
    $accounted=1;$adds=New-ProofKeySet @();$removes=New-ProofKeySet @()
    foreach($call in @(Get-SourceCalls $p.Body)){
        $receiver=$call.Receiver;$methodName=$call.Callee
        if($receiver -eq $request){
            $accounted++
            if($methodName -in @('add','replace','remove')){
                if($call.Arguments.Count -lt 1){return $no}
                $arg=$call.Arguments[0];$key=$null
                if($arg -cmatch "^'((?:[^']|'')*)'$"){$key=$Matches[1].Replace("''", "'")}
                elseif($Bindings.ContainsKey($arg.ToLowerInvariant())){$key=$Bindings[$arg.ToLowerInvariant()]}
                if($null -eq $key){return $no}
                if($methodName -eq 'remove'){[void]$removes.Add($key)}else{[void]$adds.Add($key)}
            }elseif($methodName -notin @('get','contains','keys','values','count','writeto','clone')){return $no}
            if($methodName -eq 'writeto' -and ($call.Arguments.Count -ne 1 -or $p.Types[$call.Arguments[0].ToLowerInvariant()] -notmatch '^text(?:\s|$)')){return $no}
            # A JSON receiver call must not also pass Request by var/as a value.
            foreach($arg in $call.Arguments){if($arg -ieq $request){return $no}}
            continue
        }
        $forwards=$false
        for($position=0;$position -lt $call.Arguments.Count;$position++){
            if($call.Arguments[$position] -ine $request){continue};$forwards=$true
            if($receiver -notin @('','this')){return $no}
            if(-not $Objects[$Object].Procedures.ContainsKey($methodName)){return $no}
            $calleeBodies=@($Objects[$Object].Procedures[$methodName]);if($calleeBodies.Count -ne 1){return $no}
            $callee=Get-ProofProcedure $calleeBodies[0]
            if($null -eq $callee -or $position -ge $callee.Parameters.Count -or -not (Test-ProofPureJsonReader $Objects $Object $methodName $callee.Parameters[$position])){return $no}
            # Other arguments, including bound keys, must be plain scalar values
            # passed by value; no side-effectful nested call is silently skipped.
            if($call.Arguments.Count -ne $callee.Parameters.Count){return $no}
            for($k=0;$k -lt $call.Arguments.Count;$k++){
                if($k -eq $position){continue}
                if($callee.ByVar[$callee.Parameters[$k]]){return $no}
                if($call.Arguments[$k] -notmatch "^(?:\w+|\d+|'(?:[^']|'')*')$"){return $no}
            }
            $accounted++
        }
        if($forwards){continue}
        # Pure intrinsics have no request/reference output. Evaluate/Clear and
        # arbitrary record/codeunit methods are deliberately absent.
        if($receiver -eq '' -and -not $Objects[$Object].Procedures.ContainsKey($methodName) -and $methodName -in @('exit','error','copystr','strlen','uppercase','lowercase','format','strsubstno')){continue}
        # Fresh local JSON/Token values cannot alias Request: all JSON/record
        # assignments were rejected above, and every Request use is accounted.
        if($p.Types.ContainsKey($receiver) -and $p.Parameters -notcontains $receiver -and $p.Types[$receiver] -match '^(jsonobject|jsonarray|jsontoken|jsonvalue|text)(?:\s|$)' -and $methodName -in @('add','replace','remove','get','contains','keys','values','count','writeto','clone','isvalue','isobject','isarray','asvalue','asobject','asarray','astext','asdecimal','asboolean','startswith')){continue}
        return $no
    }
    if($accounted -ne $uses){return $no}
    return @{Proven=$true;Parameter=$request;Adds=@($adds);Removes=@($removes)}
}
function Set-ProofMayShapeEffects($Engine,[string]$Name,$Summary) {
    if($Engine.State.UncertainAliasing){Set-SourceProofUnknown $Engine 'MAY-shape summary has unresolved incoming aliases';return}
    if(-not $Engine.State.Variables.ContainsKey($Name)){return}
    $value=$Engine.State.Variables[$Name]
    # A conditional removal is MAY: never remove it from the possible current
    # keys. Retain it when reconstructing the original request after validation.
    foreach($key in $Summary.Removes){[void]$value.Removed.Add($key)}
    foreach($key in $Summary.Adds){if($null -ne $value.Allowed){[void]$value.Allowed.Add($key)}}
    Add-PayloadProofTrace $Engine.State 'source-closed-may-shape' @{variable=$Name;adds=$Summary.Adds;removes=$Summary.Removes}
}
function Test-ProofProcedureCanThrowUncached([string]$Source,[string]$Method) {
    $t=@(Get-ALTokens $Source);$positions=@()
    for($i=0;$i+1 -lt $t.Count;$i++){if($t[$i].Text -ieq 'procedure' -and $t[$i+1].Text.Trim('"') -ieq $Method){$positions+=,$i}}
    if($positions.Count -ne 1){return $false}
    $j=$positions[0]-1
    while($j -ge 0 -and $t[$j].Text -iin @('local','internal','protected','public')){$j--}
    while($j -ge 0 -and $t[$j].Text -eq ']'){
        $depth=1;$hasTry=$false;$j--
        while($j -ge 0 -and $depth -gt 0){
            if($t[$j].Text -eq ']'){$depth++}elseif($t[$j].Text -eq '['){$depth--}
            if($t[$j].Text -ieq 'TryFunction'){$hasTry=$true};$j--
        }
        if($depth -ne 0 -or $hasTry){return $false}
    }
    return $true
}
function Test-ProofProcedureCanThrow([string]$Source,[string]$Method) {
    if($null -eq $script:SourceProofThrowDeclarations){$script:SourceProofThrowDeclarations=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)}
    if(-not $script:SourceProofThrowDeclarations.ContainsKey($Source)){
        if($script:SourceProofThrowDeclarations.Count -ge 512){$script:SourceProofThrowDeclarations.Clear()}
        $script:SourceProofThrowDeclarations[$Source]=[System.Collections.Generic.Dictionary[string,bool]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    $methods=$script:SourceProofThrowDeclarations[$Source]
    if(-not $methods.ContainsKey($Method)){$methods[$Method]=Test-ProofProcedureCanThrowUncached $Source $Method}
    return $methods[$Method]
}
function Test-ProofKnownScalarSymbol($Objects,[string]$Object,$Proc,[string]$Name) {
    if($Proc.Types.ContainsKey($Name)){return $true}
    $source=$Objects[$Object].Text
    if($null -eq $script:SourceProofGlobalScalars){$script:SourceProofGlobalScalars=[System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)}
    if(-not $script:SourceProofGlobalScalars.ContainsKey($source)){
        if($script:SourceProofGlobalScalars.Count -ge 512){$script:SourceProofGlobalScalars.Clear()}
        $prefix=$source;$first=[regex]::Match($source,'(?im)^\s*(?:(?:local|internal|protected)\s+)?(?:procedure|trigger)\b')
        if($first.Success){$prefix=$source.Substring(0,$first.Index)}
        $symbols=New-ProofKeySet @()
        foreach($m in [regex]::Matches($prefix,'(?i)\b(\w+)\s*:\s*(?:Text|Code|Integer|BigInteger|Decimal|Boolean|Guid|Date|DateTime|Time|Label)\b')){[void]$symbols.Add($m.Groups[1].Value.ToLowerInvariant())}
        $script:SourceProofGlobalScalars[$source]=$symbols
    }
    return $script:SourceProofGlobalScalars[$source].Contains($Name.ToLowerInvariant())
}
function Get-SourceProofMethodNames($Objects) {
    if(-not [object]::ReferenceEquals($script:SourceProofMethodObjects,$Objects)){
        $script:SourceProofMethodObjects=$Objects;$script:SourceProofMethodNames=New-ProofKeySet @()
        foreach($obj in $Objects.Values){foreach($method in $obj.Procedures.Keys){[void]$script:SourceProofMethodNames.Add($method.ToLowerInvariant())}}
    }
    return ,$script:SourceProofMethodNames
}
function Test-ProofNoImplicitEffects($Objects,[string]$Object,$Proc) {
    $t=$Proc.Tokens
    $keywords=@('if','not','and','or','xor','in','while','until','case','of','for','foreach','repeat','begin','end','then','else','do','to','downto','true','false','exit','break','continue','database','codeunit','enum','textencoding')
    for($i=$Proc.Start;$i -lt $Proc.Stop;$i++){
        $name=$t[$i].Text.ToLowerInvariant()
        if($i+2 -lt $Proc.Stop -and $t[$i].Text -in @(')',']') -and $t[$i+1].Text -eq '.'){
            $chained=$t[$i+2].Text.Trim('"').Replace('""','"').ToLowerInvariant()
            if($chained -notin @('astext','asdecimal','asboolean','asinteger','asbiginteger','asdate','asdatetime','astime','isvalue','isobject','isarray','asvalue','asobject','asarray','count','contains','get','keys','values','clone')){return $false}
        }
        if($name -notmatch '^[a-z_][\w]*$' -or $name -in $keywords){continue}
        if($i+2 -lt $Proc.Stop -and $t[$i+1].Text -eq '.' -and ($i+3 -ge $Proc.Stop -or $t[$i+3].Text -ne '(')){
            $member=$t[$i+2].Text.ToLowerInvariant();$methodKnown=(Get-SourceProofMethodNames $Objects).Contains($member)
            if($Proc.Types[$name] -notmatch '^record\s' -or $methodKnown -or $member -in @('modify','insert','delete','deleteall','rename','init','reset','validate','copy','copyfilters','get','findfirst','findlast','findset','next')){return $false}
        }
        if($i -gt 0 -and $t[$i-1].Text -in @('.',':')){continue}
        if($i+1 -lt $Proc.Stop -and $t[$i+1].Text -in @('(','.',':')){continue}
        if(-not (Test-ProofKnownScalarSymbol $Objects $Object $Proc $name)){return $false}
    }
    return $true
}

function Copy-SourceProofState($State) {
    $copy=New-RequestPayloadProof;$copy.Epoch=$State.Epoch;$copy.NextIdentity=$State.NextIdentity;$copy.UncertainAliasing=$State.UncertainAliasing
    if($null -ne $State.PayloadAllowed){$copy.PayloadAllowed=New-ProofKeySet $State.PayloadAllowed}
    $values=@{}
    foreach($name in $State.Variables.Keys){
        $value=$State.Variables[$name];$id=[string]$value.Identity
        if(-not $values.ContainsKey($id)){
            $allowed=$null;if($null -ne $value.Allowed){$allowed=New-ProofKeySet $value.Allowed}
            $values[$id]=@{Identity=$value.Identity;PayloadEpoch=$value.PayloadEpoch;Allowed=$allowed;Removed=(New-ProofKeySet $value.Removed)}
        }
        $copy.Variables[$name]=$values[$id]
    }
    foreach($read in $State.Reads){$copy.Reads.Add($read)};foreach($trace in $State.Trace){$copy.Trace.Add($trace)}
    return $copy
}
function Merge-SourceProofStates($Left,$Right) {
    $state=New-RequestPayloadProof
    $sameEpoch=$Left.Epoch -eq $Right.Epoch
    $state.Epoch=[Math]::Max($Left.Epoch,$Right.Epoch)
    if(-not $sameEpoch){$state.Epoch++}
    $state.NextIdentity=[Math]::Max($Left.NextIdentity,$Right.NextIdentity)
    if($sameEpoch -and $null -ne $Left.PayloadAllowed -and $null -ne $Right.PayloadAllowed){
        $state.PayloadAllowed=New-ProofKeySet $Left.PayloadAllowed;$state.PayloadAllowed.UnionWith($Right.PayloadAllowed)
    }
    $names=New-ProofKeySet (@($Left.Variables.Keys)+@($Right.Variables.Keys));$pairs=@{}
    foreach($name in $names){
        $lv=$Left.Variables[$name];$rv=$Right.Variables[$name]
        if($null -eq $lv -or $null -eq $rv){Set-ProofAcquisition $state $name $false;continue}
        $pair=[string]$lv.Identity+':'+[string]$rv.Identity
        if(-not $pairs.ContainsKey($pair)){
            $state.NextIdentity++;$allowed=$null;$epoch=$null
            if($null -ne $lv.Allowed -and $null -ne $rv.Allowed){$allowed=New-ProofKeySet $lv.Allowed;$allowed.UnionWith($rv.Allowed)}
            if($sameEpoch -and $null -ne $lv.PayloadEpoch -and $null -ne $rv.PayloadEpoch -and $lv.PayloadEpoch -eq $Left.Epoch -and $rv.PayloadEpoch -eq $Right.Epoch){$epoch=$state.Epoch}
            $removed=New-ProofKeySet $lv.Removed;$removed.UnionWith($rv.Removed)
            $pairs[$pair]=@{Identity=$state.NextIdentity;PayloadEpoch=$epoch;Allowed=$allowed;Removed=$removed}
        }
        $state.Variables[$name]=$pairs[$pair]
    }
    # If alias relations differ between incoming paths, a later mutation havocs
    # the state. Reads still use the union of both possible key sets.
    $state.UncertainAliasing=$Left.UncertainAliasing -or $Right.UncertainAliasing
    $array=@($names)
    for($i=0;$i -lt $array.Count;$i++){for($j=$i+1;$j -lt $array.Count;$j++){
        $a=$array[$i];$b=$array[$j]
        if($Left.Variables.ContainsKey($a) -and $Left.Variables.ContainsKey($b) -and $Right.Variables.ContainsKey($a) -and $Right.Variables.ContainsKey($b)){
            $la=$Left.Variables[$a].Identity -eq $Left.Variables[$b].Identity;$ra=$Right.Variables[$a].Identity -eq $Right.Variables[$b].Identity
            if($la -ne $ra){$state.UncertainAliasing=$true}
        }else{$state.UncertainAliasing=$true}
    }}
    foreach($read in @($Left.Reads)+@($Right.Reads)){$state.Reads.Add($read)}
    # Preserve a bounded join witness rather than duplicating complete path traces.
    Add-PayloadProofTrace $state 'source-path-union' @{leftEpoch=$Left.Epoch;rightEpoch=$Right.Epoch;uncertainAliasing=$state.UncertainAliasing}
    return $state
}
function Copy-SourceProofFrame($Frame) {
    return @{Object=$Frame.Object;Method=$Frame.Method;Proc=$Frame.Proc;Mapping=$Frame.Mapping.Clone();RecordLinks=$Frame.RecordLinks.Clone();Scalars=$Frame.Scalars.Clone();ScalarEpoch=$Frame.ScalarEpoch;Terminated=$false;Exits=[System.Collections.Generic.List[object]]::new()}
}
function Invoke-SourceProofSequence($Engine,$Frame,$Tokens,[int]$Start,[int]$Stop) {
    $i=$Start
    while($i -lt $Stop -and -not $Frame.Terminated){
        if($Tokens[$i].Text -eq '#'){
            Set-UnrestrictedSourceRegion $Engine $Frame (Get-ProofSlice $Tokens $i $Stop)
            $Frame.Exits.Add((Copy-SourceProofState $Engine.State));$Frame.Terminated=$true;return
        }
        $next=Get-ALStatementNext $Tokens $i
        if($next -le $i -or $next -gt $Stop){Set-UnrestrictedSourceRegion $Engine $Frame (Get-ProofSlice $Tokens $i $Stop);$Frame.Exits.Add((Copy-SourceProofState $Engine.State));$Frame.Terminated=$true;return}
        Invoke-SourceProofStatement $Engine $Frame (Get-ProofSlice $Tokens $i $next);$i=$next
    }
}
function Invoke-SourceProofIf($Engine,$Frame,$Tokens) {
    $depth=0;$then=-1
    for($i=1;$i -lt $Tokens.Count;$i++){
        if($Tokens[$i].Text -eq '('){$depth++}elseif($Tokens[$i].Text -eq ')'){$depth--}
        elseif($depth -eq 0 -and $Tokens[$i].Text -ieq 'then'){$then=$i;break}
    }
    if($then -lt 0){Set-SourceProofUnknown $Engine 'malformed IF';return}
    # Conditional evaluation precedes either successor, so later validation never
    # removes a read performed by the condition itself.
    Invoke-SourceProofExpression $Engine $Frame (Get-ProofSlice $Tokens 1 $then)
    $next=Get-ALStatementNext $Tokens ($then+1)
    if($next -le $then+1){Set-SourceProofUnknown $Engine 'malformed THEN';return}
    $base=Copy-SourceProofState $Engine.State;$left=Copy-SourceProofFrame $Frame
    $Engine.State=Copy-SourceProofState $base
    Invoke-SourceProofStatement $Engine $left (Get-ProofSlice $Tokens ($then+1) $next)
    $leftState=$Engine.State;$right=Copy-SourceProofFrame $Frame;$Engine.State=Copy-SourceProofState $base
    if($next -lt $Tokens.Count -and $Tokens[$next].Text -ieq 'else'){
        Invoke-SourceProofStatement $Engine $right (Get-ProofSlice $Tokens ($next+1) $Tokens.Count)
    }
    $rightState=$Engine.State
    foreach($exitState in @($left.Exits)+@($right.Exits)){$Frame.Exits.Add($exitState)}
    if($left.Terminated -and $right.Terminated){$Frame.Terminated=$true;$Engine.State=$base}
    elseif($left.Terminated){$Engine.State=$rightState}
    elseif($right.Terminated){$Engine.State=$leftState}
    else{$Engine.State=Merge-SourceProofStates $leftState $rightState}
    # Scalar branch assignments may differ; do not carry an old literal binding.
    $Frame.Scalars.Clear()
}
function Set-UnrestrictedSourceRegion($Engine,$Frame,$Tokens) {
    if($Tokens.Count -eq 0){return}
    $start=$Tokens[0].Start;$stop=$Tokens[-1].End
    $source=$Frame.Proc.Body.Substring($start,$stop-$start)
    foreach($m in $memberRead.Matches($source)){
        $variable=$m.Groups['var'].Value.ToLowerInvariant();$key=$m.Groups['key'].Value;$offset=$start+$m.Index
        $id=$Frame.Object+'::'+$Frame.Method+'::'+$offset+'::'+$variable+'::'+$key
        if(-not $Engine.Sites.ContainsKey($id)){$Engine.Sites[$id]=@{Possible=$true;Visits=0;Contexts=[System.Collections.Generic.List[string]]::new();Object=$Frame.Object;Method=$Frame.Method;Offset=$offset;Variable=$variable;Key=$key}}
        $site=$Engine.Sites[$id];$site.Possible=$true;$site.Visits++;$site.Contexts.Add($Engine.Context+'>unrestricted-region')
    }
    $words=New-ProofKeySet (@(Get-ALTokens $source | Where-Object {$_.Text -match '^(?:[\p{L}_][\w]*|"(?:[^"]|"")*")$'} | ForEach-Object {$_.Text.Trim('"').ToLowerInvariant()}))
    foreach($obj in $Engine.Objects.Keys){foreach($method in $Engine.Objects[$obj].Procedures.Keys){
        # Includes explicit and implicit calls. Only descendants with an unknown
        # incoming invocation lose proof; earlier reads in this procedure remain.
        if($words.Contains($method.ToLowerInvariant())){$Engine.Blocked[$obj+'::'+$method]=$true;$Engine.BlockReasons.Add(@{entry=$obj+'::'+$method;reason='unrestricted region';context=$Engine.Context;region=$source})}
    }}
    Set-SourceProofUnknown $Engine 'unsupported source region effects'
}

function Get-ReadKeys($Objects, [string]$Codeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $Codeunit 'executebifrosttask' $seen $true
    $sourceProof = Get-SourcePayloadReadProof $Objects $Codeunit
    $requestVars = Get-RequestVars $Objects $seen
    $origins = Get-RequestOrigins $Objects $seen $requestVars
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        $requestNames = $requestVars[$entry]
        foreach ($body in $Objects[$parts[0]].Procedures[$parts[1]]) {
            Add-TypedReaderKeys $Objects $seen $parts[0] $parts[1] $body $requestNames $keys $origins[$entry]
            foreach ($m in $memberRead.Matches($body)) {
                $proofId = $parts[0]+'::'+$parts[1]+'::'+$m.Index+'::'+$m.Groups['var'].Value.ToLowerInvariant()+'::'+$m.Groups['key'].Value
                if ($sourceProof.Sites.ContainsKey($proofId) -and -not $sourceProof.Sites[$proofId].Possible) { continue }
                Add-CallRead $m $requestNames $keys
                if ($m.Groups['var'].Success -and $origins[$entry].ContainsKey($m.Groups['var'].Value.ToLowerInvariant())) {
                    foreach ($path in $origins[$entry][$m.Groups['var'].Value.ToLowerInvariant()]) {
                        if ($path -ne '' -and $path -ne '?') { [void]$keys.Add($path) }
                    }
                }
            }
            foreach ($m in $callRead.Matches($body)) {
                if (Test-CaseSelectorArgument $Objects $parts[0] $m $body) { continue }
                if (Test-RejectionOnlyCall $Objects $parts[0] $m $body) {
                    if ($m.Groups['var'].Success -and $requestNames.Contains($m.Groups['var'].Value.ToLowerInvariant())) { [void]$script:RejectedReads.Add($m.Groups['key'].Value) }
                    continue
                }
                Add-CallRead $m $requestNames $keys
            }
            foreach ($m in $keySpec.Matches($body)) {
                foreach ($pair in $m.Groups[1].Value.Split(',')) { [void]$keys.Add($pair.Split('=')[0]) }
            }
        }
    }
    return ,$keys
}

# Bound source recognition to the selected contract chapter; unresolved dispatch remains an offender.
function Get-SelectedObjects($Objects, [string]$Contract) {
    $copy = @{}
    foreach ($name in $Objects.Keys) {
        $copy[$name] = $Objects[$name].Clone()
        $copy[$name].Procedures = @{}
        foreach ($proc in $Objects[$name].Procedures.Keys) { $copy[$name].Procedures[$proc] = @($Objects[$name].Procedures[$proc]) }
    }
    foreach ($root in @('getparameters','gettarget')) {
        $seen = @{}; Get-Reach $Objects $Contract $root $seen
        foreach ($entry in $seen.Keys) {
            $parts = $entry -split '::',2
            $obj = $Objects[$parts[0]]; $proc = $parts[1]
            $bodies = @()
            foreach ($body in $obj.Procedures[$proc]) {
                $case = [regex]::Match($body, '(?i)\bcase\s+(\w+)\s+of\b')
                if (-not $case.Success) { $bodies += $body; continue }
                $params = Get-ParameterNames $body
                $position = [array]::IndexOf($params, $case.Groups[1].Value.ToLowerInvariant())
                $selectors = New-Object 'System.Collections.Generic.HashSet[string]'
                $unknown = $position -lt 0
                foreach ($caller in $seen.Keys) {
                    $cp = $caller -split '::',2
                    foreach ($cb in $Objects[$cp[0]].Procedures[$cp[1]]) {
                        foreach ($call in $callWithArgs.Matches($cb)) {
                            if ($call.Groups['callee'].Value -ine $proc) { continue }
                            if ($cb.Substring(0,$call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                            $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
                            $targets = if ($receiver -eq '') { @($cp[0]) } elseif ($Objects[$cp[0]].Variables.ContainsKey($receiver)) { @($Objects[$cp[0]].Variables[$receiver]) } else { @() }
                            if ($targets -notcontains $parts[0]) { continue }
                            # Tokenize arguments without splitting commas inside AL strings.
                            $args = @([regex]::Matches($call.Groups['args'].Value, "'(?:[^']|'')*'|[^,]+") | ForEach-Object { $_.Value.Trim() })
                            if ($position -ge 0 -and $position -lt $args.Count -and $args[$position] -match "^'((?:[^']|'')*)'$" ) { [void]$selectors.Add($Matches[1].Replace("''", "'")) } else { $unknown = $true }
                        }
                    }
                }
                if ($unknown -or $selectors.Count -ne 1) { $script:ContractDiagnostics.Add("dynamic-ambiguity|$entry"); $bodies += $body; continue }
                $selector = @($selectors)[0]
                # Match end of CASE using AL block tokens with string literals removed.
                $tail = $body.Substring($case.Index + $case.Length)
                $mask = [regex]::Replace($tail, "'(?:[^']|'')*'", { param($m) ' ' * $m.Length })
                $depth = 1; $end = -1
                foreach ($token in [regex]::Matches($mask, '(?i)\b(begin|case|end)\b')) {
                    if ($token.Value -ieq 'end') { $depth-- } else { $depth++ }
                    if ($depth -eq 0) { $end = $token.Index; break }
                }
                if ($end -lt 0) { $script:ContractDiagnostics.Add("dynamic-ambiguity|malformed-case:$entry"); $bodies += $body; continue }
                $inside = $tail.Substring(0,$end)
                $branches = @([regex]::Matches($inside, "(?m)^\s*((?:'(?:[^']|'')*'\s*,?\s*)+):"))
                $chosen = ''
                for ($i=0; $i -lt $branches.Count; $i++) {
                    $labels = @($stringLiteral.Matches($branches[$i].Groups[1].Value) | ForEach-Object { $_.Groups[1].Value.Replace("''", "'") })
                    if ($labels -ccontains $selector) {
                        $start = $branches[$i].Index + $branches[$i].Length
                        $stop = if ($i+1 -lt $branches.Count) { $branches[$i+1].Index } else { $inside.Length }
                        $chosen = $inside.Substring($start,$stop-$start)
                    }
                }
                if ($inside -match '(?im)^\s*else\b') { $script:ContractDiagnostics.Add("dynamic-ambiguity|case-else:$entry"); $bodies += $body; continue }
                $bodies += $body.Substring(0,$case.Index) + $chosen + $tail.Substring($end+3)
            }
            $copy[$parts[0]].Procedures[$proc] = $bodies
        }
    }
    return $copy
}
function Add-ContractDeclarations([string]$Body, $Keys) {
    # Bind only to the chapter's JsonArray output (var parameter or named return value).
    $outputs = @()
    foreach ($m in [regex]::Matches($Body, '(?i)\bvar\s+(\w+)\s*:\s*JsonArray|\)\s*(\w+)\s*:\s*JsonArray')) {
        $outputs += $(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })
    }
    foreach ($output in $outputs) {
        $escaped = [regex]::Escape($output)
        # Track final chapter contents in statement order. A reset or replacement discards prior entries.
        $state = @{}
        $outputKeys = New-Object 'System.Collections.Generic.HashSet[string]'
        $statements = "(?i)\bClear\(\s*(\w+)\s*\)|\b$escaped\.ReadFrom\(\s*'((?:[^']|'')*)'\s*\)|\b(\w+)\.Add\(\s*'name'\s*,\s*'((?:[^']|'')*)'\s*\)|\b$escaped\.Add\(\s*(\w+)\s*\)"
        foreach ($m in [regex]::Matches($Body, $statements)) {
            if ($m.Groups[1].Success) {
                $state.Remove($m.Groups[1].Value.ToLowerInvariant())
                if ($m.Groups[1].Value -ieq $output) { $outputKeys.Clear() }
            } elseif ($m.Groups[2].Success) {
                $outputKeys.Clear()
                try {
                    $json = $m.Groups[2].Value.Replace("''", "'")
                    if (-not $json.TrimStart().StartsWith('[')) { throw 'Expected parameter array' }
                    $entries = ConvertFrom-Json -InputObject $json -NoEnumerate -ErrorAction Stop
                    foreach ($item in $entries) {
                        if ($item.name -isnot [string] -or $item.name -eq '') { throw 'Missing parameter name' }
                        [void]$outputKeys.Add($item.name)
                    }
                } catch { $script:ContractDiagnostics.Add('malformed-contract-json|'+$output) }
            } elseif ($m.Groups[3].Success) {
                $state[$m.Groups[3].Value.ToLowerInvariant()] = $m.Groups[4].Value.Replace("''", "'")
            } elseif ($state.ContainsKey($m.Groups[5].Value.ToLowerInvariant())) {
                [void]$outputKeys.Add($state[$m.Groups[5].Value.ToLowerInvariant()])
            }
        }
        foreach ($key in $outputKeys) { [void]$Keys.Add($key) }
    }
}
# A caller binding is usable only while the parameter stays unchanged. Treat any
# other use conservatively, including unknown calls that could receive it by var.
function Test-StableTypedReaderKey($Object, [string]$Body, [string]$Parameter) {
    $syntax = [regex]::Replace($Body, "'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/", ' ')
    $begin = [regex]::Match($syntax, '(?i)\bbegin\b')
    if (-not $begin.Success) { return $false }
    $syntax = $syntax.Substring($begin.Index + $begin.Length)
    $uses = @{}
    foreach ($use in [regex]::Matches($syntax, "(?i)(?<![\w])$([regex]::Escape($Parameter))(?![\w])")) { $uses[$use.Index] = $true }
    $stack = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $syntax.Length; $i++) {
        if ($uses.ContainsKey($i)) {
            if ($stack.Count -eq 0) { return $false }
            $call = $stack[$stack.Count - 1]
            $type = if ($Object.Variables.ContainsKey($call.Receiver)) { @($Object.Variables[$call.Receiver]) } else { @() }
            $reader = $type -contains 'Request Value Reader ori' -and $call.Name -match '^(?i:TryReadDate|TryReadDecimal|TryReadBoolean)$' -and $call.Argument -eq 2
            # Message Argument's error-response text parameters are read-only API inputs.
            $response = $type -contains 'Message Argument ori' -and $call.Name -ieq 'RespondWithError'
            if (-not $reader -and -not $response) { return $false }
        }
        if ($syntax[$i] -eq '(') {
            $match = [regex]::Match($syntax.Substring(0, $i), '(?i)(?:(?<receiver>\w+)\.)?(?<callee>\w+)\s*$')
            $stack.Add(@{ Name = $match.Groups['callee'].Value; Receiver = $match.Groups['receiver'].Value.ToLowerInvariant(); Argument = 0 })
        } elseif ($syntax[$i] -eq ')' -and $stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }
        elseif ($syntax[$i] -eq ',' -and $stack.Count -gt 0) { $stack[$stack.Count - 1].Argument++ }
    }
    return $uses.Count -gt 0
}

# Resolve one parameter only when every reached call supplies a literal. Do not
# guess through overloads, unknown receivers or another variable forwarding layer.
function Get-LiteralParameterBindings($Objects, $Seen, [string]$ObjectName, [string]$ProcedureName, [string]$Body, [string]$Parameter) {
    $unresolved = @{ Resolved = $false; Values = @() }
    if (@($Objects[$ObjectName].Procedures[$ProcedureName]).Count -ne 1) { return $unresolved }
    $params = Get-ParameterNames $Body
    $position = [array]::IndexOf($params, $Parameter.ToLowerInvariant())
    if ($position -lt 0) { return $unresolved }
    if (-not (Test-StableTypedReaderKey $Objects[$ObjectName] $Body $Parameter)) { return $unresolved }
    $values = New-Object 'System.Collections.Generic.HashSet[string]'
    $calls = 0
    foreach ($entry in $Seen.Keys) {
        $parts = $entry -split '::', 2
        $caller = $Objects[$parts[0]]
        foreach ($callerBody in $caller.Procedures[$parts[1]]) {
            $flatCalls = @($callWithArgs.Matches($callerBody))
            # A nested/dynamic argument list must not disappear from the proof just
            # because the flat argument matcher cannot parse it.
            foreach ($start in $anyCall.Matches($callerBody)) {
                $name = if ($start.Groups['callee'].Success) { $start.Groups['callee'].Value } else { $start.Groups['chained'].Value }
                if ($name -ine $ProcedureName) { continue }
                if ($callerBody.Substring(0, $start.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                if (-not ($flatCalls | Where-Object { $_.Index -eq $start.Index })) { return $unresolved }
            }
            foreach ($call in $flatCalls) {
                if ($call.Groups['callee'].Value -ine $ProcedureName) { continue }
                if ($callerBody.Substring(0, $call.Index) -match '(?i)\b(procedure|trigger)\s+$') { continue }
                $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
                $targets = @(if ($receiver -eq '' -or $receiver -in @('this', 'rec')) { $parts[0] }
                    elseif ($caller.Variables.ContainsKey($receiver)) { $caller.Variables[$receiver] })
                if ($targets.Count -eq 0) { return $unresolved }
                if ($targets -notcontains $ObjectName) { continue }
                if ($targets.Count -ne 1) { return $unresolved }
                $args = @([regex]::Matches($call.Groups['args'].Value, "'(?:[^']|'')*'|[^,]+") | ForEach-Object { $_.Value.Trim() })
                if ($position -ge $args.Count) { return $unresolved }
                $literal = [regex]::Match($args[$position], "^'((?:[^']|'')*)'$")
                if (-not $literal.Success) { return $unresolved }
                [void]$values.Add($literal.Groups[1].Value.Replace("''", "'"))
                $calls++
            }
        }
    }
    return @{ Resolved = $calls -gt 0; Values = @($values) }
}

function Add-TypedReaderKeys($Objects, $Seen, [string]$ObjectName, [string]$ProcedureName, [string]$Body, $RequestNames, $Keys, $Origins) {
    $Object = $Objects[$ObjectName]
    foreach ($call in $callWithArgs.Matches($Body)) {
        $receiver = $call.Groups['receiver'].Value.ToLowerInvariant()
        if (-not $Object.Variables.ContainsKey($receiver) -or $Object.Variables[$receiver] -notcontains 'Request Value Reader ori') { continue }
        if ($call.Groups['callee'].Value -notmatch '^(?i:TryReadDate|TryReadDecimal|TryReadBoolean)$') { continue }
        $args = @([regex]::Matches($call.Groups['args'].Value, "'(?:[^']|'')*'|[^,]+") | ForEach-Object { $_.Value.Trim() })
        $resolved = $false
        $paths = if ($args.Count -ge 5 -and $null -ne $Origins) { @(Get-ExpressionOrigins $args[1] $Origins) } else { @() }
        if ($paths.Count -gt 0 -and $paths -notcontains '' -and $paths -notcontains '?') {
            foreach ($path in $paths) { [void]$Keys.Add($path) }
            $resolved = $true
        }
        if ($args.Count -ge 5 -and $RequestNames.Contains($args[1].ToLowerInvariant())) {
            if ($args[2] -match "^'((?:[^']|'')*)'$" ) {
                [void]$Keys.Add($Matches[1].Replace("''", "'"))
                $resolved = $true
            } elseif ($args[2] -match '^\w+$') {
                $binding = Get-LiteralParameterBindings $Objects $Seen $ObjectName $ProcedureName $Body $args[2]
                if ($binding.Resolved) {
                    foreach ($key in $binding.Values) { [void]$Keys.Add($key) }
                    $resolved = $true
                }
            }
        }
        if (-not $resolved) { $script:ContractDiagnostics.Add('dynamic-ambiguity|typed-reader:'+ $call.Value) }
    }
}

# Token positions are retained so discarded branches cannot affect reachability.
function Get-ALTokens([string]$Text) {
    foreach ($match in [regex]::Matches($Text, '''(?:[^'']|'''')*''|"(?:[^"]|"")*"|//[^\r\n]*|/\*[\s\S]*?\*/|\w+|:=|<>|[^\s]')) {
        if ($match.Value.StartsWith('//') -or $match.Value.StartsWith('/*')) { continue }
        @{ Text = $match.Value; Start = $match.Index; End = $match.Index + $match.Length }
    }
}

# Return the first token following one complete AL statement, including dangling
# ELSE ownership. Unsupported/malformed statements are never used to prune.
function Get-ALStatementNext($Tokens, [int]$Index) {
    if ($Index -ge $Tokens.Count) { return -1 }
    $word = $Tokens[$Index].Text.ToLowerInvariant()
    if ($word -in @('begin','case')) {
        $depth = 1
        for ($i = $Index + 1; $i -lt $Tokens.Count; $i++) {
            if ($Tokens[$i].Text -iin @('begin','case')) { $depth++ }
            elseif ($Tokens[$i].Text -ieq 'end') { $depth-- }
            if ($depth -eq 0) {
                $i++; if ($i -lt $Tokens.Count -and $Tokens[$i].Text -eq ';') { $i++ }; return $i
            }
        }
        return -1
    }
    if($word -eq 'repeat'){
        $depth=1;$until=-1
        for($i=$Index+1;$i -lt $Tokens.Count;$i++){
            if($Tokens[$i].Text -ieq 'repeat'){$depth++}
            elseif($Tokens[$i].Text -ieq 'until'){$depth--;if($depth -eq 0){$until=$i;break}}
        }
        if($until -lt 0){return -1};$parentheses=0
        for($i=$until+1;$i -lt $Tokens.Count;$i++){
            if($Tokens[$i].Text -eq '('){$parentheses++}elseif($Tokens[$i].Text -eq ')'){$parentheses--}
            elseif($parentheses -eq 0 -and $Tokens[$i].Text -eq ';'){return ($i+1)}
            elseif($parentheses -eq 0 -and $Tokens[$i].Text -iin @('else','end')){return $i}
        }
        return -1
    }
    if ($word -in @('foreach','for','while','with')) {
        $depth=0
        for($i=$Index+1;$i -lt $Tokens.Count;$i++){
            if($Tokens[$i].Text -in @('(','[')){$depth++}
            elseif($Tokens[$i].Text -in @(')',']')){$depth--}
            elseif($depth -eq 0 -and $Tokens[$i].Text -ieq 'do'){return (Get-ALStatementNext $Tokens ($i+1))}
        }
        return -1
    }
    if ($word -eq 'if') {
        $depth = 0; $then = -1
        for ($i = $Index + 1; $i -lt $Tokens.Count; $i++) {
            if ($Tokens[$i].Text -eq '(') { $depth++ }
            elseif ($Tokens[$i].Text -eq ')') { $depth-- }
            elseif ($depth -eq 0 -and $Tokens[$i].Text -ieq 'then') { $then = $i; break }
        }
        if ($then -lt 0) { return -1 }
        $next = Get-ALStatementNext $Tokens ($then + 1)
        if ($next -ge 0 -and $next -lt $Tokens.Count -and $Tokens[$next-1].Text -ne ';' -and $Tokens[$next].Text -ieq 'else') { $next = Get-ALStatementNext $Tokens ($next + 1) }
        return $next
    }
    $depth = 0
    for ($i = $Index; $i -lt $Tokens.Count; $i++) {
        if ($Tokens[$i].Text -eq '(') { $depth++ }
        elseif ($Tokens[$i].Text -eq ')') { $depth-- }
        elseif ($depth -eq 0 -and $Tokens[$i].Text -eq ';') { return ($i + 1) }
        elseif ($depth -eq 0 -and $Tokens[$i].Text -iin @('else','end')) { return $i }
    }
    return -1
}

function Select-KnownRuntimeBranches([string]$Body, $Bindings) {
    $tokens = @(Get-ALTokens $Body)
    $entryStatement = -1
    for ($p=0;$p -lt $tokens.Count;$p++) { if ($tokens[$p].Text -ieq 'begin') { $entryStatement=$p+1;break } }
    # Work from the end, reparsing after a change so nested positions stay valid.
    for ($i = $tokens.Count - 1; $i -ge 0; $i--) {
        $replacement = $null; $next = -1
        if ($tokens[$i].Text -ieq 'if') {
            $p = $i + 1; $negated = $false
            if ($p -lt $tokens.Count -and $tokens[$p].Text -ieq 'not') { $negated = $true; $p++ }
            if ($p + 1 -ge $tokens.Count -or $tokens[$p+1].Text -ine 'then') { continue }
            $name = $tokens[$p].Text.ToLowerInvariant()
            if (-not $Bindings.ContainsKey($name) -or $Bindings[$name] -isnot [bool]) { continue }
            $value = $Bindings[$name]; if ($negated) { $value = -not $value }
            $thenStart = $p + 2; $thenNext = Get-ALStatementNext $tokens $thenStart
            if ($thenNext -le $thenStart) { continue }
            $next = $thenNext; $elseStart = -1
            if ($next -lt $tokens.Count -and $tokens[$next-1].Text -ne ';' -and $tokens[$next].Text -ieq 'else') {
                $elseStart = $next + 1; $next = Get-ALStatementNext $tokens $elseStart
                if ($next -le $elseStart) { continue }
            }
            $replacement = ''
            if ($value) { $replacement = $Body.Substring($tokens[$thenStart].Start, $tokens[$thenNext-1].End - $tokens[$thenStart].Start) + ';' }
            elseif ($elseStart -ge 0) { $replacement = $Body.Substring($tokens[$elseStart].Start, $tokens[$next-1].End - $tokens[$elseStart].Start) + ';' }
        } elseif ($tokens[$i].Text -ieq 'case' -and $i + 2 -lt $tokens.Count) {
            $name = $tokens[$i+1].Text.ToLowerInvariant(); $of = $i + 2
            if ($tokens[$of].Text -eq '.' -and $of + 2 -lt $tokens.Count) { $name += '.'+$tokens[$of+1].Text.ToLowerInvariant(); $of += 2 }
            if ($tokens[$of].Text -ine 'of' -or -not $Bindings.ContainsKey($name) -or $Bindings[$name] -isnot [string]) { continue }
            # Envelope identity is proved at entry, before the first dispatch;
            # never carry it across arbitrary code inside a selected branch.
            if ($name.Contains('.') -and $i -ne $entryStatement) { continue }
            $end = Get-ALStatementNext $tokens $i
            if ($end -lt 0) { continue }
            $cursor = $of + 1; $chosen = ''; $valid = $true
            while ($cursor -lt $end -and $tokens[$cursor].Text -ine 'end') {
                $labels = @(); $default = $tokens[$cursor].Text -ieq 'else'
                if ($default) { $cursor++ }
                else {
                    while ($cursor -lt $end) {
                        if ($tokens[$cursor].Text -match "^'((?:[^']|'')*)'$") { $labels += $Matches[1].Replace("''", "'"); $cursor++ }
                        elseif ($cursor+3 -lt $end -and $tokens[$cursor].Text.StartsWith('"') -and $tokens[$cursor+1].Text -eq ':' -and $tokens[$cursor+2].Text -eq ':' -and $tokens[$cursor+3].Text.StartsWith('"')) {
                            $labels += ($tokens[$cursor].Text+'::'+$tokens[$cursor+3].Text); $cursor+=4
                        } else { break }
                        if ($tokens[$cursor].Text -ne ',') { break }; $cursor++
                    }
                    if ($labels.Count -eq 0 -or $tokens[$cursor].Text -ne ':') { $valid = $false; break }; $cursor++
                }
                $stop = Get-ALStatementNext $tokens $cursor
                if ($stop -le $cursor) { $valid = $false; break }
                $matches=if($name -eq 'rec.type'){$labels -icontains $Bindings[$name]}else{$labels -ccontains $Bindings[$name]}
                if ($matches -or ($default -and $chosen -eq '')) {
                    $chosen = $Body.Substring($tokens[$cursor].Start, $tokens[$stop-1].End - $tokens[$cursor].Start) + ';'
                }
                $cursor = $stop
            }
            if (-not $valid) { continue }
            $replacement = $chosen; $next = $end
        }
        if ($null -ne $replacement -and $next -gt $i) {
            # A semicolon closes an IF; an ELSE following it belongs to an
            # enclosing CASE. Preserve that boundary and avoid manufacturing
            # duplicate terminators when nested branches have already changed.
            $terminated = $tokens[$next-1].Text -eq ';'
            $replacement = $replacement.TrimEnd().TrimEnd(';')
            if ($terminated) { $replacement += ';' }
            else { $replacement = 'begin ' + $replacement + ' end' }
            $Body = $Body.Substring(0, $tokens[$i].Start) + $replacement + $Body.Substring($tokens[$next-1].End)
            $tokens = @(Get-ALTokens $Body)
            $i = [Math]::Min($i, $tokens.Count)
        }
    }
    return $Body
}

# A fresh local codeunit has default Boolean/Text state. Specialize only when all
# source uses of that instance are calls, and every mode write is a simple setter
# invoked unconditionally before any operation. Shared/global instances and unknown
# setters retain both paths. Nothing is inferred from procedure or field names.
function Get-FreshCodeunitBindings($Objects, $Seen) {
    $candidates = @{}; $invalid = @{}
    foreach ($entry in $Seen.Keys) {
        $parts = $entry -split '::', 2; $caller = $Objects[$parts[0]]
        foreach ($body in $caller.Procedures[$parts[1]]) {
            $tokens = @(Get-ALTokens $body); $begin = -1
            for ($i=0; $i -lt $tokens.Count; $i++) { if ($tokens[$i].Text -ieq 'begin') { $begin = $i; break } }
            if ($begin -lt 0) { continue }
            $declarations = $body.Substring(0,$tokens[$begin].Start)
            $declarations = [regex]::Replace($declarations,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
            $localVars = @{}
            foreach ($match in [regex]::Matches($declarations, '(?i)\b(\w+)\s*:\s*Codeunit\s+"([^"]+)"')) { $localVars[$match.Groups[1].Value.ToLowerInvariant()] = $match.Groups[2].Value }
            $calls = @(Get-SourceCalls $body)
            foreach ($receiver in $caller.Variables.Keys) {
                foreach ($target in $caller.Variables[$receiver]) {
                    if (-not $Objects.ContainsKey($target) -or $Objects[$target].Kind -ne 'codeunit') { continue }
                    $instanceCalls = @($calls | Where-Object { $_.Receiver -eq $receiver })
                    if ($instanceCalls.Count -eq 0) { continue }
                    $object = $Objects[$target]
                    if (-not $localVars.ContainsKey($receiver) -or $localVars[$receiver] -ne $target -or $object.Text -match '(?i)\bSingleInstance\s*=\s*true') { $invalid[$target]=$true; continue }
                    $header = $object.Text -split '(?im)^\s*(?:\[[^\]]*\]\s*)*(?:(?:local|internal|protected)\s+)?(?:procedure|trigger)\b', 2
                    $header[0] = [regex]::Replace($header[0],"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
                    $state = @{}
                    foreach ($field in [regex]::Matches($header[0], '(?i)\b(\w+)\s*:\s*(Boolean|Text(?:\[\d+\])?)\s*;')) {
                        $state[$field.Groups[1].Value.ToLowerInvariant()] = $(if ($field.Groups[2].Value -ieq 'Boolean') { $false } else { '' })
                    }
                    if ($state.Count -eq 0) { continue }
                    # Every textual use after the declaration must be a qualified call.
                    $syntax = [regex]::Replace($body.Substring($tokens[$begin].End), "'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/", ' ')
                    $allUses = [regex]::Matches($syntax, "(?i)\b$([regex]::Escape($receiver))\b").Count
                    if ($allUses -ne $instanceCalls.Count) { $invalid[$target]=$true; continue }
                    $setters = @{}
                    foreach ($proc in $object.Procedures.Keys) {
                        if (@($object.Procedures[$proc]).Count -ne 1) { continue }
                        $setterBody = $object.Procedures[$proc][0]
                        $match = [regex]::Match($setterBody, "(?is)\bbegin\s+(\w+)\s*:=\s*(true|false|'(?:[^']|'')*'|\w+)\s*;\s*end\s*;\s*\}\s*$|\bbegin\s+(\w+)\s*:=\s*(true|false|'(?:[^']|'')*'|\w+)\s*;\s*end\s*;\s*$")
                        if (-not $match.Success) { continue }
                        $field = $(if($match.Groups[1].Success){$match.Groups[1].Value}else{$match.Groups[3].Value}).ToLowerInvariant()
                        $value = if($match.Groups[2].Success){$match.Groups[2].Value}else{$match.Groups[4].Value}
                        if ($state.ContainsKey($field) -and (Get-ParameterNames $setterBody) -notcontains $field -and $setterBody.Substring(0,$match.Index) -notmatch ("(?i)\b"+[regex]::Escape($field)+"\s*:")) { $setters[$proc] = @{ Field=$field; Value=$value; Parameters=(Get-ParameterNames $setterBody) } }
                    }
                    # A mode field with a non-setter writer cannot be inferred.
                    foreach ($field in @($state.Keys)) {
                        foreach ($proc in $object.Procedures.Keys) {
                            foreach ($procBody in $object.Procedures[$proc]) {
                                $syntax = [regex]::Replace($procBody, "'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/", ' ')
                                if ($syntax -match "(?i)\b$([regex]::Escape($field))\s*:=" -and -not $setters.ContainsKey($proc)) { $state.Remove($field) }
                                if ($syntax -match "(?i)\bClear\(\s*$([regex]::Escape($field))\s*\)") { $state.Remove($field) }
                                if (-not $setters.ContainsKey($proc)) {
                                    $start=[regex]::Match($syntax,'(?i)\bbegin\b')
                                    if ($start.Success) {
                                        $executable=$syntax.Substring($start.Index+$start.Length)
                                        $uses=[regex]::Matches($executable,"(?i)(?<![.\w])$([regex]::Escape($field))(?![\w])").Count
                                        $selectors=[regex]::Matches($executable,"(?i)\bif\s+(?:not\s+)?$([regex]::Escape($field))\s+then\b|\bcase\s+$([regex]::Escape($field))\s+of\b").Count
                                        if ($uses -ne $selectors) { $state.Remove($field) }
                                    }
                                }
                            }
                        }
                    }
                    $configured = @{}; $operationSeen=$false; $bad=$false
                    $cursor = $begin + 1
                    while ($cursor -lt $tokens.Count -and $tokens[$cursor].Text -ine 'end') {
                        $next = Get-ALStatementNext $tokens $cursor
                        if ($next -le $cursor) { $bad=$true; break }
                        $statement = $body.Substring($tokens[$cursor].Start, $tokens[$next-1].End - $tokens[$cursor].Start)
                        $uses = @(Get-SourceCalls $statement | Where-Object { $_.Receiver -eq $receiver })
                        foreach ($call in $uses) {
                            if ($setters.ContainsKey($call.Callee)) {
                                $exact = [regex]::Match($statement, '(?is)^\s*\w+\.\w+\s*\(.*\)\s*;\s*$')
                                if ($operationSeen -or -not $exact.Success -or $uses.Count -ne 1) { $bad=$true; break }
                                $setter = $setters[$call.Callee]; $value = $setter.Value
                                $position = [array]::IndexOf($setter.Parameters, $value.ToLowerInvariant())
                                if ($position -ge 0) {
                                    $setterBody=$object.Procedures[$call.Callee][0]
                                    $parameterName=[regex]::Escape($setter.Parameters[$position])
                                    if($setterBody -notmatch ("(?i)\b"+$parameterName+'\s*:\s*(?:Text|Boolean)\s*(?:;|\))')){$bad=$true;break}
                                    if ($position -ge $call.Arguments.Count) { $bad=$true; break }; $value = $call.Arguments[$position]
                                }
                                if ($value -match "^'((?:[^']|'')*)'$") { $value=$Matches[1].Replace("''", "'") }
                                elseif ($value -ieq 'true') { $value=$true }
                                elseif ($value -ieq 'false') { $value=$false }
                                else { $bad=$true; break }
                                if ($state.ContainsKey($setter.Field)) { $state[$setter.Field]=$value }
                                $configured[$call.Callee]=$true
                            } else { $operationSeen=$true }
                        }
                        $cursor=$next
                    }
                    if ($bad) { $invalid[$target]=$true; continue }
                    # Internal calls to setters could change state during the operation.
                    foreach ($calledEntry in $Seen.Keys) {
                        $ep=$calledEntry -split '::',2
                        if ($ep[0] -ne $target) { continue }
                        foreach ($procBody in $object.Procedures[$ep[1]]) {
                            foreach ($call in @(Get-SourceCalls $procBody)) {
                                if ($call.Receiver -in @('','this') -and $setters.ContainsKey($call.Callee)) { $invalid[$target]=$true }
                            }
                        }
                    }
                    if (-not $candidates.ContainsKey($target)) { $candidates[$target]=New-Object 'System.Collections.Generic.List[object]' }
                    $candidates[$target].Add($state)
                }
            }
        }
    }
    $bindings=@{}
    foreach ($target in $candidates.Keys) {
        if ($invalid.ContainsKey($target)) { continue }
        foreach ($entry in $Seen.Keys) {
            $ep=$entry -split '::',2
            foreach ($body in $Objects[$ep[0]].Procedures[$ep[1]]) {
                if ($body -match ('(?i)Codeunit::"'+[regex]::Escape($target)+'"')) { $invalid[$target]=$true }
            }
        }
        if ($invalid.ContainsKey($target)) { continue }
        $bindings[$target]=@{}
        foreach ($field in $candidates[$target][0].Keys) {
            $value=$candidates[$target][0][$field]; $same=$true
            foreach ($state in $candidates[$target]) { if (-not $state.ContainsKey($field) -or $state[$field] -cne $value) { $same=$false } }
            if ($same) { $bindings[$target][$field]=$value }
        }
    }
    return $bindings
}

function Get-SelectorBindings($Objects, $Seen, [string]$ObjectName, [string]$ProcedureName, [string]$Body) {
    $bindings=@{}
    if (@($Objects[$ObjectName].Procedures[$ProcedureName]).Count -ne 1) { return $bindings }
    $parameters=Get-ParameterNames $Body
    $syntax=[regex]::Replace($Body,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
    foreach ($parameter in $parameters) {
        $escaped=[regex]::Escape($parameter)
        # Code parameters normalize case, and bounded Text can reject a value at
        # the call boundary. Retain both paths unless the value is plain Text/Boolean.
        if($Body -notmatch ("(?i)\b"+$escaped+'\s*:\s*(?:Text|Boolean)\s*(?:;|\))')){continue}
        $selectors=[regex]::Matches($syntax,"(?i)\bif\s+(?:not\s+)?$escaped\s+then\b|\bcase\s+$escaped\s+of\b").Count
        $uses=[regex]::Matches($syntax,"(?i)(?<![.\w])$escaped(?![\w])").Count
        if ($selectors -eq 0 -or $uses -ne $selectors + 1) { continue }
        $position=[array]::IndexOf($parameters,$parameter);$values=@();$unknown=$false
        foreach ($entry in $Seen.Keys) {
            $ep=$entry -split '::',2;$caller=$Objects[$ep[0]]
            foreach ($callerBody in $caller.Procedures[$ep[1]]) {
                $callSyntax=[regex]::Replace($callerBody,'''(?:[^'']|'''')*''|"(?:[^"]|"")*"|//[^\r\n]*|/\*[\s\S]*?\*/',' ')
                foreach($site in $anyCall.Matches($callSyntax)){if($site.Groups['chained'].Value -ieq $ProcedureName){$unknown=$true}}
                foreach ($call in @(Get-SourceCalls $callerBody)) {
                    if ($call.Callee -ine $ProcedureName) { continue }
                    $targets=@(if ($call.Receiver -in @('','this','rec')) { $ep[0] }
                        elseif ($caller.Variables.ContainsKey($call.Receiver)) { $caller.Variables[$call.Receiver] })
                    if ($targets.Count -eq 0) { $unknown=$true; continue }
                    if ($targets -notcontains $ObjectName) { continue }
                    if ($targets.Count -ne 1 -or $position -ge $call.Arguments.Count) { $unknown=$true; continue }
                    $value=$call.Arguments[$position]
                    if ($value -match "^'((?:[^']|'')*)'$") { $values+=,$Matches[1].Replace("''", "'") }
                    elseif ($value -ieq 'true') { $values+=,$true }
                    elseif ($value -ieq 'false') { $values+=,$false }
                    else { $unknown=$true }
                }
            }
        }
        if (-not $unknown -and $values.Count -gt 0) {
            $same=$true
            foreach ($value in $values) { if ($value -cne $values[0] -or $value.GetType() -ne $values[0].GetType()) { $same=$false } }
            if ($same) { $bindings[$parameter]=$values[0] }
        }
    }
    return $bindings
}

# Prove envelope identity through the wrapper and its source-resolved record
# helpers before specializing a Codeunit.Run dispatch on Rec.Type. Unknown
# record methods, record replacement and Type writes keep every CASE branch.
function Test-ScalarArgumentReadOnly($Objects, [string]$ObjectName, $Call, [int]$Position) {
    if($Call.Receiver -eq '' -and $Call.Callee -in @('format','message','error','strsubstno','copystr','strlen','uppercase','lowercase')){return $true}
    $object=$Objects[$ObjectName]
    $targets=@(if($Call.Receiver -in @('','this','rec')){$ObjectName}elseif($object.Variables.ContainsKey($Call.Receiver)){$object.Variables[$Call.Receiver]})
    if($targets.Count -ne 1 -or -not $Objects.ContainsKey($targets[0]) -or -not $Objects[$targets[0]].Procedures.ContainsKey($Call.Callee)){return $false}
    foreach($body in $Objects[$targets[0]].Procedures[$Call.Callee]){
        $signature=[regex]::Match($body,'(?is)(?:procedure|trigger)\s+(?:"[^"]+"|\w+)\s*\(([^)]*)\)')
        if(-not $signature.Success){return $false};$params=@($signature.Groups[1].Value.Split(';'))
        if($Position -ge $params.Count -or $params[$Position] -match '(?i)^\s*var\b'){return $false}
    }
    return $true
}

function Test-EnvelopePreserved($Objects, [string]$ObjectName, [string]$ProcedureName, [string]$RecordName, $Seen) {
    $key="$ObjectName::$ProcedureName::$RecordName"
    if ($Seen.ContainsKey($key)) { return $true };$Seen[$key]=$true
    if (-not $Objects.ContainsKey($ObjectName) -or -not $Objects[$ObjectName].Procedures.ContainsKey($ProcedureName)) { return $false }
    $object=$Objects[$ObjectName]
    foreach ($body in $object.Procedures[$ProcedureName]) {
        $syntax=[regex]::Replace($body,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
        $name=[regex]::Escape($RecordName)
        if ($syntax -match ("(?i)\b$name\s*:=|\b$name\s*\.\s*"+'"?Type"?\s*:=|\bClear\(\s*'+$name+'\s*\)')) { return $false }
        $implicit=$object.Kind -eq 'table' -and $RecordName -eq 'rec'
        if ($implicit) {
            $fieldTokens=@(Get-ALTokens $body)
            for($i=0;$i+1 -lt $fieldTokens.Count;$i++) {
                if($fieldTokens[$i].Text -iin @('Type','"Type"') -and $fieldTokens[$i+1].Text -eq ':=' -and ($i -eq 0 -or $fieldTokens[$i-1].Text -ne '.')) { return $false }
            }
        }
        foreach($site in $anyCall.Matches($syntax)){
            if(-not $site.Groups['chained'].Success){continue}
            $tail=$syntax.Substring($site.Index+$site.Length);$stop=$tail.IndexOf(')');if($stop -ge 0){$tail=$tail.Substring(0,$stop+1)}
            $field=if($implicit){'|"?Type"?'}else{''}
            if($tail -match ("(?i)(?:^|,)\s*(?:$name(?:\."+'"?Type"?'+")?$field)\s*(?=,|\))")){return $false}
        }
        foreach ($call in @(Get-SourceCalls $body)) {
            $sameRecord=$call.Receiver -eq $RecordName -or ($implicit -and $call.Receiver -in @('','this','rec'))
            if($sameRecord -and $call.Callee -in @('get','find','findfirst','findlast','findset','next','init','reset','copy','transferfields','validate','rename')){return $false}
            if($sameRecord -and $call.Callee -in @('modify','insert','delete')){
                if($call.Arguments.Count -eq 0 -or $call.Arguments[0] -in @('','false')){continue}
                if($call.Arguments[0] -ine 'true'){return $false}
                $trigger='on'+$call.Callee
                if($Objects.ContainsKey('Message Argument ori') -and $Objects['Message Argument ori'].Procedures.ContainsKey($trigger)){
                    if(-not (Test-EnvelopePreserved $Objects 'Message Argument ori' $trigger 'rec' $Seen)){return $false}
                }
                continue
            }
            if ($call.Receiver -eq $RecordName) {
                if ($call.Callee -in @('get','find','findfirst','findlast','findset','next','init','reset','copy','transferfields','validate','rename')) { return $false }
                if ($call.Callee -in @('testfield','fieldno','fieldcaption','count','isempty','getfilters','getrangefilter','getrangemin','getrangemax')) { continue }
                if (-not (Test-EnvelopePreserved $Objects 'Message Argument ori' $call.Callee 'rec' $Seen)) { return $false }
                continue
            }
            if ($implicit -and $call.Receiver -in @('','this','rec') -and $object.Procedures.ContainsKey($call.Callee)) {
                if (-not (Test-EnvelopePreserved $Objects $ObjectName $call.Callee 'rec' $Seen)) { return $false }
            }
            for ($position=0;$position -lt $call.Arguments.Count;$position++) {
                $argument=$call.Arguments[$position]
                $field=$argument -match ("(?i)^$name\."+'(?:Type|"Type")$')
                if($implicit -and $argument -imatch '^(Type|"Type")$'){$field=$true}
                if($field -and -not (Test-ScalarArgumentReadOnly $Objects $ObjectName $call $position)){return $false}
                if ($argument -ine $RecordName) { continue }
                # Record.Copy reads its source argument; the receiver receives
                # the fields. Copying Rec to a temporary buffer does not replace Rec.
                if ($position -eq 0 -and $call.Callee -eq 'copy' -and $object.Variables.ContainsKey($call.Receiver) -and $object.Variables[$call.Receiver] -contains 'Message Argument ori') { continue }
                if ($call.Receiver -eq 'codeunit' -and $call.Callee -eq 'run' -and $position -eq 1 -and $call.Arguments[0] -match '^Codeunit::"([^"]+)"$') {
                    $target=$Matches[1]
                    if ($Objects.ContainsKey($target) -and $Objects[$target].TableNo -eq 'Message Argument ori') { continue }
                    return $false
                }
                $targets=@(if ($call.Receiver -in @('','this','rec')) { $ObjectName }
                    elseif ($object.Variables.ContainsKey($call.Receiver)) { $object.Variables[$call.Receiver] })
                if ($targets.Count -ne 1 -or -not $Objects.ContainsKey($targets[0])) { return $false }
                $target=$Objects[$targets[0]]
                if (-not $target.Procedures.ContainsKey($call.Callee)) { return $false }
                foreach ($calleeBody in $target.Procedures[$call.Callee]) {
                    $params=Get-ParameterNames $calleeBody
                    if ($position -ge $params.Count -or -not (Test-EnvelopePreserved $Objects $targets[0] $call.Callee $params[$position] $Seen)) { return $false }
                }
            }
        }
    }
    return $true
}

function Get-EnvelopeRunTargets($Objects, [string]$Root) {
    $targets=New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($body in $Objects[$Root].Procedures['executebifrosttask']) {
        $record=Get-FirstParam $body
        if ($record -eq '' -or -not (Test-EnvelopePreserved $Objects $Root 'executebifrosttask' $record @{})) { return ,$targets }
        foreach ($call in @(Get-SourceCalls $body)) {
            if ($call.Receiver -eq 'codeunit' -and $call.Callee -eq 'run' -and $call.Arguments.Count -eq 2 -and $call.Arguments[1] -ieq $record -and $call.Arguments[0] -match '^Codeunit::"([^"]+)"$') {
                $target=$Matches[1]
                if ($Objects.ContainsKey($target) -and $Objects[$target].TableNo -eq 'Message Argument ori') { [void]$targets.Add($target) }
            }
        }
    }
    return ,$targets
}

function Get-RuntimeObjects($Objects, [string]$Root, [string]$MessageType) {
    $copy=@{}
    foreach ($name in $Objects.Keys) {
        $copy[$name]=$Objects[$name].Clone();$copy[$name].Procedures=@{}
        $copy[$name].SourceProcedures=$Objects[$name].Procedures
        foreach ($proc in $Objects[$name].Procedures.Keys) { $copy[$name].Procedures[$proc]=@($Objects[$name].Procedures[$proc]) }
    }
    foreach ($target in (Get-EnvelopeRunTargets $copy $Root)) {
        $binding=@{ 'rec.type'=('"Message Type ori"::"'+$MessageType+'"') }
        $copy[$target].Procedures['onrun']=@($copy[$target].Procedures['onrun'] | ForEach-Object { Select-KnownRuntimeBranches $_ $binding })
    }
    $seen=@{};Get-Reach $copy $Root 'executebifrosttask' $seen $true
    $state=Get-FreshCodeunitBindings $copy $seen
    foreach ($name in $state.Keys) {
        foreach ($proc in @($copy[$name].Procedures.Keys)) {
            $copy[$name].Procedures[$proc]=@($copy[$name].Procedures[$proc] | ForEach-Object {
                $bindings=$state[$name].Clone()
                $bodyTokens=@(Get-ALTokens $_); $begin=@($bodyTokens | Where-Object { $_.Text -ieq 'begin' } | Select-Object -First 1)
                if ($begin.Count -eq 1) {
                    $declarations=$_.Substring(0,$begin[0].Start)
                    $declarations=[regex]::Replace($declarations,"'(?:[^']|'')*'|//[^\r\n]*|/\*[\s\S]*?\*/",' ')
                    foreach ($field in @($bindings.Keys)) {
                        if ($declarations -match ("(?i)\b"+[regex]::Escape($field)+"\s*:")) { $bindings.Remove($field) }
                    }
                }
                Select-KnownRuntimeBranches $_ $bindings
            })
        }
    }
    $seen=@{};Get-Reach $copy $Root 'executebifrosttask' $seen $true
    $pruned=@{}
    foreach ($entry in $seen.Keys) {
        $ep=$entry -split '::',2;$bodies=@()
        foreach ($body in $copy[$ep[0]].Procedures[$ep[1]]) {
            $bindings=Get-SelectorBindings $copy $seen $ep[0] $ep[1] $body
            $bodies+=Select-KnownRuntimeBranches $body $bindings
        }
        $pruned[$entry]=$bodies
    }
    foreach ($entry in $pruned.Keys) { $ep=$entry -split '::',2;$copy[$ep[0]].Procedures[$ep[1]]=$pruned[$entry] }
    return $copy
}

function Find-Offenders([string]$AppFolder) {
    $script:ContractDiagnostics = New-Object 'System.Collections.Generic.List[string]'
    $objects = Read-Source (Join-Path $AppFolder 'src')
    $types = Get-Types $objects
    foreach ($dependency in $DependencyAppFolders) {
        $dependencyObjects = Read-Source (Join-Path $dependency 'src')
        foreach ($name in $dependencyObjects.Keys) {
            if ($objects.ContainsKey($name)) { throw "Duplicate AL object name '$name' in dependency source '$dependency'." }
            $objects[$name] = $dependencyObjects[$name]
        }
    }
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($typeName in $types.Keys) {
        $contractCodeunit = $types[$typeName].Contract
        $interfaceCodeunit = $types[$typeName].Interface
        if ($contractCodeunit -eq 'Default Contract ori') { continue }
        if (-not $objects.ContainsKey($contractCodeunit) -or -not $objects.ContainsKey($interfaceCodeunit)) { continue }
        if ($Explain -ne '' -and $typeName -ne $Explain) { continue }
        $script:ContractDiagnostics.Clear()
        $script:RejectedReads=New-Object 'System.Collections.Generic.HashSet[string]'
        $selectedObjects = Get-SelectedObjects $objects $contractCodeunit
        $declared = Get-DeclaredKeys $selectedObjects $contractCodeunit
        $runtimeObjects = Get-RuntimeObjects $objects $interfaceCodeunit $typeName
        $literals = Get-ReachableLiterals $runtimeObjects $interfaceCodeunit
        $reads = Get-ReadKeys $runtimeObjects $interfaceCodeunit
        $targetKeys = Get-TargetKeys $selectedObjects $contractCodeunit
        foreach ($diagnostic in ($script:ContractDiagnostics | Sort-Object -Unique)) { $found.Add("$typeName|$diagnostic") }
        foreach ($key in ($script:RejectedReads | Sort-Object)) { Write-Host "Rejection-only request check (source-proven, unsupported): $typeName|$key" }
        if ($Explain -ne '') {
            $script:Explained = $true
            Write-Host "contract codeunit : $contractCodeunit"
            Write-Host "interface codeunit: $interfaceCodeunit"
            Write-Host "declared          : $(($declared | Sort-Object) -join ', ')"
            Write-Host "target (data.)    : $(($targetKeys | Sort-Object) -join ', ')"
            Write-Host "read              : $(($reads | Sort-Object) -join ', ')"
        }
        foreach ($key in ($declared | Sort-Object)) {
            if (-not $literals.Contains($key) -or ($script:RejectedReads.Contains($key) -and -not $reads.Contains($key))) { $found.Add("$typeName|declared-not-read|$key") }
        }
        foreach ($key in ($reads | Sort-Object)) {
            if ($script:NeverParameters -contains $key) { continue }
            if (-not $declared.Contains($key) -and -not $targetKeys.Contains($key)) { $found.Add("$typeName|read-not-declared|$key") }
        }
        # Coverage floor: a declared parameter with no detected read at all is a blind spot, not a pass (#430).
        if (($declared.Count -gt 0) -and ($reads.Count -eq 0)) { $found.Add("$typeName|no-reads-seen|*") }
    }
    return ,$found
}

function Read-AllowList([string]$Path) {
    $entries = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            $parts = $trimmed.Split('|')
            # Coverage floor. The key is always *; a block that names another key is still this rule (#430).
            if ($parts.Count -eq 3 -and $parts[1] -eq 'no-reads-seen') {
                $entries.Add("$($parts[0])|no-reads-seen|*")
                continue
            }
            $entries.Add($trimmed)
        }
    }
    return ,$entries
}

function Compare-WithAllowList($Found, $Allowed) {
    # no-reads-seen|* is compared like every other rule: missing when the guard sees no reads is a failure,
    # and an entry whose type now has a detected read no longer applies and must be removed (#430).
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in $Found) {
        if (-not $Allowed.Contains($entry)) { $problems.Add("New offender (fix the contract or the code, see #146, #357): $entry") }
    }
    foreach ($entry in $Allowed) {
        if (-not $Found.Contains($entry)) { $problems.Add("No longer applies, remove it from the allow-list: $entry") }
    }
    return ,$problems
}

function Invoke-SelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-keys-" + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app\src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    try {
        @'
namespace Origo.Bifrost;
enum 1 "Message Type ori"
{
    value(1; "Sales.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Thing Impl ori", "Msg Contract ori" = "Thing Impl ori";
    }
    value(2; "Req.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Req Impl ori", "Msg Contract ori" = "Req Impl ori";
    }
    value(3; "Wrap.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Wrap Impl ori", "Msg Contract ori" = "Wrap Impl ori";
    }
    value(4; "Blind.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Blind Impl ori", "Msg Contract ori" = "Blind Impl ori";
    }
    value(5; "Delegate.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Delegate Impl ori", "Msg Contract ori" = "Delegate Impl ori";
    }
    value(6; "Rec.Thing.Set")
    {
        Implementation = "Msg Interface ori" = "Rec Impl ori", "Msg Contract ori" = "Rec Impl ori";
    }
    value(7; "Reader.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Reader Impl ori", "Msg Contract ori" = "Reader Impl ori";
    }
    value(8; "Cond.False.Get")
    {
        Implementation = "Msg Interface ori" = "Cond False Impl ori", "Msg Contract ori" = "Cond False Impl ori";
    }
    value(9; "Cond.True.Get")
    {
        Implementation = "Msg Interface ori" = "Cond True Impl ori", "Msg Contract ori" = "Cond True Impl ori";
    }
    value(10; "Text.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Text Impl ori", "Msg Contract ori" = "Text Impl ori";
    }
    value(11; "Const.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Const Impl ori", "Msg Contract ori" = "Const Impl ori";
    }
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Type.Enum.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 2 "Thing Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('customerNo', Token) then;
        if RequestJson.Get('undocumented', Token) then;
        if RequestJson.Get('b', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('customerNo', 'string', true, 'The customer.'));
        Parameters.Add(ContractMgt.Parameter('renamed', 'string', false, 'Never read.'));
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.a, data.b, data.c', 'The keys.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Thing.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 3 "Req Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReqJson: JsonObject;
        Take: Integer;
    begin
        ReqJson := Argument.GetRequestJson();
        if not Argument.TryReadInteger(ReqJson, 'pageSize', false, Take) then;
        if not Argument.TryReadInteger(ReqJson, 'reqExtra', false, Take) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('pageSize', 'integer', false, 'Page size.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Req.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 4 "Wrap Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Value: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        Value := GetTextParam(RequestJson, 'dateFilter', '');
        Value := GetTextParam(RequestJson, 'wrapExtra', '');
        ReadInside(RequestJson);
    end;

    local procedure GetTextParam(RequestJson: JsonObject; ParamName: Text; DefaultValue: Text): Text
    begin
        exit(DefaultValue);
    end;

    local procedure ReadInside(Req: JsonObject)
    var
        Token: JsonToken;
    begin
        if Req.Get('insideKey', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('dateFilter', 'string', false, 'The date filter.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Wrap.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 5 "Blind Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('silent', 'string', false, 'Never reached.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Blind.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 6 "Delegate Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        RequestJson := Argument.GetRequestJson();
        Argument.EvaluateDelegated(RequestJson);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('delegatedKey', 'integer', false, 'Read inside the helper.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Delegate.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 8 "Rec Impl ori"
{
    // SelfTest case Rec.Thing.Set (#431): the records of the request data are read in a process codeunit that
    // takes the record object as its second argument.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RecordsArray: JsonArray;
    begin
        if not Argument.GetRequestDataArray(RecordsArray) then
            exit;
        Codeunit.Run(Codeunit::"Rec Process ori", Argument);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'The record.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Rec.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 9 "Rec Process ori"
{
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        RecordsArray: JsonArray;
        RecordToken: JsonToken;
        RecordObject: JsonObject;
    begin
        Rec.GetRequestDataArray(RecordsArray);
        RecordsArray.Get(0, RecordToken);
        RecordObject := RecordToken.AsObject();
        ProcessRecord(Rec, RecordObject, 1);
    end;

    local procedure ProcessRecord(var Argument: Record "Message Argument ori"; Item: JsonObject; Index: Integer)
    var
        Token: JsonToken;
    begin
        if Item.Get('id', Token) then;
        if Item.Get('recExtra', Token) then;
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'RecProcess.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 10 "Reader Impl ori"
{
    // SelfTest case Reader.Thing.Get (#431): the table reader of Message Argument reads tableName for the type; a
    // GetRequestJson().Contains() read counts; the pair and the nested target keys are declared; any other
    // procedure of Message Argument is not a reader.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        Argument.GetTableIdFromRequestJson(RequestJson);
        Argument.FindSomethingElse(RequestJson);
        if Argument.GetRequestJson().Contains('inlineKey') then;
        if RequestJson.Get('pairA', Token) then;
        if RequestJson.Get('nestedKey', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('tableName', 'string', false, 'The table.'));
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.pairA + data.pairB', 'The pair.'));
        Target.Add(ContractMgt.TargetEntry('data.forX.nestedKey', 'The nested key.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Reader.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 11 "Cond Parts ori"
{
    // SelfTest cases Cond.False.Get and Cond.True.Get (#401): extra and tail are declared only when the flag is true.
    procedure AddBase(var Parameters: JsonArray; WithExtra: Boolean; WithTail: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if WithTail then begin
            // don't let this apostrophe confuse the scanner
            Parameters.Add(ContractMgt.Parameter('tail', 'string', false, 'Only with the tail; ends with end; and begin.'));
            Parameters.Add(ContractMgt.Parameter('tailTwo', 'string', false, 'Only with the tail, in the same block.'));
        end;
        if not WithExtra then
            exit;
        Parameters.Add(ContractMgt.Parameter('extra', 'string', false, 'Only with the extra.'));
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'CondParts.Codeunit.al') -Encoding UTF8
        foreach ($flag in @('False', 'True')) {
            $arguments = if ($flag -eq 'True') { 'true, true' } else { 'false, false' }
            $codeunitId = if ($flag -eq 'True') { 13 } else { 12 }
            @"
namespace Origo.Bifrost;
codeunit $codeunitId "Cond $flag Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('base', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Cond Parts ori";
    begin
        Parts.AddBase(Parameters, $arguments);
        exit(true);
    end;
}
"@ | Set-Content -LiteralPath (Join-Path $src "Cond$flag.Codeunit.al") -Encoding UTF8
        }
        @'
namespace Origo.Bifrost;
codeunit 14 "Text Impl ori"
{
    // SelfTest case Text.Thing.Get (#459): a key that appears only in a translatable label or a message text is not a read.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        OnlyLbl: Label 'onlyInLabel';
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('anchor', Token) then;
        Error('onlyInLabel');
        Argument.AddError('code', 'text', 'onlyInError');
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('anchor', 'string', false, 'A real read, so the type is not blind.'));
        Parameters.Add(ContractMgt.Parameter('onlyInLabel', 'string', false, 'Only in a label and in Error.'));
        Parameters.Add(ContractMgt.Parameter('onlyInError', 'string', false, 'Only the parameter argument of AddError.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Text.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 15 "Const Impl ori"
{
    // SelfTest case Const.Thing.Get (#459): a Locked = true label in the reached procedure still names a key.
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        KeyTok: Label 'constKey', Locked = true;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('anchor', Token) then;
        ReadText(RequestJson, KeyTok);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(KeyName, Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('anchor', 'string', false, 'A real read, so the type is not blind.'));
        Parameters.Add(ContractMgt.Parameter('constKey', 'string', false, 'Read through a locked label.'));
        exit(true);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Const.Codeunit.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
table 7 "Message Argument ori"
{
    procedure GetTableIdFromRequestJson(RequestJson: JsonObject)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get('tableName', Token) then;
        if RequestJson.Get('readerExtra', Token) then;
    end;

    procedure FindSomethingElse(RequestJson: JsonObject)
    var
        Token: JsonToken;
    begin
        if RequestJson.Get('notFollowed', Token) then;
    end;

    // SelfTest case Delegate.Thing.Get: Evaluate* forwards the request into TryEvaluate*, which forwards
    // the request JsonObject plus a literal key to an internal Try* helper. That key must count as a read.
    procedure EvaluateDelegated(RequestJson: JsonObject)
    begin
        TryEvaluateDelegated(RequestJson);
    end;

    procedure TryEvaluateDelegated(RequestJson: JsonObject)
    var
        Value: Integer;
    begin
        if not TryReadInteger(RequestJson, 'delegatedKey', false, Value) then;
        if not TryReadInteger(RequestJson, 'delegateExtra', false, Value) then;
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Argument.Table.al') -Encoding UTF8
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @(
            'Sales.Thing.Get|declared-not-read|renamed',
            'Sales.Thing.Get|read-not-declared|undocumented',
            'Req.Thing.Get|read-not-declared|reqExtra',
            'Wrap.Thing.Get|read-not-declared|wrapExtra',
            'Wrap.Thing.Get|read-not-declared|insideKey',
            'Blind.Thing.Get|declared-not-read|silent',
            'Blind.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|read-not-declared|delegateExtra',
            'Rec.Thing.Set|read-not-declared|recExtra',
            'Reader.Thing.Get|read-not-declared|inlineKey',
            'Reader.Thing.Get|read-not-declared|readerExtra',
            'Cond.True.Get|declared-not-read|extra',
            'Cond.True.Get|declared-not-read|tail',
            'Cond.True.Get|declared-not-read|tailTwo',
            'Text.Thing.Get|declared-not-read|onlyInLabel',
            'Text.Thing.Get|declared-not-read|onlyInError'
        )
        $absent = @(
            'Sales.Thing.Get|read-not-declared|b',
            'Sales.Thing.Get|read-not-declared|a, data.b, data.c',
            'Req.Thing.Get|read-not-declared|pageSize',
            'Req.Thing.Get|no-reads-seen|*',
            'Wrap.Thing.Get|read-not-declared|dateFilter',
            'Wrap.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|no-reads-seen|*',
            'Delegate.Thing.Get|declared-not-read|delegatedKey',
            'Delegate.Thing.Get|read-not-declared|delegatedKey',
            'Rec.Thing.Set|no-reads-seen|*',
            'Rec.Thing.Set|read-not-declared|id',
            'Reader.Thing.Get|no-reads-seen|*',
            'Reader.Thing.Get|read-not-declared|tableName',
            'Reader.Thing.Get|read-not-declared|pairA',
            'Reader.Thing.Get|read-not-declared|nestedKey',
            'Reader.Thing.Get|read-not-declared|notFollowed',
            'Cond.False.Get|declared-not-read|extra',
            'Cond.False.Get|declared-not-read|tail',
            'Cond.False.Get|declared-not-read|tailTwo',
            'Cond.False.Get|declared-not-read|base',
            'Cond.True.Get|declared-not-read|base',
            'Text.Thing.Get|declared-not-read|anchor',
            'Text.Thing.Get|no-reads-seen|*',
            'Const.Thing.Get|declared-not-read|constKey',
            'Const.Thing.Get|declared-not-read|anchor',
            'Const.Thing.Get|no-reads-seen|*'
        )
        $failed = $false
        foreach ($e in $expected) {
            if (-not $found.Contains($e)) { Write-Host "SelfTest FAILED: not reported: $e"; $failed = $true }
        }
        foreach ($e in $absent) {
            if ($found.Contains($e)) { Write-Host "SelfTest FAILED: reported but should not be: $e"; $failed = $true }
        }
        if ($found.Count -ne $expected.Count) { Write-Host "SelfTest FAILED: expected $($expected.Count) offenders, got $($found.Count): $($found -join '; ')"; $failed = $true }
        $listed = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $listed.Add($e) }
        if ((Compare-WithAllowList $found $listed).Count -ne 0) { Write-Host 'SelfTest FAILED: a fully allow-listed set must pass.'; $failed = $true }
        if ((Compare-WithAllowList $found (New-Object 'System.Collections.Generic.List[string]')).Count -ne $expected.Count) { Write-Host 'SelfTest FAILED: new offenders must be reported.'; $failed = $true }
        $stale = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $stale.Add($e) }
        $stale.Add('Sales.Thing.Get|declared-not-read|gone')
        if ((Compare-WithAllowList $found $stale).Count -ne 1) { Write-Host 'SelfTest FAILED: a stale allow-list entry must be reported.'; $failed = $true }
        $missingFloor = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { if ($e -ne 'Blind.Thing.Get|no-reads-seen|*') { $missingFloor.Add($e) } }
        $missingProblems = Compare-WithAllowList $found $missingFloor
        if (($missingProblems | Where-Object { $_ -like '*Blind.Thing.Get|no-reads-seen|*' }).Count -ne 1) { Write-Host 'SelfTest FAILED: a type with no detected reads must fail when it is not allow-listed.'; $failed = $true }
        $staleFloor = New-Object 'System.Collections.Generic.List[string]'
        foreach ($e in $expected) { $staleFloor.Add($e) }
        $staleFloor.Add('Sales.Thing.Get|no-reads-seen|*')
        $staleFloorProblems = Compare-WithAllowList $found $staleFloor
        if (($staleFloorProblems | Where-Object { $_ -like '*Sales.Thing.Get|no-reads-seen|*' }).Count -ne 1) { Write-Host 'SelfTest FAILED: a no-reads-seen entry must fail once a read is detected.'; $failed = $true }
        if ($failed) { exit 1 }
        Write-Host 'SelfTest passed.'
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# SelfTest for the conditional parameters (#590): a call the guard cannot read keeps a parameter declared, and the exit of
# 'if not Flag then exit;' inside a nested block cuts only that block. A second synthetic app keeps these cases apart.
function Invoke-SelfTestConditionalParameters {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-keys-cond-" + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app\src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    try {
        @'
namespace Origo.Bifrost;
enum 1 "Message Type ori"
{
    value(1; "Veto.Unread.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Unread Impl ori", "Msg Contract ori" = "Veto Unread Impl ori";
    }
    value(2; "Veto.Chain.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Chain Impl ori", "Msg Contract ori" = "Veto Chain Impl ori";
    }
    value(3; "Veto.False.Get")
    {
        Implementation = "Msg Interface ori" = "Veto False Impl ori", "Msg Contract ori" = "Veto False Impl ori";
    }
    value(4; "Veto.Nested.Get")
    {
        Implementation = "Msg Interface ori" = "Veto Nested Impl ori", "Msg Contract ori" = "Veto Nested Impl ori";
    }
}
'@ | Set-Content -LiteralPath (Join-Path $src 'Type.Enum.al') -Encoding UTF8
        @'
namespace Origo.Bifrost;
codeunit 21 "Veto Parts ori"
{
    // extra is declared only when WithExtra is true.
    procedure AddBase(var Parameters: JsonArray; WithExtra: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if WithExtra then
            Parameters.Add(ContractMgt.Parameter('extra', 'string', false, 'Only with the extra.'));
    end;

    // inner is declared only when WithInner is true; afterBlock is declared always, after the block that holds the exit.
    procedure AddNested(var Parameters: JsonArray; WithInner: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('base', 'string', false, 'The base; it is always declared.'));
        if true then begin
            if not WithInner then
                exit;
            Parameters.Add(ContractMgt.Parameter('inner', 'string', false, 'Only with the inner; ends with end;'));
        end;
        Parameters.Add(ContractMgt.Parameter('afterBlock', 'string', false, 'Declared whatever the flag says.'));
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'VetoParts.Codeunit.al') -Encoding UTF8
        $calls = [ordered]@{
            'Unread' = @{ Id = 22; Body = "Parts.AddBase(Parameters, false);`n        Parts.AddBase(Parameters, Pick(1));" }
            'Chain'  = @{ Id = 23; Body = "Parts.AddBase(Parameters, false);`n        GetParts().AddBase(Parameters, true);" }
            'False'  = @{ Id = 24; Body = "Parts.AddBase(Parameters, false);" }
            'Nested' = @{ Id = 25; Body = "Parts.AddNested(Parameters, false);" }
        }
        foreach ($name in $calls.Keys) {
            $id = $calls[$name].Id
            $body = $calls[$name].Body
            @"
namespace Origo.Bifrost;
codeunit $id "Veto $name Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('base', Token) then;
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Veto Parts ori";
    begin
        $body
        exit(true);
    end;
}
"@ | Set-Content -LiteralPath (Join-Path $src "Veto$name.Codeunit.al") -Encoding UTF8
        }
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @(
            'Veto.Unread.Get|declared-not-read|extra',
            'Veto.Chain.Get|declared-not-read|extra',
            'Veto.Nested.Get|declared-not-read|afterBlock'
        )
        $absent = @(
            'Veto.False.Get|declared-not-read|extra',
            'Veto.Nested.Get|declared-not-read|inner',
            'Veto.Unread.Get|declared-not-read|base',
            'Veto.Chain.Get|declared-not-read|base',
            'Veto.False.Get|declared-not-read|base',
            'Veto.Nested.Get|declared-not-read|base'
        )
        $failed = $false
        foreach ($e in $expected) {
            if (-not $found.Contains($e)) { Write-Host "SelfTest FAILED: not reported: $e"; $failed = $true }
        }
        foreach ($e in $absent) {
            if ($found.Contains($e)) { Write-Host "SelfTest FAILED: reported but should not be: $e"; $failed = $true }
        }
        if ($found.Count -ne $expected.Count) { Write-Host "SelfTest FAILED: expected $($expected.Count) offenders, got $($found.Count): $($found -join '; ')"; $failed = $true }
        if ($failed) { exit 1 }
        Write-Host 'SelfTest (conditional parameters) passed.'
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    Invoke-SelfTestConditionalParameters
    exit 0
}

$found = Find-Offenders $AppFolder
# -Explain prints what the guard sees for one type. The other allow-list entries are not stale just because they were not printed (#430).
if ($Explain -ne '') {
    if (-not $script:Explained) {
        Write-Host "::error::No message type named '$Explain' with a contract was found. Use the name as the Message Type enum spells it, for example Data.Notes.Set."
        exit 1
    }
    exit 0
}
$allowed = Read-AllowList $AllowListPath
$problems = Compare-WithAllowList $found $allowed
if ($problems.Count -gt 0) {
    Write-Host "::error::The contract parameter names and the keys the code reads disagree ($($problems.Count) problem(s)). Fix the contract or the code; the allow-list may only shrink (#357)."
    $problems | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host "Every contract parameter is a key the code reads, and every key the code reads is declared ($($allowed.Count) allow-listed)."
