namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>Reads current item cost snapshots using Foundation item selection and native stock filters.</summary>
codeunit 10076839 "Inventory Cost Read ori"
{
    Access = Internal;

    var
        InvalidTextErr: Label 'Parameter %1 must be text.', Comment = '%1 = parameter; is-IS=Færibreytan %1 verður að vera texti.';
        ReadDeniedErr: Label 'Permission denied for item costing data.', Comment = 'is-IS=Heimild hafnað fyrir kostnaðargögn vöru.';
        NotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = item no.; is-IS=Vara %1 fannst ekki.';
        NotFoundExpectedTxt: Label 'The number of an existing item.', Comment = 'is-IS=Númer vöru sem er til.';
        NotFoundNextStepTxt: Label 'Check the item number, then send it as data.itemNo or subject.', Comment = 'is-IS=Athugaðu vörunúmerið og sendu það sem data.itemNo eða subject.';

    /// <summary>Returns current card costs and filtered inventory; asOfDate limits stock entries, never rewrites card costs historically.</summary>
    procedure ReadCosts(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Lookup: Codeunit "Document Lookup ori";
        Reader: Codeunit "Request Value Reader ori";
        ContractParts: Codeunit "Inventory Contract Parts ori";
        Request: JsonObject;
        Response: JsonObject;
        Items: JsonArray;
        RowToken: JsonToken;
        FieldToken: JsonToken;
        FieldName: Text;
        ItemNo: Code[20];
        LocationFilter: Text;
        VariantCode: Text;
        AsOfDate: Date;
    begin
        if not Item.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, ReadDeniedErr, '', '', '', '');
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not TryReadText(Argument, Request, 'locationFilter', LocationFilter) or
           not TryReadText(Argument, Request, 'variantCode', VariantCode) or
           not Reader.TryReadDate(Argument, Request, 'asOfDate', false, AsOfDate)
        then
            exit;
        if UsesFoundationSelection(Argument, Request) then begin
            if not Lookup.FindItemRange(Argument, Item) then
                exit;
        end else begin
            // An item number in data.itemNo or subject (#129): a missing number is MissingParameter,
            // a different number in each is ConflictingIdentifiers, an unknown number is RecordNotFound (#128).
            if not ContractParts.TryResolveItemNo(Argument, Request, true, ItemNo) then
                exit;
            Item.SetRange("No.", ItemNo);
            if Item.IsEmpty() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ItemNo), 'itemNo', ItemNo, NotFoundExpectedTxt, NotFoundNextStepTxt);
                exit;
            end;
        end;
        if not TryCollectCosts(Item, Request, LocationFilter, VariantCode, AsOfDate, Items) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
            exit;
        end;
        Response.Add('status', 'Success');
        // One selected item also answers its fields at the top level, the single-item form of the response.
        if Items.Count() = 1 then begin
            Items.Get(0, RowToken);
            foreach FieldName in RowToken.AsObject().Keys() do begin
                RowToken.AsObject().Get(FieldName, FieldToken);
                Response.Add(FieldName, FieldToken);
            end;
        end;
        Response.Add('items', Items);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>A SystemId subject or a SystemId/tableView key selects through Foundation's item lookup; otherwise the call names one item number.</summary>
    local procedure UsesFoundationSelection(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    var
        SubjectId: Guid;
    begin
        if Argument.Subject <> '' then
            if Evaluate(SubjectId, Argument.Subject) then
                exit(true);
        exit(Request.Contains('itemId') or Request.Contains('id') or Request.Contains('systemId') or Request.Contains('recordSystemId') or Request.Contains('tableView'));
    end;

    [TryFunction]
    local procedure TryCollectCosts(var Item: Record Item; Request: JsonObject; LocationFilter: Text; VariantCode: Text; AsOfDate: Date; var Items: JsonArray)
    var
        Row: JsonObject;
    begin
        if Request.Contains('locationFilter') then
            Item.SetFilter("Location Filter", LocationFilter);
        if Request.Contains('variantCode') then
            Item.SetRange("Variant Filter", VariantCode);
        Item.SetLoadFields("No.", SystemId, "Costing Method", "Unit Cost", "Standard Cost", "Last Direct Cost", "Indirect Cost %", "Cost is Adjusted");
        if Item.FindSet() then
            repeat
                Item.CalcFields(Inventory, "Cost is Posted to G/L");
                Clear(Row);
                Row.Add('itemNo', Item."No.");
                Row.Add('itemId', Format(Item.SystemId, 0, 4));
                Row.Add('costingMethod', Item."Costing Method".Names().Get(Item."Costing Method".Ordinals().IndexOf(Item."Costing Method".AsInteger())));
                Row.Add('unitCost', Item."Unit Cost");
                Row.Add('standardCost', Item."Standard Cost");
                Row.Add('lastDirectCost', Item."Last Direct Cost");
                Row.Add('indirectCostPct', Item."Indirect Cost %");
                Row.Add('costIsAdjusted', Item."Cost is Adjusted");
                Row.Add('costIsPostedToGL', Item."Cost is Posted to G/L");
                Row.Add('inventory', InventoryAtDate(Item, AsOfDate));
                Row.Add('locationFilter', Item.GetFilter("Location Filter"));
                Row.Add('variantFilter', Item.GetFilter("Variant Filter"));
                if AsOfDate <> 0D then
                    Row.Add('asOfDate', Format(AsOfDate, 0, 9));
                Items.Add(Row);
            until Item.Next() = 0;
    end;

    local procedure InventoryAtDate(var Item: Record Item; AsOfDate: Date): Decimal
    var
        Ledger: Record "Item Ledger Entry";
    begin
        if AsOfDate = 0D then
            exit(Item.Inventory);
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.SetRange("Posting Date", 0D, AsOfDate);
        Ledger.SetFilter("Global Dimension 1 Code", Item.GetFilter("Global Dimension 1 Filter"));
        Ledger.SetFilter("Global Dimension 2 Code", Item.GetFilter("Global Dimension 2 Filter"));
        Ledger.SetFilter("Location Code", Item.GetFilter("Location Filter"));
        Ledger.SetFilter("Drop Shipment", Item.GetFilter("Drop Shipment Filter"));
        Ledger.SetFilter("Variant Code", Item.GetFilter("Variant Filter"));
        Ledger.SetFilter("Lot No.", Item.GetFilter("Lot No. Filter"));
        Ledger.SetFilter("Serial No.", Item.GetFilter("Serial No. Filter"));
        Ledger.SetFilter("Unit of Measure Code", Item.GetFilter("Unit of Measure Filter"));
        Ledger.SetFilter("Package No.", Item.GetFilter("Package No. Filter"));
        Ledger.CalcSums(Quantity);
        exit(Ledger.Quantity);
    end;

    local procedure TryReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidTextErr, Name), Name, '', 'text', '');
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        exit(true);
    end;
}
