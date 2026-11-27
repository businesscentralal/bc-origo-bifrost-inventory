namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemVariant.Create. Creates one new variant on an existing item.
/// Refusals are answered before the write process runs, so nothing is saved.
/// </summary>
codeunit 10076991 "Item Variant Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        CodeKeyTok: Label 'code', Locked = true;
        DescriptionKeyTok: Label 'description', Locked = true;
        Description2KeyTok: Label 'description2', Locked = true;
        BlockedKeyTok: Label 'blocked', Locked = true;
        AllowedKeysTok: Label 'itemNo, code, description, description2, blocked', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        PermissionSetTok: Label 'BIFROST InvWrite ori', Locked = true;

    /// <summary>True when the caller can read items and create item variants.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(CanWriteTables());
    end;

    /// <summary>The table this type writes.</summary>
    /// <returns>The Item Variant table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Variant");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a variant on an item.', Comment = 'is-IS=Stofnar afbrigði á vöru. (vöruafbrigði, nýtt afbrigði, afbrigðiskóði, litur, stærð).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item variant, new variant, variant code, color, size', Comment = 'is-IS=vöruafbrigði, nýtt afbrigði, afbrigðiskóði, litur, stærð';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Create a new variant, such as a color or a size, on an existing item.', Comment = 'is-IS=Stofnaðu nýtt afbrigði, til dæmis lit eða stærð, á vöru sem er til.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Envelope chapter.</summary>
    /// <param name="Envelope">Receives the envelope.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The item is named under data.itemNo and the new variant under data.code; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Target chapter.</summary>
    /// <param name="Target">Receives the target entries.</param>
    /// <returns>True.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ItemTargetLbl: Label 'The existing item that receives the new variant.', Comment = 'is-IS=Varan sem er til og fær nýja afbrigðið.';
        CodeTargetLbl: Label 'The code of the new variant. It must not exist on the item yet.', Comment = 'is-IS=Kóði nýja afbrigðisins. Hann má ekki vera til á vörunni.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', ItemTargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.code', 'text', CodeTargetLbl));
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    /// <param name="Parameters">Receives the parameter entries.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemNoLbl: Label 'Number of an existing item, at most 20 characters. Required.', Comment = 'is-IS=Númer vöru sem er til, mest 20 stafir. Skylt.';
        CodeLbl: Label 'Code of the new variant, at most 10 characters. Required. A code that already exists on the item is refused.', Comment = 'is-IS=Kóði nýja afbrigðisins, mest 10 stafir. Skylt. Kóða sem er þegar til á vörunni er hafnað.';
        DescriptionLbl: Label 'Description of the variant, at most 100 characters.', Comment = 'is-IS=Lýsing afbrigðisins, mest 100 stafir.';
        Description2Lbl: Label 'Second description line of the variant, at most 50 characters.', Comment = 'is-IS=Önnur lýsingarlína afbrigðisins, mest 50 stafir.';
        BlockedLbl: Label 'true or false. true creates the variant blocked for every transaction. Defaults to false.', Comment = 'is-IS=true eða false. true stofnar afbrigðið lokað fyrir allar færslur. Sjálfgefið er false.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('code', 'string', true, CodeLbl));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, DescriptionLbl));
        Parameters.Add(ContractMgt.Parameter('description2', 'string', false, Description2Lbl));
        Parameters.Add(ContractMgt.Parameter('blocked', 'boolean', false, BlockedLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        GetImpl: Codeunit "Item Variant Get Impl ori";
        Fields: JsonArray;
        VariantField: JsonObject;
    begin
        VariantField := ContractMgt.ResponseField('variant', 'object', 'The created variant as it was saved.');
        VariantField.Add('children', GetImpl.VariantChildren());
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', 'Always true on success: the call only creates variants.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number the variant belongs to.'));
        Fields.Add(VariantField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'itemNo or code is missing or empty.', Comment = 'is-IS=itemNo eða code vantar eða er tómt.';
        MissingFixLbl: Label 'Send the number of an existing item and the code of the new variant.', Comment = 'is-IS=Sendu númer vöru sem er til og kóða nýja afbrigðisins.';
        FormatWhenLbl: Label 'A key has the wrong JSON type.', Comment = 'is-IS=Lykill er á rangri JSON-gerð.';
        FormatFixLbl: Label 'Send itemNo, code, description and description2 as text, and blocked as true or false.', Comment = 'is-IS=Sendu itemNo, code, description og description2 sem texta, og blocked sem true eða false.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        NotFoundWhenLbl: Label 'No item matched itemNo.', Comment = 'is-IS=Engin vara passaði við itemNo.';
        TooLongWhenLbl: Label 'A text is longer than its field.', Comment = 'is-IS=Texti er lengri en reiturinn hans.';
        TooLongFixLbl: Label 'Send an itemNo of at most 20 characters, a code of at most 10, a description of at most 100 and a description2 of at most 50.', Comment = 'is-IS=Sendu itemNo sem er mest 20 stafir, code sem er mest 10, description sem er mest 100 og description2 sem er mest 50.';
        ExistsWhenLbl: Label 'The item already has a variant with that code.', Comment = 'is-IS=Varan hefur þegar afbrigði með þeim kóða.';
        PermissionWhenLbl: Label 'The caller cannot read items or create item variants.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur eða stofnað vöruafbrigði.';
        NativeWhenLbl: Label 'Business Central refuses the save itself, after the request was checked. Nothing is saved.', Comment = 'is-IS=Business Central hafnar sjálfri vistuninni eftir að beiðnin var yfirfarin. Ekkert er vistað.';
        NativeFixLbl: Label 'Read the error text, correct the cause in Business Central and send the call again.', Comment = 'is-IS=Lestu villutextann, lagaðu orsökina í Business Central og sendu kallið aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, ItemNotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, TooLongWhenLbl, TooLongFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ExistsWhenLbl, ExistsNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeWhenLbl, NativeFixLbl));
        exit(true);
    end;

    /// <summary>Effect chapter: writes one new row, does not post.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The item named in itemNo exists.');
        Preconditions.Add('The item has no variant with the code named in code yet.');
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Creates one new item variant on an existing item. Existing variants and the item itself are not changed, and nothing is deleted or posted. A refusal saves nothing. Chained Omit Commit calls stay in the caller transaction; standalone calls use an isolated write.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Metering chapter: not metered.</summary>
    /// <param name="Metering">Unused.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Related chapter.</summary>
    /// <param name="Related">Receives the related types.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        GetLbl: Label 'Read the variants an item already has instead of creating one.', Comment = 'is-IS=Lesa afbrigðin sem vara hefur þegar í stað þess að stofna nýtt.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemVariant.Get', GetLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    /// <param name="Workflow">Receives the steps.</param>
    /// <returns>True.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemVariant.Get', 'Read the variants of the item to check that the code is not used yet.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemVariant.Create', 'Create the new variant.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemVariant.Get', 'Read the variant back.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create a blue variant of an item', Comment = 'is-IS=Stofna blátt afbrigði af vöru';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemVariant.Create","data":{"itemNo":"1896-S","code":"BLUE","description":"Blue","blocked":false}}', '{"status":"Success","created":true,"itemNo":"1896-S","variant":{"code":"BLUE","description":"Blue","description2":"","blocked":false,"salesBlocked":false,"purchasingBlocked":false,"systemId":"6b9a7d1e-0000-0000-0000-000000000001"}}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Creates a new variant on an existing item from itemNo and code, with an optional description, description 2 and blocked flag. The answer is the saved variant with code, descriptions, blocked flags and system id.', Comment = 'is-IS=Stofnar nýtt afbrigði á vöru sem er til út frá itemNo og code, með valfrjálsri lýsingu, lýsingu 2 og lokunarflaggi. Svarið er vistaða afbrigðið með kóða, lýsingum, lokunarflöggum og kerfiskenni.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'A successful call saves one new variant. A refusal saves nothing. The call does not change or delete existing variants, does not change the item and does not post. Sending the same request twice is refused the second time because the variant exists. Generic data writes to item variants are refused, so use this call. In a chained Omit Commit call, the write remains in the caller transaction and a native failure propagates so the whole chain can roll back.', Comment = 'is-IS=Kall sem tekst vistar eitt nýtt afbrigði. Höfnun vistar ekkert. Kallið breytir hvorki né eyðir afbrigðum sem eru til, breytir ekki vörunni og bókar ekki. Sé sama beiðni send tvisvar er henni hafnað í seinna skiptið því afbrigðið er til. Almennum gagnaskrifum í vöruafbrigði er hafnað, svo notaðu þetta kall. Í keðjuðu Omit Commit kalli helst skrifunin í færslu kallandans og innbyggð villa berst áfram svo hægt sé að afturkalla alla keðjuna.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Message direction.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Runs Inventory.ItemVariant.Create. Validates the whole request, then writes in an isolated Codeunit.Run.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('code') then;
        if RequestJson.Contains('description') then;
        if RequestJson.Contains('description2') then;
        if RequestJson.Contains('blocked') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item Variant Create Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item Variant Create Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    local procedure CanWriteTables(): Boolean
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
    begin
        exit(Item.ReadPermission() and ItemVariant.ReadPermission() and ItemVariant.WritePermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanWriteTables()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ItemNoKeyTok, CodeKeyTok, DescriptionKeyTok, Description2KeyTok, BlockedKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStep());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ItemNoText: Text;
        CodeText: Text;
        ItemNoMissingErr: Label 'itemNo is missing or empty.', Comment = 'is-IS=itemNo vantar eða er tómt.';
        ItemNoMissingNextStepLbl: Label 'Send the number of the item that gets the new variant.', Comment = 'is-IS=Sendu númer vörunnar sem fær nýja afbrigðið.';
        CodeMissingErr: Label 'code is missing or empty.', Comment = 'is-IS=code vantar eða er tómt.';
        CodeMissingNextStepLbl: Label 'Send the code of the new variant, at most 10 characters.', Comment = 'is-IS=Sendu kóða nýja afbrigðisins, mest 10 stafir.';
        ItemNotFoundErr: Label 'Item %1 does not exist.', Comment = '%1 = item number, is-IS=Vara %1 er ekki til.';
        ExistsErr: Label 'Item %1 already has variant %2.', Comment = '%1 = item number, %2 = variant code, is-IS=Vara %1 hefur þegar afbrigðið %2.';
        NotExistingExpectedLbl: Label 'a variant code not used on the item', Comment = 'is-IS=afbrigðiskóði sem er ekki notaður á vörunni';
    begin
        if not RequireText(Argument, RequestJson, ItemNoKeyTok, ItemNoMissingErr, ItemNoMissingNextStepLbl) then
            exit(false);
        if not RequireText(Argument, RequestJson, CodeKeyTok, CodeMissingErr, CodeMissingNextStepLbl) then
            exit(false);
        if not OptionalText(Argument, RequestJson, DescriptionKeyTok) then
            exit(false);
        if not OptionalText(Argument, RequestJson, Description2KeyTok) then
            exit(false);
        if not OptionalBoolean(Argument, RequestJson, BlockedKeyTok) then
            exit(false);
        ItemNoText := ReadText(RequestJson, ItemNoKeyTok);
        CodeText := ReadText(RequestJson, CodeKeyTok);
        if not CheckLength(Argument, ItemNoKeyTok, ItemNoText, MaxStrLen(Item."No.")) then
            exit(false);
        if not CheckLength(Argument, CodeKeyTok, CodeText, MaxStrLen(ItemVariant.Code)) then
            exit(false);
        if not CheckLength(Argument, DescriptionKeyTok, ReadText(RequestJson, DescriptionKeyTok), MaxStrLen(ItemVariant.Description)) then
            exit(false);
        if not CheckLength(Argument, Description2KeyTok, ReadText(RequestJson, Description2KeyTok), MaxStrLen(ItemVariant."Description 2")) then
            exit(false);
        Item.SetLoadFields("No.");
        if not Item.Get(CopyStr(ItemNoText, 1, MaxStrLen(Item."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemNotFoundErr, UpperCase(ItemNoText)), ItemNoKeyTok, CopyStr(ItemNoText, 1, 250), ItemNoKeyTok, ItemNotFoundNextStep());
            exit(false);
        end;
        ItemVariant.SetLoadFields("Item No.", Code);
        if ItemVariant.Get(Item."No.", CopyStr(CodeText, 1, MaxStrLen(ItemVariant.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ExistsErr, Item."No.", ItemVariant.Code), CodeKeyTok, CopyStr(CodeText, 1, 250), NotExistingExpectedLbl, ExistsNextStep());
            exit(false);
        end;
        exit(true);
    end;

    local procedure CheckLength(var Argument: Record "Message Argument ori"; KeyName: Text; Value: Text; MaxLength: Integer): Boolean
    var
        TooLongErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=%1 er lengra en %2 stafir.';
        TooLongNextStepLbl: Label 'Send %1 with at most %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=Sendu %1 með mest %2 stöfum.';
    begin
        if StrLen(Value) <= MaxLength then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, KeyName, MaxLength), CopyStr(KeyName, 1, 250), CopyStr(Value, 1, 250), Format(MaxLength, 0, 9), StrSubstNo(TooLongNextStepLbl, KeyName, MaxLength));
        exit(false);
    end;

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MissingErr: Text; MissingNextStep: Text): Boolean
    begin
        if not RequestJson.Contains(KeyName) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CopyStr(KeyName, 1, 250), '', TextExpectedTok, MissingNextStep);
            exit(false);
        end;
        if not OptionalText(Argument, RequestJson, KeyName) then
            exit(false);
        if ReadText(RequestJson, KeyName) = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, CopyStr(KeyName, 1, 250), '', TextExpectedTok, MissingNextStep);
            exit(false);
        end;
        exit(true);
    end;

    local procedure OptionalText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure OptionalBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
        FormatNextStepLbl: Label 'Send %1 as true or false.', Comment = '%1 = key, is-IS=Sendu %1 sem true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if (not Token.IsValue()) or IsNullToken(Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), '', BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if (Raw <> 'true') and (Raw <> 'false') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsNullToken(Token: JsonToken): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        exit(Token.AsValue().IsNull());
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if (not Token.IsValue()) or IsNullToken(Token) then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure UnknownNextStep(): Text
    var
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo, code, description, description2 and blocked.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo, code, description, description2 og blocked.';
    begin
        exit(UnknownNextStepLbl);
    end;

    local procedure ItemNotFoundNextStep(): Text
    var
        ItemNotFoundNextStepLbl: Label 'Check the item number. The item must exist before a variant can be created on it.', Comment = 'is-IS=Athugaðu vörunúmerið. Varan verður að vera til áður en hægt er að stofna afbrigði á henni.';
    begin
        exit(ItemNotFoundNextStepLbl);
    end;

    local procedure ExistsNextStep(): Text
    var
        ExistsNextStepLbl: Label 'Choose another variant code, or read the existing variant with Inventory.ItemVariant.Get.', Comment = 'is-IS=Veldu annan afbrigðiskóða, eða lestu afbrigðið sem er til með Inventory.ItemVariant.Get.';
    begin
        exit(ExistsNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set with Inventory write permissions and a Business Central permission set that can read items and create item variants.', Comment = 'is-IS=Úthlutaðu Bifrost fullum aðgangi með skrifheimildum birgða og Business Central heimildasafni sem getur lesið vörur og stofnað vöruafbrigði.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
