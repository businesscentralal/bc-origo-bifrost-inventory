namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Read-only projections of native tracking and reservation records with explicit source identities.</summary>
codeunit 10036916 "Inventory Tracking Read ori"
{
    Access = Internal;

    var
        Resolver: Codeunit "Inventory Source Resolve ori";
        LocationFilter: Text;
        LocationCode: Text;
        VariantCode: Text;
        LotNo: Text;
        SerialNo: Text;
        PackageNo: Text;
        Skip: Integer;
        Take: Integer;
        InvalidFilterErr: Label 'The tracking filter or paging value is invalid.', Comment = 'is-IS=Rakningarsía eða síðugildi er ógilt.';
        NoTrackingErr: Label 'No item tracking found matching the specified criteria.', Comment = 'is-IS=Engin vörurakning fannst sem passar við tilgreind skilyrði.';
        PermissionErr: Label 'Permission denied for the requested tracking data.', Comment = 'is-IS=Heimild hafnað fyrir umbeðin rakningargögn.';

    /// <summary>Reads tracked document positions or open item positions without changing ledger or tracking tables.</summary>
    procedure ReadTracking(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Entry: Record "Reservation Entry";
        Ledger: Record "Item Ledger Entry";
        Specification: Record "Tracking Specification";
        SourceSpec: Record "Tracking Specification";
        ItemResolve: Codeunit "Item Attribute Resolve ori";
        SourceRef: RecordRef;
        Direction: Enum "Transfer Direction";
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        Row: JsonObject;
        IsSource: Boolean;
        TotalQuantity: Decimal;
    begin
        Request := Argument.GetRequestJson();
        if not CheckRead(Argument, Database::Item) or not CheckRead(Argument, Database::"Item Tracking Code") or not ReadFilters(Argument, Request) then
            exit;
        AddSubjectSource(Argument, Request);
        IsSource := Request.Contains('source') or Request.Contains('documentType');
        if IsSource then begin
            if not Resolver.ResolveDocument(Argument, Request, false, SourceRef, SourceSpec, Direction) then
                exit;
            if not CheckRead(Argument, Database::"Reservation Entry") or not CheckRead(Argument, Database::"Tracking Specification") then
                exit;
            Entry.TransferFields(SourceSpec);
            Entry.SetPointerFilter();
            Specification.SetSourceFilter(SourceSpec."Source Type", SourceSpec."Source Subtype", SourceSpec."Source ID", SourceSpec."Source Ref. No.", true);
            Specification.SetSourceFilter(SourceSpec."Source Batch Name", SourceSpec."Source Prod. Order Line");
            Item."No." := SourceSpec."Item No.";
            AddSource(Response, SourceSpec."Source Type", SourceSpec."Source Subtype", SourceSpec."Source ID", SourceSpec."Source Batch Name", SourceSpec."Source Prod. Order Line", SourceSpec."Source Ref. No.");
        end else begin
            if not CheckRead(Argument, Database::Item) or not CheckRead(Argument, Database::"Item Ledger Entry") or not CheckRead(Argument, Database::"Reservation Entry") then
                exit;
            if not ItemResolve.ResolveSingleItem(Argument, Item) then
                exit;
            Ledger.SetRange("Item No.", Item."No.");
            Ledger.SetFilter("Remaining Quantity", '<>0');
            FilterLedger(Ledger, Request);
            Ledger.SetLoadFields("Entry No.", "Item No.", "Lot No.", "Serial No.", "Package No.", "Location Code", "Variant Code", "Remaining Quantity", "Expiration Date");
            Ledger.ReadIsolation(IsolationLevel::ReadCommitted);
            if Ledger.FindSet() then
                repeat
                    if HasTracking(Ledger."Lot No.", Ledger."Serial No.", Ledger."Package No.") then begin
                        Row := TrackingRow('ItemLedgerEntry', Ledger."Entry No.", Ledger."Item No.", Ledger."Lot No.", Ledger."Serial No.", Ledger."Package No.", Ledger."Location Code", Ledger."Variant Code", Ledger."Remaining Quantity", Ledger."Expiration Date");
                        Lines.Add(Row);
                        TotalQuantity += Ledger."Remaining Quantity";
                    end;
                until Ledger.Next() = 0;
            Entry.SetRange("Item No.", Item."No.");
            Entry.SetFilter("Quantity (Base)", '<>0');
        end;
        FilterReservation(Entry, Request);
        Entry.SetLoadFields("Entry No.", "Item No.", "Lot No.", "Serial No.", "Package No.", "Location Code", "Variant Code", Quantity, "Quantity (Base)", "Expiration Date", Positive, "Reservation Status", "Source Type", "Source Subtype", "Source ID", "Source Batch Name", "Source Prod. Order Line", "Source Ref. No.");
        Entry.ReadIsolation(IsolationLevel::ReadCommitted);
        if Entry.FindSet() then
            repeat
                if HasTracking(Entry."Lot No.", Entry."Serial No.", Entry."Package No.") then begin
                    Row := TrackingRow('ReservationEntry', Entry."Entry No.", Entry."Item No.", Entry."Lot No.", Entry."Serial No.", Entry."Package No.", Entry."Location Code", Entry."Variant Code", Entry."Quantity (Base)", Entry."Expiration Date");
                    Row.Add('positive', Entry.Positive);
                    Row.Add('reservationStatus', Entry."Reservation Status".Names().Get(Entry."Reservation Status".Ordinals().IndexOf(Entry."Reservation Status".AsInteger())));
                    AddSource(Row, Entry."Source Type", Entry."Source Subtype", Entry."Source ID", Entry."Source Batch Name", Entry."Source Prod. Order Line", Entry."Source Ref. No.");
                    Lines.Add(Row);
                    TotalQuantity += Entry."Quantity (Base)";
                end;
            until Entry.Next() = 0;
        if IsSource then begin
            FilterSpecification(Specification, Request);
            Specification.SetLoadFields("Entry No.", "Item No.", "Lot No.", "Serial No.", "Package No.", "Location Code", "Variant Code", "Quantity (Base)", "Expiration Date", "Quantity Handled (Base)", "Quantity Invoiced (Base)");
            Specification.ReadIsolation(IsolationLevel::ReadCommitted);
            if Specification.FindSet() then
                repeat
                    if HasTracking(Specification."Lot No.", Specification."Serial No.", Specification."Package No.") then begin
                        Row := TrackingRow('TrackingSpecification', Specification."Entry No.", Specification."Item No.", Specification."Lot No.", Specification."Serial No.", Specification."Package No.", Specification."Location Code", Specification."Variant Code", Specification."Quantity (Base)", Specification."Expiration Date");
                        Row.Add('quantityHandledBase', Specification."Quantity Handled (Base)");
                        Row.Add('quantityInvoicedBase', Specification."Quantity Invoiced (Base)");
                        Lines.Add(Row);
                        TotalQuantity += Specification."Quantity (Base)";
                    end;
                until Specification.Next() = 0;
        end;
        if Lines.Count() = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NoTrackingErr, '', '', '', '');
            exit;
        end;
        Response.Add('itemNo', Item."No.");
        Response.Add('quantityBase', TotalQuantity);
        RespondPage(Argument, Response, 'trackingLines', Lines);
    end;

    /// <summary>Groups open posted stock by all tracking dimensions and subtracts only its native reserved quantity.</summary>
    procedure ReadAvailability(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        ItemResolve: Codeunit "Item Attribute Resolve ori";
        Request: JsonObject;
        Response: JsonObject;
        Rows: JsonArray;
    begin
        Request := Argument.GetRequestJson();
        if not CheckRead(Argument, Database::Item) or not CheckRead(Argument, Database::"Item Tracking Code") or
           not CheckRead(Argument, Database::"Item Ledger Entry") or not CheckRead(Argument, Database::"Reservation Entry") or
           not ReadFilters(Argument, Request)
        then
            exit;
        if not ItemResolve.ResolveSingleItem(Argument, Item) then
            exit;
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.SetRange(Open, true);
        Ledger.SetRange(Positive, true);
        Ledger.SetFilter("Remaining Quantity", '>0');
        FilterLedger(Ledger, Request);
        Ledger.SetLoadFields("Entry No.", "Item No.", "Lot No.", "Serial No.", "Package No.", "Location Code", "Variant Code", "Remaining Quantity", "Expiration Date");
        Ledger.ReadIsolation(IsolationLevel::ReadCommitted);
        Ledger.SetAutoCalcFields("Reserved Quantity");
        AggregateAvailability(Ledger, Rows);
        Response.Add('itemNo', Item."No.");
        RespondPage(Argument, Response, 'availability', Rows);
    end;

    /// <summary>Projects filtered native stock, blanking grouped dates on disagreement; temporary records support impossible-state defensive tests.</summary>
    procedure AggregateAvailability(var Ledger: Record "Item Ledger Entry"; var Rows: JsonArray)
    var
        Row: JsonObject;
        KeyParts: JsonArray;
        Token: JsonToken;
        IndexByKey: Dictionary of [Text, Integer];
        GroupKey: Text;
        Expiration: Text;
        Index: Integer;
        Inventory: Decimal;
        Reserved: Decimal;
    begin
        Clear(Rows);
        if Ledger.FindSet() then
            repeat
                if HasTracking(Ledger."Lot No.", Ledger."Serial No.", Ledger."Package No.") then begin
                    Clear(KeyParts);
                    KeyParts.Add(Ledger."Location Code");
                    KeyParts.Add(Ledger."Variant Code");
                    KeyParts.Add(Ledger."Lot No.");
                    KeyParts.Add(Ledger."Serial No.");
                    KeyParts.Add(Ledger."Package No.");
                    KeyParts.WriteTo(GroupKey);
                    Expiration := ExpirationText(Ledger."Item No.", Ledger."Expiration Date");
                    if IndexByKey.Get(GroupKey, Index) then begin
                        Rows.Get(Index, Token);
                        Row := Token.AsObject();
                        Row.Get('inventory', Token);
                        Inventory := Token.AsValue().AsDecimal() + Ledger."Remaining Quantity";
                        Row.Get('qtyReserved', Token);
                        Reserved := Token.AsValue().AsDecimal() + Ledger."Reserved Quantity";
                        Row.Replace('inventory', Inventory);
                        Row.Replace('remainingQuantity', Inventory);
                        Row.Replace('qtyReserved', Reserved);
                        Row.Replace('availableQuantity', Inventory - Reserved);
                        Row.Get('expirationDate', Token);
                        if Token.AsValue().AsText() <> Expiration then
                            Row.Replace('expirationDate', '');
                        Rows.Set(Index, Row);
                    end else begin
                        Clear(Row);
                        Row.Add('lotNo', Ledger."Lot No.");
                        Row.Add('serialNo', Ledger."Serial No.");
                        Row.Add('packageNo', Ledger."Package No.");
                        Row.Add('locationCode', Ledger."Location Code");
                        Row.Add('variantCode', Ledger."Variant Code");
                        Row.Add('expirationDate', Expiration);
                        Row.Add('inventory', Ledger."Remaining Quantity");
                        Row.Add('remainingQuantity', Ledger."Remaining Quantity");
                        Row.Add('qtyReserved', Ledger."Reserved Quantity");
                        Row.Add('availableQuantity', Ledger."Remaining Quantity" - Ledger."Reserved Quantity");
                        IndexByKey.Add(GroupKey, Rows.Count());
                        Rows.Add(Row);
                    end;
                end;
            until Ledger.Next() = 0;
    end;

    local procedure AddSubjectSource(Argument: Record "Message Argument ori"; var Request: JsonObject)
    var
        SourceRef: RecordRef;
        Id: Guid;
        TypeName: Text;
        Types: List of [Text];
        Source: JsonObject;
    begin
        if Request.Contains('source') or Request.Contains('documentType') or (Argument.Subject = '') then
            exit;
        if not Evaluate(Id, Argument.Subject) then
            exit;
        Types.Add('SalesLine');
        Types.Add('PurchaseLine');
        Types.Add('TransferLine');
        foreach TypeName in Types do begin
            SourceRef.Open(Resolver.SourceTableNo(TypeName));
            SourceRef.SetLoadFields(SourceRef.SystemIdNo());
            if SourceRef.ReadPermission() then
                if SourceRef.GetBySystemId(Id) then begin
                    Source.Add('type', TypeName);
                    Source.Add('systemId', Format(Id, 0, 4));
                    Request.Add('source', Source);
                    exit;
                end;
            SourceRef.Close();
        end;
    end;

    local procedure ReadFilters(var Argument: Record "Message Argument ori"; Request: JsonObject): Boolean
    begin
        Skip := 0;
        Take := 100;
        if not Resolver.ReadText(Argument, Request, 'locationFilter', false, LocationFilter) or
           not Resolver.ReadText(Argument, Request, 'locationCode', false, LocationCode) or
           not Resolver.ReadText(Argument, Request, 'variantCode', false, VariantCode) or
           not Resolver.ReadText(Argument, Request, 'lotNo', false, LotNo) or
           not Resolver.ReadText(Argument, Request, 'serialNo', false, SerialNo) or
           not Resolver.ReadText(Argument, Request, 'packageNo', false, PackageNo)
        then
            exit(false);
        if (StrLen(LocationCode) > 10) or (StrLen(VariantCode) > 10) or (StrLen(LotNo) > 50) or (StrLen(SerialNo) > 50) or (StrLen(PackageNo) > 50) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFilterErr, '', '', '', '');
            exit(false);
        end;
        if Request.Contains('skip') then
            if not ReadInteger(Argument, Request, 'skip', 0, 2147483647, Skip) then
                exit(false);
        if Request.Contains('take') then
            if not ReadInteger(Argument, Request, 'take', 1, 10000, Take) then
                exit(false);
        exit(true);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Minimum: Integer; Maximum: Integer; var Value: Integer): Boolean
    var
        Reader: Codeunit "Request Value Reader ori";
        Number: Decimal;
    begin
        if not Reader.TryReadDecimal(Argument, Request, KeyName, true, Number) then
            exit(false);
        if (Number < Minimum) or (Number > Maximum) or (Number <> Round(Number, 1)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFilterErr, KeyName, Format(Number, 0, 9), IntegerRangeExpectedLbl, '');
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure FilterLedger(var Entry: Record "Item Ledger Entry"; Request: JsonObject)
    begin
        if LocationFilter <> '' then
            Entry.SetFilter("Location Code", LocationFilter);
        // Exact location and filter are intersected, never silently substituted for each other.
        Entry.FilterGroup(2);
        if Request.Contains('locationCode') then
            Entry.SetRange("Location Code", LocationCode);
        Entry.FilterGroup(0);
        if Request.Contains('variantCode') then
            Entry.SetRange("Variant Code", VariantCode);
        if Request.Contains('lotNo') then
            Entry.SetRange("Lot No.", LotNo);
        if Request.Contains('serialNo') then
            Entry.SetRange("Serial No.", SerialNo);
        if Request.Contains('packageNo') then
            Entry.SetRange("Package No.", PackageNo);
    end;

    local procedure FilterReservation(var Entry: Record "Reservation Entry"; Request: JsonObject)
    begin
        if LocationFilter <> '' then
            Entry.SetFilter("Location Code", LocationFilter);
        Entry.FilterGroup(2);
        if Request.Contains('locationCode') then
            Entry.SetRange("Location Code", LocationCode);
        Entry.FilterGroup(0);
        if Request.Contains('variantCode') then
            Entry.SetRange("Variant Code", VariantCode);
        if Request.Contains('lotNo') then
            Entry.SetRange("Lot No.", LotNo);
        if Request.Contains('serialNo') then
            Entry.SetRange("Serial No.", SerialNo);
        if Request.Contains('packageNo') then
            Entry.SetRange("Package No.", PackageNo);
    end;

    local procedure FilterSpecification(var Entry: Record "Tracking Specification"; Request: JsonObject)
    begin
        if LocationFilter <> '' then
            Entry.SetFilter("Location Code", LocationFilter);
        Entry.FilterGroup(2);
        if Request.Contains('locationCode') then
            Entry.SetRange("Location Code", LocationCode);
        Entry.FilterGroup(0);
        if Request.Contains('variantCode') then
            Entry.SetRange("Variant Code", VariantCode);
        if Request.Contains('lotNo') then
            Entry.SetRange("Lot No.", LotNo);
        if Request.Contains('serialNo') then
            Entry.SetRange("Serial No.", SerialNo);
        if Request.Contains('packageNo') then
            Entry.SetRange("Package No.", PackageNo);
    end;

    local procedure CheckRead(var Argument: Record "Message Argument ori"; TableNo: Integer): Boolean
    var
        SourceRef: RecordRef;
    begin
        SourceRef.Open(TableNo);
        if SourceRef.ReadPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', '');
        exit(false);
    end;

    local procedure HasTracking(Lot: Text; Serial: Text; Package: Text): Boolean
    begin
        exit((Lot <> '') or (Serial <> '') or (Package <> ''));
    end;

    local procedure TrackingRow(Source: Text; EntryNo: Integer; ItemNo: Code[20]; Lot: Code[50]; Serial: Code[50]; Package: Code[50]; Location: Code[10]; Variant: Code[10]; Quantity: Decimal; ExpirationDate: Date) Row: JsonObject
    begin
        Row.Add('source', Source);
        Row.Add('entryNo', EntryNo);
        Row.Add('itemNo', ItemNo);
        Row.Add('lotNo', Lot);
        Row.Add('serialNo', Serial);
        Row.Add('packageNo', Package);
        Row.Add('locationCode', Location);
        Row.Add('variantCode', Variant);
        Row.Add('quantityBase', Quantity);
        Row.Add('expirationDate', ExpirationText(ItemNo, ExpirationDate));
    end;

    local procedure AddSource(var Row: JsonObject; TableNo: Integer; Subtype: Integer; DocumentNo: Code[20]; Batch: Code[10]; ProdLine: Integer; LineNo: Integer)
    begin
        Row.Add('sourceType', Resolver.SourceTypeName(TableNo));
        Row.Add('sourceTableNo', TableNo);
        Row.Add('sourceSubtype', Subtype);
        Row.Add('documentType', Resolver.DocumentTypeName(TableNo, Subtype));
        Row.Add('sourceId', DocumentNo);
        Row.Add('documentNo', DocumentNo);
        Row.Add('sourceBatchName', Batch);
        Row.Add('sourceProdOrderLine', ProdLine);
        Row.Add('sourceRefNo', LineNo);
        Row.Add('lineNo', LineNo);
    end;

    local procedure ExpirationText(ItemNo: Code[20]; Value: Date): Text
    var
        Item: Record Item;
        TrackingCode: Record "Item Tracking Code";
    begin
        Item.SetLoadFields("Item Tracking Code");
        Item.ReadIsolation(IsolationLevel::ReadCommitted);
        if not Item.Get(ItemNo) then
            exit('');
        TrackingCode.SetLoadFields("Use Expiration Dates");
        TrackingCode.ReadIsolation(IsolationLevel::ReadCommitted);
        if not TrackingCode.Get(Item."Item Tracking Code") then
            exit('');
        if not TrackingCode."Use Expiration Dates" then
            exit('');
        exit(DateText(Value));
    end;

    local procedure DateText(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure RespondPage(var Argument: Record "Message Argument ori"; Response: JsonObject; PropertyName: Text; Rows: JsonArray)
    var
        PageRows: JsonArray;
        Token: JsonToken;
        Index: Integer;
    begin
        Index := Skip;
        while (Index < Rows.Count()) and (PageRows.Count() < Take) do begin
            Rows.Get(Index, Token);
            PageRows.Add(Token);
            Index += 1;
        end;
        Response.Add('status', 'Success');
        Response.Add('noOfLines', PageRows.Count());
        Response.Add('totalNoOfLines', Rows.Count());
        Response.Add(PropertyName, PageRows);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
    var
        IntegerRangeExpectedLbl: Label 'integer in range', Comment = 'is-IS=heiltala innan marka';
}
