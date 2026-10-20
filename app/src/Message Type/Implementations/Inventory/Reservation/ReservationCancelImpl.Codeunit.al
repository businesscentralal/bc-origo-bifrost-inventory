namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 10076892 "Reservation Cancel Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        DescriptionLbl: Label 'Cancels a reservation entry through Reservation Management.', Comment = 'is-IS=Afturkallar frátekningarfærslu með Reservation Management.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'cancel reservation, delete reservation', Comment = 'is-IS=afturkalla frátekningu, eyða frátekningu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Cancels one reservation entry by entry number.', Comment = 'is-IS=Afturkallar eina frátekningarfærslu eftir færslunúmeri.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Cancel');
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
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'entryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('entryNo', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'entryNo was not found');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Reservation Entry');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read reservations before cancelling one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Create', 'Create a reservation instead of cancelling one.'));
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
    begin
        Overview := 'Cancels one reservation entry through Reservation Management.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Cancels both sides of the reservation pair through the native Reservation Engine Mgt. CancelReservation, the same action as Cancel Reservation on the Reservation Entries page. Only entries with status Reservation can be cancelled.', Comment = 'is-IS=Afturkallar báðar hliðar frátekningarparsins með innbyggða CancelReservation í Reservation Engine Mgt., sömu aðgerð og Afturkalla frátekningu á síðunni Frátekningarfærslur. Aðeins er hægt að afturkalla færslur með stöðuna Reservation.';
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
        Process: Codeunit "Inventory Write Process ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
        EntryNo: Integer;
        EntryNoRequiredErr: Label 'entryNo is required.', Comment = 'is-IS=entryNo er nauðsynlegt.';
        EntryNoFormatErr: Label 'entryNo must be a positive whole number.', Comment = 'is-IS=entryNo verður að vera jákvæð heiltala.';
        NotFoundErr: Label 'Reservation entry %1 was not found.', Comment = '%1 = entry number; is-IS=Frátekningarfærsla %1 fannst ekki.';
        NotReservationErr: Label 'Entry %1 is item tracking or surplus, not a reservation. Only entries with status Reservation can be cancelled.', Comment = '%1 = entry number; is-IS=Færsla %1 er vörurakning eða afgangur, ekki frátekning. Aðeins er hægt að afturkalla færslur með stöðuna Reservation.';
        IntegerExpectedTok: Label 'a positive JSON integer', Comment = 'is-IS=jákvæð JSON-heiltala';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, EntryNoRequiredErr, 'entryNo', '', IntegerExpectedTok, '');
            exit;
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or Serialized.StartsWith('"') or not Evaluate(Number, Serialized, 9) then
            Number := 0;
        if (Number <= 0) or (Number > 2147483647) or (Number <> Round(Number, 1)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, EntryNoFormatErr, 'entryNo', Serialized, IntegerExpectedTok, '');
            exit;
        end;
        EntryNo := Number;
        ReservationEntry.SetRange("Entry No.", EntryNo);
        if not ReservationEntry.FindFirst() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), '', '');
            exit;
        end;
        if ReservationEntry."Reservation Status" <> ReservationEntry."Reservation Status"::Reservation then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NotReservationErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), '', '');
            exit;
        end;

        Process.SetOperation('ReservationCancel');
        Process.SetCancelReservation(EntryNo);
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithError(GetLastErrorText());
                exit;
            end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', ReservationEntry."Item No.");
        ResponseJson.Add('quantity', Abs(ReservationEntry.Quantity));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
