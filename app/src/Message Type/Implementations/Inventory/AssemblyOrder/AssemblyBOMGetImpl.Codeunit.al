namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.AssemblyBOM.Get. Answers the assembly BOM components of an item (BOM Component, table 90), optionally
/// exploded through every sub-assembly level. Read only.
/// </summary>
codeunit 10076966 "Assembly BOM Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ItemNoKeyTok: Label 'itemNo', Locked = true;
        ExplodeKeyTok: Label 'explode', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;
        MaxLevels: Integer;

    /// <summary>Reports discovery availability without reading setup for an unauthorized caller.</summary>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Assembly Header", false, false) then
            exit(false);
        exit(CanReadSources());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Answers the assembly BOM components of an item, optionally exploded through every sub-assembly level.', Comment = 'is-IS=Svarar íhlutum samsetningaruppskriftar vöru, valfrjálst sundurliðað í gegnum öll stig undirsamsetninga. (íhlutir, samsett vara, sundurliða uppskrift).';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assembly BOM, bill of materials, components, kit, explode BOM', Comment = 'is-IS=samsetningaruppskrift, uppskrift, íhlutir, samsett vara, sundurliða uppskrift';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reads the components of an assembly BOM, one level or exploded, without changing anything.', Comment = 'is-IS=Les íhluti samsetningaruppskriftar, eitt stig eða sundurliðað, án þess að breyta neinu.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the item is named in data.itemNo."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The parent item whose assembly BOM is read.', Comment = 'is-IS=Yfirvaran sem samsetningaruppskriftin er lesin fyrir.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoLbl: Label 'The item number of the parent item.', Comment = 'is-IS=Vörunúmer yfirvörunnar.';
        ExplodeLbl: Label 'true also lists the components of every component that has its own assembly BOM, down through all levels. Off (false) by default: only the first level is listed.', Comment = 'is-IS=true listar einnig íhluti allra íhluta sem hafa eigin samsetningaruppskrift, niður öll stig. Slökkt (false) sjálfgefið: aðeins fyrsta stigið er listað.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('explode', 'boolean', false, ExplodeLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The parent item number.'));
        Fields.Add(ContractMgt.ResponseField('description', 'string', 'The parent item description.'));
        Fields.Add(ContractMgt.ResponseField('baseUnitOfMeasure', 'string', 'The base unit of measure of the parent item; the BOM is for one unit of it.'));
        Fields.Add(ContractMgt.ResponseField('assemblyBOM', 'boolean', 'true when the item has assembly BOM components.'));
        Fields.Add(ContractMgt.ResponseField('exploded', 'boolean', 'true when sub-assemblies were exploded.'));
        Fields.Add(ContractMgt.ResponseField('componentCount', 'integer', 'The number of entries in components.'));
        Fields.Add(ContractMgt.ResponseField('components', 'array', 'The BOM lines in tree order: level (1 = directly on the item), parentItemNo, lineNo, type (Item, Resource, or empty for a text line), no, variantCode, description, unitOfMeasureCode, quantityPer, totalQuantityPer, assemblyBOM, position, resourceUsageType (Direct or Fixed for resources, else empty) and leadTimeOffset.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'itemNo is missing or empty.', Comment = 'is-IS=itemNo vantar eða er tómt.';
        MissingFixLbl: Label 'Send itemNo.', Comment = 'is-IS=Sendu itemNo.';
        FormatWhenLbl: Label 'itemNo is not text, or explode is not true or false.', Comment = 'is-IS=itemNo er ekki texti, eða explode er ekki true eða false.';
        FormatFixLbl: Label 'Send itemNo as text and explode as true or false.', Comment = 'is-IS=Sendu itemNo sem texta og explode sem true eða false.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are itemNo and explode.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo og explode.';
        NotFoundWhenLbl: Label 'The item does not exist.', Comment = 'is-IS=Varan er ekki til.';
        NotFoundFixLbl: Label 'Check the item no.', Comment = 'is-IS=Athugaðu vörunúmerið.';
        DomainWhenLbl: Label 'The Assembly domain is turned off in Inventory Setup.', Comment = 'is-IS=Slökkt er á samsetningarsviðinu í Uppsetningu birgða.';
        DomainFixLbl: Label 'Ask an administrator to turn the Assembly domain on from the Inventory Setup page.', Comment = 'is-IS=Biddu kerfisstjóra að kveikja á samsetningarsviðinu á síðunni Uppsetning birgða.';
        PermissionWhenLbl: Label 'The caller cannot read items, BOM components or item units of measure.', Comment = 'is-IS=Kallandinn getur ekki lesið vörur, uppskriftaríhluti eða mælieiningar vöru.';
        PermissionFixLbl: Label 'Assign the Bifrost "Read-Only" permission set (extended by Inventory read permissions) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, DomainWhenLbl, DomainFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. The call only reads the item, its BOM components and units of measure.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read items, BOM components and item units of measure.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyToOrder.Get', 'Use it for the assembly order linked to a sales line.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Create', 'Use it to create an assembly order that copies this BOM into its lines.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Read the exploded assembly BOM of an item', Comment = 'is-IS=Lesa sundurliðaða samsetningaruppskrift vöru';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"type":"Inventory.AssemblyBOM.Get","data":{"itemNo":"1925-W","explode":true}}',
            '{"status":"Success","itemNo":"1925-W","description":"Conference Bundle 1-6","baseUnitOfMeasure":"PCS","assemblyBOM":true,"exploded":true,"componentCount":2,"components":[{"level":1,"parentItemNo":"1925-W","lineNo":10000,"type":"Item","no":"1924-W","unitOfMeasureCode":"PCS","quantityPer":1,"totalQuantityPer":1,"assemblyBOM":true},{"level":2,"parentItemNo":"1924-W","lineNo":10000,"type":"Item","no":"1906-S","unitOfMeasureCode":"PCS","quantityPer":2,"totalQuantityPer":2,"assemblyBOM":false}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Answers the assembly BOM of an item: its components with quantity per unit. With explode true, components that are assemblies themselves are followed down through every level, and totalQuantityPer says how much is needed for one unit of the parent item. Nothing is changed.', Comment = 'is-IS=Svarar samsetningaruppskrift vöru: íhlutum hennar með magni á einingu. Með explode true er íhlutum sem eru sjálfir samsetningar fylgt niður öll stig og totalQuantityPer segir hve mikið þarf í eina einingu yfirvörunnar. Engu er breytt.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'components are in tree order: each sub-assembly is followed by its own components. quantityPer is in unitOfMeasureCode per unit of parentItemNo. totalQuantityPer is in unitOfMeasureCode per one base unit of itemNo, multiplied through the levels; for a resource with resourceUsageType Fixed it is not multiplied by the quantity of the order. type and resourceUsageType are fixed English names, not captions. An item without components answers assemblyBOM false and an empty list. A component that already appears higher on its own branch is not exploded again.', Comment = 'is-IS=components eru í trjáröð: hverri undirsamsetningu fylgja hennar eigin íhlutir. quantityPer er í unitOfMeasureCode á hverja einingu af parentItemNo. totalQuantityPer er í unitOfMeasureCode á hverja grunneiningu af itemNo, margfaldað gegnum stigin; fyrir forða með resourceUsageType Fixed margfaldast það ekki með magni pöntunar. type og resourceUsageType eru föst ensk heiti, ekki skjátextar. Vara án íhluta svarar assemblyBOM false og tómum lista. Íhlutur sem kemur þegar fyrir ofar á eigin grein er ekki sundurliðaður aftur.';
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
        Item: Record Item;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Components: JsonArray;
        Path: List of [Code[20]];
        ItemNo: Text;
        Explode: Boolean;
        NotFoundErr: Label 'The item does not exist.', Comment = 'is-IS=Varan er ekki til.';
        NotFoundNextStepLbl: Label 'Check the item no.', Comment = 'is-IS=Athugaðu vörunúmerið.';
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('itemNo') then;
        if RequestJson.Contains('explode') then;
        if not ReadItemNo(Argument, RequestJson, ItemNo) then
            exit;
        if not ReadBoolean(Argument, RequestJson, ExplodeKeyTok, Explode) then
            exit;
        if (StrLen(ItemNo) > MaxStrLen(Item."No.")) or not Item.Get(CopyStr(ItemNo, 1, MaxStrLen(Item."No."))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, ItemNoKeyTok, CopyStr(ItemNo, 1, 250), '', NotFoundNextStepLbl);
            exit;
        end;

        MaxLevels := 50;
        Path.Add(Item."No.");
        AddComponents(Item."No.", 1, 1, Explode, Path, Components);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('description', Item.Description);
        ResponseJson.Add('baseUnitOfMeasure', Item."Base Unit of Measure");
        ResponseJson.Add('assemblyBOM', Components.Count() > 0);
        ResponseJson.Add('exploded', Explode);
        ResponseJson.Add('componentCount', Components.Count());
        ResponseJson.Add('components', Components);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AddComponents(ParentItemNo: Code[20]; Level: Integer; ParentBaseQuantity: Decimal; Explode: Boolean; var Path: List of [Code[20]]; var Components: JsonArray)
    var
        BOMComponent: Record "BOM Component";
        ComponentJson: JsonObject;
        TotalQuantityPer: Decimal;
        HasOwnBOM: Boolean;
    begin
        BOMComponent.SetRange("Parent Item No.", ParentItemNo);
        if not BOMComponent.FindSet() then
            exit;
        repeat
            HasOwnBOM := false;
            if BOMComponent.Type = BOMComponent.Type::Item then
                HasOwnBOM := ItemHasBOM(BOMComponent."No.");
            if (BOMComponent.Type = BOMComponent.Type::Resource) and (BOMComponent."Resource Usage Type" = BOMComponent."Resource Usage Type"::Fixed) then
                TotalQuantityPer := BOMComponent."Quantity per"
            else
                TotalQuantityPer := ParentBaseQuantity * BOMComponent."Quantity per";
            Clear(ComponentJson);
            ComponentJson.Add('level', Level);
            ComponentJson.Add('parentItemNo', BOMComponent."Parent Item No.");
            ComponentJson.Add('lineNo', BOMComponent."Line No.");
            ComponentJson.Add('type', ComponentTypeName(BOMComponent.Type));
            ComponentJson.Add('no', BOMComponent."No.");
            ComponentJson.Add('variantCode', BOMComponent."Variant Code");
            ComponentJson.Add('description', BOMComponent.Description);
            ComponentJson.Add('unitOfMeasureCode', BOMComponent."Unit of Measure Code");
            ComponentJson.Add('quantityPer', BOMComponent."Quantity per");
            ComponentJson.Add('totalQuantityPer', TotalQuantityPer);
            ComponentJson.Add('assemblyBOM', HasOwnBOM);
            ComponentJson.Add('position', BOMComponent.Position);
            ComponentJson.Add('resourceUsageType', ResourceUsageTypeName(BOMComponent));
            ComponentJson.Add('leadTimeOffset', Format(BOMComponent."Lead-Time Offset"));
            Components.Add(ComponentJson);
            if Explode and HasOwnBOM and (Level < MaxLevels) and not Path.Contains(BOMComponent."No.") then begin
                Path.Add(BOMComponent."No.");
                AddComponents(BOMComponent."No.", Level + 1, TotalQuantityPer * QtyPerUnitOfMeasure(BOMComponent."No.", BOMComponent."Unit of Measure Code"), Explode, Path, Components);
                Path.RemoveAt(Path.Count());
            end;
        until BOMComponent.Next() = 0;
    end;

    local procedure ItemHasBOM(ItemNo: Code[20]): Boolean
    var
        BOMComponent: Record "BOM Component";
    begin
        BOMComponent.SetRange("Parent Item No.", ItemNo);
        exit(not BOMComponent.IsEmpty());
    end;

    local procedure QtyPerUnitOfMeasure(ItemNo: Code[20]; UnitOfMeasureCode: Code[10]): Decimal
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if UnitOfMeasureCode = '' then
            exit(1);
        if not ItemUnitOfMeasure.Get(ItemNo, UnitOfMeasureCode) then
            exit(1);
        if ItemUnitOfMeasure."Qty. per Unit of Measure" = 0 then
            exit(1);
        exit(ItemUnitOfMeasure."Qty. per Unit of Measure");
    end;

    local procedure ComponentTypeName(ComponentType: Enum "BOM Component Type"): Text
    begin
        case ComponentType of
            ComponentType::Item:
                exit('Item');
            ComponentType::Resource:
                exit('Resource');
        end;
        exit('');
    end;

    local procedure ResourceUsageTypeName(BOMComponent: Record "BOM Component"): Text
    begin
        if BOMComponent.Type <> BOMComponent.Type::Resource then
            exit('');
        if BOMComponent."Resource Usage Type" = BOMComponent."Resource Usage Type"::Fixed then
            exit('Fixed');
        exit('Direct');
    end;

    local procedure CanReadSources(): Boolean
    var
        Item: Record Item;
        BOMComponent: Record "BOM Component";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        exit(Item.ReadPermission() and BOMComponent.ReadPermission() and ItemUnitOfMeasure.ReadPermission());
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not (InventorySetup.ReadPermission() and CanReadSources()) then begin
            RespondPermission(Argument);
            exit(false);
        end;
        exit(DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", false, false));
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are itemNo and explode.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru itemNo og explode.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [ItemNoKeyTok, ExplodeKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, KeyName, KeyName, '', UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadItemNo(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not GetPresentToken(RequestJson, ItemNoKeyTok, Token) then begin
            RespondMissing(Argument);
            exit(false);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, ItemNoKeyTok, '', TextExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, ItemNoKeyTok, Raw, TextExpectedTok);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Value = '' then begin
            RespondMissing(Argument);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Boolean): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := false;
        if not GetPresentToken(RequestJson, KeyName, Token) then
            exit(true);
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', BooleanExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not (Raw in ['true', 'false']) then begin
            RespondFormat(Argument, KeyName, Raw, BooleanExpectedTok);
            exit(false);
        end;
        Value := Raw = 'true';
        exit(true);
    end;

    local procedure GetPresentToken(RequestJson: JsonObject; KeyName: Text; var Token: JsonToken): Boolean
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(false);
        exit(true);
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori")
    var
        MissingErr: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextStepLbl: Label 'Send itemNo.', Comment = 'is-IS=Sendu itemNo.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, ItemNoKeyTok, '', ItemNoKeyTok, MissingNextStepLbl);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text; Expected: Text)
    var
        FormatErr: Label 'The value has the wrong format.', Comment = 'is-IS=Gildið er á röngu sniði.';
        FormatNextStepLbl: Label 'Send itemNo as text and explode as true or false.', Comment = 'is-IS=Sendu itemNo sem texta og explode sem true eða false.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Received, 1, 250), Expected, FormatNextStepLbl);
    end;

    local procedure RespondPermission(var Argument: Record "Message Argument ori")
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst með lesheimildum birgða og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
    end;
}
