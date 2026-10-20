namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads lot, serial and package tracking for an item or document line.</summary>
codeunit 10076900 "Tracking Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads lot, serial and package tracking for an item or document line.', Comment = 'is-IS=Les lotu-, raðnúmera- og pakkarakningu fyrir vöru eða skjalalínu.';
        SelectionLbl: Label 'Select a source or legacy document line; otherwise select an item. A sales, purchase or transfer line SystemId in subject selects that source.', Comment = 'is-IS=Veldu uppruna eða eldri skjalalínuvalkost; annars skaltu velja vöru. SystemId sölu-, innkaupa- eða flutningslínu í subject velur þann uppruna.';
        KeywordsLbl: Label 'read tracking,lot tracking,serial tracking,package tracking', Comment = 'is-IS=lesa rakningu,loturakning,raðnúmerarakning,pakkarakning';
        OverviewLbl: Label 'Reads lot, serial and package tracking for an item or document line.', Comment = 'is-IS=Les lotu-, raðnúmera- og pakkarakningu fyrir vöru eða skjalalínu.';
        NotesLbl: Label 'Read only. Source selection takes precedence over item selection. Item mode returns tracked remaining ledger entries and nonzero reservation entries; source mode returns reservation and tracking specification rows. quantityBase totals all matching rows before paging, not available stock. Expiration is the native entry date only when Use Expiration Dates is enabled; otherwise blank, never 0D. No matching tracking returns RecordNotFound; paging past existing rows returns an empty page.', Comment = 'is-IS=Aðeins lestur. Val uppruna hefur forgang yfir vöruval. Vöruval skilar röknum eftirstöðvum vörufærslna og frátektarfærslum með magni; upprunaval skilar frátektar- og rakningarlínum. quantityBase er summa allra samsvarandi lína fyrir síðuskiptingu, ekki tiltækar birgðir. Fyrning er innbyggð dagsetning færslunnar aðeins þegar Use Expiration Dates er virkt; annars tómt, aldrei 0D. Ef engin rakning finnst er skilað RecordNotFound; síðuskipting fram yfir fyrirliggjandi línur skilar tómri síðu.';

    /// <summary>Provides IsEnabled for Inventory.Tracking.Get.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", false, false));
    end;

    /// <summary>Provides GetFilterTableNo for Inventory.Tracking.Get.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Provides GetDescription for Inventory.Tracking.Get.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides GetKeywords for Inventory.Tracking.Get.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides GetSelectionDescription for Inventory.Tracking.Get.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides GetEnvelope for Inventory.Tracking.Get.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Tracking.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.Tracking.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetParameters for Inventory.Tracking.Get.</summary>
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
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Business Central Item table view in SetView syntax. Item mode only, after subject and item identifiers; reads tracking for the first matching item. Filter to one item for an exact selection.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Business Central location filter.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Exact location code; intersects locationFilter.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant code, including blank.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Exact lot number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Exact serial number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Exact package number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Number of rows to skip; default 0.'));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size 1..10000; default 100.'));
        Parameters.Add(ContractMgt.Parameter('source', 'object', false, 'Object with type (SalesLine, PurchaseLine or TransferLine) and systemId (GUID); transferDirection selects Outbound (default) or Inbound. Source takes precedence over legacy document fields.'));
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, 'Sales.Order, Sales.Invoice, Sales.CreditMemo, Sales.ReturnOrder, corresponding Purchase types, or Transfer.Order. Unqualified Order means Sales.Order.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Document number with documentType and lineNo.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Positive document line number.'));
        Parameters.Add(ContractMgt.Parameter('transferDirection', 'string', false, 'Outbound (default) or Inbound for transfers.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.Tracking.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item on the selected source or item.'));
        Fields.Add(ContractMgt.ResponseField('quantityBase', 'decimal', 'Sum of all matching signed tracking rows before paging; not available stock.'));
        Fields.Add(ContractMgt.ResponseField('trackingLines', 'array', 'Rows contain source, entryNo, itemNo, lotNo, serialNo, packageNo, locationCode, variantCode, quantityBase and expirationDate. Reservation rows also include positive, reservationStatus and source pointer fields; specification rows include quantityHandledBase and quantityInvoicedBase. In source mode the response also includes source pointer fields.'));
        Fields.Add(ContractMgt.ResponseField('noOfLines', 'integer', 'Rows returned after skip and take.'));
        Fields.Add(ContractMgt.ResponseField('totalNoOfLines', 'integer', 'All matching rows before paging.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.Tracking.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required source, document identifier or quantity is absent.', 'Supply the required selector and data described in parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A selected source is missing or no tracking rows match before paging.', 'Check the source and intersected filters; paging alone does not cause this error.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native item selection or filter error.', 'Foundation rejects the item selector or a native filter cannot be evaluated.', 'Correct the item selection and Business Central filter syntax.'));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.Tracking.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        exit(true);
    end;

    /// <summary>Provides GetMetering for Inventory.Tracking.Get.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for Inventory.Tracking.Get.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking after reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete an item tracking specification instead of reading availability.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.Tracking.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.Tracking.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Read tracking on an owned purchase line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Tracking.Get","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"},"take":100}}}]');
        exit(true);
    end;

    /// <summary>Provides GetOverview for Inventory.Tracking.Get.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Provides GetNotes for Inventory.Tracking.Get.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Provides GetMessageDirection for Inventory.Tracking.Get.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for Inventory.Tracking.Get.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingRead: Codeunit "Inventory Tracking Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingRead.ReadTracking(Argument);
    end;
}
