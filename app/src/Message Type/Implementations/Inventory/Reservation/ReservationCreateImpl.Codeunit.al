namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013476 "Reservation Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Manually pairs native reservation sources with explicit supply or matching posted inventory.', Comment = 'is-IS=Parar innbyggða frátektaruppruna handvirkt við tilgreindan uppruna eða samsvarandi bókaðar birgðir.';
        SelectionLbl: Label 'Select a W1 reservation source or legacy document line and a positive quantity in the source unit of measure.', Comment = 'is-IS=Veldu W1 frátektaruppruna eða eldri skjalalínuvalkost og jákvætt magn í mælieiningu upprunans.';
        KeywordsLbl: Label 'create manual reservation,explicit supply,reserve item', Comment = 'is-IS=stofna handvirka frátekt,tilgreindur uppruni,taka vöru frá';
        OverviewLbl: Label 'Manually pairs native reservation sources with explicit supply or matching posted inventory.', Comment = 'is-IS=Parar innbyggða frátektaruppruna handvirkt við tilgreindan uppruna eða samsvarandi bókaðar birgðir.';
        NotesLbl: Label 'Uses native W1 source adapters and Create Reserv. Entry. quantity uses the source unit of measure; quantityBase is the converted quantity. Explicit supply must be distinct and opposite, with the same item, variant and location. Without supply or itemLedgerEntryNo, matching open positive posted inventory is selected in entry order and may produce several pairs. expectedDate is forwarded to each native pair. Closed sources, insufficient availability and invalid serial quantities refuse without partial pairing. The native call must increase reserved base quantity by the requested amount; sources without native creation support are refused without partial pairing. RequisitionLine and PlanningComponent require native order-to-order binding; ordinary manual requests for those sources are refused. No posting occurs.', Comment = 'is-IS=Notar innbyggða W1 upprunaaðlögun og Create Reserv. Entry. quantity er í mælieiningu upprunans; quantityBase er umreiknað magn. Tilgreindur mótuppruni verður að vera aðskilinn og gagnstæður fyrir sömu vöru, afbrigði og birgðageymslu. Án supply eða itemLedgerEntryNo eru samsvarandi opnar jákvæðar bókaðar birgðir valdar í færsluröð og geta myndað mörg pör. expectedDate er sent áfram til hvers innbyggðs pars. Lokuðum uppruna, ónógu tiltæku magni og ógildu raðnúmeramagni er hafnað án pörunar að hluta. Innbyggða aðgerðin verður að auka frátekið grunnmagn um umbeðið magn; upprunum án innbyggðs stuðnings við stofnun er hafnað án pörunar að hluta. RequisitionLine og PlanningComponent krefjast innbyggðrar pöntunartengingar; venjulegum handvirkum beiðnum fyrir þá uppruna er hafnað. Engin bókun fer fram.';

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
        ParameterJson: JsonObject;
    begin
        Clear(Parameters);
        ParameterJson.Add('name', 'source');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Object with type (SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine, ServiceLine, ProdOrderLine, ProdOrderComponent, ItemJournalLine, RequisitionLine, PlanningComponent, JobJournalLine, JobPlanningLine, InventoryDocumentLine or ItemLedgerEntry) and systemId (GUID). transferDirection is Outbound (default) or Inbound. Required unless documentType with a line selector is supplied; source takes precedence.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'supply');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Opposite native source object with type and systemId, plus optional transferDirection. Takes precedence over itemLedgerEntryNo. Omit both for matching posted inventory in entry order.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'quantity');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', 'Positive quantity in the source unit of measure.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'expectedDate');
        ParameterJson.Add('type', 'date');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Optional native expected date forwarded to each selected pair; defaults to an unspecified date.');
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
        Clear(ParameterJson);
        ParameterJson.Add('name', 'itemLedgerEntryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Specific posted supply instead of the supply object.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lotNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested lot; must match selected inventory.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'serialNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested serial; one base unit only.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'packageNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested package; must match selected inventory.');
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
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Reserved quantity in the source unit of measure.'));
        Fields.Add(ContractMgt.ResponseField('quantityBase', 'decimal', 'Reserved quantity in base units.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'Created pair number for explicit supply, or when automatic inventory selection creates exactly one pair.'));
        Fields.Add(ContractMgt.ResponseField('entryNos', 'array', 'Created pair numbers for automatic inventory selection; absent for explicit supply.'));
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
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Reserve owned inventory for a sales line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Reservation.Create","data":{"source":{"type":"SalesLine","systemId":"11111111-1111-1111-1111-111111111111"},"itemLedgerEntryNo":123,"quantity":2}}}]');
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
        if Argument."Omit Commit" then
            ReservationWrite.Run(Argument)
        else
            if not ReservationWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
