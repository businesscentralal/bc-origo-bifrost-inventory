namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Planning;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
using Origo.Bifrost;

/// <summary>Read-only projections of native tracking and reservation records with explicit source identities; also resolves the sales, purchase, transfer and other tracking sources.</summary>
codeunit 10076841 "Inventory Tracking Read ori"
{
    Access = Internal;

    var
        LocationFilter: Text;
        LocationCode: Text;
        VariantCode: Text;
        LotNo: Text;
        SerialNo: Text;
        PackageNo: Text;
        Skip: Integer;
        Take: Integer;
        InvalidFilterErr: Label 'The tracking filter or paging value is invalid.', Comment = 'is-IS=Rakningarsía eða síðugildi er ógilt.';
        TrackingExpectedTxt: Label 'Existing item tracking for the selected item or source line.', Comment = 'is-IS=Vörurakning sem er til fyrir valda vöru eða upprunalínu.';
        TrackingNextStepTxt: Label 'Check the item, source and filters; assign tracking to the source line before reading it.', Comment = 'is-IS=Athugaðu vöru, uppruna og síur; úthlutaðu rakningu á upprunalínuna áður en hún er lesin.';
        NoTrackingErr: Label 'No item tracking found matching the specified criteria.', Comment = 'is-IS=Engin vörurakning fannst sem passar við tilgreind skilyrði.';
        PermissionErr: Label 'Permission denied for the requested tracking data.', Comment = 'is-IS=Heimild hafnað fyrir umbeðin rakningargögn.';
        MissingSelectionErr: Label 'Select an item or a source line.', Comment = 'is-IS=Veldu vöru eða upprunalínu.';
        SelectionExpectedTxt: Label 'A non-empty item number in data.itemNo, an item SystemId, a tableView, or a source line.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo, SystemId vöru, tableView eða upprunalína.';
        SelectionNextStepTxt: Label 'Send data.itemNo, or select a sales, purchase or transfer line in data.source.', Comment = 'is-IS=Sendu data.itemNo eða veldu sölu-, innkaupa- eða flutningslínu í data.source.';

    /// <summary>Reads tracked document positions or open item positions without changing ledger or tracking tables.</summary>
    procedure ReadTracking(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Entry: Record "Reservation Entry";
        Ledger: Record "Item Ledger Entry";
        Specification: Record "Tracking Specification";
        SourceSpec: Record "Tracking Specification";
        TransferLine: Record "Transfer Line";
        ItemResolve: Codeunit "Item Attribute Resolve ori";
        TransferReserve: Codeunit "Transfer Line-Reserve";
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
            if not ResolveDocument(Argument, Request, false, SourceRef, SourceSpec, Direction) then
                exit;
            if not CheckRead(Argument, Database::"Reservation Entry") or not CheckRead(Argument, Database::"Tracking Specification") then
                exit;
            Entry.TransferFields(SourceSpec);
            Entry.SetPointerFilter();
            if (SourceRef.Number = Database::"Transfer Line") and (Direction = Direction::Inbound) then begin
                SourceRef.SetTable(TransferLine);
                // Native receipt tracking belongs to derived transfer lines after shipment.
                TransferReserve.FindInboundReservEntry(TransferLine, Entry);
            end;
            Specification.SetSourceFilter(SourceSpec."Source Type", SourceSpec."Source Subtype", SourceSpec."Source ID", SourceSpec."Source Ref. No.", true);
            Specification.SetSourceFilter(SourceSpec."Source Batch Name", SourceSpec."Source Prod. Order Line");
            Item."No." := SourceSpec."Item No.";
            AddSource(Response, SourceSpec."Source Type", SourceSpec."Source Subtype", SourceSpec."Source ID", SourceSpec."Source Batch Name", SourceSpec."Source Prod. Order Line", SourceSpec."Source Ref. No.");
        end else begin
            if not CheckRead(Argument, Database::Item) or not CheckRead(Argument, Database::"Item Ledger Entry") or not CheckRead(Argument, Database::"Reservation Entry") then
                exit;
            // Without a selector Foundation's item range is every item, and the first item would be read silently.
            if not HasItemSelection(Argument) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSelectionErr, 'itemNo', '', SelectionExpectedTxt, SelectionNextStepTxt);
                exit;
            end;
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
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NoTrackingErr, 'itemNo', Item."No.", TrackingExpectedTxt, TrackingNextStepTxt);
            exit;
        end;
        Response.Add('itemNo', Item."No.");
        Response.Add('quantityBase', TotalQuantity);
        RespondPage(Argument, Response, 'trackingLines', Lines);
    end;

    /// <summary>Tells whether the request selects an item: a subject, an item SystemId alias, a tableView or a non-blank itemNo.</summary>
    /// <param name="Argument">The message argument with the subject and the request.</param>
    /// <returns>True when Foundation's item selection has something to select by.</returns>
    procedure HasItemSelection(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
    begin
        if DelChr(Argument.Subject, '<>', ' ') <> '' then
            exit(true);
        Request := Argument.GetRequestJson();
        if Request.Contains('itemId') or Request.Contains('id') or Request.Contains('systemId') or Request.Contains('recordSystemId') or Request.Contains('tableView') then
            exit(true);
        if not Request.Get('itemNo', Token) then
            exit(false);
        if not Token.IsValue() then
            exit(true);
        if Token.AsValue().IsNull() then
            exit(false);
        exit(DelChr(Token.AsValue().AsText(), '<>', ' ') <> '');
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
            SourceRef.Open(SourceTableNo(TypeName));
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
        if not ReadText(Argument, Request, 'locationFilter', false, LocationFilter) or
           not ReadText(Argument, Request, 'locationCode', false, LocationCode) or
           not ReadText(Argument, Request, 'variantCode', false, VariantCode) or
           not ReadText(Argument, Request, 'lotNo', false, LotNo) or
           not ReadText(Argument, Request, 'serialNo', false, SerialNo) or
           not ReadText(Argument, Request, 'packageNo', false, PackageNo)
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
        Row.Add('sourceType', SourceTypeName(TableNo));
        Row.Add('sourceTableNo', TableNo);
        Row.Add('sourceSubtype', Subtype);
        Row.Add('documentType', DocumentTypeName(TableNo, Subtype));
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

    /// <summary>Resolves an explicit source object by type and SystemId, checking source permissions before use.</summary>
    procedure Resolve(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; NeedWrite: Boolean; var SourceRef: RecordRef; var Specification: Record "Tracking Specification"; var Direction: Enum "Transfer Direction"): Boolean
    var
        Source: JsonObject;
        Token: JsonToken;
        TypeName: Text;
        IdText: Text;
        DirectionText: Text;
        SourceId: Guid;
        TableNo: Integer;
        InvalidSourceErr: Label 'Specify %1 with a supported type and systemId.', Comment = '%1 = request property, is-IS=Tilgreindu %1 með studdri tegund og systemId.';
        MissingSourceErr: Label 'The requested source record does not exist.', Comment = 'is-IS=Umbeðin upprunafærsla er ekki til.';
        SourcePermissionErr: Label 'Permission denied for the source record.', Comment = 'is-IS=Heimild hafnað fyrir upprunafærsluna.';
    begin
        Clear(Specification);
        Direction := Direction::Outbound;
        if not Request.Get(KeyName, Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName, '', 'object', '');
            exit(false);
        end;
        if not Token.IsObject() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidSourceErr, KeyName), KeyName, '', 'object', '');
            exit(false);
        end;
        Source := Token.AsObject();
        if not ReadText(Argument, Source, 'type', true, TypeName) then
            exit(false);
        TableNo := SourceTableNo(TypeName);
        if TableNo = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.type', TypeName, '', '');
            exit(false);
        end;
        if not ReadText(Argument, Source, 'systemId', true, IdText) then
            exit(false);
        if not Evaluate(SourceId, IdText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.systemId', IdText, 'guid', '');
            exit(false);
        end;
        if not ReadText(Argument, Source, 'transferDirection', false, DirectionText) then
            exit(false);
        case DirectionText of
            '', 'Outbound':;
            'Inbound':
                Direction := Direction::Inbound;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidSourceErr, KeyName), KeyName + '.transferDirection', DirectionText, 'Outbound|Inbound', '');
                exit(false);
            end;
        end;
        SourceRef.Open(TableNo);
        if not SourceRef.ReadPermission() or (NeedWrite and (TableNo <> Database::"Item Ledger Entry") and not SourceRef.WritePermission()) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, SourcePermissionErr, KeyName, '', '', '');
            exit(false);
        end;
        // Full-record by native contract: InitFromSalesLine, InitFromPurchLine or InitFromTransLine consumes this record.
        if not SourceRef.GetBySystemId(SourceId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, MissingSourceErr, KeyName + '.systemId', IdText, '', '');
            exit(false);
        end;
        InitializeSpecification(SourceRef, Direction, Specification);
        exit(true);
    end;

    /// <summary>Resolves legacy document keys through the same permission-checked native source adapter.</summary>
    procedure ResolveDocument(var Argument: Record "Message Argument ori"; Request: JsonObject; NeedWrite: Boolean; var SourceRef: RecordRef; var Specification: Record "Tracking Specification"; var Direction: Enum "Transfer Direction"): Boolean
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        Reader: Codeunit "Request Value Reader ori";
        PermissionRef: RecordRef;
        DocumentType: Text;
        DocumentNo: Text;
        IdText: Text;
        TypeName: Text;
        Subtype: Integer;
        LineNo: Decimal;
        Found: Boolean;
        Source: JsonObject;
        SourceRequest: JsonObject;
        Token: JsonToken;
        DocumentErr: Label 'Specify a supported document type and an existing item line.', Comment = 'is-IS=Tilgreindu studda skjalategund og fyrirliggjandi vörulínu.';
        SourcePermissionErr: Label 'Permission denied for the source record.', Comment = 'is-IS=Heimild hafnað fyrir upprunafærsluna.';
    begin
        if Request.Contains('source') then
            exit(Resolve(Argument, Request, 'source', NeedWrite, SourceRef, Specification, Direction));
        if not ReadText(Argument, Request, 'documentType', true, DocumentType) then
            exit(false);
        case DocumentType of
            'Order', 'Sales.Order': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::Order.AsInteger();
            end;
            'Invoice', 'Sales.Invoice': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::Invoice.AsInteger();
            end;
            'Credit Memo', 'Sales.CreditMemo': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::"Credit Memo".AsInteger();
            end;
            'Return Order', 'Sales.ReturnOrder': begin
                TypeName := 'SalesLine';
                Subtype := SalesLine."Document Type"::"Return Order".AsInteger();
            end;
            'Purchase.Order': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::Order.AsInteger();
            end;
            'Purchase.Invoice': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::Invoice.AsInteger();
            end;
            'Purchase.CreditMemo': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::"Credit Memo".AsInteger();
            end;
            'Purchase.ReturnOrder': begin
                TypeName := 'PurchaseLine';
                Subtype := PurchaseLine."Document Type"::"Return Order".AsInteger();
            end;
            'Transfer.Order':
                TypeName := 'TransferLine';
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentErr, 'documentType', DocumentType, '', '');
                exit(false);
            end;
        end;
        Source.Add('type', TypeName);
        if not ReadText(Argument, Request, 'systemId', false, IdText) then
            exit(false);
        if IdText = '' then begin
            if not ReadText(Argument, Request, 'documentNo', true, DocumentNo) then
                exit(false);
            if not Reader.TryReadDecimal(Argument, Request, 'lineNo', true, LineNo) then
                exit(false);
            if (StrLen(DocumentNo) > 20) or (LineNo <= 0) or (LineNo > 2147483647) or (LineNo <> Round(LineNo, 1)) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, DocumentErr, 'lineNo', Format(LineNo, 0, 9), 'positive integer; documentNo max 20 characters', '');
                exit(false);
            end;
            PermissionRef.Open(SourceTableNo(TypeName));
            if not PermissionRef.ReadPermission() or (NeedWrite and not PermissionRef.WritePermission()) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, SourcePermissionErr, 'documentType', DocumentType, '', '');
                exit(false);
            end;
            case TypeName of
                'SalesLine': begin
                    SalesLine.SetLoadFields(SystemId);
                    SalesLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := SalesLine.Get(Subtype, DocumentNo, LineNo);
                    IdText := Format(SalesLine.SystemId, 0, 4);
                end;
                'PurchaseLine': begin
                    PurchaseLine.SetLoadFields(SystemId);
                    PurchaseLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := PurchaseLine.Get(Subtype, DocumentNo, LineNo);
                    IdText := Format(PurchaseLine.SystemId, 0, 4);
                end;
                'TransferLine': begin
                    TransferLine.SetLoadFields(SystemId);
                    TransferLine.ReadIsolation(IsolationLevel::ReadCommitted);
                    Found := TransferLine.Get(DocumentNo, LineNo);
                    IdText := Format(TransferLine.SystemId, 0, 4);
                end;
            end;
            if not Found then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, DocumentErr, 'documentNo', DocumentNo, '', '');
                exit(false);
            end;
        end;
        Source.Add('systemId', IdText);
        if Request.Get('transferDirection', Token) then
            Source.Add('transferDirection', Token);
        SourceRequest.Add('source', Source);
        if not Resolve(Argument, SourceRequest, 'source', NeedWrite, SourceRef, Specification, Direction) then
            exit(false);
        if (TypeName <> 'TransferLine') and (Specification."Source Subtype" <> Subtype) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DocumentErr, 'documentType', DocumentType, '', '');
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Returns stable sales, purchase and transfer document names for wire responses.</summary>
    procedure DocumentTypeName(TableNo: Integer; Subtype: Integer): Text
    var
        Family: Text;
    begin
        case TableNo of
            Database::"Sales Line": Family := 'Sales.';
            Database::"Purchase Line": Family := 'Purchase.';
            Database::"Transfer Line": exit('Transfer.Order');
            else exit('');
        end;
        case Subtype of
            0: exit(Family + 'Quote');
            1: exit(Family + 'Order');
            2: exit(Family + 'Invoice');
            3: exit(Family + 'CreditMemo');
            4: exit(Family + 'BlanketOrder');
            5: exit(Family + 'ReturnOrder');
        end;
        exit('');
    end;

    /// <summary>Returns a stable wire name rather than a localized table caption or numeric table ID.</summary>
    procedure SourceTypeName(TableNo: Integer): Text
    begin
        case TableNo of
            Database::"Sales Line":
                exit('SalesLine');
            Database::"Purchase Line":
                exit('PurchaseLine');
            Database::"Transfer Line":
                exit('TransferLine');
            Database::"Assembly Header":
                exit('AssemblyHeader');
            Database::"Assembly Line":
                exit('AssemblyLine');
            Database::"Service Line":
                exit('ServiceLine');
            Database::"Prod. Order Line":
                exit('ProdOrderLine');
            Database::"Prod. Order Component":
                exit('ProdOrderComponent');
            Database::"Item Journal Line":
                exit('ItemJournalLine');
            Database::"Requisition Line":
                exit('RequisitionLine');
            Database::"Planning Component":
                exit('PlanningComponent');
            Database::"Job Journal Line":
                exit('JobJournalLine');
            Database::"Job Planning Line":
                exit('JobPlanningLine');
            Database::"Invt. Document Line":
                exit('InventoryDocumentLine');
            Database::"Item Ledger Entry":
                exit('ItemLedgerEntry');
        end;
        exit('Unknown');
    end;

    /// <summary>Reads a JSON string without coercing objects, arrays, null, numbers or booleans.</summary>
    procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        InvalidTextErr: Label 'Specify %1 as text.', Comment = '%1 = request property, is-IS=Tilgreindu %1 sem texta.';
    begin
        Clear(Value);
        if not Request.Get(KeyName, Token) then begin
            if not Required then
                exit(true);
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidTextErr, KeyName), KeyName, '', 'string', '');
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidTextErr, KeyName), KeyName, Serialized, 'string', '');
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(InvalidTextErr, KeyName), KeyName, '', 'nonempty string', '');
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Maps only W1 reservation sources; arbitrary tables are never opened.</summary>
    procedure SourceTableNo(TypeName: Text): Integer
    begin
        case TypeName of
            'SalesLine':
                exit(Database::"Sales Line");
            'PurchaseLine':
                exit(Database::"Purchase Line");
            'TransferLine':
                exit(Database::"Transfer Line");
        end;
        exit(0);
    end;

    /// <summary>Uses each native source adapter, preserving quantities, UOM, source keys and posting progress.</summary>
    procedure InitializeSpecification(SourceRef: RecordRef; Direction: Enum "Transfer Direction"; var Specification: Record "Tracking Specification")
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
        PurchaseLineReserve: Codeunit "Purch. Line-Reserve";
        TransferLineReserve: Codeunit "Transfer Line-Reserve";
        AvailabilityDate: Date;
    begin
        Clear(Specification);
        case SourceRef.Number of
            Database::"Sales Line":
                begin
                    SourceRef.SetTable(SalesLine);
                    // Full-record by native contract: SalesLineReserve.InitFromSalesLine.
                    SalesLineReserve.InitFromSalesLine(Specification, SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    SourceRef.SetTable(PurchaseLine);
                    // Full-record by native contract: PurchaseLineReserve.InitFromPurchLine.
                    PurchaseLineReserve.InitFromPurchLine(Specification, PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    SourceRef.SetTable(TransferLine);
                    // Full-record by native contract: TransferLineReserve.InitFromTransLine.
                    TransferLineReserve.InitFromTransLine(Specification, TransferLine, AvailabilityDate, Direction);
                end;
        end;
        Specification.TestField("Source Type");
        Specification.TestField("Item No.");
    end;
}
