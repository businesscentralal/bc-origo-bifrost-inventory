namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemTracing.Get traces a lot or serial number through the item ledger, as the Item Tracing page
/// does: from the origin to where it was used, or from the use back to where it came from. It only reads: the
/// trace is built in temporary records.
/// </summary>
codeunit 10076994 "Item Tracing Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        AllowedKeysTok: Label 'lotNo, serialNo, itemNo, variantCode, direction', Locked = true;
        DirectionsTok: Label 'usageToOrigin, originToUsage', Locked = true;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Ledger Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Traces a lot or serial number to where it came from or where it went.', Comment = 'is-IS=Rekur lotu- eða raðnúmer til uppruna þess eða þangað sem það fór. (vörurakning, innköllun, lotuferill, raðnúmeraferill, notkun, uppruni).';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item tracing, recall, lot trace, serial trace, where used, origin', Comment = 'is-IS=vörurakning, innköllun, lotuferill, raðnúmeraferill, notkun, uppruni';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'The lot or serial number is named in data; subject is not read.', Comment = 'is-IS=Lotu- eða raðnúmerið er tilgreint í data; subject er ekki lesið.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The lot or serial number is named in data (lotNo, serialNo); subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LotTargetLbl: Label 'A lot number, optionally narrowed by item number and variant code.', Comment = 'is-IS=Lotunúmer, að vali þrengt með vörunúmeri og afbrigðakóða.';
        SerialTargetLbl: Label 'A serial number, optionally narrowed by item number and variant code.', Comment = 'is-IS=Raðnúmer, að vali þrengt með vörunúmeri og afbrigðakóða.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.lotNo', 'lot no.', LotTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.serialNo', 'serial no.', SerialTargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LotNoLbl: Label 'The lot number to trace. Send lotNo, serialNo or both. Exact value; filter characters are refused.', Comment = 'is-IS=Lotunúmerið sem á að rekja. Sendu lotNo, serialNo eða bæði. Nákvæmt gildi; síunarstafir eru ekki leyfðir.';
        SerialNoLbl: Label 'The serial number to trace. Send lotNo, serialNo or both. Exact value; filter characters are refused.', Comment = 'is-IS=Raðnúmerið sem á að rekja. Sendu lotNo, serialNo eða bæði. Nákvæmt gildi; síunarstafir eru ekki leyfðir.';
        ItemNoLbl: Label 'Optional. Only trace entries of this item number.', Comment = 'is-IS=Valfrjálst. Rekja aðeins færslur þessa vörunúmers.';
        VariantCodeLbl: Label 'Optional. Only trace entries of this variant code.', Comment = 'is-IS=Valfrjálst. Rekja aðeins færslur þessa afbrigðakóða.';
        DirectionLbl: Label 'originToUsage (default) follows the lot or serial from where it came into stock to where it was used. usageToOrigin follows it from where it was used back to where it came from.', Comment = 'is-IS=originToUsage (sjálfgefið) rekur lotuna eða raðnúmerið frá því að það kom á lager þangað til það var notað. usageToOrigin rekur það frá notkun aftur til uppruna.';
    begin
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, LotNoLbl));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, SerialNoLbl));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, VariantCodeLbl));
        Parameters.Add(ContractMgt.Parameter('direction', 'string', false, DirectionLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        NodeFields: JsonArray;
        NodesField: JsonObject;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the trace was read.'));
        Fields.Add(ContractMgt.ResponseField('direction', 'string', 'The direction that was traced: originToUsage or usageToOrigin.'));
        Fields.Add(ContractMgt.ResponseField('nodeCount', 'integer', 'The number of nodes in the trace.'));
        NodeFields.Add(ContractMgt.ResponseField('level', 'integer', 'The depth in the trace tree; 0 is a match of your lotNo or serialNo.'));
        NodeFields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The item ledger entry number of the node.'));
        NodeFields.Add(ContractMgt.ResponseField('parentEntryNo', 'integer', 'The item ledger entry number of the parent node; 0 at level 0.'));
        NodeFields.Add(ContractMgt.ResponseField('entryType', 'string', 'The item ledger entry type, for example Purchase, Sale, Consumption or Output.'));
        NodeFields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The document number of the entry.'));
        NodeFields.Add(ContractMgt.ResponseField('postingDate', 'string', 'The posting date in YYYY-MM-DD form.'));
        NodeFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the entry.'));
        NodeFields.Add(ContractMgt.ResponseField('variantCode', 'string', 'The variant code of the entry; blank when there is none.'));
        NodeFields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number of the entry; blank when there is none.'));
        NodeFields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number of the entry; blank when there is none.'));
        NodeFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code of the entry; blank when there is none.'));
        NodeFields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity of the entry, in the base unit of measure; negative when stock left.'));
        NodeFields.Add(ContractMgt.ResponseField('remainingQuantity', 'decimal', 'The quantity of the entry that is still open.'));
        NodeFields.Add(ContractMgt.ResponseField('open', 'boolean', 'True when the entry still has remaining quantity.'));
        NodesField := ContractMgt.ResponseField('nodes', 'array', 'The trace tree as a flat list in tree order; level and parentEntryNo give the structure.');
        NodesField.Add('children', NodeFields);
        Fields.Add(NodesField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'Neither lotNo nor serialNo is sent.', Comment = 'is-IS=Hvorki lotNo né serialNo er sent.';
        MissingFixLbl: Label 'Send lotNo, serialNo or both.', Comment = 'is-IS=Sendu lotNo, serialNo eða bæði.';
        InvalidWhenLbl: Label 'direction has a value this type does not support, a value contains filter characters or is too long, or the Item Tracking domain is turned off.', Comment = 'is-IS=direction hefur gildi sem þessi tegund styður ekki, gildi inniheldur síunarstafi eða er of langt, eða slökkt er á rakningarsviðinu.';
        InvalidFixLbl: Label 'Send direction usageToOrigin or originToUsage and plain values, or turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Sendu direction usageToOrigin eða originToUsage og venjuleg gildi, eða kveiktu á sviðinu á síðunni Uppsetning birgða.';
        FormatWhenLbl: Label 'A key is an object or an array instead of a string.', Comment = 'is-IS=Lykill er hlutur eða fylki í stað strengs.';
        FormatFixLbl: Label 'Send lotNo, serialNo, itemNo, variantCode and direction as strings.', Comment = 'is-IS=Sendu lotNo, serialNo, itemNo, variantCode og direction sem strengi.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are lotNo, serialNo, itemNo, variantCode and direction.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru lotNo, serialNo, itemNo, variantCode og direction.';
        NotFoundWhenLbl: Label 'No item ledger entry has the lot or serial number.', Comment = 'is-IS=Engin birgðafærsla hefur lotu- eða raðnúmerið.';
        NotFoundFixLbl: Label 'Check the number, and itemNo and variantCode if you sent them.', Comment = 'is-IS=Athugaðu númerið, og itemNo og variantCode ef þú sendir þau.';
        LimitWhenLbl: Label 'The trace has more nodes than one call returns.', Comment = 'is-IS=Rakningin hefur fleiri hnúta en eitt kall skilar.';
        LimitFixLbl: Label 'Send itemNo, variantCode or a single lotNo or serialNo to narrow the trace.', Comment = 'is-IS=Sendu itemNo, variantCode eða eitt lotNo eða serialNo til að þrengja rakninguna.';
        PermissionWhenLbl: Label 'The caller cannot read item ledger entries.', Comment = 'is-IS=Kallandinn getur ekki lesið birgðafærslur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, LimitWhenLbl, LimitFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native item tracing error text.', 'Business Central fails while it builds the trace; the answer carries its text.', NativeNextStep()));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Item Tracking domain is turned on in Inventory Setup.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is changed. The trace is worked out in temporary records for the call and returned.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('preconditions', Preconditions);
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TrackingGetLbl: Label 'Read the lot and serial tracking of one item or document line instead of a trace through the ledger.', Comment = 'is-IS=Lestu lotu- og raðnúmerarakningu einnar vöru eða skjalalínu í stað rakningar í gegnum birgðafærslur.';
        TrackingAvailLbl: Label 'See how much of a lot or serial number is available.', Comment = 'is-IS=Sjáðu hversu mikið er tiltækt af lotu eða raðnúmeri.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', TrackingGetLbl));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', TrackingAvailLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Trace a lot from where it came from to where it was used', Comment = 'is-IS=Rekja lotu frá uppruna til notkunar';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"type":"Inventory.ItemTracing.Get","data":{"lotNo":"LOT0001","direction":"originToUsage"}}',
            '{"status":"Success","direction":"originToUsage","nodeCount":2,"nodes":[{"level":0,"entryNo":101,"parentEntryNo":0,"entryType":"Purchase","documentNo":"107001","postingDate":"2026-10-20","itemNo":"1000","variantCode":"","lotNo":"LOT0001","serialNo":"","locationCode":"BLUE","quantity":10,"remainingQuantity":7,"open":true},{"level":1,"entryNo":105,"parentEntryNo":101,"entryType":"Sale","documentNo":"102001","postingDate":"2026-10-25","itemNo":"1000","variantCode":"","lotNo":"LOT0001","serialNo":"","locationCode":"BLUE","quantity":-3,"remainingQuantity":0,"open":false}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Traces a lot or serial number through the item ledger, as the Item Tracing page does: from where it came into stock to where it was used, or from where it was used back to where it came from. Each node names the document, entry type, quantity and location. This call does not change any data.', Comment = 'is-IS=Rekur lotu- eða raðnúmer í gegnum birgðafærslur, eins og síðan Vörurakning gerir: frá því að það kom á lager þangað til það var notað, eða frá notkun aftur til uppruna. Hver hnútur tilgreinir fylgiskjal, færslutegund, magn og staðsetningu. Þetta kall breytir engum gögnum.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Send lotNo, serialNo or both; itemNo and variantCode narrow the trace. The values are exact: filter characters such as * ? | & < > = @ ( ) and .. are refused. direction originToUsage (default) follows the number from where it came into stock to where it was used; usageToOrigin follows it back from where it was used. nodes is the trace tree in tree order: level 0 is a ledger entry that carries your number, deeper levels are the entries it led to (or came from), and parentEntryNo names the parent. Item-tracked components of assembly and production are followed. A trace with more than 1000 nodes answers LimitExceeded; narrow it with itemNo or variantCode. A number that no entry carries answers RecordNotFound. The call only reads; the Item Tracking domain must be turned on in Inventory Setup.', Comment = 'is-IS=Sendu lotNo, serialNo eða bæði; itemNo og variantCode þrengja rakninguna. Gildin eru nákvæm: síunarstafir eins og * ? | & < > = @ ( ) og .. eru ekki leyfðir. direction originToUsage (sjálfgefið) rekur númerið frá því að það kom á lager þangað til það var notað; usageToOrigin rekur það aftur frá notkun. nodes er rakningartréð í trjáröð: level 0 er birgðafærsla sem ber númerið þitt, dýpri stig eru færslurnar sem það leiddi til (eða kom frá), og parentEntryNo nefnir foreldrið. Rakningarskyldir íhlutir samsetningar og framleiðslu eru raktir. Rakning með fleiri en 1000 hnúta svarar LimitExceeded; þrengdu hana með itemNo eða variantCode. Númer sem engin færsla ber svarar RecordNotFound. Kallið les aðeins; rakningarsviðið þarf að vera kveikt í birgðauppsetningu.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Nodes: JsonArray;
        Backward: Boolean;
        TooMany: Boolean;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false) then begin
            EnsureRecoveryGuidance(Argument, PermissionNextStep());
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ValidateRequest(Argument, RequestJson, Backward) then
            exit;
        if not TryTrace(RequestJson, Backward, Nodes, TooMany) then begin
            Argument.RespondWithLastError();
            EnsureRecoveryGuidance(Argument, NativeNextStep());
            exit;
        end;
        if TooMany then begin
            RespondLimit(Argument);
            exit;
        end;
        if Nodes.Count() = 0 then begin
            RespondNotFound(Argument, RequestJson);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        if Backward then
            ResponseJson.Add('direction', 'usageToOrigin')
        else
            ResponseJson.Add('direction', 'originToUsage');
        ResponseJson.Add('nodeCount', Nodes.Count());
        ResponseJson.Add('nodes', Nodes);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure EnsureRecoveryGuidance(var Argument: Record "Message Argument ori"; NextStep: Text)
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Response := Argument.GetResponseJson();
        if Response.Get('nextStep', Token) then
            if not Token.AsValue().IsNull() then
                if Token.AsValue().AsText() <> '' then
                    exit;
        if Response.Contains('nextStep') then
            Response.Replace('nextStep', NextStep)
        else
            Response.Add('nextStep', NextStep);
        Argument.SetResponseJson(Response);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set (extended by Inventory read permissions) and a Business Central permission set that can read item ledger entries.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið birgðafærslur.';
    begin
        exit(PermissionNextStepLbl);
    end;

    local procedure NativeNextStep(): Text
    var
        NativeNextStepLbl: Label 'Read the error text and check the lot or serial number on the Item Tracing page. Ask an administrator to resolve the Business Central error before retrying.', Comment = 'is-IS=Lestu villutextann og athugaðu lotu- eða raðnúmerið á síðunni Vörurakning. Biddu kerfisstjóra að leysa villuna í Business Central áður en þú reynir aftur.';
    begin
        exit(NativeNextStepLbl);
    end;

    local procedure MaxNodes(): Integer
    begin
        exit(1000);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Backward: Boolean): Boolean
    var
        KeyName: Text;
        Direction: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are lotNo, serialNo, itemNo, variantCode and direction.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru lotNo, serialNo, itemNo, variantCode og direction.';
        FormatErr: Label '%1 must be a string value.', Comment = '%1 = key name, is-IS=%1 verður að vera strengjagildi.';
        FormatNextStepLbl: Label 'Send %1 as a JSON string.', Comment = '%1 = key name, is-IS=Sendu %1 sem JSON-streng.';
        MissingErr: Label 'lotNo or serialNo is required.', Comment = 'is-IS=lotNo eða serialNo er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send lotNo, serialNo or both.', Comment = 'is-IS=Sendu lotNo, serialNo eða bæði.';
        DirectionErr: Label 'direction is not supported.', Comment = 'is-IS=direction er ekki stutt.';
        DirectionNextStepLbl: Label 'Send direction usageToOrigin or originToUsage, or leave it out for originToUsage.', Comment = 'is-IS=Sendu direction usageToOrigin eða originToUsage, eða slepptu því fyrir originToUsage.';
    begin
        foreach KeyName in RequestJson.Keys() do begin
            if not (KeyName in ['lotNo', 'serialNo', 'itemNo', 'variantCode', 'direction']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
            if not IsValueToken(RequestJson, KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, '', '', StrSubstNo(FormatNextStepLbl, KeyName));
                exit(false);
            end;
        end;
        if (ReadText(RequestJson, 'lotNo') = '') and (ReadText(RequestJson, 'serialNo') = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'lotNo', '', 'lotNo, serialNo', MissingNextStepLbl);
            exit(false);
        end;
        if not ValidateValue(Argument, RequestJson, 'lotNo', 50) then
            exit(false);
        if not ValidateValue(Argument, RequestJson, 'serialNo', 50) then
            exit(false);
        if not ValidateValue(Argument, RequestJson, 'itemNo', 20) then
            exit(false);
        if not ValidateValue(Argument, RequestJson, 'variantCode', 10) then
            exit(false);
        Direction := UpperCase(ReadText(RequestJson, 'direction'));
        if not (Direction in ['', 'ORIGINTOUSAGE', 'USAGETOORIGIN']) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DirectionErr, 'direction', ReadText(RequestJson, 'direction'), DirectionsTok, DirectionNextStepLbl);
            exit(false);
        end;
        Backward := Direction = 'USAGETOORIGIN';
        exit(true);
    end;

    local procedure ValidateValue(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer): Boolean
    var
        Value: Text;
        FilterChar: Text;
        LengthErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key name, %2 = maximum length, is-IS=%1 er lengra en %2 stafir.';
        FilterErr: Label '%1 contains filter characters.', Comment = '%1 = key name, is-IS=%1 inniheldur síunarstafi.';
        ValueNextStepLbl: Label 'Send the exact value, without * ? | & < > = @ ( ) or ..', Comment = 'is-IS=Sendu nákvæmt gildi, án * ? | & < > = @ ( ) eða ..';
    begin
        Value := ReadText(RequestJson, KeyName);
        if Value = '' then
            exit(true);
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(LengthErr, KeyName, MaxLength), KeyName, CopyStr(Value, 1, 250), '', ValueNextStepLbl);
            exit(false);
        end;
        foreach FilterChar in FilterCharacters() do
            if StrPos(Value, FilterChar) > 0 then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(FilterErr, KeyName), KeyName, CopyStr(Value, 1, 250), '', ValueNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure FilterCharacters() Characters: List of [Text]
    begin
        Characters.Add('*');
        Characters.Add('?');
        Characters.Add('|');
        Characters.Add('&');
        Characters.Add('<');
        Characters.Add('>');
        Characters.Add('=');
        Characters.Add('@');
        Characters.Add('(');
        Characters.Add(')');
        Characters.Add('..');
        Characters.Add('''');
    end;

    [TryFunction]
    local procedure TryTrace(RequestJson: JsonObject; Backward: Boolean; var Nodes: JsonArray; var TooMany: Boolean)
    var
        TempTrack: Record "Item Tracing Buffer" temporary;
        TempTrack2: Record "Item Tracing Buffer" temporary;
        ItemTracingMgt: Codeunit "Item Tracing Mgt.";
        ShowComponents: Option "No","Item-tracked only","All";
        TraceDirection: Option Forward,Backward;
        Count: Integer;
    begin
        if Backward then
            TraceDirection := TraceDirection::Backward
        else
            TraceDirection := TraceDirection::Forward;
        ItemTracingMgt.FindRecords(TempTrack, TempTrack2, ReadText(RequestJson, 'serialNo'), ReadText(RequestJson, 'lotNo'), '', ReadText(RequestJson, 'itemNo'), ReadText(RequestJson, 'variantCode'), TraceDirection, ShowComponents::"Item-tracked only");
        ItemTracingMgt.ExpandAll(TempTrack, TempTrack2);
        TempTrack.Reset();
        Count := TempTrack.Count();
        if Count > MaxNodes() then begin
            TooMany := true;
            exit;
        end;
        if TempTrack.FindSet() then
            repeat
                Nodes.Add(NodeToJson(TempTrack));
            until TempTrack.Next() = 0;
    end;

    local procedure NodeToJson(TempTrack: Record "Item Tracing Buffer" temporary) Node: JsonObject
    var
        EntryTypeNames: List of [Text];
        EntryTypeOrdinals: List of [Integer];
        EntryTypeName: Text;
        Index: Integer;
    begin
        EntryTypeNames := TempTrack."Entry Type".Names();
        EntryTypeOrdinals := TempTrack."Entry Type".Ordinals();
        Index := EntryTypeOrdinals.IndexOf(TempTrack."Entry Type".AsInteger());
        if Index > 0 then
            EntryTypeName := EntryTypeNames.Get(Index);
        Node.Add('level', TempTrack.Level);
        Node.Add('entryNo', TempTrack."Item Ledger Entry No.");
        Node.Add('parentEntryNo', TempTrack."Parent Item Ledger Entry No.");
        Node.Add('entryType', EntryTypeName);
        Node.Add('documentNo', TempTrack."Document No.");
        Node.Add('postingDate', Format(TempTrack."Posting Date", 0, 9));
        Node.Add('itemNo', TempTrack."Item No.");
        Node.Add('variantCode', TempTrack."Variant Code");
        Node.Add('lotNo', TempTrack."Lot No.");
        Node.Add('serialNo', TempTrack."Serial No.");
        Node.Add('locationCode', TempTrack."Location Code");
        Node.Add('quantity', TempTrack.Quantity);
        Node.Add('remainingQuantity', TempTrack."Remaining Quantity");
        Node.Add('open', TempTrack.Open);
    end;

    local procedure RespondLimit(var Argument: Record "Message Argument ori")
    var
        LimitErr: Label 'The trace has more than %1 nodes.', Comment = '%1 = node cap, is-IS=Rakningin hefur fleiri en %1 hnúta.';
        LimitNextStepLbl: Label 'Send itemNo, variantCode or a single lotNo or serialNo to narrow the trace.', Comment = 'is-IS=Sendu itemNo, variantCode eða eitt lotNo eða serialNo til að þrengja rakninguna.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::LimitExceeded, StrSubstNo(LimitErr, MaxNodes()), '', '', Format(MaxNodes()), LimitNextStepLbl);
    end;

    local procedure RespondNotFound(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        NotFoundErr: Label 'No item ledger entry has this lot or serial number.', Comment = 'is-IS=Engin birgðafærsla hefur þetta lotu- eða raðnúmer.';
        NotFoundNextStepLbl: Label 'Check the number, and itemNo and variantCode if you sent them.', Comment = 'is-IS=Athugaðu númerið, og itemNo og variantCode ef þú sendir þau.';
        KeyName: Text;
    begin
        if ReadText(RequestJson, 'lotNo') <> '' then
            KeyName := 'lotNo'
        else
            KeyName := 'serialNo';
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, KeyName, ReadText(RequestJson, KeyName), '', NotFoundNextStepLbl);
    end;

    local procedure IsValueToken(RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        exit(Token.IsValue());
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
