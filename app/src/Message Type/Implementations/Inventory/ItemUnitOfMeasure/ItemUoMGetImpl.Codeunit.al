namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>
/// Inventory.ItemUnitOfMeasure.Get. Returns the units of measure of one item, or one unit when code is sent,
/// with the base unit flagged. Read-only: checks read permission and never changes an item or a unit.
/// </summary>
codeunit 10077011 "Item UoM Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        CodeKeyTok: Label 'code', Locked = true;
        AllowedKeysTok: Label 'itemNo, code', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;

    /// <summary>True when the caller can read items, item units of measure and item ledger entries.</summary>
    /// <returns>True when the type may run for the current user.</returns>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        exit(CanReadTables());
    end;

    /// <summary>The table this type reads.</summary>
    /// <returns>The Item Unit of Measure table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Unit of Measure");
    end;

    /// <summary>Short description for discovery.</summary>
    /// <returns>The translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads the units of measure of an item.', Comment = 'is-IS=Les mælieiningar vöru. (vörumælieining, grunneining, magn í einingu, kassi, bretti, þyngd).';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords for discovery.</summary>
    /// <returns>The translated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item unit of measure, base unit, quantity per unit, carton, pallet, weight', Comment = 'is-IS=vörumælieining, grunneining, magn í einingu, kassi, bretti, þyngd';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Text a picker shows for this type.</summary>
    /// <returns>The translated selection text.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Show the units of measure of an item with the base unit flagged, or one unit by its code.', Comment = 'is-IS=Sýndu mælieiningar vöru með grunneininguna merkta, eða eina einingu eftir kóða hennar.';
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
        Subject.Add('description', 'The item is named under data.itemNo; subject is not read.');
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
        ItemTargetLbl: Label 'The item whose units of measure are read.', Comment = 'is-IS=Varan sem mælieiningarnar eru lesnar fyrir.';
        CodeTargetLbl: Label 'One unit of measure of the item. Omit code to read every unit of the item.', Comment = 'is-IS=Ein mælieining vörunnar. Slepptu code til að lesa allar mælieiningar vörunnar.';
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
        ItemNoLbl: Label 'Item number, at most 20 characters. Required.', Comment = 'is-IS=Vörunúmer, mest 20 stafir. Skylt.';
        CodeLbl: Label 'Unit of measure code, at most 10 characters. Omit code to read every unit of the item.', Comment = 'is-IS=Mælieiningarkóði, mest 10 stafir. Slepptu code til að lesa allar mælieiningar vörunnar.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('code', 'string', false, CodeLbl));
        exit(true);
    end;

    /// <summary>Response chapter: the shape of a successful answer.</summary>
    /// <param name="Response">Receives the response shape.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        UnitField: JsonObject;
    begin
        UnitField := ContractMgt.ResponseField('units', 'array', 'The units read: one when code was sent, otherwise every unit of the item in code order. Empty when the item has no units.');
        UnitField.Add('children', UnitChildren());
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success on a successful call; Error responses use the standard error envelope.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number the units belong to.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure code of the item. Empty when the item has none.'));
        Fields.Add(UnitField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Errors chapter: every refusal with its next step.</summary>
    /// <param name="Errors">Receives the error entries.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        MissingWhenLbl: Label 'itemNo is missing or empty, or code was sent empty.', Comment = 'is-IS=itemNo vantar eða er tómt, eða code var sent tómt.';
        MissingFixLbl: Label 'Send a non-empty itemNo, and send code only when you want one unit.', Comment = 'is-IS=Sendu itemNo sem er ekki tómt, og sendu code aðeins ef þú vilt eina einingu.';
        FormatWhenLbl: Label 'itemNo or code is not a JSON string.', Comment = 'is-IS=itemNo eða code er ekki JSON-strengur.';
        FormatFixLbl: Label 'Send itemNo and code as text.', Comment = 'is-IS=Sendu itemNo og code sem texta.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        NotFoundWhenLbl: Label 'No item matched itemNo, or the item has no unit of measure with that code.', Comment = 'is-IS=Engin vara passaði við itemNo, eða varan hefur enga mælieiningu með þeim kóða.';
        InvalidWhenLbl: Label 'itemNo is longer than 20 characters or code is longer than 10 characters.', Comment = 'is-IS=itemNo er lengra en 20 stafir eða code er lengra en 10 stafir.';
        InvalidFixLbl: Label 'Send an itemNo of at most 20 characters and a code of at most 10 characters.', Comment = 'is-IS=Sendu itemNo sem er mest 20 stafir og code sem er mest 10 stafir.';
        PermissionWhenLbl: Label 'The caller cannot read items, item units of measure or item ledger entries.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur, vörumælieiningar eða birgðafærslur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundNextStep()));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidWhenLbl, InvalidFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionNextStep()));
        exit(true);
    end;

    /// <summary>Effect chapter: this type does not write.</summary>
    /// <param name="Effect">Receives the effect flags.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Nothing. The call only reads the units of measure of one item.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
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
        CreateLbl: Label 'Create a new unit of measure on the item instead of reading the existing ones.', Comment = 'is-IS=Stofna nýja mælieiningu á vörunni í stað þess að lesa þær sem eru til.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemUnitOfMeasure.Create', CreateLbl));
        exit(true);
    end;

    /// <summary>Workflow chapter: none.</summary>
    /// <param name="Workflow">Unused.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Examples chapter.</summary>
    /// <param name="Examples">Receives the examples.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Read every unit of measure of an item', Comment = 'is-IS=Lesa allar mælieiningar vöru';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemUnitOfMeasure.Get","data":{"itemNo":"1896-S"}}', '{"status":"Success","itemNo":"1896-S","baseUnitOfMeasure":"PCS","units":[{"code":"BOX","qtyPerUnitOfMeasure":6,"isBaseUnit":false,"length":0,"width":0,"height":0,"cubage":0,"weight":2.5,"hasLedgerEntries":false,"systemId":"6b9a7d1e-0000-0000-0000-000000000001"},{"code":"PCS","qtyPerUnitOfMeasure":1,"isBaseUnit":true,"length":0,"width":0,"height":0,"cubage":0,"weight":0.4,"hasLedgerEntries":true,"systemId":"6b9a7d1e-0000-0000-0000-000000000002"}]}'));
        exit(true);
    end;

    /// <summary>Overview chapter.</summary>
    /// <param name="Overview">Receives the overview text.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reads the units of measure of one item with code, quantity per unit of measure, base unit flag, length, width, height, cubage, weight, a flag that says whether item ledger entries use the unit, and system id. Send itemNo to read every unit in code order, and add code to read one unit.', Comment = 'is-IS=Les mælieiningar einnar vöru með kóða, magni í mælieiningu, grunneiningarmerki, lengd, breidd, hæð, rúmmáli, þyngd, merki um hvort birgðafærslur nota eininguna og kerfiskenni. Sendu itemNo til að lesa allar einingar í röð kóða, og bættu code við til að lesa eina einingu.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Notes chapter.</summary>
    /// <param name="Notes">Receives the notes text.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'This call only reads. isBaseUnit is true for the unit that is the base unit of measure of the item. hasLedgerEntries is true when item ledger entries of the item use the unit; the quantity per unit of such a unit must not change. An item without units answers an empty units array, not an error. The caller needs read access to items, item units of measure and item ledger entries.', Comment = 'is-IS=Þetta kall les eingöngu. isBaseUnit er true fyrir eininguna sem er grunnmælieining vörunnar. hasLedgerEntries er true þegar birgðafærslur vörunnar nota eininguna; magni í slíkri einingu má ekki breyta. Vara án eininga svarar tómu units-fylki, ekki villu. Kallandinn þarf lesaðgang að vörum, vörumælieiningum og birgðafærslum.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Message direction.</summary>
    /// <returns>Outbound.</returns>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Runs Inventory.ItemUnitOfMeasure.Get.</summary>
    /// <param name="Argument">The message argument with the request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        ItemNo: Code[20];
        UnitCode: Code[10];
    begin
        if not AssertCanRun(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('code') then;
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        if not ValidateRequest(Argument, RequestJson, ItemNo, UnitCode) then
            exit;
        WriteResponse(Argument, ItemNo, UnitCode);
    end;

    /// <summary>Builds the JSON object for one unit, shared with Inventory.ItemUnitOfMeasure.Create.</summary>
    /// <param name="ItemUnitOfMeasure">The unit.</param>
    /// <param name="BaseUnitCode">The base unit of measure code of the item.</param>
    /// <returns>The unit JSON object.</returns>
    procedure BuildUnitJson(ItemUnitOfMeasure: Record "Item Unit of Measure"; BaseUnitCode: Code[10]) Result: JsonObject
    begin
        Result.Add('code', ItemUnitOfMeasure.Code);
        Result.Add('qtyPerUnitOfMeasure', ItemUnitOfMeasure."Qty. per Unit of Measure");
        Result.Add('isBaseUnit', (BaseUnitCode <> '') and (ItemUnitOfMeasure.Code = BaseUnitCode));
        Result.Add('length', ItemUnitOfMeasure.Length);
        Result.Add('width', ItemUnitOfMeasure.Width);
        Result.Add('height', ItemUnitOfMeasure.Height);
        Result.Add('cubage', ItemUnitOfMeasure.Cubage);
        Result.Add('weight', ItemUnitOfMeasure.Weight);
        Result.Add('hasLedgerEntries', HasLedgerEntries(ItemUnitOfMeasure."Item No.", ItemUnitOfMeasure.Code));
        Result.Add('systemId', Format(ItemUnitOfMeasure.SystemId, 0, 4).ToLower());
    end;

    /// <summary>True when item ledger entries of the item use the unit of measure.</summary>
    /// <param name="ItemNo">The item number.</param>
    /// <param name="UnitCode">The unit of measure code.</param>
    /// <returns>True when at least one item ledger entry uses the unit. The caller must already hold Item Ledger Entry read access.</returns>
    procedure HasLedgerEntries(ItemNo: Code[20]; UnitCode: Code[10]): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        // Callers gate on Item Ledger Entry read access first, so a missing permission is never reported as an absence.
        ItemLedgerEntry.SetCurrentKey("Item No.");
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Unit of Measure Code", UnitCode);
        exit(not ItemLedgerEntry.IsEmpty());
    end;

    /// <summary>The response fields of one unit, shared with Inventory.ItemUnitOfMeasure.Create.</summary>
    /// <returns>The response field entries.</returns>
    procedure UnitChildren() Children: JsonArray
    begin
        Children.Add(ContractMgt.ResponseField('code', 'string', 'The unit of measure code.'));
        Children.Add(ContractMgt.ResponseField('qtyPerUnitOfMeasure', 'number', 'How many base units one unit holds. 1 for the base unit.'));
        Children.Add(ContractMgt.ResponseField('isBaseUnit', 'boolean', 'True when this unit is the base unit of measure of the item.'));
        Children.Add(ContractMgt.ResponseField('length', 'number', 'Length of one unit.'));
        Children.Add(ContractMgt.ResponseField('width', 'number', 'Width of one unit.'));
        Children.Add(ContractMgt.ResponseField('height', 'number', 'Height of one unit.'));
        Children.Add(ContractMgt.ResponseField('cubage', 'number', 'Cubage of one unit, as Business Central calculates it from length, width and height.'));
        Children.Add(ContractMgt.ResponseField('weight', 'number', 'Weight of one unit.'));
        Children.Add(ContractMgt.ResponseField('hasLedgerEntries', 'boolean', 'True when item ledger entries of the item use the unit. The quantity per unit of such a unit must not change.'));
        Children.Add(ContractMgt.ResponseField('systemId', 'string', 'The system id (GUID) of the unit.'));
    end;

    local procedure CanReadTables(): Boolean
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        exit(Item.ReadPermission() and ItemUnitOfMeasure.ReadPermission() and ItemLedgerEntry.ReadPermission());
    end;

    local procedure AssertCanRun(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
    begin
        if (not InventorySetup.ReadPermission()) or (not CanReadTables()) then begin
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
            if not (KeyName in [ItemNoKeyTok, CodeKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), AllowedKeysTok, UnknownNextStep());
                exit(false);
            end;
        exit(true);
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var ItemNo: Code[20]; var UnitCode: Code[10]): Boolean
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ValueText: Text;
        ItemNoMissingErr: Label 'itemNo is missing or empty.', Comment = 'is-IS=itemNo vantar eða er tómt.';
        ItemNoMissingNextStepLbl: Label 'Send the number of the item whose units of measure you want to read.', Comment = 'is-IS=Sendu númer vörunnar sem þú vilt lesa mælieiningar fyrir.';
        CodeEmptyErr: Label 'code is empty.', Comment = 'is-IS=code er tómt.';
        CodeEmptyNextStepLbl: Label 'Send a unit of measure code, or omit code to read every unit of the item.', Comment = 'is-IS=Sendu mælieiningarkóða, eða slepptu code til að lesa allar mælieiningar vörunnar.';
    begin
        ItemNo := '';
        UnitCode := '';
        if not RequestJson.Contains(ItemNoKeyTok) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, ItemNoMissingErr, ItemNoKeyTok, '', TextExpectedTok, ItemNoMissingNextStepLbl);
            exit(false);
        end;
        if not RequireText(Argument, RequestJson, ItemNoKeyTok) then
            exit(false);
        ValueText := ReadText(RequestJson, ItemNoKeyTok);
        if ValueText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, ItemNoMissingErr, ItemNoKeyTok, '', TextExpectedTok, ItemNoMissingNextStepLbl);
            exit(false);
        end;
        if not CheckLength(Argument, ItemNoKeyTok, ValueText, MaxStrLen(Item."No.")) then
            exit(false);
        ItemNo := CopyStr(ValueText, 1, MaxStrLen(ItemNo));
        if not RequestJson.Contains(CodeKeyTok) then
            exit(true);
        if not RequireText(Argument, RequestJson, CodeKeyTok) then
            exit(false);
        ValueText := ReadText(RequestJson, CodeKeyTok);
        if ValueText = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, CodeEmptyErr, CodeKeyTok, '', TextExpectedTok, CodeEmptyNextStepLbl);
            exit(false);
        end;
        if not CheckLength(Argument, CodeKeyTok, ValueText, MaxStrLen(ItemUnitOfMeasure.Code)) then
            exit(false);
        UnitCode := CopyStr(ValueText, 1, MaxStrLen(UnitCode));
        exit(true);
    end;

    local procedure WriteResponse(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; UnitCode: Code[10])
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResponseJson: JsonObject;
        Units: JsonArray;
        ItemNotFoundErr: Label 'Item %1 does not exist.', Comment = '%1 = item number, is-IS=Vara %1 er ekki til.';
        UnitNotFoundErr: Label 'Item %1 has no unit of measure %2.', Comment = '%1 = item number, %2 = unit of measure code, is-IS=Vara %1 hefur enga mælieiningu %2.';
    begin
        Item.SetLoadFields("No.", "Base Unit of Measure");
        if not Item.Get(ItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemNotFoundErr, ItemNo), ItemNoKeyTok, ItemNo, ItemNoKeyTok, NotFoundNextStep());
            exit;
        end;
        if UnitCode <> '' then begin
            if not ItemUnitOfMeasure.Get(ItemNo, UnitCode) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnitNotFoundErr, ItemNo, UnitCode), CodeKeyTok, UnitCode, CodeKeyTok, UnitNotFoundNextStep());
                exit;
            end;
            Units.Add(BuildUnitJson(ItemUnitOfMeasure, Item."Base Unit of Measure"));
        end else begin
            ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
            if ItemUnitOfMeasure.FindSet() then
                repeat
                    Units.Add(BuildUnitJson(ItemUnitOfMeasure, Item."Base Unit of Measure"));
                until ItemUnitOfMeasure.Next() = 0;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        ResponseJson.Add('units', Units);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
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

    local procedure RequireText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
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
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo and code.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo og code.';
    begin
        exit(UnknownNextStepLbl);
    end;

    local procedure NotFoundNextStep(): Text
    var
        NotFoundNextStepLbl: Label 'Check the item number, or omit code to read every unit of measure of the item.', Comment = 'is-IS=Athugaðu vörunúmerið, eða slepptu code til að lesa allar mælieiningar vörunnar.';
    begin
        exit(NotFoundNextStepLbl);
    end;

    local procedure UnitNotFoundNextStep(): Text
    var
        UnitNotFoundNextStepLbl: Label 'Omit code to list the units of the item, or create the unit with Inventory.ItemUnitOfMeasure.Create.', Comment = 'is-IS=Slepptu code til að fá lista yfir einingar vörunnar, eða stofnaðu eininguna með Inventory.ItemUnitOfMeasure.Create.';
    begin
        exit(UnitNotFoundNextStepLbl);
    end;

    local procedure PermissionNextStep(): Text
    var
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions and a Business Central permission set that can read items, item units of measure and item ledger entries.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst með lesheimildum birgða og Business Central heimildasafni sem getur lesið vörur, vörumælieiningar og birgðafærslur.';
    begin
        exit(PermissionNextStepLbl);
    end;
}
