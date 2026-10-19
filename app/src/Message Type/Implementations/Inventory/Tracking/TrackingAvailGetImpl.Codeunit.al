namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads tracked stock, reserved quantities and availability by location and variant.</summary>
codeunit 70013473 "Tracking Avail. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads tracked inventory, reserved quantities and availability by location and variant.', Comment = 'is-IS=Les raktar birgðir, frátekið magn og tiltækt magn eftir birgðageymslu og afbrigði.';
        SelectionLbl: Label 'Select an item using subject or item identifiers; intersect location, variant and exact tracking filters.', Comment = 'is-IS=Veldu vöru með subject eða vöruauðkennum; sameinaðu síur fyrir birgðageymslu, afbrigði og nákvæma rakningu.';
        KeywordsLbl: Label 'tracking availability,lot availability,serial availability,package availability', Comment = 'is-IS=tiltæk rakning,tiltækar lotur,tiltæk raðnúmer,tiltækir pakkar';
        OverviewLbl: Label 'Reads tracked inventory, reserved quantities and availability by location and variant.', Comment = 'is-IS=Les raktar birgðir, frátekið magn og tiltækt magn eftir birgðageymslu og afbrigði.';
        NotesLbl: Label 'Read only. Groups open positive tracked item ledger entries by location, variant, lot, serial and package. All quantities use base units; availableQuantity equals remainingQuantity minus qtyReserved. expirationDate is the native entry date only with Use Expiration Dates enabled, and blank for undated or disagreeing grouped entries. No matching stock returns a successful empty page. Filters apply before paging.', Comment = 'is-IS=Aðeins lestur. Opnar jákvæðar raktar vörufærslur eru flokkaðar eftir birgðageymslu, afbrigði, lotu, raðnúmeri og pakka. Allt magn er í grunneiningum; availableQuantity er remainingQuantity að frádregnu qtyReserved. expirationDate er innbyggð dagsetning færslunnar aðeins þegar Use Expiration Dates er virkt, og tómt fyrir ódagsettar færslur eða misræmi innan hóps. Ef engar samsvarandi birgðir finnast er skilað tómri síðu án villu. Síur gilda fyrir síðuskiptingu.';

    /// <summary>Provides IsEnabled for Inventory.TrackingAvailability.Get.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false));
    end;

    /// <summary>Provides GetFilterTableNo for Inventory.TrackingAvailability.Get.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Provides GetDescription for Inventory.TrackingAvailability.Get.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Provides GetKeywords for Inventory.TrackingAvailability.Get.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Provides GetSelectionDescription for Inventory.TrackingAvailability.Get.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Provides GetEnvelope for Inventory.TrackingAvailability.Get.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.TrackingAvailability.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.TrackingAvailability.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetParameters for Inventory.TrackingAvailability.Get.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Item number; subject takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Item SystemId alias; document-line selectors are not supported by this operation.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('tableView', 'string', false, 'Business Central Item table view in SetView syntax. Used after subject and item identifiers; reads availability for the first matching item. Filter to one item for an exact selection.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Business Central location filter.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Exact location code; intersects locationFilter.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant code, including blank.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Exact lot number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Exact serial number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Exact package number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Number of rows to skip; default 0.'));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size 1..10000; default 100.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.TrackingAvailability.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Selected item.'));
        Fields.Add(ContractMgt.ResponseField('availability', 'array', 'Groups contain lotNo, serialNo, packageNo, locationCode, variantCode, expirationDate, inventory, remainingQuantity, qtyReserved and availableQuantity. Quantities are base units; availability subtracts reserved from remaining quantity.'));
        Fields.Add(ContractMgt.ResponseField('noOfLines', 'integer', 'Rows returned after skip and take.'));
        Fields.Add(ContractMgt.ResponseField('totalNoOfLines', 'integer', 'All matching rows before paging.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.TrackingAvailability.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required source, document identifier or quantity is absent.', 'Supply the required selector and data described in parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A requested item identifier cannot be resolved by Foundation.', 'Correct the item selector; no tracked stock is a successful empty page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.TextErrorEntry('Native item selection or filter error.', 'Foundation rejects the item selector or a native filter cannot be evaluated.', 'Correct the item selection and Business Central filter syntax.'));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.TrackingAvailability.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        exit(true);
    end;

    /// <summary>Provides GetMetering for Inventory.TrackingAvailability.Get.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for Inventory.TrackingAvailability.Get.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking after reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete an item tracking specification instead of reading availability.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.TrackingAvailability.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.TrackingAvailability.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Read an owned lot availability","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.TrackingAvailability.Get","data":{"itemNo":"OWNED-ITEM","lotNo":"OWNED-LOT","take":100}}}]');
        exit(true);
    end;

    /// <summary>Provides GetOverview for Inventory.TrackingAvailability.Get.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Provides GetNotes for Inventory.TrackingAvailability.Get.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Provides GetMessageDirection for Inventory.TrackingAvailability.Get.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for Inventory.TrackingAvailability.Get.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingRead: Codeunit "Inventory Tracking Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingRead.ReadAvailability(Argument);
    end;
}
