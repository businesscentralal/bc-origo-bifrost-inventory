namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads reservations with source identities and intersected item, source and tracking filters.</summary>
codeunit 70013477 "Reservation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads native reservation entries with source identities and intersected filters.', Comment = 'is-IS=Les innbyggðar frátektarfærslur með upprunaauðkennum og sameinuðum síum.';
        SelectionLbl: Label 'Read all entries or intersect item, source, entryNo, location, variant and tracking filters. entryNo identifies a pair; source selects its side.', Comment = 'is-IS=Lestu allar færslur eða sameinaðu síur fyrir vöru, uppruna, entryNo, birgðageymslu, afbrigði og rakningu. entryNo auðkennir par; uppruni velur hlið þess.';
        KeywordsLbl: Label 'read reservations,reservation pair,reserved quantity,source filter', Comment = 'is-IS=lesa frátektir,frátektarpar,frátekið magn,upprunasía';
        OverviewLbl: Label 'Reads native reservation entries with source identities and intersected filters.', Comment = 'is-IS=Les innbyggðar frátektarfærslur með upprunaauðkennum og sameinuðum síum.';
        NotesLbl: Label 'Read only. Native Reservation Entry is keyed by Entry No. and Positive; entryNo retains both matching sides unless source filters isolate one. No reservation-status filter is imposed. quantity uses source units and quantityBase uses signed base units. Expiration is the native entry date only with Use Expiration Dates enabled; otherwise blank, never 0D. No matches returns an empty page, except an explicit unmatched entryNo returns RecordNotFound.', Comment = 'is-IS=Aðeins lestur. Lykill innbyggðrar Reservation Entry er Entry No. og Positive; entryNo heldur báðum samsvarandi hliðum nema upprunasíur einangri aðra. Engin sía á frátektarstöðu er sett. quantity er í mælieiningu upprunans og quantityBase í formerktu grunnmagni. Fyrning er innbyggð dagsetning færslunnar aðeins þegar Use Expiration Dates er virkt; annars tómt, aldrei 0D. Ef ekkert finnst er skilað tómri síðu, nema tilgreint entryNo án samsvörunar skili RecordNotFound.';

    /// <summary>Provides IsEnabled for Inventory.Reservation.Get.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false));
    end;

    /// <summary>Provides GetFilterTableNo for Inventory.Reservation.Get.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    /// <summary>Provides GetDescription for Inventory.Reservation.Get.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides GetKeywords for Inventory.Reservation.Get.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides GetSelectionDescription for Inventory.Reservation.Get.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides GetEnvelope for Inventory.Reservation.Get.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.Reservation.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetParameters for Inventory.Reservation.Get.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Item number; subject takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Item SystemId, or document line SystemId with documentType.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Business Central location filter.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Exact location code; intersects locationFilter.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant code, including blank.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Exact lot number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Exact serial number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Exact package number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Number of rows to skip; default 0.'));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size 1..10000; default 100.'));
        Parameters.Add(ContractMgt.Parameter('source', 'object', false, 'Object with type (SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine, ServiceLine, ProdOrderLine, ProdOrderComponent, ItemJournalLine, RequisitionLine, PlanningComponent, JobJournalLine, JobPlanningLine, InventoryDocumentLine or ItemLedgerEntry) and systemId (GUID); transferDirection selects Outbound (default) or Inbound. Source takes precedence over legacy document fields.'));
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, 'Sales.Order, Sales.Invoice, Sales.CreditMemo, Sales.ReturnOrder, corresponding Purchase types, or Transfer.Order. Unqualified Order means Sales.Order.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Document number with documentType and lineNo.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Positive document line number.'));
        Parameters.Add(ContractMgt.Parameter('transferDirection', 'string', false, 'Outbound (default) or Inbound for transfers.'));
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, 'Reservation pair number; source filters select one side.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.Reservation.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('entries', 'array', 'Rows contain entryNo, positive, itemNo, quantity, quantityBase, locationCode, variantCode, lotNo, serialNo, packageNo, expirationDate, reservationStatus and native source pointer fields: sourceType, sourceTableNo, sourceSubtype, documentType, sourceId, documentNo, sourceBatchName, sourceProdOrderLine, sourceRefNo and lineNo.'));
        Fields.Add(ContractMgt.ResponseField('noOfLines', 'integer', 'Rows returned after skip and take.'));
        Fields.Add(ContractMgt.ResponseField('totalNoOfLines', 'integer', 'All matching rows before paging.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.Reservation.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required source, document identifier or quantity is absent.', 'Supply the required selector and data described in parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A selected source is missing or an explicit entryNo has no match after all filters.', 'Correct the source or entry number; an empty general query succeeds.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native item selection or filter error.', 'Foundation rejects the item selector or a native filter cannot be evaluated.', 'Correct the item selection and Business Central filter syntax.'));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.Reservation.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        exit(true);
    end;

    /// <summary>Provides GetMetering for Inventory.Reservation.Get.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for Inventory.Reservation.Get.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Create', 'Create a native reservation pair after reading existing entries.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a native reservation by source or entry number.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.Reservation.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.Reservation.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Read reservations on an owned sales line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Reservation.Get","data":{"source":{"type":"SalesLine","systemId":"11111111-1111-1111-1111-111111111111"},"take":100}}}]');
        exit(true);
    end;

    /// <summary>Provides GetOverview for Inventory.Reservation.Get.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Provides GetNotes for Inventory.Reservation.Get.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Provides GetMessageDirection for Inventory.Reservation.Get.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for Inventory.Reservation.Get.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingRead: Codeunit "Inventory Tracking Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingRead.ReadReservations(Argument);
    end;
}
