namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Document;
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
        DescriptionLbl: Label 'Cancels a reservation entry through Reservation Management.', Comment = 'is-IS=Afturkallar frátekningarfærslu með Reservation Management. (afturkalla frátekningu, eyða frátekningu).';
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
        SelectionDescriptionLbl: Label 'Cancels one reservation by entryNo, or every reservation of one source line by sourceType, sourceNo and sourceLineNo.', Comment = 'is-IS=Afturkallar eina frátekningu eftir entryNo, eða allar frátekningar einnar upprunalínu eftir sourceType, sourceNo og sourceLineNo.';
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
        Subject.Add('description', 'The reservation entry (entryNo) or the source line (sourceType, sourceNo, sourceLineNo) is named in data; subject is not read.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceTargetLbl: Label 'Used when entryNo is not sent: every reservation (status Reservation) of that source line is cancelled, for any source the Reserve action supports. sourceBatchName is required for an item journal line (83) and sourceProdOrderLine and sourceSubtype for production output (5406) and components (5407). For a Job Planning Line (1003), send sourceNo as the project number, sourceTaskNo as the project task number and sourceLineNo as the planning line number.', Comment = 'is-IS=Notað þegar entryNo er ekki sent: allar frátekningar (staða Reservation) fyrir upprunalínuna eru afturkallaðar, fyrir alla uppruna sem aðgerðin Taka frá styður. sourceBatchName er nauðsynlegt fyrir vörubókarlínu (83) og sourceProdOrderLine og sourceSubtype fyrir framleiðsluafurðir (5406) og íhluti (5407). Fyrir verkáætlunarlínu (1003) skal senda verkefnisnúmerið í sourceNo, verkþáttarnúmerið í sourceTaskNo og línunúmer verkáætlunarlínunnar í sourceLineNo.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'reservation entry no.', 'The Entry No. of a reservation entry with status Reservation, as returned by Inventory.Reservation.Create or read with Inventory.Reservation.Get. Both entries of the reservation pair share the number and both are cancelled.'));
        Target.Add(ContractMgt.TargetEntry('data.sourceType + data.sourceSubtype + data.sourceNo + data.sourceLineNo + data.sourceBatchName + data.sourceProdOrderLine', 'table no., subtype, document no., line no., batch and production order line', SourceTargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceTypeLbl: Label 'Source table number of the line whose reservations are cancelled when entryNo is not sent, for example 37 Sales Line, 39 Purchase Line, 5741 Transfer Line, 901 Assembly Line, 5902 Service Line, 5406 Prod. Order Line, 5407 Prod. Order Component, 83 Item Journal Line or 1003 Job Planning Line (project planning line; also send sourceTaskNo).', Comment = 'is-IS=Númer upprunatöflu línunnar sem frátekningar eru afturkallaðar fyrir þegar entryNo er ekki sent, til dæmis 37 sölulína, 39 innkaupalína, 5741 millifærslulína, 901 samsetningarlína, 5902 þjónustulína, 5406 framleiðslupöntunarlína, 5407 framleiðsluíhlutur, 83 vörubókarlína eða 1003 verkáætlunarlína (einnig er sent sourceTaskNo).';
        SourceSubtypeLbl: Label 'Source subtype: the document type ordinal (1 = Order) or the transfer direction (0 outbound, 1 inbound). Defaults to 1 for sales, purchase and assembly lines; required for production output and components (5406/5407) to identify the production status. For other sources every subtype of the line is cancelled when it is left out.', Comment = 'is-IS=Undirtegund uppruna: raðtala skjalategundar (1 = pöntun) eða stefna millifærslu (0 út, 1 inn). Sjálfgefið 1 fyrir sölu-, innkaupa- og samsetningarlínur; nauðsynlegt fyrir framleiðsluafurðir og íhluti (5406/5407) til að tilgreina framleiðslustöðu. Fyrir aðra uppruna eru allar undirtegundir línunnar afturkallaðar ef hún er ekki send.';
        SourceNoLbl: Label 'Source document number (for an item journal line, the journal template name).', Comment = 'is-IS=Númer upprunaskjals (fyrir vörubókarlínu, heiti bókarsniðmátsins).';
        SourceLineNoLbl: Label 'Source line number (Source Ref. No.).', Comment = 'is-IS=Línunúmer uppruna (Source Ref. No.).';
        SourceTaskLbl: Label 'Project task number; required for a project planning line (sourceType 1003), where sourceNo is the project number and sourceLineNo the planning line number.', Comment = 'is-IS=Verkþáttarnúmer; nauðsynlegt fyrir verkáætlunarlínu (sourceType 1003), þar sem sourceNo er verkefnisnúmerið og sourceLineNo línunúmer verkáætlunarlínunnar.';
        SourceBatchLbl: Label 'Journal batch name; required for an item journal line (sourceType 83).', Comment = 'is-IS=Heiti bókarkeyrslu; nauðsynlegt fyrir vörubókarlínu (sourceType 83).';
        SourceProdLineLbl: Label 'Production order line number; required for production output and components (sourceType 5406/5407).', Comment = 'is-IS=Línunúmer framleiðslupöntunar; nauðsynlegt fyrir framleiðsluafurðir og íhluti (sourceType 5406/5407).';
    begin
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, 'Send entryNo or the source line. The reservation entry number, a positive whole number up to 2147483647. Both entries of the pair share it. Both demand and supply entries must have status Reservation, matching item, variant and location, and equal opposite base quantities.'));
        Parameters.Add(ContractMgt.Parameter('sourceType', 'integer', false, SourceTypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceSubtype', 'integer', false, SourceSubtypeLbl));
        Parameters.Add(ContractMgt.Parameter('sourceNo', 'string', false, SourceNoLbl));
        Parameters.Add(ContractMgt.Parameter('sourceLineNo', 'integer', false, SourceLineNoLbl));
        Parameters.Add(ContractMgt.Parameter('sourceTaskNo', 'string', false, SourceTaskLbl));
        Parameters.Add(ContractMgt.Parameter('sourceBatchName', 'string', false, SourceBatchLbl));
        Parameters.Add(ContractMgt.Parameter('sourceProdOrderLine', 'integer', false, SourceProdLineLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the reservation was cancelled.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The reservation entry number that was cancelled: as sent, or the first one of the source line; 0 when the line had none.'));
        Fields.Add(ContractMgt.ResponseField('entryNos', 'array', 'Every reservation entry number that was cancelled.'));
        Fields.Add(ContractMgt.ResponseField('entriesCancelled', 'integer', 'The number of reservations (entry pairs) that were cancelled; 0 when the source line had none.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the cancelled reservation entry.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The reserved quantity that was cancelled, as a positive number in the unit of measure of the entry (summed over the source line when cancelling by line).'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Neither entryNo nor the source line was sent, or sourceNo, sourceLineNo, sourceBatchName (item journal line) or sourceProdOrderLine (production order component) is missing.', 'Send entryNo, or sourceType, sourceNo and sourceLineNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The sales source line does not exist.', 'Check sourceSubtype, sourceNo and sourceLineNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The sales source line is closed: its outstanding quantity is 0.', 'Nothing is reserved on a closed line; read its reservations with Inventory.Reservation.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'entryNo is not a positive whole number up to 2147483647.', 'Send entryNo as a JSON number such as 120.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'No reservation entry has that entry number.', 'Read the entry numbers with Inventory.Reservation.Get, or use the entryNo that Inventory.Reservation.Create returned.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The entry is item tracking or surplus, not a reservation (its status is not Reservation), or the Reservations domain is turned off for the company.', 'Send the number of an entry with status Reservation, or turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change reservation entries.', 'Assign the Bifrost "Full Access" permission set (extended by Inventory write permissions) and a Business Central permission set that can change reservation entries.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native cancellation error text.', 'Business Central refuses the cancellation while it runs; the answer carries its text.', 'Read the error text and correct the reservation it names.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The reservation pair is incomplete or has inconsistent status, identity or base quantity.', 'Inspect both entries and correct their native reservation state.'));
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
            '{"status":"Success","entryNo":120,"entryNos":[120],"entriesCancelled":1,"itemNo":"1000","quantity":5}'));
        Examples.Add(ContractMgt.Example(
            'Cancel every reservation of sales order line 10000. Replace the identifiers with your own.',
            '{"type":"Inventory.Reservation.Cancel","data":{"sourceType":37,"sourceSubtype":1,"sourceNo":"S-ORD101001","sourceLineNo":10000}}',
            '{"status":"Success","entryNo":120,"entryNos":[120,121],"entriesCancelled":2,"itemNo":"1000","quantity":7}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Cancels one reservation, both its supply entry and its demand entry, by the entry number they share, or every reservation of one source line.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Cancels both sides of the reservation pair, the same action as Cancel Reservation on the Reservation Entries page. Only entries with status Reservation can be cancelled; item tracking and surplus entries are refused as InvalidParameter. Bifrost commits the cancellation when the call finishes; under Omit Commit the caller''s transaction commits instead. The answer gives the item and the reserved quantity of the entry as they were before the cancellation. Read the entry numbers with Inventory.Reservation.Get.', Comment = 'is-IS=Afturkallar báðar hliðar frátekningarparsins, sömu aðgerð og Afturkalla frátekningu á síðunni Frátekningarfærslur. Aðeins er hægt að afturkalla færslur með stöðuna Reservation; vörurakningar- og afgangsfærslum er hafnað sem InvalidParameter. Bifrost vistar afturköllunina þegar kallinu lýkur; með Omit Commit vistar kallandinn færsluna í staðinn. Svarið gefur vöruna og frátekna magnið í færslunni eins og það var fyrir afturköllunina. Lestu færslunúmerin með Inventory.Reservation.Get.';
        LineNotesLbl: Label ' Without entryNo, sourceType, sourceNo and sourceLineNo name a source line and every reservation of that line is cancelled in one transaction; a line without reservations answers Success with entriesCancelled 0. A sales line with outstanding quantity 0 is refused as PreconditionFailed.', Comment = 'is-IS= Án entryNo nefna sourceType, sourceNo og sourceLineNo upprunalínu og allar frátekningar þeirrar línu eru afturkallaðar í einni færslu; lína án frátekninga svarar Success með entriesCancelled 0. Sölulínu með útistandandi magn 0 er hafnað sem PreconditionFailed.';
    begin
        Notes := 'Cancellation requires both sides of a consistent reservation pair: Reservation status on both entries, matching item, variant and location, and equal opposite nonzero base quantities. A missing or inconsistent side is refused before any cancellation; the pair is checked again under a native write lock. ' +
            NotesLbl + LineNotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Contains('entryNo') and RequestJson.Contains('sourceType') then
            CancelSourceLine(Argument, RequestJson)
        else
            CancelEntry(Argument, RequestJson);
    end;

    local procedure CancelEntry(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        ReservationEntry: Record "Reservation Entry";
        Process: Codeunit "Inventory Write Process ori";
        ResponseJson: JsonObject;
        EntryNos: JsonArray;
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
        EntryNo: Integer;
        EntryNoRequiredErr: Label 'entryNo is required.', Comment = 'is-IS=entryNo er nauðsynlegt.';
        EntryNoFormatErr: Label 'entryNo must be a positive whole number.', Comment = 'is-IS=entryNo verður að vera jákvæð heiltala.';
        NotFoundErr: Label 'Reservation entry %1 was not found.', Comment = '%1 = entry number; is-IS=Frátekningarfærsla %1 fannst ekki.';
        NotReservationErr: Label 'Entry %1 is item tracking or surplus, not a reservation. Only entries with status Reservation can be cancelled.', Comment = '%1 = entry number; is-IS=Færsla %1 er vörurakning eða afgangur, ekki frátekning. Aðeins er hægt að afturkalla færslur með stöðuna Reservation.';
        IntegerExpectedTok: Label 'a positive JSON integer', Comment = 'is-IS=jákvæð JSON-heiltala';
        InconsistentPairErr: Label 'Reservation %1 does not contain a consistent reservation pair.', Comment = '%1 = entry number; is-IS=Frátekning %1 inniheldur ekki samræmt frátekningarpar.';
        ListReservationsLbl: Label 'Read the current reservations with Inventory.Reservation.Get and send the entryNo of an entry that exists.', Comment = 'is-IS=Lestu núverandi frátekningar með Inventory.Reservation.Get og sendu entryNo færslu sem er til.';
        InspectPairLbl: Label 'Inspect both reservation entries and correct their native reservation state before retrying.', Comment = 'is-IS=Skoðaðu báðar frátekningarfærslur og leiðréttu stöðu þeirra í kerfinu áður en reynt er aftur.';
    begin
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
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), IntegerExpectedTok, ListReservationsLbl);
            exit;
        end;
        if ReservationEntry."Reservation Status" <> ReservationEntry."Reservation Status"::Reservation then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NotReservationErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), '', '');
            exit;
        end;

        Process.SetOperation('ReservationCancel');
        Process.SetCancelReservation(EntryNo);
        if not Process.HasConsistentReservationPair(EntryNo, ReservationEntry) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InconsistentPairErr, EntryNo), 'entryNo', Format(EntryNo, 0, 9), '', InspectPairLbl);
            exit;
        end;
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
                exit;
            end;
        EntryNos.Add(EntryNo);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('entryNos', EntryNos);
        ResponseJson.Add('entriesCancelled', 1);
        ResponseJson.Add('itemNo', ReservationEntry."Item No.");
        ResponseJson.Add('quantity', Abs(ReservationEntry.Quantity));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CancelSourceLine(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        ReservationEntry: Record "Reservation Entry";
        DemandEntry: Record "Reservation Entry";
        Process: Codeunit "Inventory Write Process ori";
        ProjectPolicy: Codeunit "Reserv. AutoReserve Proc ori";
        TaskNo: Text;
        HasTask: Boolean;
        ProjectItemNo: Code[20];
        ProjectLocationCode: Code[10];
        ProjectDate: Date;
        ProjectQtyPerUOM: Decimal;
        ProjectDescription: Text[100];
        ContractEntryNo: Integer;
        ResponseJson: JsonObject;
        EntryNoArray: JsonArray;
        EntryNos: List of [Integer];
        SourceNo: Text;
        BatchName: Text;
        ItemNo: Code[20];
        Quantity: Decimal;
        SourceType: Integer;
        SourceSubtype: Integer;
        SourceLineNo: Integer;
        ProdOrderLine: Integer;
        FirstEntryNo: Integer;
        EntryNo: Integer;
        HasSourceType: Boolean;
        HasSubtype: Boolean;
        HasSourceNo: Boolean;
        HasLineNo: Boolean;
        HasBatch: Boolean;
        HasProdOrderLine: Boolean;
        ReadOk: Boolean;
        MissingErr: Label '%1 is required to cancel the reservations of a source line.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt til að afturkalla frátekningar upprunalínu.';
        MissingNextStepLbl: Label 'Send entryNo, or sourceType, sourceNo and sourceLineNo (with sourceBatchName for an item journal line and sourceProdOrderLine and sourceSubtype for production output and components).', Comment = 'is-IS=Sendu entryNo, eða sourceType, sourceNo og sourceLineNo (með sourceBatchName fyrir vörubókarlínu og sourceProdOrderLine og sourceSubtype fyrir framleiðsluafurðir og íhluti).';
        InconsistentPairErr: Label 'Reservation %1 does not contain a consistent reservation pair.', Comment = '%1 = entry number; is-IS=Frátekning %1 inniheldur ekki samræmt frátekningarpar.';
        InspectPairLbl: Label 'Inspect both reservation entries and correct their native reservation state before retrying.', Comment = 'is-IS=Skoðaðu báðar frátekningarfærslur og leiðréttu stöðu þeirra í kerfinu áður en reynt er aftur.';
    begin
        Process.SetOperation('ReservationCancel');
        ItemNo := '';
        ReadOk := ReadInteger(Argument, RequestJson, 'sourceType', SourceType, HasSourceType);
        if ReadOk then
            ReadOk := ReadInteger(Argument, RequestJson, 'sourceSubtype', SourceSubtype, HasSubtype);
        if ReadOk then
            ReadOk := ReadInteger(Argument, RequestJson, 'sourceLineNo', SourceLineNo, HasLineNo);
        if ReadOk then
            ReadOk := ReadInteger(Argument, RequestJson, 'sourceProdOrderLine', ProdOrderLine, HasProdOrderLine);
        if ReadOk then
            ReadOk := ReadText(Argument, RequestJson, 'sourceNo', 20, SourceNo, HasSourceNo);
        if ReadOk then
            ReadOk := ReadText(Argument, RequestJson, 'sourceBatchName', 10, BatchName, HasBatch);
        if ReadOk then
            ReadOk := ReadText(Argument, RequestJson, 'sourceTaskNo', 20, TaskNo, HasTask);
        if not ReadOk then
            exit;
        if not HasSourceNo then begin
            RespondMissing(Argument, MissingErr, 'sourceNo', MissingNextStepLbl);
            exit;
        end;
        if not HasLineNo then begin
            RespondMissing(Argument, MissingErr, 'sourceLineNo', MissingNextStepLbl);
            exit;
        end;
        if (SourceType = 83) and not HasBatch then begin
            RespondMissing(Argument, MissingErr, 'sourceBatchName', MissingNextStepLbl);
            exit;
        end;
        if (SourceType in [5406, 5407]) and not HasProdOrderLine then begin
            RespondMissing(Argument, MissingErr, 'sourceProdOrderLine', MissingNextStepLbl);
            exit;
        end;
        if (SourceType in [5406, 5407]) and not HasSubtype then begin
            RespondMissing(Argument, MissingErr, 'sourceSubtype', MissingNextStepLbl);
            exit;
        end;
        if not HasSubtype and (SourceType in [37, 39, 901]) then begin
            SourceSubtype := 1;
            HasSubtype := true;
        end;
        if SourceType = Database::"Job Planning Line" then begin
            if not HasTask then begin
                RespondMissing(Argument, MissingErr, 'sourceTaskNo', MissingNextStepLbl);
                exit;
            end;
            // Project planning lines are reserved under their status and job contract entry number.
            if not ProjectPolicy.ResolveProjectPlanningLine(Argument, CopyStr(SourceNo, 1, 20), CopyStr(TaskNo, 1, 20), SourceLineNo, false, SourceSubtype, ContractEntryNo, ProjectItemNo, ProjectLocationCode, ProjectDate, ProjectQtyPerUOM, ProjectDescription) then
                exit;
            HasSubtype := true;
            SourceLineNo := ContractEntryNo;
        end;
        if SourceType = Database::"Sales Line" then
            if not CheckSalesLineOpen(Argument, SourceSubtype, CopyStr(SourceNo, 1, 20), SourceLineNo) then
                exit;

        ReservationEntry.SetRange("Source Type", SourceType);
        if HasSubtype then
            ReservationEntry.SetRange("Source Subtype", SourceSubtype);
        ReservationEntry.SetRange("Source ID", CopyStr(SourceNo, 1, MaxStrLen(ReservationEntry."Source ID")));
        ReservationEntry.SetRange("Source Ref. No.", SourceLineNo);
        if HasBatch then
            ReservationEntry.SetRange("Source Batch Name", CopyStr(BatchName, 1, MaxStrLen(ReservationEntry."Source Batch Name")));
        if HasProdOrderLine then
            ReservationEntry.SetRange("Source Prod. Order Line", ProdOrderLine);
        ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
        ReservationEntry.SetLoadFields("Entry No.", "Item No.", Quantity);
        if ReservationEntry.FindSet() then
            repeat
                if not EntryNos.Contains(ReservationEntry."Entry No.") then begin
                    EntryNos.Add(ReservationEntry."Entry No.");
                    Quantity += Abs(ReservationEntry.Quantity);
                    if ItemNo = '' then
                        ItemNo := ReservationEntry."Item No.";
                end;
            until ReservationEntry.Next() = 0;
        foreach EntryNo in EntryNos do
            if not Process.HasConsistentReservationPair(EntryNo, DemandEntry) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(InconsistentPairErr, EntryNo), 'sourceLineNo', Format(SourceLineNo, 0, 9), '', InspectPairLbl);
                exit;
            end;
        if EntryNos.Count() > 0 then begin
            Process.SetCancelReservations(EntryNos);
            if Argument."Omit Commit" then
                Process.Run(Argument)
            else
                if not Process.Run(Argument) then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
                    exit;
                end;
            FirstEntryNo := EntryNos.Get(1);
        end;
        foreach EntryNo in EntryNos do
            EntryNoArray.Add(EntryNo);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', FirstEntryNo);
        ResponseJson.Add('entryNos', EntryNoArray);
        ResponseJson.Add('entriesCancelled', EntryNos.Count());
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('quantity', Quantity);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CheckSalesLineOpen(var Argument: Record "Message Argument ori"; SourceSubtype: Integer; SourceNo: Code[20]; SourceLineNo: Integer): Boolean
    var
        SalesLine: Record "Sales Line";
        NotFoundErr: Label 'Sales line %1 %2 was not found.', Comment = '%1 = document number; %2 = line number; is-IS=Sölulína %1 %2 fannst ekki.';
        ClosedErr: Label 'Sales line %1 %2 is closed: its outstanding quantity is 0.', Comment = '%1 = document number; %2 = line number; is-IS=Sölulína %1 %2 er lokuð: útistandandi magn hennar er 0.';
        LineExpectedTok: Label 'an open sales line', Comment = 'is-IS=opin sölulína';
        LineNextStepLbl: Label 'Check sourceSubtype, sourceNo and sourceLineNo, and read the line reservations with Inventory.Reservation.Get.', Comment = 'is-IS=Athugaðu sourceSubtype, sourceNo og sourceLineNo og lestu frátekningar línunnar með Inventory.Reservation.Get.';
    begin
        if not Enum::"Sales Document Type".Ordinals().Contains(SourceSubtype) then
            SourceSubtype := -1;
        SalesLine.SetLoadFields("Outstanding Quantity");
        if (SourceSubtype < 0) or not SalesLine.Get(Enum::"Sales Document Type".FromInteger(SourceSubtype), SourceNo, SourceLineNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, SourceNo, SourceLineNo), 'sourceLineNo', Format(SourceLineNo, 0, 9), LineExpectedTok, LineNextStepLbl);
            exit(false);
        end;
        if SalesLine."Outstanding Quantity" = 0 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ClosedErr, SourceNo, SourceLineNo), 'sourceLineNo', Format(SourceLineNo, 0, 9), LineExpectedTok, LineNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori"; MissingErr: Text; KeyName: Text; NextStep: Text)
    var
        RequiredExpectedTok: Label 'a value', Comment = 'is-IS=gildi';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, KeyName), KeyName, '<missing>', RequiredExpectedTok, NextStep);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Integer; var Sent: Boolean): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
        FormatErr: Label '%1 must be a whole number of 0 or more.', Comment = '%1 = parameter name; is-IS=%1 verður að vera heiltala, 0 eða stærri.';
        IntegerExpectedTok: Label 'a JSON integer', Comment = 'is-IS=JSON-heiltala';
        IntegerNextStepLbl: Label 'Send the value as a JSON number without quotes.', Comment = 'is-IS=Sendu gildið sem JSON-tölu án gæsalappa.';
    begin
        Sent := RequestJson.Get(KeyName, Token);
        if not Sent then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or Serialized.StartsWith('"') or not Evaluate(Number, Serialized, 9) then
            Number := -1;
        if (Number <> Round(Number, 1)) or (Number < 0) or (Number > 2147483647) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName), KeyName, Serialized, IntegerExpectedTok, IntegerNextStepLbl);
            exit(false);
        end;
        Value := Number;
        exit(true);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; MaxLength: Integer; var Value: Text; var Sent: Boolean): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        FormatErr: Label '%1 must be text of 1 to %2 characters.', Comment = '%1 = parameter name; %2 = maximum length; is-IS=%1 verður að vera texti, 1 til %2 stafir.';
        StringExpectedTok: Label 'a JSON string', Comment = 'is-IS=JSON-strengur';
        StringNextStepLbl: Label 'Send the value as text in quotes.', Comment = 'is-IS=Sendu gildið sem texta innan gæsalappa.';
    begin
        Sent := RequestJson.Get(KeyName, Token);
        if not Sent then
            exit(true);
        Token.WriteTo(Serialized);
        if Token.IsValue() and Serialized.StartsWith('"') then
            Value := Token.AsValue().AsText();
        if not Token.IsValue() or not Serialized.StartsWith('"') or (Value = '') or (StrLen(Value) > MaxLength) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, KeyName, MaxLength), KeyName, Serialized, StringExpectedTok, StringNextStepLbl);
            exit(false);
        end;
        Value := UpperCase(Value);
        exit(true);
    end;
}
