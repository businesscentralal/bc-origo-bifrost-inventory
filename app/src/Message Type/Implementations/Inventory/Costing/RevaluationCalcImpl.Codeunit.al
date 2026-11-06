namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

codeunit 10076865 "Revaluation Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        DescriptionLbl: Label 'Calculates remaining inventory quantity and value for an item.', Comment = 'is-IS=Reiknar eftirstandandi birgðamagn og birgðavirði vöru.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'revaluation, calculate inventory value', Comment = 'is-IS=endurmat, reikna birgðavirði';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Calculates remaining quantity and inventory value. Does not post a revaluation journal.', Comment = 'is-IS=Reiknar eftirstandandi magn og birgðavirði. Bókar ekki endurmatsbók.';
    begin
        exit(SelectionDescriptionLbl);
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
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item whose open item ledger entries are summed. Spaces around the number are ignored.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, 'The No. of an existing item, sent as JSON text.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The No. of the item.'));
        Fields.Add(ContractMgt.ResponseField('remainingQuantity', 'decimal', 'The sum of the remaining quantity of the open item ledger entries of the item, over all locations and variants.'));
        Fields.Add(ContractMgt.ResponseField('inventoryValue', 'decimal', 'The sum, over those entries, of the remaining quantity times the cost per unit of the entry, where the cost per unit is the actual plus expected cost amount divided by the quantity of the entry.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemNo is missing, empty, or not a JSON value.', 'Send the item number in data.itemNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No item has the number in itemNo.', 'Check the item number and send it again.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Costing domain is turned off in Inventory Setup.', 'Turn on the Costing domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read item ledger entries.', 'Request read permission on item ledger entries from an administrator.'));
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
        Effect.Add('changes', 'None. Sums the remaining quantity and value of the open item ledger entries of one item. No revaluation journal line is created or changed.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Costing domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read item ledger entries.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Cost.Get', 'Use it to read the current card costs of items instead of summing the value of open item ledger entries.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Use it to bring item costs up to date; this type only sums entries and adjusts nothing.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Post', 'Use it to post a Revaluation journal batch that already exists; this type creates no journal lines.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Read the remaining quantity and value of item 1000',
            '{"type":"Inventory.Revaluation.Calculate","data":{"itemNo":"1000"}}',
            '{"status":"Success","itemNo":"1000","remainingQuantity":40,"inventoryValue":500}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Sums the remaining quantity of the open item ledger entries of one item and values it at the cost of each entry. Nothing is written and no revaluation journal line is created.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        Notes := 'Despite its name this type does not calculate a revaluation journal: it reads, and it creates or changes no journal line. It sums over all open item ledger entries of the item, so there is no filter on location, variant or date. ' +
            'Each entry is valued at its actual plus expected cost amount, scaled by its remaining quantity, so the value is only as current as the last cost adjustment; run Inventory.AdjustCost.Run first when costIsAdjusted from Inventory.Cost.Get is false. ' +
            'The item may be blocked. The caller needs BIFROST Read ori and read permission on item ledger entries, and the Costing domain must be on in Inventory Setup.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        ItemLedgerEntry: Record "Item Ledger Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        RemainingQty: Decimal;
        InventoryValue: Decimal;
        ItemNo: Code[20];
        MissingItemErr: Label 'itemNo must be specified.', Comment = 'is-IS=itemNo verður að vera tilgreint.';
        ItemNoExpectedTxt: Label 'A non-empty item number in data.itemNo.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo.';
        ItemNoNextStepTxt: Label 'Send the item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo.';
        NotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = item no., is-IS=Vara %1 fannst ekki.';
        NotFoundExpectedTxt: Label 'The number of an existing item.', Comment = 'is-IS=Númer vöru sem er til.';
        NotFoundNextStepTxt: Label 'Check the item number and send it again.', Comment = 'is-IS=Athugaðu vörunúmerið og sendu það aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemNo', Token) then
            if Token.IsValue() then
                if not Token.AsValue().IsNull() then
                    ItemNo := CopyStr(DelChr(Token.AsValue().AsCode(), '<>', ' '), 1, MaxStrLen(ItemNo));
        if ItemNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingItemErr, 'itemNo', '', ItemNoExpectedTxt, ItemNoNextStepTxt);
            exit;
        end;
        Item.SetLoadFields("No.");
        if not Item.Get(ItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ItemNo), 'itemNo', ItemNo, NotFoundExpectedTxt, NotFoundNextStepTxt);
            exit;
        end;
        ItemLedgerEntry.SetLoadFields("Item No.", "Remaining Quantity", Quantity);
        ItemLedgerEntry.SetRange("Item No.", Item."No.");
        ItemLedgerEntry.SetFilter("Remaining Quantity", '<>0');
        if ItemLedgerEntry.FindSet() then
            repeat
                RemainingQty += ItemLedgerEntry."Remaining Quantity";
                InventoryValue += RemainingValue(ItemLedgerEntry);
            until ItemLedgerEntry.Next() = 0;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('remainingQuantity', RemainingQty);
        ResponseJson.Add('inventoryValue', InventoryValue);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RemainingValue(var ItemLedgerEntry: Record "Item Ledger Entry"): Decimal
    begin
        if ItemLedgerEntry.Quantity = 0 then
            exit(0);
        // Cost Amount (Actual) and Cost Amount (Expected) are FlowFields. An unread FlowField is 0.
        // They are not both posted for the same value, so the sum is the entry cost.
        ItemLedgerEntry.CalcFields("Cost Amount (Actual)", "Cost Amount (Expected)");
        exit(ItemLedgerEntry."Remaining Quantity" * (ItemLedgerEntry."Cost Amount (Actual)" + ItemLedgerEntry."Cost Amount (Expected)") / ItemLedgerEntry.Quantity);
    end;
}
