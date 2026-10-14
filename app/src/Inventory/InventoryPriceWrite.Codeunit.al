namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Updates exactly one Item Unit Price through native validation and caller field permissions.</summary>
codeunit 70013438 "Inventory Price Write ori"
{
    Access = Internal;

    var
        SelectionErr: Label 'Select exactly one item using subject, an item identifier or tableView.', Comment = 'is-IS=Veldu nákvæmlega eina vöru með subject, vöruauðkenni eða tableView.';
        ParameterErr: Label 'Unsupported price parameter %1.', Comment = '%1 = parameter name; is-IS=Verðfæribreytan %1 er ekki studd.';
        IdentifierErr: Label 'Item selection parameter %1 must be nonempty text.', Comment = '%1 = parameter name; is-IS=Vöruvalsfæribreytan %1 verður að vera texti sem er ekki tómur.';
        WriteDeniedErr: Label 'Permission denied to update item unit price.', Comment = 'is-IS=Heimild hafnað til að uppfæra einingarverð vöru.';
        BlockedErr: Label 'Item %1 is blocked. Set allowBlocked=true only when the blocked-item change is intended.', Comment = '%1 = item number; is-IS=Vara %1 er lokuð. Stilltu allowBlocked=true aðeins ef breyting á lokaðri vöru er fyrirhuguð.';

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
            Error(WriteDeniedErr);
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
            Error(WriteDeniedErr);
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
}
