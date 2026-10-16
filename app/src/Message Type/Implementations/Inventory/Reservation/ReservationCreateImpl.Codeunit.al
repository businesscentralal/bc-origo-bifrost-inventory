namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

codeunit 70013476 "Reservation Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a reservation against a source document line through Reservation Management.', Comment = 'is-IS=Býr til pöntun gegn línu skjals í gegnum Reservation Management.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'create reservation, auto reserve, reserve item, source line', Comment = 'is-IS=búa til pöntun, sjálfvirk pöntun, panta vöru, upprunalína';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reserves quantity for a source line (sales, purchase, transfer, or assembly).', Comment = 'is-IS=Pantar magn fyrir upprunalínu (sala, innkaup, millifærsla eða samsetning).';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Create');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Reservation Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceTypeLbl: Label 'Source table number: 37 Sales Line, 39 Purchase Line, 5741 Transfer Line, 901 Assembly Line.', Comment = 'is-IS=Númer upprunatöflu: 37 sölulína, 39 innkaupalína, 5741 millifærslulína, 901 samsetningarlína.';
        SourceSubtypeLbl: Label 'Source subtype. Sales/purchase document type, or transfer direction 0 outbound / 1 inbound. Defaults to Order or Outbound.', Comment = 'is-IS=Undirgerð uppruna. Skjalategund sölu/innkaupa, eða millifærslustefna 0 út / 1 inn. Sjálfgefið pöntun eða út.';
        SourceNoLbl: Label 'Source document number.', Comment = 'is-IS=Númer upprunaskjals.';
        SourceLineNoLbl: Label 'Source document line number.', Comment = 'is-IS=Línunúmer upprunaskjals.';
        QuantityLbl: Label 'Quantity to reserve, in the source line unit of measure.', Comment = 'is-IS=Magn til að panta, í mælieiningu upprunalínunnar.';
        ItemNoLbl: Label 'Optional item number; must match the source line when sent.', Comment = 'is-IS=Valfrjálst vörunúmer; verður að passa við upprunalínuna þegar það er sent.';
        LocationCodeLbl: Label 'Optional location code; taken from the source line when omitted.', Comment = 'is-IS=Valfrjáls staðarkóði; tekinn af upprunalínunni þegar honum er sleppt.';
    begin
        Parameters.Add(ContractMgt.Parameter('sourceType', 'integer', true, SourceTypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceSubtype', 'integer', false, SourceSubtypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceNo', 'string', true, SourceNoLbl));
        Parameters.Add(ContractMgt.Parameter('sourceLineNo', 'integer', true, SourceLineNoLbl));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, QuantityLbl));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, ItemNoLbl));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, LocationCodeLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success when a reservation entry was created.', Comment = 'is-IS=Success þegar pöntunarfærsla var búin til.';
        EntryNoLbl: Label 'Reservation entry number. Pass it to Inventory.Reservation.Cancel.', Comment = 'is-IS=Númer pöntunarfærslu. Sendu það í Inventory.Reservation.Cancel.';
        QuantityLbl: Label 'Quantity reserved.', Comment = 'is-IS=Pantað magn.';
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', EntryNoLbl));
        Fields.Add(ContractMgt.ResponseField('quantity', 'number', QuantityLbl));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'sourceType, sourceNo, sourceLineNo, or quantity is missing.', Comment = 'is-IS=sourceType, sourceNo, sourceLineNo eða quantity vantar.';
        MissingFixLbl: Label 'Name the source table, document, line, and quantity to reserve.', Comment = 'is-IS=Tilgreindu upprunatöflu, skjal, línu og magn til að panta.';
        NotFoundWhenLbl: Label 'the source line does not exist', Comment = 'is-IS=upprunalínan er ekki til';
        NotFoundFixLbl: Label 'Check sourceType, sourceSubtype, sourceNo, and sourceLineNo.', Comment = 'is-IS=Athugaðu sourceType, sourceSubtype, sourceNo og sourceLineNo.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read reservations before creating one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation instead of creating one.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Reserves quantity against a real source line and returns the reservation entry number.', Comment = 'is-IS=Pantar magn gegn raunverulegri upprunalínu og skilar númeri pöntunarfærslunnar.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'AutoReserve runs on the loaded source record. Cancel that entry with Inventory.Reservation.Cancel.', Comment = 'is-IS=AutoReserve keyrir á hlaðinni upprunafærslu. Hættu þeirri færslu með Inventory.Reservation.Cancel.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReservationEntry: Record "Reservation Entry";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestValueReader: Codeunit "Request Value Reader ori";
        ReservationManagement: Codeunit "Reservation Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        LocationCode: Code[10];
        SourceNo: Code[20];
        Quantity: Decimal;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceLineNo: Integer;
        EntryNo: Integer;
        FullAutoReservation: Boolean;
        AvailabilityDate: Date;
        QtyPerUOM: Decimal;
        MissingSourceTypeErr: Label 'sourceType is required.', Comment = 'is-IS=sourceType er skylda.';
        MissingSourceNoErr: Label 'sourceNo is required.', Comment = 'is-IS=sourceNo er skylda.';
        MissingSourceLineErr: Label 'sourceLineNo is required.', Comment = 'is-IS=sourceLineNo er skylda.';
        QuantityPositiveErr: Label 'quantity must be greater than zero.', Comment = 'is-IS=quantity verður að vera stærra en núll.';
        QuantityExpectedTok: Label 'a quantity greater than 0', Comment = 'is-IS=magn stærra en 0';
        UnsupportedSourceErr: Label 'sourceType %1 is not a supported reservation source.', Comment = '%1 = source table number, is-IS=sourceType %1 er ekki studdur pöntunaruppruni.';
        SourceNotFoundErr: Label 'Source line %1 %2 %3 was not found.', Comment = '%1 = source type, %2 = source no, %3 = source line no, is-IS=Upprunalína %1 %2 %3 fannst ekki.';
        ItemMismatchErr: Label 'itemNo %1 does not match the source line item %2.', Comment = '%1 = requested item, %2 = source item, is-IS=itemNo %1 passar ekki við vöru upprunalínunnar %2.';
        NothingReservedErr: Label 'No reservation entry was created for the source line.', Comment = 'is-IS=Engin pöntunarfærsla var búin til fyrir upprunalínuna.';
        NothingReservedExpectedTok: Label 'available inventory for the source line', Comment = 'is-IS=tiltækar birgðir fyrir upprunalínuna';
        NothingReservedNextStepTok: Label 'Check stock at the source location, then retry Inventory.Reservation.Create.', Comment = 'is-IS=Athugaðu birgðir á upprunastað og reyndu svo Inventory.Reservation.Create aftur.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('sourceType', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSourceTypeErr, 'sourceType', '', '', '');
            exit;
        end;
        SourceType := Token.AsValue().AsInteger();
        if RequestJson.Get('sourceSubtype', Token) then
            SourceSubtype := Token.AsValue().AsInteger()
        else
            SourceSubtype := DefaultSourceSubtype(SourceType);
        if not RequestJson.Get('sourceNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSourceNoErr, 'sourceNo', '', '', '');
            exit;
        end;
        SourceNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(SourceNo));
        if not RequestJson.Get('sourceLineNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingSourceLineErr, 'sourceLineNo', '', '', '');
            exit;
        end;
        SourceLineNo := Token.AsValue().AsInteger();
        if not RequestValueReader.TryReadDecimal(Argument, RequestJson, 'quantity', true, Quantity) then
            exit;
        if Quantity <= 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, QuantityPositiveErr, 'quantity', Format(Quantity, 0, 9), QuantityExpectedTok, '');
            exit;
        end;
        if RequestJson.Get('itemNo', Token) then
            ItemNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ItemNo));
        if RequestJson.Get('locationCode', Token) then
            LocationCode := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(LocationCode));

        if not BindReservationSource(
            Argument, ReservationManagement, SourceType, SourceSubtype, SourceNo, SourceLineNo,
            ItemNo, LocationCode, AvailabilityDate, QtyPerUOM, UnsupportedSourceErr, SourceNotFoundErr, ItemMismatchErr)
        then
            exit;

        if AvailabilityDate = 0D then
            AvailabilityDate := WorkDate();
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;
        if not TryAutoReserve(ReservationManagement, FullAutoReservation, ItemNo, AvailabilityDate, Quantity, Quantity * QtyPerUOM) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;

        ReservationEntry.SetRange("Source Type", SourceType);
        ReservationEntry.SetRange("Source Subtype", SourceSubtype);
        ReservationEntry.SetRange("Source ID", SourceNo);
        ReservationEntry.SetRange("Source Ref. No.", SourceLineNo);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        if not ReservationEntry.FindLast() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingReservedErr, 'sourceNo', SourceNo, NothingReservedExpectedTok, NothingReservedNextStepTok);
            exit;
        end;
        EntryNo := ReservationEntry."Entry No.";

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('quantity', Quantity);
        ResponseJson.Add('fullAutoReservation', FullAutoReservation);
        ResponseJson.Add('sourceType', SourceType);
        ResponseJson.Add('sourceSubtype', SourceSubtype);
        ResponseJson.Add('sourceNo', SourceNo);
        ResponseJson.Add('sourceLineNo', SourceLineNo);
        ResponseJson.Add('locationCode', LocationCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure DefaultSourceSubtype(SourceType: Integer): Integer
    begin
        case SourceType of
            Database::"Sales Line", Database::"Purchase Line", Database::"Assembly Line":
                exit(1);
            Database::"Transfer Line":
                exit(0);
        end;
        exit(0);
    end;

    local procedure BindReservationSource(
        var Argument: Record "Message Argument ori";
        var ReservationManagement: Codeunit "Reservation Management";
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceNo: Code[20];
        SourceLineNo: Integer;
        var ItemNo: Code[20];
        var LocationCode: Code[10];
        var AvailabilityDate: Date;
        var QtyPerUOM: Decimal;
        UnsupportedSourceErr: Text;
        SourceNotFoundErr: Text;
        ItemMismatchErr: Text): Boolean
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        AssemblyLine: Record "Assembly Line";
        SourceItemNo: Code[20];
        SourceLocationCode: Code[10];
    begin
        QtyPerUOM := 1;
        case SourceType of
            Database::"Sales Line":
                begin
                    if not SalesLine.Get(Enum::"Sales Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SourceNotFoundErr, SourceType, SourceNo, SourceLineNo), 'sourceNo', SourceNo, '', '');
                        exit(false);
                    end;
                    SourceItemNo := SalesLine."No.";
                    SourceLocationCode := SalesLine."Location Code";
                    QtyPerUOM := SalesLine."Qty. per Unit of Measure";
                    AvailabilityDate := SalesLine."Shipment Date";
                    ReservationManagement.SetReservSource(SalesLine);
                end;
            Database::"Purchase Line":
                begin
                    if not PurchaseLine.Get(Enum::"Purchase Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SourceNotFoundErr, SourceType, SourceNo, SourceLineNo), 'sourceNo', SourceNo, '', '');
                        exit(false);
                    end;
                    SourceItemNo := PurchaseLine."No.";
                    SourceLocationCode := PurchaseLine."Location Code";
                    QtyPerUOM := PurchaseLine."Qty. per Unit of Measure";
                    AvailabilityDate := PurchaseLine."Expected Receipt Date";
                    ReservationManagement.SetReservSource(PurchaseLine);
                end;
            Database::"Transfer Line":
                begin
                    if not TransferLine.Get(SourceNo, SourceLineNo) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SourceNotFoundErr, SourceType, SourceNo, SourceLineNo), 'sourceNo', SourceNo, '', '');
                        exit(false);
                    end;
                    SourceItemNo := TransferLine."Item No.";
                    if SourceSubtype = 1 then
                        SourceLocationCode := TransferLine."Transfer-to Code"
                    else
                        SourceLocationCode := TransferLine."Transfer-from Code";
                    QtyPerUOM := TransferLine."Qty. per Unit of Measure";
                    AvailabilityDate := TransferLine."Shipment Date";
                    ReservationManagement.SetReservSource(TransferLine);
                end;
            Database::"Assembly Line":
                begin
                    if not AssemblyLine.Get(Enum::"Assembly Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo) then begin
                        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SourceNotFoundErr, SourceType, SourceNo, SourceLineNo), 'sourceNo', SourceNo, '', '');
                        exit(false);
                    end;
                    SourceItemNo := AssemblyLine."No.";
                    SourceLocationCode := AssemblyLine."Location Code";
                    QtyPerUOM := AssemblyLine."Qty. per Unit of Measure";
                    AvailabilityDate := AssemblyLine."Due Date";
                    ReservationManagement.SetReservSource(AssemblyLine);
                end;
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(UnsupportedSourceErr, SourceType), 'sourceType', Format(SourceType), '37, 39, 5741, or 901', '');
                exit(false);
            end;
        end;

        if ItemNo = '' then
            ItemNo := SourceItemNo
        else
            if ItemNo <> SourceItemNo then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ItemMismatchErr, ItemNo, SourceItemNo), 'itemNo', ItemNo, SourceItemNo, '');
                exit(false);
            end;
        if LocationCode = '' then
            LocationCode := SourceLocationCode;
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;
        exit(true);
    end;

    [TryFunction]
    local procedure TryAutoReserve(var ReservationManagement: Codeunit "Reservation Management"; var FullAutoReservation: Boolean; Description: Text[100]; AvailabilityDate: Date; Quantity: Decimal; QuantityBase: Decimal)
    begin
        ReservationManagement.AutoReserve(FullAutoReservation, Description, AvailabilityDate, Quantity, QuantityBase);
    end;
}
