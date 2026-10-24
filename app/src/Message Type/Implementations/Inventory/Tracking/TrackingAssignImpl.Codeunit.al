namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 10076897 "Tracking Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Assigns lot, serial or package tracking to an existing sales, purchase or transfer line through native item tracking.', Comment = 'is-IS=Úthlutar lotu-, rað- eða pakkarakningu á sölu-, innkaupa- eða flutningslínu með innbyggðri vörurakningu.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assign lot, assign serial, assign package, item tracking', Comment = 'is-IS=úthluta lotu, úthluta raðnúmeri, úthluta pakka, vörurekjanleiki';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Assigns lot, serial or package tracking to an existing sales, purchase or transfer line through native item tracking.', Comment = 'is-IS=Úthlutar lotu-, rað- eða pakkarakningu á sölu-, innkaupa- eða flutningslínu með innbyggðri vörurakningu.';
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
        Subject.Add('description', 'Select the document line with data.source.type and data.source.systemId.');
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
        Target.Add(ContractMgt.TargetEntry('data.source', 'document line', 'Select SalesLine, PurchaseLine or TransferLine by its SystemId. The source line determines the item and native tracking pointer.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('source', 'object', true, 'Existing line: type is SalesLine, PurchaseLine or TransferLine, systemId is its GUID. TransferLine optionally accepts transferDirection Outbound (default) or Inbound.'));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Optional item consistency check; must match the selected source line.'));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', false, 'Positive base quantity for one tracking assignment. Required unless entries is supplied. A serial number requires exactly one base unit.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Lot number, at most 50 characters; at least one tracking number is required.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Serial number, at most 50 characters.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Package number, at most 50 characters.'));
        Parameters.Add(ContractMgt.Parameter('expirationDate', 'string', false, 'Optional ISO date YYYY-MM-DD, subject to native item tracking rules.'));
        Parameters.Add(ContractMgt.Parameter('entries', 'array', false, 'Optional 1..200 tracking objects, each with required positive quantity and lotNo, serialNo or packageNo; optional expirationDate. All request values are validated before writes. Use this instead of the top-level tracking values.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the source tracking entry was inserted.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the new record. Pass it to Inventory.Tracking.Delete to remove the record.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number that was stored.'));
        Fields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity that was stored, in the base unit of measure.'));
        Fields.Add(ContractMgt.ResponseField('entriesAssigned', 'integer', 'Number of selected tracking entries processed. Single-entry responses also retain entryNo, itemNo and tracking fields.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A source selector, quantity or entryNo is absent.', 'Send the required source and tracking parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A selector or tracking value has the wrong JSON type.', 'Use the declared JSON types, positive integer entry numbers and ISO dates.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, quantity, tracking numbers or item consistency check is invalid, or the domain is disabled.', 'Use an enabled source with valid native item tracking and a positive base quantity.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected line or tracking entry does not exist on that source.', 'Read Inventory.Tracking.Get for the selected source and use its entryNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected tracking is reserved or cannot be removed.', 'Cancel the reservation using Inventory.Reservation.Cancel before removing its tracking.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Native source or tracking permissions are missing.', 'Assign BIFROST Full ori and the required Business Central document and reservation permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native item tracking validation refuses the operation.', 'Correct the source or tracking values in Business Central. A standalone failure rolls back; Omit Commit propagates the failure to the caller transaction.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('Item Tracking is enabled and the caller can write the selected source and reservation entries.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Changes only unposted tracking on the selected source using native item tracking and reservation handling. No direct persistent Tracking Specification inserts and no ledger postings. Standalone calls commit on success; Omit Commit stays in the caller transaction.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Remove one unreserved tracking entry by source and entryNo.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read which lots, serial and package numbers exist and what is available before assigning.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking of an item or document line instead of creating a specification.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Assign', 'Assign tracking to your own selected document line.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Get', 'Read the same source and keep its ReservationEntry entryNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Delete', 'Remove one unreserved entryNo from the same source when no longer needed.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Use your own purchase line SystemId and tracking entry', '{"type":"Inventory.Tracking.Assign","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"},"quantity":2,"lotNo":"LOT-A"}}', '{"status":"Success","entryNo":210,"itemNo":"1000","lotNo":"LOT-A","serialNo":"","packageNo":""}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Assigns lot, serial or package tracking to an existing sales, purchase or transfer line through native item tracking.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Select an existing SalesLine, PurchaseLine or TransferLine using data.source.type and data.source.systemId. Native source permissions and item tracking rules apply. Quantity is in base units; serial tracking requires one unit. Read Inventory.Tracking.Get with the same source to see the resulting ReservationEntry rows. Delete requires the source and one unreserved entryNo, so another document cannot be affected. ' +
            'No ledger entries are posted. No unlinked persistent Tracking Specification is inserted. Native failures roll back standalone calls; Omit Commit leaves transaction ownership with the caller and propagates native failures. Repeating an assignment may add quantity; read the source before retrying.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            TrackingWrite.Run(Argument)
        else
            if not TrackingWrite.Run(Argument) then
                Argument.RespondWithLastError();
    end;
}
