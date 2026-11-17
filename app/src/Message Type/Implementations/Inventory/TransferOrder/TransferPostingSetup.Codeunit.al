namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;

/// <summary>Reads direct-transfer posting mode on both BC 28 and BC 29 without obsolete field references.</summary>
codeunit 10077025 "Transfer Posting Setup ori"
{
    Access = Internal;

    /// <summary>Returns true for the single direct-transfer document mode.</summary>
    procedure PostAsSingleDocument(InventorySetup: Record "Inventory Setup"): Boolean
    var
        SetupReference: RecordRef;
        PostingField: FieldRef;
        PostingMode: Integer;
    begin
        SetupReference.GetTable(InventorySetup);
        // BC 29 replaces option field 5855 (0/1) with enum field 5857 (10/20).
        if SetupReference.FieldExist(5857) then begin
            PostingField := SetupReference.Field(5857);
            PostingMode := PostingField.Value();
            exit(PostingMode = 20);
        end;
        PostingField := SetupReference.Field(5855);
        PostingMode := PostingField.Value();
        exit(PostingMode = 1);
    end;
}
