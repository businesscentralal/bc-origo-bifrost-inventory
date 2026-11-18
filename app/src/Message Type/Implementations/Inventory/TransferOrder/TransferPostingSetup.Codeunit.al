namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;

/// <summary>Reads direct-transfer posting mode on both BC 28 and BC 29 without obsolete field references.</summary>
codeunit 10077025 "Transfer Posting Setup ori"
{
    Access = Internal;

    /// <summary>Uses the existing order's BC 29 posting mode, with Inventory Setup as the BC 28 fallback.</summary>
    procedure PostAsSingleDocument(TransferHeader: Record "Transfer Header"): Boolean
    var
        InventorySetup: Record "Inventory Setup";
        HeaderReference: RecordRef;
        PostingField: FieldRef;
        PostingMode: Integer;
    begin
        HeaderReference.GetTable(TransferHeader);
        if HeaderReference.FieldExist(5858) then begin
            PostingField := HeaderReference.Field(5858);
            PostingMode := PostingField.Value();
            exit(PostingMode = 20);
        end;
        InventorySetup.Get();
        exit(PostAsSingleDocument(InventorySetup));
    end;

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
