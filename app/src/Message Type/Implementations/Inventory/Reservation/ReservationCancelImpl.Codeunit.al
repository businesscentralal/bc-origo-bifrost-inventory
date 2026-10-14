namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013478 "Reservation Cancel Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Cancels native reservations by source or reservation entry number.', Comment = 'is-IS=Afturkallar innbyggðar frátektir eftir uppruna eða frátektarfærslunúmeri.';
        SelectionLbl: Label 'Select a source, optionally narrowed by entryNo, or provide entryNo alone to resolve its native source.', Comment = 'is-IS=Veldu uppruna, valfrjálst þrengdan með entryNo, eða gefðu aðeins entryNo til að finna innbyggðan uppruna hans.';
        KeywordsLbl: Label 'cancel reservation,release reserved quantity,reservation source', Comment = 'is-IS=afturkalla frátekt,losa frátekið magn,frátektaruppruni';
        OverviewLbl: Label 'Cancels native reservations by source or reservation entry number.', Comment = 'is-IS=Afturkallar innbyggðar frátektir eftir uppruna eða frátektarfærslunúmeri.';
        NotesLbl: Label 'Cancels only Reservation-status entries through Reservation Engine Mgt. and removes both sides of each selected pair. A source without entryNo cancels all its reservations and is repeatable with entriesCancelled zero; a missing explicit entryNo returns RecordNotFound. Closed sources are refused. entriesCancelled counts selected source rows, not both pair sides. Returned quantities are positive magnitudes in source and base units. No posting occurs.', Comment = 'is-IS=Afturkallar aðeins færslur með stöðuna Reservation með Reservation Engine Mgt. og fjarlægir báðar hliðar hvers valins pars. Uppruni án entryNo afturkallar allar frátektir sínar og má endurtaka með entriesCancelled núll; ef tilgreint entryNo finnst ekki er skilað RecordNotFound. Lokuðum uppruna er hafnað. entriesCancelled telur valdar upprunalínur, ekki báðar hliðar parsins. Skilað magn er jákvætt í mælieiningu upprunans og grunneiningum. Engin bókun fer fram.';

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Inventory Setup ori", false, false) and Resolver.HasReservationWritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
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
        TargetJson.Add('codeunit', 'Reservation Engine Mgt.');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        Clear(Parameters);
        ParameterJson.Add('name', 'source');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Object with type (SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine, ServiceLine, ProdOrderLine, ProdOrderComponent, ItemJournalLine, RequisitionLine, PlanningComponent, JobJournalLine, JobPlanningLine, InventoryDocumentLine or ItemLedgerEntry) and systemId (GUID). transferDirection is Outbound (default) or Inbound. Required unless entryNo alone or a legacy document line selector is supplied; source takes precedence.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'entryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Positive reservation pair number. With a source, intersects that source; alone, resolves the native demand-side pointer. Omit with a source to cancel all its reservations.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentType');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Legacy document type, for example Sales.Order.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document number used with documentType and lineNo.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lineNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document line number.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'systemId');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document line SystemId used with documentType.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'transferDirection');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Outbound or Inbound transfer side.');
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('entriesCancelled', 'integer', 'Selected source reservation rows cancelled, not both pair sides.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item on the resolved source.'));
        Fields.Add(ContractMgt.ResponseField('quantityUnreserved', 'decimal', 'Positive unreserved quantity in the source unit of measure.'));
        Fields.Add(ContractMgt.ResponseField('quantityBaseUnreserved', 'decimal', 'Positive unreserved quantity in base units.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required source, document identifier or quantity is absent.', 'Supply the required selector and data described in parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A selected source or explicit entry does not exist or does not match the filters.', 'Read the source again and use identifiers belonging to it.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native source, tracking or reservation validation raises an error in the isolated write transaction.', 'Resolve the native error before retrying; failed native writes roll back.'));
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
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Cancel reservations on an owned sales line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Reservation.Cancel","data":{"source":{"type":"SalesLine","systemId":"11111111-1111-1111-1111-111111111111"}}}}]');
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
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
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Inventory Setup ori", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ReservationWrite.SetCancelMode();
        if Argument."Omit Commit" then
            ReservationWrite.Run(Argument)
        else
            if not ReservationWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
