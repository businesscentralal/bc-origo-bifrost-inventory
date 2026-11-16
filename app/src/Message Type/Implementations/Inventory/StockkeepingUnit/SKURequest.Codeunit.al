namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>
/// Shared request checks and the stockkeeping unit JSON for Inventory.SKU.Create and Inventory.SKU.Get.
/// </summary>
codeunit 10076998 "SKU Request ori"
{
    Access = Internal;

    var
        TextExpectedTok: Label 'text', Locked = true;
        BooleanExpectedTok: Label 'boolean', Locked = true;

    /// <summary>Answers PermissionDenied (with a nextStep) or the disabled-domain refusal; true when the type may run.</summary>
    procedure AssertCanRun(var Argument: Record "Message Argument ori"; NeedWrite: Boolean): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        StockkeepingUnit: Record "Stockkeeping Unit";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        ReadNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions, and read permission on stockkeeping units.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðeins lestur“ í Bifröst með birgðalestrarheimildum, og lestrarheimild á birgðageymsluvörum.';
        WriteNextStepLbl: Label 'Assign the Bifrost "Full Access" permission set with Inventory write permissions, and write permission on stockkeeping units.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Aðgangur að öllum hlutum“ í Bifröst með birgðaskriftarheimildum, og skriftarheimild á birgðageymsluvörum.';
    begin
        if (not InventorySetup.ReadPermission()) or (NeedWrite and (not StockkeepingUnit.WritePermission())) or (not NeedWrite and (not StockkeepingUnit.ReadPermission())) then begin
            if NeedWrite then
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', '', WriteNextStepLbl)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', '', ReadNextStepLbl);
            exit(false);
        end;
        exit(DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Availability, Database::"Stockkeeping Unit", NeedWrite, false));
    end;

    /// <summary>Refuses a request key that the type does not read.</summary>
    procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; AllowedKeys: Text): Boolean
    var
        KeyName: Text;
        AllowedList: List of [Text];
        UnknownKeyErr: Label 'The request contains an unknown key.', Comment = 'is-IS=Beiðnin inniheldur óþekktan lykil.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are %1.', Comment = '%1 = list of keys, is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru %1.';
    begin
        AllowedList := AllowedKeys.Split(', ');
        foreach KeyName in RequestJson.Keys() do
            if not AllowedList.Contains(KeyName) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, CopyStr(KeyName, 1, 250), CopyStr(KeyName, 1, 250), CopyStr(AllowedKeys, 1, 250), StrSubstNo(UnknownNextStepLbl, AllowedKeys));
                exit(false);
            end;
        exit(true);
    end;

    /// <summary>True when the key is absent or a JSON text; otherwise answers InvalidParameterFormat.</summary>
    procedure CheckText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be text.', Comment = '%1 = key, is-IS=%1 verður að vera texti.';
        FormatNextStepLbl: Label 'Send %1 as text.', Comment = '%1 = key, is-IS=Sendu %1 sem texta.';
        TooLongErr: Label '%1 is longer than %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=%1 er lengra en %2 stafir.';
        TooLongNextStepLbl: Label 'Send %1 with at most %2 characters.', Comment = '%1 = key, %2 = maximum length, is-IS=Sendu %1 með í mesta lagi %2 stöfum.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                Raw := ''
            else
                Token.WriteTo(Raw);
        if (not Token.IsValue()) or (not Raw.StartsWith('"')) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), TextExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        if StrLen(ReadText(RequestJson, KeyName)) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooLongErr, KeyName, MaxLength), CopyStr(KeyName, 1, 250), '', Format(MaxLength, 0, 9), StrSubstNo(TooLongNextStepLbl, KeyName, MaxLength));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>True when the key is absent or true/false; otherwise answers InvalidParameterFormat.</summary>
    procedure CheckBoolean(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        FormatErr: Label '%1 must be true or false.', Comment = '%1 = key, is-IS=%1 verður að vera true eða false.';
        FormatNextStepLbl: Label 'Send %1 as true or false.', Comment = '%1 = key, is-IS=Sendu %1 sem true eða false.';
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            if not Token.AsValue().IsNull() then
                Token.WriteTo(Raw);
        if (Raw <> 'true') and (Raw <> 'false') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), CopyStr(KeyName, 1, 250), CopyStr(Raw, 1, 250), BooleanExpectedTok, StrSubstNo(FormatNextStepLbl, KeyName));
            exit(false);
        end;
        exit(true);
    end;

    procedure ReadText(RequestJson: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit('');
        if (not Token.IsValue()) or Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    procedure ReadBoolean(RequestJson: JsonObject; KeyName: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(DefaultValue);
        if (not Token.IsValue()) or Token.AsValue().IsNull() then
            exit(DefaultValue);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Maps createPer text to the report option; false when the text is not one of the three.</summary>
    procedure TryParseCreationMethod(MethodText: Text; var SKUCreationMethod: Enum "SKU Creation Method"): Boolean
    begin
        case LowerCase(DelChr(MethodText, '=', ' &')) of
            'location':
                SKUCreationMethod := SKUCreationMethod::Location;
            'variant':
                SKUCreationMethod := SKUCreationMethod::Variant;
            'locationvariant', 'locationandvariant':
                SKUCreationMethod := SKUCreationMethod::"Location & Variant";
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>Builds the JSON for one stockkeeping unit with its planning and cost fields.</summary>
    procedure BuildSkuJson(var StockkeepingUnit: Record "Stockkeeping Unit") Result: JsonObject
    begin
        StockkeepingUnit.CalcFields(Inventory);
        Result.Add('itemNo', StockkeepingUnit."Item No.");
        Result.Add('locationCode', StockkeepingUnit."Location Code");
        Result.Add('variantCode', StockkeepingUnit."Variant Code");
        Result.Add('replenishmentSystem', Format(StockkeepingUnit."Replenishment System", 0, 9));
        Result.Add('reorderingPolicy', Format(StockkeepingUnit."Reordering Policy", 0, 9));
        Result.Add('includeInventory', StockkeepingUnit."Include Inventory");
        Result.Add('reorderPoint', StockkeepingUnit."Reorder Point");
        Result.Add('reorderQuantity', StockkeepingUnit."Reorder Quantity");
        Result.Add('maximumInventory', StockkeepingUnit."Maximum Inventory");
        Result.Add('safetyStockQuantity', StockkeepingUnit."Safety Stock Quantity");
        Result.Add('minimumOrderQuantity', StockkeepingUnit."Minimum Order Quantity");
        Result.Add('maximumOrderQuantity', StockkeepingUnit."Maximum Order Quantity");
        Result.Add('orderMultiple', StockkeepingUnit."Order Multiple");
        Result.Add('lotSize', StockkeepingUnit."Lot Size");
        Result.Add('leadTimeCalculation', Format(StockkeepingUnit."Lead Time Calculation", 0, 9));
        Result.Add('safetyLeadTime', Format(StockkeepingUnit."Safety Lead Time", 0, 9));
        Result.Add('transferFromCode', StockkeepingUnit."Transfer-from Code");
        Result.Add('vendorNo', StockkeepingUnit."Vendor No.");
        Result.Add('vendorItemNo', StockkeepingUnit."Vendor Item No.");
        Result.Add('unitCost', StockkeepingUnit."Unit Cost");
        Result.Add('standardCost', StockkeepingUnit."Standard Cost");
        Result.Add('lastDirectCost', StockkeepingUnit."Last Direct Cost");
        Result.Add('inventory', StockkeepingUnit.Inventory);
    end;
}
