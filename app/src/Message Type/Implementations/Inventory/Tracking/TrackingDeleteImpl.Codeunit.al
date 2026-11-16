namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Implements the released source-bound item tracking message contract.</summary>
codeunit 10076899 "Tracking Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports the shared domain and native permission gate.</summary>
    procedure IsEnabled(): Boolean
    var
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        exit(TrackingWrite.IsEnabled());
    end;

    /// <summary>Returns the native table used for message selection.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    /// <summary>Returns the localized discovery description.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Removes selected unposted item tracking from its document line through native reservation handling.', Comment = 'is-IS=Fjarlægir valda óbókaða vörurakningu af skjalalínu með innbyggðri frátektarvinnslu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized discovery keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete tracking, delete lot, delete serial, delete package', Comment = 'is-IS=eyða rekjanleika, eyða lotu, eyða raðnúmeri, eyða pakka';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized source selection guidance.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Removes selected unposted item tracking from its document line through native reservation handling.', Comment = 'is-IS=Fjarlægir valda óbókaða vörurakningu af skjalalínu með innbyggðri frátektarvinnslu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>Describes the envelope chapter of the public tracking contract.</summary>
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

    /// <summary>Describes the target chapter of the public tracking contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('data.source', 'document line', 'Select SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine or ItemJournalLine by its SystemId. The source line determines the item and native tracking pointer.'));
        exit(true);
    end;

    /// <summary>Describes the parameters chapter of the public tracking contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('source', 'object', true, 'Existing line: type is SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine or ItemJournalLine, systemId is its GUID. TransferLine optionally accepts transferDirection Outbound (default) or Inbound.'));
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Optional item consistency check; must match the selected source line.'));
        Parameters.Add(ContractMgt.Parameter('entryNos', 'array', false, 'Optional 1..200 positive entry numbers from this source. Duplicate numbers are counted once. Omit entryNo and entryNos to remove all unreserved tracking on the source, at most 200 entries. Reserved tracking refuses the whole operation.'));
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', false, 'Optional positive entryNo of an unreserved ReservationEntry tracking row returned by Inventory.Tracking.Get for this exact source. Cannot be combined with entryNos.'));
        exit(true);
    end;

    /// <summary>Describes the response chapter of the public tracking contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the source tracking entry was deleted.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the deleted record, as sent.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number the record held before it was deleted.'));
        Fields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number the record held; blank when it had none.'));
        Fields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number the record held; blank when it had none.'));
        Fields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number the record held; blank when it had none.'));
        Fields.Add(ContractMgt.ResponseField('entriesDeleted', 'integer', 'Number of selected tracking entries processed. Single-entry responses also retain entryNo, itemNo and tracking fields.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes the errors chapter of the public tracking contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DisabledWhenLbl: Label 'Item Tracking is turned off in Inventory Setup for this company.', Comment = 'is-IS=Slökkt er á vörurakningu í uppsetningu birgða fyrir þetta fyrirtæki.';
        DisabledFixLbl: Label 'Ask an administrator with the Inv. Posting Gate permission set to turn on Item Tracking in Inventory Setup.', Comment = 'is-IS=Biddu kerfisstjóra með heimildasafnið Bókunarhlið birgða að kveikja á vörurakningu í uppsetningu birgða.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, DisabledWhenLbl, DisabledFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A source selector, quantity or entryNo is absent.', 'Send the required source and tracking parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A selector or tracking value has the wrong JSON type.', 'Use the declared JSON types, positive integer entry numbers and ISO dates.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, quantity, tracking numbers or item consistency check is invalid.', 'Use an enabled source with valid native item tracking and a positive base quantity.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected line or tracking entry does not exist on that source.', 'Read Inventory.Tracking.Get for the selected source and use its entryNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The selected tracking is reserved or cannot be removed.', 'Cancel the reservation using Inventory.Reservation.Cancel before removing its tracking.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Native source or tracking permissions are missing.', 'Assign the Bifrost "Full Access" permission set and the required Business Central document and reservation permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native item tracking validation refuses the operation.', 'Correct the source or tracking values in Business Central. A standalone failure rolls back; Omit Commit propagates the failure to the caller transaction.'));
        exit(true);
    end;

    /// <summary>Describes the effect chapter of the public tracking contract.</summary>
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

    /// <summary>Describes the metering chapter of the public tracking contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the related chapter of the public tracking contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking instead of deleting it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read tracking availability before deleting a specification.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking rows of an item or document line; a ReservationEntry row carries the entryNo to delete.'));
        exit(true);
    end;

    /// <summary>Describes the workflow chapter of the public tracking contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Assign', 'Assign tracking to your own selected document line.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Get', 'Read the same source and keep its ReservationEntry entryNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Delete', 'Remove unreserved tracking from the same source when no longer needed.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Describes the examples chapter of the public tracking contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Use your own purchase line SystemId and tracking entry', '{"type":"Inventory.Tracking.Delete","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"},"entryNo":210}}', '{"status":"Success","entryNo":210,"itemNo":"1000","lotNo":"LOT-A","serialNo":"","packageNo":""}'));
        exit(true);
    end;

    /// <summary>Describes the overview chapter of the public tracking contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Removes selected unposted item tracking from its document line through native reservation handling.';
        exit(true);
    end;

    /// <summary>Describes the notes chapter of the public tracking contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Select an existing SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine or ItemJournalLine using data.source.type and data.source.systemId. Native source permissions and item tracking rules apply. Quantity is in base units; serial tracking requires one unit. Read Inventory.Tracking.Get with the same source to see the resulting ReservationEntry rows. Delete accepts one entryNo, an entryNos array, or all unreserved tracking on the selected source when both are omitted. Every selected entry is validated before any removal; another source cannot be affected. ' +
            'No ledger entries are posted. No unlinked persistent Tracking Specification is inserted. Native failures roll back standalone calls; Omit Commit leaves transaction ownership with the caller and propagates native failures. Repeating an assignment may add quantity; read the source before retrying.';
        exit(true);
    end;

    /// <summary>Returns the direction of this released message type.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Executes the versioned tracking operation after checking the company gate and licence.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        TrackingWrite.SetDeleteMode();
        if not TrackingWrite.AssertEnabled(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            TrackingWrite.Run(Argument)
        else
            if not TrackingWrite.Run(Argument) then
                TrackingWrite.RespondWithFailure(Argument);
    end;
}
