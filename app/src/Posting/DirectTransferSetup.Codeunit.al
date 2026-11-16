namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;

/// <summary>Reads direct-transfer posting settings across the BC 28 option and BC 29 enum.</summary>
codeunit 10076933 "Direct Transfer Setup ori"
{
    Access = Internal;

    /// <summary>Returns true when setup chooses one posted direct-transfer document.</summary>
    procedure PostsSingleDocument(): Boolean
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.Get();
        exit(GetPostingChoice(InventorySetup) = 1);
    end;

    /// <summary>Reads the available native field without depending on an obsolete option.</summary>
    procedure GetPostingChoice(InventorySetup: Record "Inventory Setup") Choice: Integer
    var
        SetupRef: RecordRef;
        PostingField: FieldRef;
    begin
        SetupRef.GetTable(InventorySetup);
        PostingField := SetupRef.Field(GetPostingFieldNo(SetupRef));
        Choice := PostingField.Value();
    end;

    /// <summary>Changes the available native field on the passed record buffer; does not save it.</summary>
    procedure SetPostingChoice(var InventorySetup: Record "Inventory Setup"; Choice: Integer)
    var
        SetupRef: RecordRef;
        PostingField: FieldRef;
    begin
        SetupRef.GetTable(InventorySetup);
        PostingField := SetupRef.Field(GetPostingFieldNo(SetupRef));
        PostingField.Value := Choice;
        SetupRef.SetTable(InventorySetup);
    end;

    local procedure GetPostingFieldNo(SetupRef: RecordRef): Integer
    begin
        // Both native fields use ordinal 0 for shipment/receipt and 1 for a single document.
        if SetupRef.FieldExist(5857) then
            exit(5857);
        exit(5855);
    end;
}
