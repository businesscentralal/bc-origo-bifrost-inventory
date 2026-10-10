<#
.SYNOPSIS
    Fails when a message type's contract and its code disagree about the request parameter names (#357, #146 rule 6).

.DESCRIPTION
    A contract lists the parameter names a caller may send under data (the "parameters" chapter). Nothing used to
    compare that list with the keys the implementation reads, so a key renamed in the contract only, or read in the
    code and never documented, stayed unnoticed. This guard reads the AL source under app/src and, for every message
    type that has a contract. Declarations include ContractMgt.Parameter calls and direct
    literal JSON arrays read into GetParameters' var JsonArray output. Literal JSON must be
    an array of objects with nonempty string names. Unrelated receivers, comments and response
    examples do not declare keys. Dynamic JSON construction is outside this literal reader:

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
$callRead = [regex]::new("(?:\b\w+\.)?\b\w+\s*\(\s*(?:(?<var>\w+)|(?:\w+\.)?GetRequestJson\(\))\s*,\s*'(?<key>[^']+)'", 'IgnoreCase')
# RequestJson.Get('k'...) / ReqJson.Contains('k'...) / GetRequestJson().Contains('k') (#431).
$memberRead = [regex]::new("(?:\b(?<var>\w+)|GetRequestJson\(\))\.(?:Get|Contains)\(\s*'(?<key>[^']+)'", 'IgnoreCase')

function Read-Source([string]$AppSrc) {
    $objects = @{}
    foreach ($file in Get-ChildItem -LiteralPath $AppSrc -Recurse -Filter '*.al') {
        $sourceText = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
        # Keep literals intact and line positions stable before recognizing declarations.
        $sourceText = [regex]::Replace($sourceText, "(?s)'(?:[^']|'')*'|//[^\r\n]*|/\*.*?\*/", {
            param($match)
            if ($match.Value.StartsWith('/')) { return [regex]::Replace($match.Value, '[^\r\n]', ' ') }
            return $match.Value
        })
        $lines = @($sourceText -split "\r?\n")
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
                $object.Variables[$varName] += $v.Groups[2].Value
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
    $literalSpans = @([regex]::Matches($Body, "(?s)'(?:[^']|'')*'|//[^\r\n]*|/\*.*?\*/"))
    $hits = @($ifFlag.Matches($Body) | Where-Object {
        $hit = $_
        $FlagNames.Contains($hit.Groups['flag'].Value.ToLowerInvariant()) -and
            -not @($literalSpans | Where-Object { $hit.Index -ge $_.Index -and $hit.Index -lt ($_.Index + $_.Length) }).Count
    })
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

# Literal JSON chapters are also declarations. Bind the receiver to GetParameters' output,
# rather than treating unrelated JSON examples or response fields as request parameters.
function Add-LiteralParameterKeys([string]$Body, $Keys) {
    # Preserve AL string literals while removing both comment forms.
    $Body = [regex]::Replace($Body, "(?s)'(?:[^']|'')*'|//[^\r\n]*|/\*.*?\*/", {
        param($match)
        if ($match.Value.StartsWith('/')) { return ' ' }
        return $match.Value
    })
    $signature = [regex]::Match($Body, '(?im)^\s*procedure\s+GetParameters\s*\(\s*var\s+(\w+)\s*:\s*JsonArray\s*\)')
    if (-not $signature.Success) { return }
    $receiver = [regex]::Escape($signature.Groups[1].Value)
    $pattern = '(?im)^\s*' + $receiver + '\.ReadFrom\(\s*''((?:[^'']|'''')*)''\s*\)\s*;'
    foreach ($literal in [regex]::Matches($Body, $pattern)) {
        $json = $literal.Groups[1].Value.Replace("''", "'")
        try { $chapter = ConvertFrom-Json -InputObject $json -AsHashtable -NoEnumerate -ErrorAction Stop }
        catch { throw "Invalid literal GetParameters JSON: $($_.Exception.Message)" }
        if ($chapter -isnot [array]) { throw 'Literal GetParameters chapter must be a JSON array.' }
        foreach ($parameter in $chapter) {
            if ($parameter -isnot [System.Collections.IDictionary] -or
                $parameter['name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($parameter['name'])) {
                throw 'Each literal GetParameters entry must have a nonempty string name.'
            }
            [void]$Keys.Add($parameter['name'])
        }
    }
}

# The declaration/target walker is independent of the implementation-read walker. Its
# lexer protects strings/comments, and its cache includes literal Text arguments.
# Limits are tooling budgets: 32 call edges and 256 contexts per chapter root. Any
# unsupported Text control flow, binding, cycle or exhausted budget fails explicitly.
if (-not ('ContractLiteralWalk' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
public sealed class ContractLiteralWalk {
    public sealed class Source { public string Name, Text; public Dictionary<string,string[]> Methods; }
    public sealed class Result { public List<string> Bodies = new List<string>(); public List<string> Diagnostics = new List<string>(); }
    sealed class Token { public string Raw, Value; public bool String; }
    sealed class Node { public string Kind; public List<Token> Expr = new List<Token>(); public List<Node> Children = new List<Node>(); public Node Yes, No; public List<List<Token>> Labels = new List<List<Token>>(); }
    sealed class Method { public string Object, Name, Header; public List<string> Params = new List<string>(); public Dictionary<string,string> Types = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase); public HashSet<string> Var = new HashSet<string>(StringComparer.OrdinalIgnoreCase); public Node Body; }
    readonly Dictionary<string,Source> sources = new Dictionary<string,Source>(StringComparer.OrdinalIgnoreCase);
    readonly Dictionary<string,List<Method>> methods = new Dictionary<string,List<Method>>(StringComparer.OrdinalIgnoreCase);
    readonly HashSet<string> cache = new HashSet<string>(); readonly HashSet<string> active = new HashSet<string>();
    readonly Result result = new Result(); string context; int maxDepth, maxContexts;
    static List<Token> Lex(string s) {
        var t = new List<Token>();
        for(int i=0;i<s.Length;) {
            if(char.IsWhiteSpace(s[i])) { i++; continue; }
            if(i+1<s.Length && s.Substring(i,2)=="//") { while(i<s.Length && s[i]!='\n') i++; continue; }
            if(i+1<s.Length && s.Substring(i,2)=="/*") { int j=s.IndexOf("*/",i+2,StringComparison.Ordinal); if(j<0) throw new Exception("unterminated block comment"); i=j+2; continue; }
            int start=i; char q=s[i];
            if(q=='\'' || q=='"') {
                i++; string value=""; bool closed=false;
                while(i<s.Length) { if(s[i]==q) { i++; if(i<s.Length && s[i]==q) { value+=q; i++; } else { closed=true; break; } } else value+=s[i++]; }
                if(!closed) throw new Exception("unterminated literal");
                t.Add(new Token{Raw=s.Substring(start,i-start), Value=q=='\''?value:s.Substring(start,i-start),String=q=='\''}); continue;
            }
            if(char.IsLetterOrDigit(q)||q=='_') { while(i<s.Length&&(char.IsLetterOrDigit(s[i])||s[i]=='_')) i++; }
            else { i++; if(i<s.Length && new[]{":=","<>","<=",">=","::"}.Contains(s.Substring(start,2))) i++; }
            string raw=s.Substring(start,i-start); t.Add(new Token{Raw=raw,Value=raw.ToLowerInvariant()});
        }
        return t;
    }
    static bool Is(Token t,string s) { return !t.String && t.Value==s; }
    static string Raw(IEnumerable<Token> t) { return string.Join(" ",t.Select(x=>x.Raw)); }
    sealed class Parser {
        readonly List<Token> t; int i;
        public Parser(List<Token> tokens,int start) { t=tokens;i=start; }
        bool At(string v) { return i<t.Count && Is(t[i],v); }
        void Need(string v) { if(!At(v)) throw new Exception("expected "+v+" near "+(i<t.Count?t[i].Raw:"EOF")); i++; }
        List<Token> Until(string end) { int depth=0; var r=new List<Token>(); while(i<t.Count) { if(depth==0&&At(end)) return r; if(At("(")||At("["))depth++; if(At(")")||At("]"))depth--; r.Add(t[i++]); } throw new Exception("missing "+end); }
        public Node Statement() {
            if(At(";")){i++;return new Node{Kind="block"};}
            if(At("begin")) { i++; var n=new Node{Kind="block"}; while(!At("end")) { if(i>=t.Count)throw new Exception("unclosed block"); n.Children.Add(Statement()); } i++; return n; }
            if(At("if")) { i++; var n=new Node{Kind="if",Expr=Until("then")}; Need("then");n.Yes=Statement(); if(At("else")){i++;n.No=Statement();}return n; }
            if(At("case")) {
                i++;var n=new Node{Kind="case",Expr=Until("of")};Need("of");
                while(!At("end")) { while(At(";"))i++; if(At("end"))break; if(At("else")){i++;var b=new Node{Kind="block"};while(!At("end"))b.Children.Add(Statement());n.No=b;break;} n.Labels.Add(Until(":"));Need(":");n.Children.Add(Statement()); }
                Need("end");return n;
            }
            if(At("for")||At("foreach")||At("while")||At("with")) {string kind=t[i++].Value;var n=new Node{Kind="loop",Expr=Until("do")};Need("do");n.Yes=Statement();return n;}
            if(At("repeat")){i++;var n=new Node{Kind="loop",Yes=new Node{Kind="block"}};while(!At("until"))n.Yes.Children.Add(Statement());Need("until");n.Expr=Until(";");i++;return n;}
            var simple=new Node{Kind="simple"};int depth=0;
            while(i<t.Count) { if(depth==0&&(At(";")||At("else")||At("end")))break; if(At("("))depth++;if(At(")"))depth--;simple.Expr.Add(t[i++]); }
            if(simple.Expr.Count==0)throw new Exception("unsupported statement near "+(i<t.Count?t[i].Raw:"EOF"));if(At(";"))i++;return simple;
        }
    }
    static void Declarations(string text, Dictionary<string,string> into) {
        foreach(Match m in Regex.Matches(text,@"(?i)\b(\w+)\s*:\s*(?:(Codeunit|Record|Interface)\s+(""[^""]+"")|(Text|Code|Boolean|JsonArray|JsonObject)\b)"))
            into[m.Groups[1].Value] = m.Groups[2].Success?m.Groups[2].Value.ToLowerInvariant()+":"+m.Groups[3].Value.Trim('"'):m.Groups[4].Value.ToLowerInvariant();
    }
    static IEnumerable<Token> GlobalTokens(List<Token> tokens) {
        // AL globals may precede or follow procedures. Exclude complete signatures,
        // locals and bodies, rather than unioning variables from every procedure.
        for(int i=0;i<tokens.Count;i++) {
            if(!Is(tokens[i],"procedure")&&!Is(tokens[i],"trigger")){yield return tokens[i];continue;}
            int b=i+1;
            while(b<tokens.Count&&!Is(tokens[b],"begin")&&!Is(tokens[b],"procedure")&&!Is(tokens[b],"trigger"))b++;
            if(b==tokens.Count){yield break;}
            if(!Is(tokens[b],"begin")){i=b-1;continue;}
            int nesting=1,j=b+1;
            for(;j<tokens.Count&&nesting>0;j++){if(Is(tokens[j],"begin")||Is(tokens[j],"case"))nesting++;if(Is(tokens[j],"end"))nesting--;}
            if(nesting!=0)throw new Exception("unclosed procedure body");i=j-1;
        }
    }
    public ContractLiteralWalk(Source[] inputs,int depth,int contexts) {
        maxDepth=depth;maxContexts=contexts;
        foreach(var s in inputs)sources[s.Name]=s;
        foreach(var s in inputs) {
            var globals=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            string clean=Raw(GlobalTokens(Lex(s.Text)).Select(x=>x.String?new Token{Raw="''",Value="",String=true}:x)); Declarations(clean,globals);
            foreach(var pair in s.Methods)foreach(var body in pair.Value) {
                var tokens=Lex(body);int b=tokens.FindIndex(x=>Is(x,"begin")); if(b<0)continue;
                string header=Raw(tokens.Take(b));var m=new Method{Object=s.Name,Name=pair.Key,Header=header,Types=new Dictionary<string,string>(globals,StringComparer.OrdinalIgnoreCase)};
                Declarations(Raw(tokens.Take(b).Select(x=>x.String?new Token{Raw="''",Value="",String=true}:x)),m.Types);
                var sig=Regex.Match(header,@"(?i)\b(?:procedure|trigger)\s+(?:""[^""]+""|\w+)\s*\((.*?)\)");
                if(sig.Success)foreach(var p in sig.Groups[1].Value.Split(';')) { var match=Regex.Match(p,@"(?i)^\s*(var\s+)?(\w+)\s*:");if(match.Success){m.Params.Add(match.Groups[2].Value);if(match.Groups[1].Success)m.Var.Add(match.Groups[2].Value);} }
                try { m.Body=new Parser(tokens,b).Statement(); } catch(Exception e) { m.Body=new Node{Kind="unsupported",Expr=Lex("'"+e.Message.Replace("'","''")+"'")}; }
                string key=s.Name+"::"+pair.Key; if(!methods.ContainsKey(key))methods[key]=new List<Method>();methods[key].Add(m);
            }
        }
    }
    void Diagnostic(string message) { string d=context+": "+message;if(!result.Diagnostics.Contains(d))result.Diagnostics.Add(d); }
    static List<List<Token>> Split(List<Token> t,string delimiter) {var r=new List<List<Token>>();int depth=0;var p=new List<Token>();foreach(var x in t){if(Is(x,"(")||Is(x,"["))depth++;if(Is(x,")")||Is(x,"]"))depth--;if(depth==0&&Is(x,delimiter)){r.Add(p);p=new List<Token>();}else p.Add(x);}r.Add(p);return r;}
    object Eval(List<Token> input,Dictionary<string,object> env) {
        var t=input;
        if(t.Count==0)return null;
        // Remove only a pair enclosing the whole expression.
        if(Is(t[0],"(")&&Is(t[t.Count-1],")")) {int depth=0;bool whole=true;for(int i=0;i<t.Count-1;i++){if(Is(t[i],"("))depth++;if(Is(t[i],")"))depth--;if(depth==0){whole=false;break;}}if(whole)return Eval(t.Skip(1).Take(t.Count-2).ToList(),env);}
        foreach(string op in new[]{"or","and","=","<>","in","+"}) {
            var parts=Split(t,op); if(parts.Count<=1)continue;
            if(op=="+"){var v=parts.Select(x=>Eval(x,env)).ToArray();return v.All(x=>x is string)?string.Concat(v):null;}
            var left=Eval(parts[0],env);var right=Eval(parts[1],env);
            if(op=="in") { var p=parts[1];if(left==null||p.Count<2||!Is(p[0],"[")||!Is(p[p.Count-1],"]"))return null;var vals=Split(p.Skip(1).Take(p.Count-2).ToList(),",").Select(x=>Eval(x,env)).ToArray();return vals.Any(x=>x==null)?null:(object)vals.Any(x=>Equals(left,x)); }
            if(op=="and"){if(Equals(left,false)||Equals(right,false))return false;if(Equals(left,true)&&Equals(right,true))return true;return null;}
            if(op=="or"){if(Equals(left,true)||Equals(right,true))return true;if(Equals(left,false)&&Equals(right,false))return false;return null;}
            if(left==null||right==null)return null;return op=="="?Equals(left,right):!Equals(left,right);
        }
        if(Is(t[0],"not")){var v=Eval(t.Skip(1).ToList(),env);return v is bool?(object)!(bool)v:null;}
        if(t.Count==1){if(t[0].String)return t[0].Value;object v;if(env.TryGetValue(t[0].Value,out v))return v;if(Is(t[0],"true"))return true;if(Is(t[0],"false"))return false;return null;}
        if(t.Count==6&&Is(t[1],".")&&Is(t[2],"startswith")&&Is(t[3],"(")&&Is(t[5],")")){object v;return env.TryGetValue(t[0].Value,out v)&&v is string&&t[4].String?(object)((string)v).StartsWith(t[4].Value,StringComparison.Ordinal):null;}
        return null;
    }
    bool TextDependent(List<Token> expr,Method m) {return expr.Any(x=>!x.String&&m.Types.ContainsKey(x.Value)&&(m.Types[x.Value]=="text"||m.Types[x.Value]=="code"));}
    string Render(List<Token> t,Dictionary<string,object> env) {
        var tokens=new List<Token>();
        foreach(var x in t) {
            if(!x.String&&env.ContainsKey(x.Value)&&env[x.Value] is string) {
                string v=(string)env[x.Value];tokens.Add(new Token{Raw="'"+v.Replace("'","''")+"'",Value=v,String=true});
            } else tokens.Add(x);
        }
        // Fold only adjacent proven literal tokens; never rewrite punctuation inside strings.
        for(int i=0;i+2<tokens.Count;) {
            if(tokens[i].String&&Is(tokens[i+1],"+")&&tokens[i+2].String) {
                string value=tokens[i].Value+tokens[i+2].Value;
                tokens[i]=new Token{Raw="'"+value.Replace("'","''")+"'",Value=value,String=true};tokens.RemoveRange(i+1,2);
            }else i++;
        }
        string r="";
        for(int i=0;i<tokens.Count;i++) {
            bool compact=i==0||Is(tokens[i],".")||Is(tokens[i],"(")||Is(tokens[i],")")||Is(tokens[i-1],".")||Is(tokens[i-1],"(");
            r+=(compact?"":" ")+tokens[i].Raw;
        }
        return r;
    }
    void Calls(List<Token> t,Method m,Dictionary<string,object> env,int depth) {
        for(int i=0;i<t.Count-1;i++) {
            if(t[i].String||!Is(t[i+1],"("))continue;
            string name=t[i].Value; if(new[]{"exit","clear","error","if"}.Contains(name))continue;
            string receiver=i>=2&&Is(t[i-1],".")?t[i-2].Value:"";
            if(name=="parameter"||name=="targetentry") {
                string builderType;
                if(receiver==""||!m.Types.TryGetValue(receiver,out builderType)||!builderType.Equals("codeunit:Msg Contract Mgt ori",StringComparison.OrdinalIgnoreCase))
                    Diagnostic("unproven contract builder "+receiver+"."+name);
            }
            string target=m.Object;bool unknown=false;
            if(receiver!=""&&receiver!="this") {string type;if(!m.Types.TryGetValue(receiver,out type)){unknown=true;}else if(type.StartsWith("codeunit:")||type.StartsWith("record:")){target=type.Substring(type.IndexOf(':')+1);}else if(type.StartsWith("interface:")){Diagnostic("unsupported interface dispatch "+receiver+"."+name);continue;}else continue;}
            if(unknown) {if(methods.Keys.Any(x=>x.EndsWith("::"+name,StringComparison.OrdinalIgnoreCase))) {
                Diagnostic("unresolved receiver "+receiver+"."+name);
                // Preserve conservative legacy Boolean declarations, but an unresolved binding cannot pass.
                foreach(var candidate in methods.Where(x=>x.Key.EndsWith("::"+name,StringComparison.OrdinalIgnoreCase))) {
                    if(!candidate.Value.Any(x=>x.Params.Any(p=>x.Types.ContainsKey(p)&&x.Types[p]=="text")))Walk(candidate.Value[0].Object,name,new Dictionary<string,object>(StringComparer.OrdinalIgnoreCase),depth+1);
                }
            } continue;}
            string key=target+"::"+name;if(!methods.ContainsKey(key))continue;
            int j=i+2, nesting=1;var args=new List<Token>();for(;j<t.Count;j++){if(Is(t[j],"("))nesting++;if(Is(t[j],")"))nesting--;if(nesting==0)break;args.Add(t[j]);}if(nesting!=0){Diagnostic("unclosed call "+key);continue;}
            if(methods[key].Count!=1){Diagnostic("ambiguous overload "+key);continue;}var callee=methods[key][0];var values=Split(args,",");var bound=new Dictionary<string,object>(StringComparer.OrdinalIgnoreCase);
            for(int k=0;k<callee.Params.Count;k++) {string p=callee.Params[k];object v=k<values.Count?Eval(values[k],env):null;if(callee.Types.ContainsKey(p)&&(callee.Types[p]=="text"||callee.Types[p]=="boolean"))bound[p]=v; // Keep known Boolean contexts separate; the legacy veto/pruning controls remain in force.
                if(callee.Var.Contains(p)&&k<values.Count&&values[k].Count==1&&env.ContainsKey(values[k][0].Value)) {string actual=values[k][0].Value;env[actual]=null;Diagnostic("var alias mutation invalidates "+actual);}
            }
            Walk(target,name,bound,depth+1);
        }
    }
    bool Execute(Node n,Method m,Dictionary<string,object> env,List<string> output,int depth) {
        if(n==null)return false;
        if(n.Kind=="unsupported"){Diagnostic("unsupported branch shape "+Raw(n.Expr));return false;}
        if(n.Kind=="block"){foreach(var child in n.Children)if(Execute(child,m,env,output,depth))return true;return false;}
        if(n.Kind=="if") {
            Calls(n.Expr,m,env,depth);
            object v=Eval(n.Expr,env);
            if(v is bool)return Execute((bool)v?n.Yes:n.No,m,env,output,depth);
            if(TextDependent(n.Expr,m))Diagnostic("unknown/dynamic Text selector "+Raw(n.Expr));
            var a=new Dictionary<string,object>(env,StringComparer.OrdinalIgnoreCase);var b=new Dictionary<string,object>(env,StringComparer.OrdinalIgnoreCase);
            Execute(n.Yes,m,a,output,depth);Execute(n.No,m,b,output,depth);
            foreach(string k in env.Keys.ToArray())if(!a.ContainsKey(k)||!b.ContainsKey(k)||!Equals(a[k],b[k]))env[k]=null;
            return false;
        }
        if(n.Kind=="case") {
            Calls(n.Expr,m,env,depth);
            object value=Eval(n.Expr,env);if(value==null){Diagnostic("unknown/dynamic case selector "+Raw(n.Expr));foreach(var c in n.Children)Execute(c,m,new Dictionary<string,object>(env,StringComparer.OrdinalIgnoreCase),output,depth);Execute(n.No,m,env,output,depth);return false;}
            for(int i=0;i<n.Labels.Count;i++){var labels=Split(n.Labels[i],",").Select(x=>Eval(x,env)).ToArray();if(labels.Any(x=>x==null))Diagnostic("unsupported case label "+Raw(n.Labels[i]));if(labels.Any(x=>Equals(x,value)))return Execute(n.Children[i],m,env,output,depth);}return Execute(n.No,m,env,output,depth);
        }
        if(n.Kind=="loop") {Calls(n.Expr,m,env,depth);if(TextDependent(n.Expr,m))Diagnostic("unsupported Text loop "+Raw(n.Expr));Execute(n.Yes,m,env,output,depth);return false;}
        if(n.Expr.Count>=2&&Is(n.Expr[1],":=")) {string variable=n.Expr[0].Value;if(env.ContainsKey(variable)){env[variable]=null;Diagnostic("selector assignment invalidates "+variable);} }
        if(n.Expr.Count>=4&&Is(n.Expr[0],"clear")&&Is(n.Expr[1],"(")&&env.ContainsKey(n.Expr[2].Value)){env[n.Expr[2].Value]=null;Diagnostic("Clear invalidates selector "+n.Expr[2].Value);}
        Calls(n.Expr,m,env,depth);output.Add(Render(n.Expr,env)+";");return n.Expr.Count>0&&Is(n.Expr[0],"exit");
    }
    void Walk(string obj,string name,Dictionary<string,object> env,int depth) {
        string key=obj+"::"+name;string previous=context;context=key+"("+string.Join(",",env.OrderBy(x=>x.Key).Select(x=>x.Key+"="+(x.Value==null?"?":x.Value.ToString())))+")";
        try {
            if(depth>maxDepth){Diagnostic("call-depth budget exhausted ("+maxDepth+")");return;}
            if(!methods.ContainsKey(key))return;if(methods[key].Count!=1){Diagnostic("ambiguous overload");return;}
            string id=key+"|"+string.Join("|",env.OrderBy(x=>x.Key).Select(x=>x.Key.Length+":"+x.Key+":"+(x.Value==null?"?":x.Value.GetType().Name+":"+x.Value.ToString().Length+":"+x.Value)));if(active.Contains(id)){Diagnostic("recursive context/cycle");return;}if(cache.Contains(id))return;if(cache.Count>=maxContexts){Diagnostic("context budget exhausted ("+maxContexts+")");return;}
            cache.Add(id);active.Add(id);var m=methods[key][0];var output=new List<string>();Execute(m.Body,m,env,output,depth);result.Bodies.Add(m.Header+"\nbegin\n"+string.Join("\n",output)+"\nend;");active.Remove(id);
        }finally{context=previous;}
    }
    public Result Run(string obj,string method) { Walk(obj,method,new Dictionary<string,object>(StringComparer.OrdinalIgnoreCase),0);return result; }
}
'@
}

function Get-LiteralContextBodies($Objects, [string]$Root, [string]$Chapter, [int]$MaxDepth = 32, [int]$MaxContexts = 256) {
    $inputs = [System.Collections.Generic.List[ContractLiteralWalk+Source]]::new()
    foreach ($name in $Objects.Keys) {
        $methods = [System.Collections.Generic.Dictionary[string,string[]]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($method in $Objects[$name].Procedures.Keys) { $methods[$method] = [string[]]$Objects[$name].Procedures[$method] }
        $inputs.Add([ContractLiteralWalk+Source]@{ Name = $name; Text = $Objects[$name].Text; Methods = $methods })
    }
    $walk = [ContractLiteralWalk]::new($inputs.ToArray(), $MaxDepth, $MaxContexts)
    $result = $walk.Run($Root, $Chapter)
    foreach ($diagnostic in $result.Diagnostics) {
        $objectName = ($diagnostic -split '::', 2)[0]
        [void]$script:ContextDiagnostics.Add("$($Objects[$objectName].File): $diagnostic")
    }
    return ,$result.Bodies
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
    foreach ($body in (Get-LiteralContextBodies $Objects $ContractCodeunit 'getparameters')) {
            foreach ($m in $parameterLiteral.Matches($body)) { [void]$keys.Add($m.Groups[1].Value) }
            Add-LiteralParameterKeys $body $keys
            # A parameter declared in a loop over a literal list: AdjustNames.AddRange('a', 'b') ... Parameter(AdjustNames.Get(i), ...)
            foreach ($loop in [regex]::Matches($body, '\.Parameter\(\s*(\w+)\.Get\(')) {
                $listName = [regex]::Escape($loop.Groups[1].Value)
                $rangePattern = $listName + $addRangeTail
                foreach ($range in [regex]::Matches($body, $rangePattern)) {
                    foreach ($literal in $stringLiteral.Matches($range.Groups[1].Value)) { [void]$keys.Add($literal.Groups[1].Value) }
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
    foreach ($body in (Get-LiteralContextBodies $Objects $ContractCodeunit 'gettarget')) {
        foreach ($m in $targetLiteral.Matches($body)) { Add-TargetText $m.Groups[1].Value $keys }
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

# The keys the implementation reads from the request in the procedures it reaches from ExecuteBifrostTask.
# A call whose first argument is the request and whose second argument is a literal counts, including a wrapper
# such as GetTextParam(RequestJson, 'dateFilter', ...) and a variable such as ReqJson (#430).
function Get-ReadKeys($Objects, [string]$Codeunit) {
    $keys = New-Object 'System.Collections.Generic.HashSet[string]'
    $seen = @{}
    Get-Reach $Objects $Codeunit 'executebifrosttask' $seen $true
    $requestVars = Get-RequestVars $Objects $seen
    foreach ($entry in $seen.Keys) {
        $parts = $entry -split '::', 2
        $requestNames = $requestVars[$entry]
        foreach ($body in $Objects[$parts[0]].Procedures[$parts[1]]) {
            foreach ($m in $memberRead.Matches($body)) { Add-CallRead $m $requestNames $keys }
            foreach ($m in $callRead.Matches($body)) { Add-CallRead $m $requestNames $keys }
            foreach ($m in $keySpec.Matches($body)) {
                foreach ($pair in $m.Groups[1].Value.Split(',')) { [void]$keys.Add($pair.Split('=')[0]) }
            }
        }
    }
    return ,$keys
}

function Find-Offenders([string]$AppFolder) {
    $script:ContextDiagnostics = [System.Collections.Generic.List[string]]::new()
    $objects = Read-Source (Join-Path $AppFolder 'src')
    $types = Get-Types $objects
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($typeName in $types.Keys) {
        $contractCodeunit = $types[$typeName].Contract
        $interfaceCodeunit = $types[$typeName].Interface
        if ($contractCodeunit -eq 'Default Contract ori') { continue }
        if (-not $objects.ContainsKey($contractCodeunit) -or -not $objects.ContainsKey($interfaceCodeunit)) { continue }
        if ($Explain -ne '' -and $typeName -ne $Explain) { continue }
        $declared = Get-DeclaredKeys $objects $contractCodeunit
        $literals = Get-ReachableLiterals $objects $interfaceCodeunit
        $reads = Get-ReadKeys $objects $interfaceCodeunit
        $targetKeys = Get-TargetKeys $objects $contractCodeunit
        if ($Explain -ne '') {
            $script:Explained = $true
            Write-Host "contract codeunit : $contractCodeunit"
            Write-Host "interface codeunit: $interfaceCodeunit"
            Write-Host "declared          : $(($declared | Sort-Object) -join ', ')"
            Write-Host "target (data.)    : $(($targetKeys | Sort-Object) -join ', ')"
            Write-Host "read              : $(($reads | Sort-Object) -join ', ')"
        }
        foreach ($key in ($declared | Sort-Object)) {
            if (-not $literals.Contains($key)) { $found.Add("$typeName|declared-not-read|$key") }
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

function Invoke-SelfTestLiteralParameters {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("contract-json-" + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app/src'
    New-Item -ItemType Directory -Path $src -Force | Out-Null
    try {
        @'
namespace Origo.Bifrost;
enum 1 "Message Type ori"
{
    value(1; "Literal.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Literal Impl ori", "Msg Contract ori" = "Literal Impl ori";
    }
}
codeunit 1 "Literal Impl ori" implements "Msg Interface ori", "Msg Contract ori"
{
    procedure GetParameters(var Chapter: JsonArray): Boolean
    var
        Other: JsonArray;
    begin
        // Chapter.ReadFrom('[{"name":"commentOnly"}]');
        /*
        Chapter.ReadFrom('[{"name":"blockCommentOnly"}]');
        */
        Other.ReadFrom('[{"name":"missing"},{"name":"unrelated"}]');
        Chapter.ReadFrom('[{"name":"used","description":"caller''s key"},{"name":"unused"}]');
        exit(true);
    end;
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        RequestJson.Get('used', Token);
        RequestJson.Get('missing', Token);
    end;
}
'@ | Set-Content -LiteralPath (Join-Path $src 'literal.al') -Encoding UTF8
        # One AL object per file, matching Read-Source's existing object index.
        $fixture = Get-Content -LiteralPath (Join-Path $src 'literal.al') -Raw
        $start = $fixture.IndexOf('codeunit 1')
        $fixture.Substring(0, $start) | Set-Content -LiteralPath (Join-Path $src 'literal.al') -Encoding UTF8
        ("namespace Origo.Bifrost;`n" + $fixture.Substring($start)) | Set-Content -LiteralPath (Join-Path $src 'implementation.al') -Encoding UTF8
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @('Literal.Thing.Get|declared-not-read|unused', 'Literal.Thing.Get|read-not-declared|missing')
        if ($found.Count -ne $expected.Count -or @($expected | Where-Object { -not $found.Contains($_) }).Count -gt 0) {
            throw "Literal parameter SelfTest failed: $($found -join '; ')"
        }
        foreach ($invalid in @('{}', 'null', '[{"name":false}]', '[{"name":""}]', '[null]', '[broken')) {
            $body = "procedure GetParameters(var Chapter: JsonArray): Boolean`nbegin`nChapter.ReadFrom('$invalid');`nend;"
            $keys = New-Object 'System.Collections.Generic.HashSet[string]'
            $rejected = $false
            try { Add-LiteralParameterKeys $body $keys } catch { $rejected = $true }
            if (-not $rejected) { throw "Literal parameter SelfTest accepted invalid chapter: $invalid" }
        }
        $keys = New-Object 'System.Collections.Generic.HashSet[string]'
        Add-LiteralParameterKeys "procedure GetParameters(var Chapter: JsonArray): Boolean`nbegin`nChapter.ReadFrom('[]');`nend;" $keys
        if ($keys.Count -ne 0) { throw 'Empty literal parameter array declared a key.' }
        Write-Host 'SelfTest (literal parameters: mismatch, receiver, comments, escaping, six invalid chapters, empty array) passed.'
    }
    finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-SelfTestLiteralContexts {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('contract-context-' + [guid]::NewGuid().ToString('N'))
    $src = Join-Path $root 'app/src'
    [void](New-Item -ItemType Directory -Path $src -Force)
    try {
        @'
namespace Origo.Bifrost;
codeunit 1 "Context Parts"
{
    procedure Parameters(Selector: Text) Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        // case Selector of 'A': ContractMgt.Parameter('comment', '', false, ''); end;
        /* Selector := 'B'; */
        case Selector of
            'A', 'A''quoted':
                begin
                    if Selector in ['A', 'A''quoted'] then
                        Result.Add(ContractMgt.Parameter('alpha', 'string', false, 'literal end; case '' escape'));
                    case Selector of
                        'A': Result.Add(ContractMgt.Parameter('nested', 'string', false, ''));
                    end;
                end;
            'B': Result.Add(ContractMgt.Parameter('beta', 'string', false, ''));
            else
                exit;
        end;
    end;
    procedure Target(Selector: Text) Result: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if Selector = 'None' then exit;
        if Selector in ['A', 'A''quoted'] then begin
            Result.Add(ContractMgt.TargetEntry('data.alphaId', 'guid', ''));
            exit;
        end;
        Result.Add(ContractMgt.TargetEntry('data.betaId', 'guid', ''));
    end;
}
'@ | Set-Content (Join-Path $src 'Parts.al')
        @'
namespace Origo.Bifrost;
codeunit 2 "Forwarder"
{
    procedure Forward(Selector: Text) Result: JsonArray
    var
        Parts: Codeunit "Context Parts";
    begin
        Result := Parts.Parameters(Selector);
    end;
}
'@ | Set-Content (Join-Path $src 'Forwarder.al')
        @'
namespace Origo.Bifrost;
codeunit 3 "Wrong Parts"
{
    procedure Parameters(Selector: Text) Result: JsonArray
    var
        Mgt: Codeunit "Msg Contract Mgt ori";
    begin
        Result.Add(Mgt.Parameter('wrongScope', 'string', false, ''));
    end;
}
'@ | Set-Content (Join-Path $src 'Wrong.al')
        foreach ($name in @('A', 'B', 'None', "A'quoted")) {
            $alLiteral = $name.Replace("'", "''")
            @"
namespace Origo.Bifrost;
codeunit 4 "Caller $name"
{
    var
        Parts: Codeunit "Wrong Parts";
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parts: Codeunit "Forwarder";
    begin
        Parameters := Parts.Forward('$alLiteral');
        exit(true);
    end;
    procedure Unrelated()
    var
        Parts: Codeunit "Wrong Parts";
    begin
        Parts.Parameters('B');
    end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Context Parts";
    begin
        Target := Parts.Target('$alLiteral');
        exit(true);
    end;
}
"@ | Set-Content (Join-Path $src ($name.Replace("'",'') + '.al'))
        }
        $objects = Read-Source $src
        $script:ContextDiagnostics = [System.Collections.Generic.List[string]]::new()
        foreach ($name in @('A', 'B', 'None', "A'quoted")) {
            $keys = Get-DeclaredKeys $objects "Caller $name"
            $targets = Get-TargetKeys $objects "Caller $name"
            $expected = switch ($name) { A { 'alpha,nested' }; B { 'beta' }; None { '' }; default { 'alpha' } }
            $expectedTarget = switch ($name) { A { 'alphaId' }; None { '' }; "A'quoted" { 'alphaId' }; default { 'betaId' } }
            if ((($keys | Sort-Object) -join ',') -cne $expected -or (($targets | Sort-Object) -join ',') -cne $expectedTarget) {
                throw "Context separation failed: $name parameters=$keys targets=$targets"
            }
        }
        if ($script:ContextDiagnostics.Count) { throw ($script:ContextDiagnostics -join '; ') }
        # A global receiver and a formal receiver independently shadow procedure-local names.
        $saved = $objects['Caller A'].Procedures['getparameters']
        $objects['Caller A'].Procedures['getparameters'] = @($objects['Caller A'].Procedures['unrelated'][0])
        $savedText = $objects['Caller A'].Text
        $globalDecl = 'Parts: Codeunit "Wrong Parts";'
        $objects['Caller A'].Text = $savedText.Replace($globalDecl, '').TrimEnd().TrimEnd('}') + "`nvar`n    $globalDecl`n}"
        $globalKeys = Get-DeclaredKeys $objects 'Caller A'
        if ((($globalKeys | Sort-Object) -join ',') -cne 'wrongScope') { throw 'Global receiver borrowed a local binding.' }
        $objects['Caller A'].Procedures['getparameters'] = @('procedure GetParameters(Parts: Codeunit "Context Parts")
begin Parts.Parameters(''B''); end;')
        $formalKeys = Get-DeclaredKeys $objects 'Caller A'
        if ((($formalKeys | Sort-Object) -join ',') -cne 'beta') { throw 'Formal receiver failed to shadow globals.' }
        $objects['Caller A'].Procedures['getparameters'] = $saved
        $objects['Caller A'].Text = $savedText
        # One root calls the same helper repeatedly with differing literals: separate cache entries.
        $objects['Caller A'].Procedures['getparameters'] = @($objects['Caller A'].Procedures['getparameters'][0].Replace("Parts.Forward('A');", "Parts.Forward('A'); Parts.Forward('B'); Parts.Forward('A');"))
        $keys = Get-DeclaredKeys $objects 'Caller A'
        if ((($keys | Sort-Object) -join ',') -cne 'alpha,beta,nested') { throw 'Repeated literal contexts collapsed.' }
        # Full normal-guard fixture: matching, wrong/missing branch, wrong reads and declaration-only keys.
        @'
namespace Origo.Bifrost;
enumextension 5 "Context Enum" extends "Message Type ori"
{
    value(1; "Context.Match") { Implementation = "Msg Contract ori" = "Match", "Msg Interface ori" = "Match";
    }
    value(2; "Context.Missing") { Implementation = "Msg Contract ori" = "Missing", "Msg Interface ori" = "Missing";
    }
    value(3; "Context.Wrong") { Implementation = "Msg Contract ori" = "Wrong", "Msg Interface ori" = "Wrong";
    }
}
'@ | Set-Content (Join-Path $src 'Enum.al')
        foreach ($name in @('Match','Missing','Wrong')) {
            $selector = if ($name -eq 'Missing') { 'None' } elseif ($name -eq 'Wrong') { 'B' } else { 'A' }
            $wrongRead = if ($name -eq 'Match') { "if RequestJson.Get('rogue', Token) then;" } else { '' }
            @"
namespace Origo.Bifrost;
codeunit 6 "$name"
{
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var Parts: Codeunit "Context Parts";
    begin Parameters := Parts.Parameters('$selector'); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var Parts: Codeunit "Context Parts";
    begin Target := Parts.Target('$selector'); exit(true); end;
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var RequestJson: JsonObject; Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('alpha', Token) then;
        if RequestJson.Get('alphaId', Token) then;
        $wrongRead
    end;
}
"@ | Set-Content (Join-Path $src ($name + '.al'))
        }
        $found = Find-Offenders (Join-Path $root 'app')
        $expected = @('Context.Match|declared-not-read|nested','Context.Match|read-not-declared|rogue',
            'Context.Missing|read-not-declared|alpha','Context.Missing|read-not-declared|alphaId',
            'Context.Wrong|declared-not-read|beta','Context.Wrong|read-not-declared|alpha','Context.Wrong|read-not-declared|alphaId')
        if ((($found | Sort-Object) -join ';') -cne (($expected | Sort-Object) -join ';')) { throw "Discriminating offenders changed: $found" }
        if ($script:ContextDiagnostics.Count) { throw ($script:ContextDiagnostics -join '; ') }
        # Explicit fail-closed controls, tested via the same production walker.
        foreach ($control in @('dynamic','target-dynamic','unresolved','builder','mutation','clear','var-alias','interface','overload','recursion','unsupported')) {
            $signature = 'procedure Forward(Selector: Text) Result: JsonArray'
            $vars = 'var Parts: Codeunit "Context Parts";'
            $body = 'Result := Parts.Parameters(Selector);'
            switch ($control) {
                dynamic { $body = 'Result := Parts.Parameters(Unknown());' }
                'target-dynamic' { $body = 'Result := Parts.Target(Unknown());' }
                unresolved { $body = 'Result := Missing.Parameters(Selector);' }
                builder { $vars = 'var Bad: JsonObject;'; $body = "Result.Add(Bad.Parameter('alpha', 'string', false, ''));" }
                mutation { $body = "Selector := 'B'; Result := Parts.Parameters(Selector);" }
                clear { $body = 'Clear(Selector); Result := Parts.Parameters(Selector);' }
                'var-alias' { $body = 'Mutate(Selector); Result := Parts.Parameters(Selector);' }
                interface { $vars = 'var Parts: Interface "Context API";' }
                recursion { $body = 'Result := Forward(Selector);' }
                unsupported { $body = "case Selector of 1..10: exit; end;" }
            }
            $extra = if ($control -eq 'overload') { "procedure Forward(Other: Text) Result: JsonArray begin exit; end;" } elseif ($control -eq 'var-alias') { "local procedure Mutate(var Selector: Text) begin Selector := 'B'; end;" } else { '' }
            "namespace Origo.Bifrost;`ncodeunit 2 `"Forwarder`"`n{`n$signature`n$vars`nbegin $body end;`n$extra`n}" | Set-Content (Join-Path $src 'Forwarder.al')
            # Read-Source is line based; put the extra procedure on its own line.
            $objects = Read-Source $src
            $script:ContextDiagnostics = [System.Collections.Generic.List[string]]::new()
            [void](Get-LiteralContextBodies $objects 'Caller A' 'getparameters')
            $expectedDiagnostic = switch ($control) {
                dynamic { 'unknown/dynamic' }; 'target-dynamic' { 'unknown/dynamic' }; unresolved { 'unresolved receiver' }; builder { 'unproven contract builder' }; mutation { 'assignment invalidates' }; clear { 'Clear invalidates' }
                'var-alias' { 'var alias mutation' }; interface { 'unsupported interface dispatch' }
                overload { 'ambiguous overload' }; recursion { 'recursive context/cycle' }; unsupported { 'unsupported case label' }
            }
            if (-not @($script:ContextDiagnostics | Where-Object { $_.Contains($expectedDiagnostic) }).Count) {
                throw "Fail-closed control lacked its specific diagnostic: $control -> $($script:ContextDiagnostics -join '; ')"
            }
            Write-Host "SelfTest negative ${control}: $($script:ContextDiagnostics -join '; ')"
        }
        # Exact budget boundaries (root counts as a context; call depth counts edges).
        foreach ($depth in @(32,33)) {
            $methods = for ($i = 0; $i -le $depth; $i++) { $call = if ($i -lt $depth) { "Hop$($i+1)(Selector);" } else { '' }; "procedure Hop$i(Selector: Text)`nbegin $call end;" }
            "namespace Origo.Bifrost;`ncodeunit 9 `"Budget`"`n{`n$($methods -join "`n")`n}" | Set-Content (Join-Path $src 'Budget.al')
            $objects = Read-Source $src; $script:ContextDiagnostics = [System.Collections.Generic.List[string]]::new()
            [void](Get-LiteralContextBodies $objects 'Budget' 'hop0')
            if (($script:ContextDiagnostics.Count -gt 0) -ne ($depth -eq 33)) { throw "Depth boundary wrong: $depth" }
        }
        foreach ($count in @(255,256)) {
            $calls = (0..($count-1) | ForEach-Object { "Hop('$_');" }) -join ' '
            "namespace Origo.Bifrost;`ncodeunit 9 `"Budget`"`n{`nprocedure Root()`nbegin $calls end;`nprocedure Hop(Selector: Text)`nbegin exit; end;`n}" | Set-Content (Join-Path $src 'Budget.al')
            $objects = Read-Source $src; $script:ContextDiagnostics = [System.Collections.Generic.List[string]]::new()
            [void](Get-LiteralContextBodies $objects 'Budget' 'root')
            if (($script:ContextDiagnostics.Count -gt 0) -ne ($count -eq 256)) { throw "Context boundary wrong: $count" }
        }
        Write-Host 'SelfTest (literal contexts: chapter separation, lexical shadowing, forwarders, grouped/nested branches, early exits, comments/escaping, eleven failures, depth/context boundaries) passed.'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($SelfTest) {
    Invoke-SelfTest
    Invoke-SelfTestConditionalParameters
    Invoke-SelfTestLiteralParameters
    Invoke-SelfTestLiteralContexts
    exit 0
}

$found = Find-Offenders $AppFolder
# -Explain prints what the guard sees for one type. The other allow-list entries are not stale just because they were not printed (#430).
if ($Explain -ne '') {
    if (-not $script:Explained) {
        Write-Host "::error::No message type named '$Explain' with a contract was found. Use the name as the Message Type enum spells it, for example Data.Notes.Set."
        exit 1
    }
    if ($script:ContextDiagnostics.Count -gt 0) {
        $script:ContextDiagnostics | ForEach-Object { Write-Host "::error::Contract literal context: $_" }
        exit 1
    }
    exit 0
}
if ($script:ContextDiagnostics.Count -gt 0) {
    foreach ($diagnostic in ($script:ContextDiagnostics | Sort-Object -Unique)) { Write-Host "::error::Contract literal context: $diagnostic" }
}
$allowed = Read-AllowList $AllowListPath
$problems = Compare-WithAllowList $found $allowed
if ($problems.Count -gt 0) {
    Write-Host "::error::The contract parameter names and the keys the code reads disagree ($($problems.Count) problem(s)). Fix the contract or the code; the allow-list may only shrink (#357)."
    $problems | ForEach-Object { Write-Host $_ }
    exit 1
}
if ($script:ContextDiagnostics.Count -gt 0) { exit 1 }
Write-Host "Every contract parameter is a key the code reads, and every key the code reads is declared ($($allowed.Count) allow-listed)."
