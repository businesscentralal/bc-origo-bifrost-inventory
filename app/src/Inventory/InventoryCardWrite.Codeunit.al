namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Validates intentional item-card cost and unit price changes before native field validation and one modify.</summary>
codeunit 10076837 "Inventory Card Write ori"
{
    Access = Internal;

    var
        SelectionErr: Label 'Select exactly one item using subject, an item identifier or tableView.', Comment = 'is-IS=Veldu nákvæmlega eina vöru með subject, vöruauðkenni eða tableView.';
        NoFieldsErr: Label 'Supply unitCost, lastDirectCost or standardCost.', Comment = 'is-IS=Tilgreindu unitCost, lastDirectCost eða standardCost.';
        StandardErr: Label 'Standard-costed items require Inventory.Revaluation.Post. No item-card cost was changed.', Comment = 'is-IS=Vörur með staðalkostnað krefjast Inventory.Revaluation.Post. Kostnaði á vöruspjaldi var ekki breytt.';
        BlockedErr: Label 'Item %1 is blocked. Set allowBlocked=true only when the blocked-item change is intended.', Comment = '%1 = item number; is-IS=Vara %1 er lokuð. Stilltu allowBlocked=true aðeins ef breyting á lokaðri vöru er fyrirhuguð.';
        MethodErr: Label 'expectedCostingMethod does not match the current costing method %1.', Comment = '%1 = current method; is-IS=expectedCostingMethod passar ekki við núverandi kostnaðaraðferð %1.';
        FieldDeniedErr: Label 'Permission denied to write item cost field %1.', Comment = '%1 = field number; is-IS=Heimild hafnað til að breyta kostnaðarreit vöru %1.';
        CostWriteDeniedErr: Label 'Permission denied to update item costs.', Comment = 'is-IS=Heimild hafnað til að uppfæra vörukostnað.';
        TextErr: Label 'expectedCostingMethod must be text.', Comment = 'is-IS=expectedCostingMethod verður að vera texti.';
        ParameterErr: Label 'Unsupported price parameter %1.', Comment = '%1 = parameter name; is-IS=Verðfæribreytan %1 er ekki studd.';
        IdentifierErr: Label 'Item selection parameter %1 must be nonempty text.', Comment = '%1 = parameter name; is-IS=Vöruvalsfæribreytan %1 verður að vera texti sem er ekki tómur.';
        PriceWriteDeniedErr: Label 'Permission denied to update item unit price.', Comment = 'is-IS=Heimild hafnað til að uppfæra einingarverð vöru.';

    /// <summary>Runs within the owning codeunit-run transaction; refuses unsupported selections, native permissions and field restrictions before any validation.</summary>
    procedure UpdateCost(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Lookup: Codeunit "Document Lookup ori";
        Reader: Codeunit "Request Value Reader ori";
        Request: JsonObject;
        Response: JsonObject;
        Before: JsonObject;
        Warnings: JsonArray;
        Token: JsonToken;
        ExpectedMethod: Text;
        MethodName: Text;
        Serialized: Text;
        UnitCost: Decimal;
        LastDirectCost: Decimal;
        StandardCost: Decimal;
        AllowBlocked: Boolean;
    begin
        if not Item.WritePermission() then
            Error(CostWriteDeniedErr);
        Request := Argument.GetRequestJson();
        if (Argument.Subject = '') and not Request.Contains('itemNo') and not Request.Contains('itemId') and
           not Request.Contains('id') and not Request.Contains('systemId') and not Request.Contains('recordSystemId') and not Request.Contains('tableView')
        then
            Error(SelectionErr);
        if not Request.Contains('unitCost') and not Request.Contains('lastDirectCost') and not Request.Contains('standardCost') then
            Error(NoFieldsErr);
        if not Reader.TryReadBoolean(Argument, Request, 'allowBlocked', false, AllowBlocked) then
            exit;
        if Request.Contains('unitCost') then
            if not Reader.TryReadDecimal(Argument, Request, 'unitCost', true, UnitCost) then
                exit;
        if Request.Contains('lastDirectCost') then
            if not Reader.TryReadDecimal(Argument, Request, 'lastDirectCost', true, LastDirectCost) then
                exit;
        if Request.Contains('standardCost') then
            if not Reader.TryReadDecimal(Argument, Request, 'standardCost', true, StandardCost) then
                exit;
        if Request.Get('expectedCostingMethod', Token) then begin
            Token.WriteTo(Serialized);
            if not Token.IsValue() or not Serialized.StartsWith('"') then
                Error(TextErr);
            ExpectedMethod := Token.AsValue().AsText();
        end;
        Item.LockTable();
        if not Lookup.FindItemRange(Argument, Item) then
            exit;
        if Item.Count() <> 1 then
            Error(SelectionErr);
        Item.FindFirst();
        if Item."Costing Method" = Item."Costing Method"::Standard then
            Error(StandardErr);
        if Item.Blocked and not AllowBlocked then
            Error(BlockedErr, Item."No.");
        MethodName := Item."Costing Method".Names().Get(Item."Costing Method".Ordinals().IndexOf(Item."Costing Method".AsInteger()));
        if Request.Contains('expectedCostingMethod') and (UpperCase(ExpectedMethod) <> UpperCase(MethodName)) then
            Error(MethodErr, MethodName);
        if Request.Contains('unitCost') then
            CheckField(Reader, Item.FieldNo("Unit Cost"));
        if Request.Contains('lastDirectCost') then
            CheckField(Reader, Item.FieldNo("Last Direct Cost"));
        if Request.Contains('standardCost') then
            CheckField(Reader, Item.FieldNo("Standard Cost"));
        Before := CostFields(Item);
        if Request.Contains('lastDirectCost') then
            Item.Validate("Last Direct Cost", LastDirectCost);
        if Request.Contains('standardCost') then
            Item.Validate("Standard Cost", StandardCost);
        if Request.Contains('unitCost') then
            Item.Validate("Unit Cost", UnitCost);
        Item.Modify(true);
        Response.Add('status', 'Success');
        Response.Add('itemNo', Item."No.");
        Response.Add('itemId', Format(Item.SystemId, 0, 4));
        Response.Add('costingMethod', MethodName);
        Response.Add('before', Before);
        Response.Add('after', CostFields(Item));
        Response.Add('warnings', Warnings);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Checks parameters and permissions before Validate/Modify; caller owns the Codeunit.Run rollback boundary.</summary>
    procedure UpdatePrice(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Lookup: Codeunit "Document Lookup ori";
        Reader: Codeunit "Request Value Reader ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ParameterName: Text;
        Serialized: Text;
        UnitPrice: Decimal;
        PreviousPrice: Decimal;
        AllowBlocked: Boolean;
        HasSelection: Boolean;
    begin
        if not Item.WritePermission() then
            Error(PriceWriteDeniedErr);
        Request := Argument.GetRequestJson();
        HasSelection := Argument.Subject <> '';
        foreach ParameterName in Request.Keys() do
            case ParameterName of
                'itemNo', 'itemId', 'id', 'systemId', 'recordSystemId', 'tableView':
                    begin
                        Request.Get(ParameterName, Token);
                        Token.WriteTo(Serialized);
                        if not Token.IsValue() or not Serialized.StartsWith('"') then
                            Error(IdentifierErr, ParameterName);
                        if Token.AsValue().AsText().Trim() = '' then
                            Error(IdentifierErr, ParameterName);
                        HasSelection := true;
                    end;
                'unitPrice', 'allowBlocked':
                    ;
                else
                    Error(ParameterErr, ParameterName);
            end;
        if not HasSelection then
            Error(SelectionErr);
        if not Reader.TryReadDecimal(Argument, Request, 'unitPrice', true, UnitPrice) then
            exit;
        if not Reader.TryReadBoolean(Argument, Request, 'allowBlocked', Request.Contains('allowBlocked'), AllowBlocked) then
            exit;
        if Reader.IsFieldWriteRestricted(Database::Item, Item.FieldNo("Unit Price")) then
            Error(PriceWriteDeniedErr);
        Item.LockTable();
        if not Lookup.FindItemRange(Argument, Item) then
            exit;
        if Item.Count() <> 1 then
            Error(SelectionErr);
        Item.FindFirst();
        if Item.Blocked and not AllowBlocked then
            Error(BlockedErr, Item."No.");
        PreviousPrice := Item."Unit Price";
        Item.Validate("Unit Price", UnitPrice);
        Item.Modify(true);
        Response.Add('status', 'Success');
        Response.Add('messageType', 'Inventory.Price.Update');
        Response.Add('itemNo', Item."No.");
        Response.Add('itemId', Format(Item.SystemId, 0, 4));
        Response.Add('previousUnitPrice', PreviousPrice);
        Response.Add('unitPrice', Item."Unit Price");
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CheckField(Reader: Codeunit "Request Value Reader ori"; FieldNo: Integer)
    begin
        if Reader.IsFieldWriteRestricted(Database::Item, FieldNo) then
            Error(FieldDeniedErr, FieldNo);
    end;

    local procedure CostFields(Item: Record Item) Fields: JsonObject
    begin
        Fields.Add('unitCost', Item."Unit Cost");
        Fields.Add('lastDirectCost', Item."Last Direct Cost");
        Fields.Add('standardCost', Item."Standard Cost");
    end;
}
