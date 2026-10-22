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
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The reservation entry is named in data (entryNo); subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'reservation entry no.', 'The Entry No. of a reservation entry with status Reservation, as returned by Inventory.Reservation.Create or read with Inventory.Reservation.Get. Both entries of the reservation pair share the number and both are cancelled.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The reservation entry number, a positive whole number up to 2147483647. Both entries of the pair share it. Only an entry with status Reservation can be cancelled.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the reservation was cancelled.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The reservation entry number that was cancelled, as sent.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the cancelled reservation entry.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The reserved quantity of the entry before it was cancelled, as a positive number in the unit of measure of the entry.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'entryNo was not sent.', 'Send entryNo as a positive whole number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'entryNo is not a positive whole number up to 2147483647.', 'Send entryNo as a JSON number such as 120.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No reservation entry has that entry number.', 'Read the entry numbers with Inventory.Reservation.Get, or use the entryNo that Inventory.Reservation.Create returned.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The entry is item tracking or surplus, not a reservation (its status is not Reservation), or the Reservations domain is turned off for the company.', 'Send the number of an entry with status Reservation, or turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change reservation entries.', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change reservation entries.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native cancellation error text.', 'Business Central refuses the cancellation while it runs; the answer carries its text.', 'Read the error text and correct the reservation it names.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Reservations domain is turned on in Inventory Setup.');
        Preconditions.Add('The reservation entry exists and has status Reservation.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Cancels both entries of the reservation pair, so the supply and the demand stay but are no longer tied to each other. Bifrost commits the cancellation when the call finishes. Nothing is posted.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.AutoReserve', 'Reserve a sales order line again from the available supply after cancelling.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Get', 'Read the reservations and find the entryNo to cancel.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Cancel', 'Cancel the reservation by its entryNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Reservation.Create', 'Reserve again from other supply when that is wanted.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(
            'Cancel the reservation with entry number 120',
            '{"type":"Inventory.Reservation.Cancel","data":{"entryNo":120}}',
            '{"status":"Success","entryNo":120,"itemNo":"1000","quantity":5}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Cancels one reservation, both its supply entry and its demand entry, by the entry number they share.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Cancels both sides of the reservation pair, the same action as Cancel Reservation on the Reservation Entries page. Only entries with status Reservation can be cancelled; item tracking and surplus entries are refused as InvalidParameter. Bifrost commits the cancellation when the call finishes; under Omit Commit the caller''s transaction commits instead. The answer gives the item and the reserved quantity of the entry as they were before the cancellation. Read the entry numbers with Inventory.Reservation.Get.', Comment = 'is-IS=Afturkallar báðar hliðar frátekningarparsins, sömu aðgerð og Afturkalla frátekningu á síðunni Frátekningarfærslur. Aðeins er hægt að afturkalla færslur með stöðuna Reservation; vörurakningar- og afgangsfærslum er hafnað sem InvalidParameter. Bifrost vistar afturköllunina þegar kallinu lýkur; með Omit Commit vistar kallandinn færsluna í staðinn. Svarið gefur vöruna og frátekna magnið í færslunni eins og það var fyrir afturköllunina. Lestu færslunúmerin með Inventory.Reservation.Get.';
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
