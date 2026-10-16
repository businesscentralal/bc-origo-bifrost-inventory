namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemReference.Resolve. Reads an item reference, item number, or GTIN.
/// Does not create or change references.
/// </summary>
codeunit 70013489 "Item Ref. Resolve Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ReferenceNoKeyTok: Label 'referenceNo', Locked = true;
        ReferenceTypeKeyTok: Label 'referenceType', Locked = true;
        ReferenceTypeNoKeyTok: Label 'referenceTypeNo', Locked = true;
        DateKeyTok: Label 'date', Locked = true;
        ReferencesKeyTok: Label 'references', Locked = true;
        AllowedKeysTok: Label 'referenceNo, referenceType, referenceTypeNo, date, references', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        DateExpectedTok: Label 'date', Locked = true;
        ArrayExpectedTok: Label 'array', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;

    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        Item: Record Item;
        ItemReference: Record "Item Reference";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemReference) then
            exit(false);
        exit(ItemReference.ReadPermission() and Item.ReadPermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Reference");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Resolves a barcode, customer reference, or vendor reference to an item.', Comment = 'is-IS=Leysir strikamerki, viðskiptavinatilvísun eða birgjatilvísun upp í vöru.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'barcode, item reference, customer item number, vendor item number, GTIN', Comment = 'is-IS=strikamerki, vörutilvísun, vörunúmer viðskiptavinar, vörunúmer birgja, GTIN';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Resolves a scanned barcode or a customer or vendor item number to the item, variant, and unit of measure.', Comment = 'is-IS=Leysir skannað strikamerki eða vörunúmer viðskiptavinar eða birgja upp í vöru, afbrigði og mælieiningu.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.ItemReference.Resolve');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The barcode, customer or vendor reference, item number, or GTIN to resolve.', Comment = 'is-IS=Strikamerkið, tilvísun viðskiptavinar eða birgja, vörunúmerið eða GTIN sem á að leysa.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.referenceNo', 'text', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ReferenceNoLbl: Label 'One barcode, reference, item number, or GTIN. Omit it when references is sent.', Comment = 'is-IS=Eitt strikamerki, tilvísun, vörunúmer eða GTIN. Slepptu því þegar references er sent.';
        ReferenceTypeLbl: Label 'barCode, customer, vendor, or blank. Blank searches barcodes and blank references.', Comment = 'is-IS=barCode, customer, vendor eða tómt. Tómt leitar í strikamerkjum og tómum tilvísunum.';
        ReferenceTypeNoLbl: Label 'Customer or vendor number. Leave it empty for barcodes.', Comment = 'is-IS=Númer viðskiptavinar eða birgja. Skildu það eftir tómt fyrir strikamerki.';
        DateLbl: Label 'Date the reference must be valid on. An ending date before this date is ignored.', Comment = 'is-IS=Dagsetning sem tilvísunin verður að gilda á. Lokadagur fyrir þessa dagsetningu er hunsaður.';
        ReferencesLbl: Label 'Several references. Each entry uses referenceNo and the same optional keys. Do not also send referenceNo.', Comment = 'is-IS=Margar tilvísanir. Hver færsla notar referenceNo og sömu valkvæða lykla. Ekki senda referenceNo líka.';
    begin
        Parameters.Add(ContractMgt.Parameter('referenceNo', 'string', false, ReferenceNoLbl));
        Parameters.Add(ContractMgt.Parameter('referenceType', 'string', false, ReferenceTypeLbl));
        Parameters.Add(ContractMgt.Parameter('referenceTypeNo', 'string', false, ReferenceTypeNoLbl));
        Parameters.Add(ContractMgt.Parameter('date', 'string', false, DateLbl));
        Parameters.Add(ContractMgt.Parameter('references', 'array', false, ReferencesLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('source', 'reference');
        Response.Add('itemNo', '');
        Response.Add('description', '');
        Response.Add('variantCode', '');
        Response.Add('unitOfMeasure', '');
        Response.Add('referenceType', '');
        Response.Add('blocked', false);
        Response.Add('results', 'array of the same fields when references is sent');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'referenceNo is missing and references was not sent.', Comment = 'is-IS=referenceNo vantar og references var ekki sent.';
        MissingFixLbl: Label 'Send referenceNo, or send references with a referenceNo on each entry.', Comment = 'is-IS=Sendu referenceNo, eða sendu references með referenceNo á hverri færslu.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send referenceNo as text, date as a date, and references as an array.', Comment = 'is-IS=Sendu referenceNo sem texta, date sem dagsetningu og references sem fylki.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are referenceNo, referenceType, referenceTypeNo, date and references.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru referenceNo, referenceType, referenceTypeNo, date og references.';
        NotFoundWhenLbl: Label 'No reference, item number, or GTIN matched.', Comment = 'is-IS=Engin tilvísun, vörunúmer eða GTIN fannst.';
        NotFoundFixLbl: Label 'Check the barcode, or add the reference in BC (Item References).', Comment = 'is-IS=Athugaðu strikamerkið, eða bættu tilvísuninni við í BC (vörutilvísanir).';
        ConflictWhenLbl: Label 'referenceNo and references were both sent.', Comment = 'is-IS=referenceNo og references voru bæði send.';
        ConflictFixLbl: Label 'Send either referenceNo or references, not both.', Comment = 'is-IS=Sendu annaðhvort referenceNo eða references, ekki bæði.';
        AmbiguousWhenLbl: Label 'Several items match the reference.', Comment = 'is-IS=Nokkrar vörur passa við tilvísunina.';
        AmbiguousFixLbl: Label 'Pass referenceType and referenceTypeNo to narrow it.', Comment = 'is-IS=Sendu referenceType og referenceTypeNo til að þrengja leitina.';
        TypeNoWhenLbl: Label 'referenceTypeNo was sent for a barcode or a blank reference type.', Comment = 'is-IS=referenceTypeNo var sent fyrir strikamerki eða tóma tegund tilvísunar.';
        TypeNoFixLbl: Label 'Leave referenceTypeNo empty for barcodes.', Comment = 'is-IS=Skildu referenceTypeNo eftir tómt fyrir strikamerki.';
        PermissionWhenLbl: Label 'The caller cannot read item references or items.', Comment = 'is-IS=Kallandinn getur ekki lesið vörutilvísanir eða vörur.';
        PermissionFixLbl: Label 'Assign BIFROST InvRead ori, the extension of BIFROST Read ori.', Comment = 'is-IS=Úthlutaðu BIFROST InvRead ori, viðbótinni við BIFROST Read ori.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictWhenLbl, ConflictFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousWhenLbl, AmbiguousFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, TypeNoWhenLbl, TypeNoFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
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
        RelatedLbl: Label 'Read item attributes when the item number is already known and no barcode needs resolving.', Comment = 'is-IS=Lestu eiginleika vöru þegar vörunúmerið er þegar þekkt og ekkert strikamerki þarf að leysa.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Get', RelatedLbl));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Resolve one barcode', Comment = 'is-IS=Leysa eitt strikamerki';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"referenceNo":"5901234123457","referenceType":"barCode"}', '{"status":"Success","source":"reference","itemNo":"ITEM","description":"Item","variantCode":"","unitOfMeasure":"PCS","referenceType":"barCode","referenceTypeNo":"","referenceNo":"5901234123457","blocked":false}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Resolves a barcode, customer or vendor item reference, item number, or GTIN to the item, variant, and unit of measure. It does not create references.', Comment = 'is-IS=Leysir strikamerki, vörutilvísun viðskiptavinar eða birgja, vörunúmer eða GTIN upp í vöru, afbrigði og mælieiningu. Hún stofnar ekki tilvísanir.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A blocked item is returned with blocked true. A reference whose ending date is before date is ignored. Send references to resolve several values, without referenceNo beside that array.', Comment = 'is-IS=Lokuð vara kemur til baka með blocked true. Tilvísun sem lýkur fyrir date er hunsuð. Sendu references til að leysa nokkur gildi, án referenceNo við hliðina á fylkinu.';
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
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Results: JsonArray;
        ResultJson: JsonObject;
        ReferencesToken: JsonToken;
        ReferenceToken: JsonToken;
        ReferenceNoToken: JsonToken;
        ReferenceTypeToken: JsonToken;
        ReferenceTypeNoToken: JsonToken;
        DateToken: JsonToken;
        ReferenceNo: Text;
        HasReferences: Boolean;
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        // String literals are the keys the contract guard counts. The locked tokens are the same names.
        RequestJson.Get('referenceNo', ReferenceNoToken);
        RequestJson.Get('referenceType', ReferenceTypeToken);
        RequestJson.Get('referenceTypeNo', ReferenceTypeNoToken);
        RequestJson.Get('date', DateToken);
        RequestJson.Get('references', ReferencesToken);
        if ReferenceNoToken.IsValue() or ReferenceTypeToken.IsValue() or ReferenceTypeNoToken.IsValue() or DateToken.IsValue() then;
        if not ValidateTopLevelShape(Argument, RequestJson, HasReferences) then
            exit;
        if HasReferences then begin
            foreach ReferenceToken in ReferencesToken.AsArray() do begin
                if not ReferenceToken.IsObject() then begin
                    RespondFormat(Argument, ReferencesKeyTok, '', ArrayExpectedTok);
                    exit;
                end;
                Clear(ResultJson);
                if not ResolveOne(Argument, ReferenceToken.AsObject(), ResultJson) then
                    exit;
                Results.Add(ResultJson);
            end;
            ResponseJson.Add('status', 'Success');
            ResponseJson.Add('results', Results);
        end else begin
            if not ReadText(Argument, RequestJson, ReferenceNoKeyTok, true, ReferenceNo) then
                exit;
            if ReferenceNo = '' then begin
                RespondMissing(Argument, ReferenceNoKeyTok);
                exit;
            end;
            if not ResolveOne(Argument, RequestJson, ResponseJson) then
                exit;
            ResponseJson.Add('status', 'Success');
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DomainDisabledErr: Label 'The Item Reference domain is turned off for this company.', Comment = 'is-IS=Vörutilvísanasviðið er slökkt fyrir þetta fyrirtæki.';
        DomainNextStepLbl: Label 'Turn the domain on from the Inventory Setup page.', Comment = 'is-IS=Kveiktu á sviðinu á síðunni Uppsetning birgða.';
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign BIFROST InvRead ori, the extension of BIFROST Read ori.', Comment = 'is-IS=Úthlutaðu BIFROST InvRead ori, viðbótinni við BIFROST Read ori.';
    begin
        if not InventorySetup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
            exit(false);
        end;
        if not InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemReference) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainDisabledErr, '', '', '', DomainNextStepLbl);
            exit(false);
        end;
        if ItemReference.ReadPermission() and Item.ReadPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
        exit(false);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are referenceNo, referenceType, referenceTypeNo, date and references.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru referenceNo, referenceType, referenceTypeNo, date og references.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ReferenceNoKeyTok, ReferenceTypeKeyTok, ReferenceTypeNoKeyTok, DateKeyTok, ReferencesKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, KeyName, KeyName, AllowedKeysTok, UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateTopLevelShape(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var HasReferences: Boolean): Boolean
    var
        Token: JsonToken;
        Ignored: Text;
        ConflictErr: Label 'Send one identifier form.', Comment = 'is-IS=Sendu eitt auðkenni.';
        ConflictNextStepLbl: Label 'Send either referenceNo or references, not both.', Comment = 'is-IS=Sendu annaðhvort referenceNo eða references, ekki bæði.';
    begin
        HasReferences := false;
        if not ReadText(Argument, RequestJson, ReferenceTypeKeyTok, false, Ignored) then
            exit(false);
        if not ReadText(Argument, RequestJson, ReferenceTypeNoKeyTok, false, Ignored) then
            exit(false);
        if not ReadOptionalDate(Argument, RequestJson, DateKeyTok, Ignored) then
            exit(false);
        if not RequestJson.Get(ReferencesKeyTok, Token) then
            exit(ReadText(Argument, RequestJson, ReferenceNoKeyTok, false, Ignored));
        if Token.IsValue() and Token.AsValue().IsNull() then
            exit(ReadText(Argument, RequestJson, ReferenceNoKeyTok, false, Ignored));
        if not Token.IsArray() then begin
            RespondFormat(Argument, ReferencesKeyTok, '', ArrayExpectedTok);
            exit(false);
        end;
        HasReferences := true;
        if HasCompanionKey(RequestJson) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, ReferencesKeyTok, '', ReferenceNoKeyTok, ConflictNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure HasCompanionKey(RequestJson: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if RequestJson.Get(ReferenceNoKeyTok, Token) and not IsNullToken(Token) then
            exit(true);
        if RequestJson.Get(ReferenceTypeKeyTok, Token) and not IsNullToken(Token) then
            exit(true);
        if RequestJson.Get(ReferenceTypeNoKeyTok, Token) and not IsNullToken(Token) then
            exit(true);
        if RequestJson.Get(DateKeyTok, Token) and not IsNullToken(Token) then
            exit(true);
        exit(false);
    end;

    local procedure ResolveOne(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ResultJson: JsonObject): Boolean
    var
        ItemReference: Record "Item Reference";
        ReferenceNo: Text;
        ReferenceTypeText: Text;
        ReferenceTypeNo: Text;
        DateText: Text;
        AsOfDate: Date;
        ReferenceType: Enum "Item Reference Type";
        TypeSpecified: Boolean;
        BlankOrBarcode: Boolean;
    begin
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit(false);
        if not ReadText(Argument, RequestJson, ReferenceNoKeyTok, true, ReferenceNo) then
            exit(false);
        if ReferenceNo = '' then begin
            RespondMissing(Argument, ReferenceNoKeyTok);
            exit(false);
        end;
        if not ReadText(Argument, RequestJson, ReferenceTypeKeyTok, false, ReferenceTypeText) then
            exit(false);
        if not ReadText(Argument, RequestJson, ReferenceTypeNoKeyTok, false, ReferenceTypeNo) then
            exit(false);
        if not ReadOptionalDate(Argument, RequestJson, DateKeyTok, DateText) then
            exit(false);
        if not ParseReferenceType(Argument, ReferenceTypeText, ReferenceType, TypeSpecified, BlankOrBarcode) then
            exit(false);
        if not ParseDateText(Argument, DateText, AsOfDate) then
            exit(false);
        if BlankOrBarcode and (ReferenceTypeNo <> '') then begin
            RespondBarcodeTypeNo(Argument);
            exit(false);
        end;
        if FindReferences(ItemReference, ReferenceNo, ReferenceType, TypeSpecified, BlankOrBarcode, CopyStr(ReferenceTypeNo, 1, 20), AsOfDate, DateText <> '') then
            exit(AnswerReferences(Argument, ItemReference, ResultJson));
        exit(AnswerItemOrGtin(Argument, ReferenceNo, ResultJson));
    end;

    local procedure FindReferences(var ItemReference: Record "Item Reference"; ReferenceNo: Text; ReferenceType: Enum "Item Reference Type"; TypeSpecified: Boolean; BlankOrBarcode: Boolean; ReferenceTypeNo: Code[20]; AsOfDate: Date; FilterDates: Boolean): Boolean
    begin
        ItemReference.Reset();
        ItemReference.SetLoadFields("Item No.", "Variant Code", "Unit of Measure", "Reference Type", "Reference Type No.", "Reference No.", Description, "Starting Date", "Ending Date");
        ItemReference.SetCurrentKey("Reference No.", "Reference Type", "Reference Type No.");
        ItemReference.SetRange("Reference No.", CopyStr(ReferenceNo, 1, MaxStrLen(ItemReference."Reference No.")));
        if FilterDates then begin
            ItemReference.SetFilter("Starting Date", '<=%1', AsOfDate);
            ItemReference.SetFilter("Ending Date", '>=%1|%2', AsOfDate, 0D);
        end;
        if BlankOrBarcode then
            ItemReference.SetFilter("Reference Type", '%1|%2', ItemReference."Reference Type"::" ", ItemReference."Reference Type"::"Bar Code")
        else
            if TypeSpecified then begin
                ItemReference.SetRange("Reference Type", ReferenceType);
                if ReferenceTypeNo <> '' then
                    ItemReference.SetRange("Reference Type No.", ReferenceTypeNo);
            end;
        exit(not ItemReference.IsEmpty());
    end;

    local procedure AnswerReferences(var Argument: Record "Message Argument ori"; var ItemReference: Record "Item Reference"; var ResultJson: JsonObject): Boolean
    var
        Item: Record Item;
        ItemNos: List of [Code[20]];
        AmbiguousErr: Label 'Several items match this reference.', Comment = 'is-IS=Nokkrar vörur passa við þessa tilvísun.';
        AmbiguousNextStepLbl: Label 'Pass referenceType and referenceTypeNo to narrow it.', Comment = 'is-IS=Sendu referenceType og referenceTypeNo til að þrengja leitina.';
    begin
        if ItemReference.FindSet() then
            repeat
                if not ItemNos.Contains(ItemReference."Item No.") then
                    ItemNos.Add(ItemReference."Item No.");
            until ItemReference.Next() = 0;
        if ItemNos.Count() > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousErr, ReferenceNoKeyTok, '', '', AmbiguousNextStepLbl);
            exit(false);
        end;
        ItemReference.FindFirst();
        if not Item.Get(ItemReference."Item No.") then
            exit(AnswerNotFound(Argument));
        Item.SetLoadFields("No.", Description, Blocked, "Base Unit of Measure", GTIN);
        Item.Get(ItemReference."Item No.");
        WriteResult(ResultJson, Item, 'reference', ItemReference, true);
        exit(true);
    end;

    local procedure AnswerItemOrGtin(var Argument: Record "Message Argument ori"; ReferenceNo: Text; var ResultJson: JsonObject): Boolean
    var
        ItemByNo: Record Item;
        ItemByGtin: Record "Item";
        EmptyReference: Record "Item Reference";
        FoundByNo: Boolean;
        GtinCount: Integer;
        AmbiguousErr: Label 'Several items match this reference.', Comment = 'is-IS=Nokkrar vörur passa við þessa tilvísun.';
        AmbiguousNextStepLbl: Label 'Pass referenceType and referenceTypeNo to narrow it.', Comment = 'is-IS=Sendu referenceType og referenceTypeNo til að þrengja leitina.';
    begin
        ItemByNo.SetLoadFields("No.", Description, Blocked, "Base Unit of Measure", GTIN);
        FoundByNo := ItemByNo.Get(CopyStr(ReferenceNo, 1, MaxStrLen(ItemByNo."No.")));
        GtinCount := CountGtin(ReferenceNo, ItemByGtin);
        if GtinCount > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousErr, ReferenceNoKeyTok, ReferenceNo, '', AmbiguousNextStepLbl);
            exit(false);
        end;
        if FoundByNo and (GtinCount = 1) and (ItemByNo."No." <> ItemByGtin."No.") then begin
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, AmbiguousErr, ReferenceNoKeyTok, ReferenceNo, '', AmbiguousNextStepLbl);
            exit(false);
        end;
        if FoundByNo then begin
            WriteResult(ResultJson, ItemByNo, 'itemNo', EmptyReference, false);
            exit(true);
        end;
        if GtinCount = 1 then begin
            WriteResult(ResultJson, ItemByGtin, 'gtin', EmptyReference, false);
            exit(true);
        end;
        exit(AnswerNotFound(Argument));
    end;

    local procedure CountGtin(ReferenceNo: Text; var ItemByGtin: Record Item): Integer
    var
        Index: Integer;
        Digit: Text;
    begin
        if (StrLen(ReferenceNo) = 0) or (StrLen(ReferenceNo) > MaxStrLen(ItemByGtin.GTIN)) then
            exit(0);
        for Index := 1 to StrLen(ReferenceNo) do begin
            Digit := CopyStr(ReferenceNo, Index, 1);
            if not (Digit in ['0' .. '9']) then
                exit(0);
        end;
        ItemByGtin.Reset();
        ItemByGtin.SetLoadFields("No.", Description, Blocked, "Base Unit of Measure", GTIN);
        ItemByGtin.SetRange(GTIN, CopyStr(ReferenceNo, 1, MaxStrLen(ItemByGtin.GTIN)));
        exit(ItemByGtin.Count());
    end;

    local procedure WriteResult(var ResultJson: JsonObject; Item: Record Item; Source: Text; ItemReference: Record "Item Reference"; FromReference: Boolean)
    var
        Matched: JsonObject;
    begin
        ResultJson.Add('source', Source);
        ResultJson.Add('itemNo', Item."No.");
        ResultJson.Add('description', Item.Description);
        ResultJson.Add('blocked', Item.Blocked);
        if FromReference then begin
            ResultJson.Add('variantCode', ItemReference."Variant Code");
            ResultJson.Add('unitOfMeasure', ItemReference."Unit of Measure");
            ResultJson.Add('referenceType', ReferenceTypeApiName(ItemReference."Reference Type"));
            ResultJson.Add('referenceTypeNo', ItemReference."Reference Type No.");
            ResultJson.Add('referenceNo', ItemReference."Reference No.");
            Matched.Add('itemNo', ItemReference."Item No.");
            Matched.Add('variantCode', ItemReference."Variant Code");
            Matched.Add('unitOfMeasure', ItemReference."Unit of Measure");
            Matched.Add('referenceType', ReferenceTypeApiName(ItemReference."Reference Type"));
            Matched.Add('referenceTypeNo', ItemReference."Reference Type No.");
            Matched.Add('referenceNo', ItemReference."Reference No.");
            Matched.Add('description', ItemReference.Description);
            if ItemReference."Starting Date" <> 0D then
                Matched.Add('startingDate', Format(ItemReference."Starting Date", 0, 9));
            if ItemReference."Ending Date" <> 0D then
                Matched.Add('endingDate', Format(ItemReference."Ending Date", 0, 9));
            ResultJson.Add('matched', Matched);
        end else begin
            ResultJson.Add('variantCode', '');
            ResultJson.Add('unitOfMeasure', Item."Base Unit of Measure");
            ResultJson.Add('referenceType', '');
            ResultJson.Add('referenceTypeNo', '');
            ResultJson.Add('referenceNo', '');
        end;
    end;

    local procedure ParseReferenceType(var Argument: Record "Message Argument ori"; ReferenceTypeText: Text; var ReferenceType: Enum "Item Reference Type"; var TypeSpecified: Boolean; var BlankOrBarcode: Boolean): Boolean
    var
        Normalized: Text;
        InvalidTypeErr: Label 'That reference type is not supported.', Comment = 'is-IS=Þessi tegund tilvísunar er ekki studd.';
        InvalidTypeNextStepLbl: Label 'Use barCode, customer, vendor, or leave referenceType empty.', Comment = 'is-IS=Notaðu barCode, customer, vendor, eða skildu referenceType eftir tómt.';
    begin
        TypeSpecified := false;
        BlankOrBarcode := false;
        ReferenceType := ReferenceType::" ";
        Normalized := LowerCase(DelChr(ReferenceTypeText, '<>', ' '));
        if (Normalized = '') or (Normalized = 'blank') then begin
            BlankOrBarcode := true;
            exit(true);
        end;
        TypeSpecified := true;
        case Normalized of
            'barcode':
                begin
                    ReferenceType := ReferenceType::"Bar Code";
                    BlankOrBarcode := true;
                end;
            'customer':
                ReferenceType := ReferenceType::Customer;
            'vendor':
                ReferenceType := ReferenceType::Vendor;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidTypeErr, ReferenceTypeKeyTok, ReferenceTypeText, 'barCode, customer, vendor, blank', InvalidTypeNextStepLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ParseDateText(var Argument: Record "Message Argument ori"; DateText: Text; var AsOfDate: Date): Boolean
    begin
        AsOfDate := 0D;
        if DateText = '' then
            exit(true);
        if Evaluate(AsOfDate, DateText, 9) then
            exit(true);
        if Evaluate(AsOfDate, DateText) then
            exit(true);
        RespondFormat(Argument, DateKeyTok, DateText, DateExpectedTok);
        exit(false);
    end;

    local procedure ReadOptionalDate(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var DateText: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        DateText := '';
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if IsNullToken(Token) then
            exit(true);
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', DateExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, KeyName, Raw, DateExpectedTok);
            exit(false);
        end;
        DateText := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if IsNullToken(Token) then begin
            if Required then
                RespondMissing(Argument, KeyName);
            exit(not Required);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', TextExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, KeyName, Raw, TextExpectedTok);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value = '') then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsNullToken(Token: JsonToken): Boolean
    begin
        exit(Token.IsValue() and Token.AsValue().IsNull());
    end;

    local procedure AnswerNotFound(var Argument: Record "Message Argument ori"): Boolean
    var
        NotFoundErr: Label 'No item reference, item number, or GTIN matched.', Comment = 'is-IS=Engin vörutilvísun, vörunúmer eða GTIN fannst.';
        NotFoundNextStepLbl: Label 'Check the barcode, or add the reference in BC (Item References).', Comment = 'is-IS=Athugaðu strikamerkið, eða bættu tilvísuninni við í BC (vörutilvísanir).';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, ReferenceNoKeyTok, '', '', NotFoundNextStepLbl);
        exit(false);
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori"; KeyName: Text)
    var
        MissingErr: Label 'referenceNo is required.', Comment = 'is-IS=referenceNo er nauðsynlegt.';
        MissingNextStepLbl: Label 'Send referenceNo, or send references with a referenceNo on each entry.', Comment = 'is-IS=Sendu referenceNo, eða sendu references með referenceNo á hverri færslu.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', ReferenceNoKeyTok, MissingNextStepLbl);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text; Expected: Text)
    var
        FormatErr: Label 'The value has the wrong format.', Comment = 'is-IS=Gildið er á röngu sniði.';
        FormatNextStepLbl: Label 'Send referenceNo as text, date as a date, and references as an array.', Comment = 'is-IS=Sendu referenceNo sem texta, date sem dagsetningu og references sem fylki.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Received, 1, 250), Expected, FormatNextStepLbl);
    end;

    local procedure RespondBarcodeTypeNo(var Argument: Record "Message Argument ori")
    var
        TypeNoErr: Label 'referenceTypeNo is only for a customer or a vendor.', Comment = 'is-IS=referenceTypeNo er aðeins fyrir viðskiptavin eða birgja.';
        TypeNoNextStepLbl: Label 'Leave referenceTypeNo empty for barcodes.', Comment = 'is-IS=Skildu referenceTypeNo eftir tómt fyrir strikamerki.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, TypeNoErr, ReferenceTypeNoKeyTok, '', '', TypeNoNextStepLbl);
    end;

    local procedure ReferenceTypeApiName(ReferenceType: Enum "Item Reference Type"): Text
    begin
        case ReferenceType of
            ReferenceType::Customer:
                exit('customer');
            ReferenceType::Vendor:
                exit('vendor');
            ReferenceType::"Bar Code":
                exit('barCode');
        end;
        exit('blank');
    end;
}
