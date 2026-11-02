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
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('guid');
        Forms.Add('item no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The subject is the SystemId of a Sales Line, Purchase Line or Transfer Line (selects that source) or the SystemId or No. of the Item; data selects the same things when subject is blank.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.Tracking.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.source', 'object', 'A Sales Line, Purchase Line or Transfer Line selected by type and systemId (and transferDirection). A source takes precedence over every other selector.'));
        Target.Add(ContractMgt.TargetEntry('data.documentType + data.documentNo + data.lineNo', 'document type, document no. and line no.', 'A Sales Line, Purchase Line or Transfer Line selected by document type, document number and line number. It takes precedence over subject and item selectors.'));
        Target.Add(ContractMgt.TargetEntry('data.documentType + data.systemId', 'document type and guid', 'The same line selected by its SystemId, with documentType instead of documentNo and lineNo.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of a Sales Line, Purchase Line or Transfer Line selects that source; any other SystemId is read as the SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item; it takes precedence over the item identifiers in data.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item, used when subject is blank.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item, tried in this order after itemNo.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view; the first matching item is read, so filter to one item for an exact selection.'));
        exit(true);
    end;

    /// <summary>Provides GetParameters for Inventory.Tracking.Get.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        SourceParameter: JsonObject;
        SourceChildren: JsonArray;
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
        SourceParameter := ContractMgt.Parameter('source', 'object', false, 'The source line to read tracking for. Source takes precedence over the legacy document fields.');
        SourceChildren.Add(ContractMgt.Parameter('type', 'string', true, 'SalesLine, PurchaseLine or TransferLine.'));
        SourceChildren.Add(ContractMgt.Parameter('systemId', 'string', true, 'The SystemId (GUID) of the source line.'));
        SourceChildren.Add(ContractMgt.Parameter('transferDirection', 'string', false, 'Outbound (default) or Inbound; selects the shipment or the receipt side of a TransferLine.'));
        SourceParameter.Add('children', SourceChildren);
        Parameters.Add(SourceParameter);
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, 'Sales.Order, Sales.Invoice, Sales.CreditMemo, Sales.ReturnOrder, Purchase.Order, Purchase.Invoice, Purchase.CreditMemo, Purchase.ReturnOrder or Transfer.Order. The unqualified Order, Invoice, Credit Memo and Return Order mean the Sales types. Quotes and blanket orders are not supported.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Document number with documentType and lineNo, up to 20 characters. Not used when systemId selects the line.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Positive document line number, with documentType and documentNo.'));
        Parameters.Add(ContractMgt.Parameter('transferDirection', 'string', false, 'Outbound (default) or Inbound for transfers, with documentType Transfer.Order.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.Tracking.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        LineFields: JsonArray;
        LinesField: JsonObject;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item on the selected source or item.'));
        Fields.Add(ContractMgt.ResponseField('quantityBase', 'decimal', 'Sum of all matching signed tracking rows before paging; not available stock.'));
        Fields.Add(ContractMgt.ResponseField('sourceType', 'string', 'Source mode only: the source kind, for example SalesLine, PurchaseLine or TransferLine.'));
        Fields.Add(ContractMgt.ResponseField('sourceTableNo', 'integer', 'Source mode only: the table number of the source line.'));
        Fields.Add(ContractMgt.ResponseField('sourceSubtype', 'integer', 'Source mode only: the document type ordinal of the source line, or the transfer direction.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'Source mode only: the document type of the source line, for example Purchase.Order.'));
        Fields.Add(ContractMgt.ResponseField('sourceId', 'string', 'Source mode only: the document number of the source line.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'Source mode only: the document number of the source line, as sourceId.'));
        Fields.Add(ContractMgt.ResponseField('sourceBatchName', 'string', 'Source mode only: the batch name of the source line; blank for document lines.'));
        Fields.Add(ContractMgt.ResponseField('sourceProdOrderLine', 'integer', 'Source mode only: the production order line of the source line; 0 for document lines.'));
        Fields.Add(ContractMgt.ResponseField('sourceRefNo', 'integer', 'Source mode only: the line number of the source line.'));
        Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Source mode only: the line number of the source line, as sourceRefNo.'));
        LineFields.Add(ContractMgt.ResponseField('source', 'string', 'Where the row comes from: ItemLedgerEntry, ReservationEntry or TrackingSpecification.'));
        LineFields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number in the table the row comes from.'));
        LineFields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number of the row.'));
        LineFields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number; blank when the row has none.'));
        LineFields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number; blank when the row has none.'));
        LineFields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number; blank when the row has none.'));
        LineFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code of the row.'));
        LineFields.Add(ContractMgt.ResponseField('variantCode', 'string', 'The variant code of the row.'));
        LineFields.Add(ContractMgt.ResponseField('quantityBase', 'decimal', 'The signed quantity of the row in the base unit of measure; for a ledger entry the remaining quantity.'));
        LineFields.Add(ContractMgt.ResponseField('expirationDate', 'string', 'The expiration date in YYYY-MM-DD form when the item tracking code uses expiration dates; otherwise blank.'));
        LineFields.Add(ContractMgt.ResponseField('positive', 'boolean', 'Reservation rows only: true on the supply side.'));
        LineFields.Add(ContractMgt.ResponseField('reservationStatus', 'string', 'Reservation rows only: Reservation, Tracking, Surplus or Prospect.'));
        LineFields.Add(ContractMgt.ResponseField('sourceType', 'string', 'Reservation rows only: the source kind the row belongs to.'));
        LineFields.Add(ContractMgt.ResponseField('sourceTableNo', 'integer', 'Reservation rows only: the table number of the source.'));
        LineFields.Add(ContractMgt.ResponseField('sourceSubtype', 'integer', 'Reservation rows only: the source subtype.'));
        LineFields.Add(ContractMgt.ResponseField('documentType', 'string', 'Reservation rows only: the document type of the source, for example Sales.Order.'));
        LineFields.Add(ContractMgt.ResponseField('sourceId', 'string', 'Reservation rows only: the document number of the source.'));
        LineFields.Add(ContractMgt.ResponseField('documentNo', 'string', 'Reservation rows only: the document number of the source, as sourceId.'));
        LineFields.Add(ContractMgt.ResponseField('sourceBatchName', 'string', 'Reservation rows only: the batch name of the source.'));
        LineFields.Add(ContractMgt.ResponseField('sourceProdOrderLine', 'integer', 'Reservation rows only: the production order line of the source.'));
        LineFields.Add(ContractMgt.ResponseField('sourceRefNo', 'integer', 'Reservation rows only: the line number of the source.'));
        LineFields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Reservation rows only: the line number of the source, as sourceRefNo.'));
        LineFields.Add(ContractMgt.ResponseField('quantityHandledBase', 'decimal', 'Tracking specification rows only: the quantity already handled, in the base unit of measure.'));
        LineFields.Add(ContractMgt.ResponseField('quantityInvoicedBase', 'decimal', 'Tracking specification rows only: the quantity already invoiced, in the base unit of measure.'));
        LinesField := ContractMgt.ResponseField('trackingLines', 'array', 'The tracking rows of the page: remaining ledger entries and nonzero reservation entries in item mode; reservation and tracking specification rows in source mode.');
        LinesField.Add('children', LineFields);
        Fields.Add(LinesField);
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native item selection or filter error.', 'Foundation rejects the item selector or a native filter cannot be evaluated.', 'Correct the item selection and Business Central filter syntax.'));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.Tracking.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is changed. Reads lot, serial and package tracking from item ledger entries, reservation entries and tracking specifications.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'the Bifrost "Read-Only" permission set');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read how much of each lot, serial or package is in stock and available after reservations, instead of tracking rows.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Create a tracking specification instead of reading tracking.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete a tracking specification by the entryNo of a TrackingSpecification row.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read the reservations of an item or line instead of its tracking numbers.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.Tracking.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.Tracking.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Example: JsonObject;
    begin
        Clear(Examples);
        Example := ContractMgt.Example(
            'Read tracking on an owned purchase line',
            '{"type":"Inventory.Tracking.Get","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"},"take":100}}',
            '{"status":"Success","itemNo":"1000","quantityBase":2,"sourceType":"PurchaseLine","sourceTableNo":39,"sourceSubtype":1,"documentType":"Purchase.Order","sourceId":"106001","documentNo":"106001","sourceBatchName":"","sourceProdOrderLine":0,"sourceRefNo":10000,"lineNo":10000,"trackingLines":[{"source":"ReservationEntry","entryNo":210,"itemNo":"1000","lotNo":"LOT0001","serialNo":"","packageNo":"","locationCode":"BLUE","variantCode":"","quantityBase":2,"expirationDate":"","positive":true,"reservationStatus":"Surplus","sourceType":"PurchaseLine","sourceTableNo":39,"sourceSubtype":1,"documentType":"Purchase.Order","sourceId":"106001","documentNo":"106001","sourceBatchName":"","sourceProdOrderLine":0,"sourceRefNo":10000,"lineNo":10000}],"noOfLines":1,"totalNoOfLines":1}');
        Example.Add('description', 'Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.');
        Examples.Add(Example);
        Examples.Add(ContractMgt.Example(
            'Read the lot tracking of item 1000 at location BLUE',
            '{"type":"Inventory.Tracking.Get","data":{"itemNo":"1000","locationCode":"BLUE"}}',
            '{"status":"Success","itemNo":"1000","quantityBase":10,"trackingLines":[{"source":"ItemLedgerEntry","entryNo":45,"itemNo":"1000","lotNo":"LOT0001","serialNo":"","packageNo":"","locationCode":"BLUE","variantCode":"","quantityBase":10,"expirationDate":""}],"noOfLines":1,"totalNoOfLines":1}'));
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
