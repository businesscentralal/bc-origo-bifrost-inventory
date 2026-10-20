namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Blocks only dedicated Item cost/price fields in generic writers; unrelated Item and journal fields remain available.</summary>
codeunit 10076838 "Inventory Cost Data Guard ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictCostFields(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    var
        Item: Record Item;
    begin
        if TableNo = Database::Item then
            if FieldNo in [Item.FieldNo("Unit Cost"), Item.FieldNo("Standard Cost"), Item.FieldNo("Last Direct Cost"), Item.FieldNo("Unit Price")] then
                IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure HintCostFields(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        Item: Record Item;
    begin
        if TableNo <> Database::Item then
            exit;
        if FieldNo in [Item.FieldNo("Unit Cost"), Item.FieldNo("Standard Cost"), Item.FieldNo("Last Direct Cost")] then
            Hint := 'Inventory.Cost.Update; Inventory.Revaluation.Post for Standard-costed items.';
        if FieldNo = Item.FieldNo("Unit Price") then
            Hint := 'Inventory.Price.Update';
    end;
}
