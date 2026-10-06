namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

codeunit 70013488 "Revaluation Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::"Item Ledger Entry", false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Ledger Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Calculates remaining inventory quantity and value for an item.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('revaluation, calculate inventory value');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Calculates remaining quantity and inventory value. Does not post a revaluation journal.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        RemainingQty: Decimal;
        InventoryValue: Decimal;
        MissingItemErr: Label 'itemNo must be specified.', Locked = true;
        NotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = item no.', Locked = true;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError(MissingItemErr);
            exit;
        end;
        if not Item.Get(CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(Item."No."))) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, Token.AsValue().AsCode()));
            exit;
        end;
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>0');
        if ItemLedgerEntry.FindSet() then
            repeat
                RemainingQty += ItemLedgerEntry."Remaining Quantity";
                InventoryValue += ItemLedgerEntry."Remaining Quantity" * ItemLedgerEntry."Cost Amount (Actual)" / ItemLedgerEntry.Quantity;
            until ItemLedgerEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('remainingQuantity', RemainingQty);
        ResponseJson.Add('inventoryValue', InventoryValue);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
