namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;

/// <summary>Reads direct-transfer posting settings across the BC 28 option and BC 29 enum.</summary>
codeunit 10076953 "Direct Transfer Setup ori"
{
    Access = Internal;

    /// <summary>Returns true when setup chooses one posted direct-transfer document.</summary>
    procedure PostsSingleDocument(TransferHeader: Record "Transfer Header"): Boolean
    var
        InventorySetup: Record "Inventory Setup";
        HeaderRef: RecordRef;
        PostingField: FieldRef;
        Ordinal: Integer;
    begin
        HeaderRef.GetTable(TransferHeader);
        if HeaderRef.FieldExist(5858) then begin
            PostingField := HeaderRef.Field(5858);
            Ordinal := PostingField.Value();
            exit(Ordinal = 20);
        end;
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
        if SetupRef.FieldExist(5857) then
            if Choice = 20 then
                Choice := 1
            else
                Choice := 0;
    end;

    /// <summary>Changes the available native field on the passed record buffer; does not save it.</summary>
    procedure SetPostingChoice(var InventorySetup: Record "Inventory Setup"; Choice: Integer)
    var
        SetupRef: RecordRef;
        PostingField: FieldRef;
    begin
        SetupRef.GetTable(InventorySetup);
        PostingField := SetupRef.Field(GetPostingFieldNo(SetupRef));
        if SetupRef.FieldExist(5857) then
            if Choice = 1 then
                PostingField.Value := 20
            else
                PostingField.Value := 10
        else
            PostingField.Value := Choice;
        SetupRef.SetTable(InventorySetup);
    end;

    local procedure GetPostingFieldNo(SetupRef: RecordRef): Integer
    begin
        // BC 28 option: 0/1. BC 29 enum: 0 blank, 10 shipment/receipt, 20 direct transfer.
        if SetupRef.FieldExist(5857) then
            exit(5857);
        exit(5855);
    end;
}
