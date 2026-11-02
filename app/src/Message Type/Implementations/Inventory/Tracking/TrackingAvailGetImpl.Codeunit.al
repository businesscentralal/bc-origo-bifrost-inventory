namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads tracked stock, reserved quantities and availability by location and variant.</summary>
codeunit 10076898 "Tracking Avail. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('guid');
        Forms.Add('item no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', 'The subject is the SystemId or No. of the Item; data selects the same item when subject is blank.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', false);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.TrackingAvailability.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item; it takes precedence over the item identifiers in data.'));
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item, used when subject is blank.'));
        Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid', 'The SystemId of the Item, tried in this order after itemNo. Document line SystemIds are not accepted.'));
        Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view; the first matching item is read, so filter to one item for an exact selection.'));
        exit(true);
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
        GroupFields: JsonArray;
        GroupsField: JsonObject;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Selected item.'));
        GroupFields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number of the group; blank when the group has none.'));
        GroupFields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number of the group; blank when the group has none.'));
        GroupFields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number of the group; blank when the group has none.'));
        GroupFields.Add(ContractMgt.ResponseField('locationCode', 'string', 'The location code of the group.'));
        GroupFields.Add(ContractMgt.ResponseField('variantCode', 'string', 'The variant code of the group.'));
        GroupFields.Add(ContractMgt.ResponseField('expirationDate', 'string', 'The expiration date in YYYY-MM-DD form when the item tracking code uses expiration dates and the grouped entries agree; otherwise blank.'));
        GroupFields.Add(ContractMgt.ResponseField('inventory', 'decimal', 'The remaining quantity of the group in the base unit of measure.'));
        GroupFields.Add(ContractMgt.ResponseField('remainingQuantity', 'decimal', 'The remaining quantity of the group; the same as inventory.'));
        GroupFields.Add(ContractMgt.ResponseField('qtyReserved', 'decimal', 'The quantity of the group that is reserved, in the base unit of measure.'));
        GroupFields.Add(ContractMgt.ResponseField('availableQuantity', 'decimal', 'The remaining quantity less the reserved quantity.'));
        GroupsField := ContractMgt.ResponseField('availability', 'array', 'One group per location, variant, lot, serial and package of open positive tracked item ledger entries. Quantities are base units; availability subtracts reserved from remaining quantity.');
        GroupsField.Add('children', GroupFields);
        Fields.Add(GroupsField);
        Fields.Add(ContractMgt.ResponseField('noOfLines', 'integer', 'Rows returned after skip and take.'));
        Fields.Add(ContractMgt.ResponseField('totalNoOfLines', 'integer', 'All matching rows before paging.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.TrackingAvailability.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingItemErr: Label 'itemNo must be specified.', Comment = 'is-IS=itemNo verður að vera tilgreint.';
        MissingItemWhenTxt: Label 'data.itemNo was not sent or is blank.', Comment = 'is-IS=data.itemNo var ekki sent eða er autt.';
        ItemNoNextStepTxt: Label 'Send the item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingItemErr, MissingItemWhenTxt, ItemNoNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A requested item identifier cannot be resolved by Foundation.', 'Correct the item selector; no tracked stock is a successful empty page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native item selection or filter error.', 'Foundation rejects the item selector or a native filter cannot be evaluated.', 'Correct the item selection and Business Central filter syntax.'));
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.TrackingAvailability.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Nothing is changed. Reads the open tracked item ledger entries of the item and the quantity reserved against them.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Read-Only');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking rows (ledger entries, reservations and specifications) of an item or a document line instead of availability per lot.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Create a tracking specification instead of reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete a tracking specification instead of reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read the reservations of the item when you need the demand behind qtyReserved.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.TrackingAvailability.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.TrackingAvailability.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Example: JsonObject;
    begin
        Clear(Examples);
        Example := ContractMgt.Example(
            'Read an owned lot availability',
            '{"type":"Inventory.TrackingAvailability.Get","data":{"itemNo":"OWNED-ITEM","lotNo":"OWNED-LOT","take":100}}',
            '{"status":"Success","itemNo":"OWNED-ITEM","availability":[{"lotNo":"OWNED-LOT","serialNo":"","packageNo":"","locationCode":"BLUE","variantCode":"","expirationDate":"","inventory":2,"remainingQuantity":2,"qtyReserved":0,"availableQuantity":2}],"noOfLines":1,"totalNoOfLines":1}');
        Example.Add('description', 'Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.');
        Examples.Add(Example);
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
        MissingItemErr: Label 'itemNo must be specified.', Comment = 'is-IS=itemNo verður að vera tilgreint.';
        ItemNoExpectedTxt: Label 'A non-empty item number in data.itemNo.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo.';
        ItemNoNextStepTxt: Label 'Send the item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Item Ledger Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        // #128: no item selection at all (or a blank itemNo alone) is MissingParameter on itemNo.
        if not TrackingRead.HasItemSelection(Argument) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingItemErr, 'itemNo', '', ItemNoExpectedTxt, ItemNoNextStepTxt);
            exit;
        end;
        TrackingRead.ReadAvailability(Argument);
    end;
}
