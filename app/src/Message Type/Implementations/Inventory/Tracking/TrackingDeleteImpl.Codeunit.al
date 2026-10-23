namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 10076899 "Tracking Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Tracking Specification");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Deletes a tracking specification record by its entry number.', Comment = 'is-IS=Eyðir rakningarforskrift eftir færslunúmeri hennar.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'delete tracking, delete lot, delete serial, delete package', Comment = 'is-IS=eyða rekjanleika, eyða lotu, eyða raðnúmeri, eyða pakka';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Deletes one tracking specification by entry number.', Comment = 'is-IS=Eyðir einni rekjanleikaforskrift eftir færslunúmeri.';
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
        Subject.Add('description', 'The tracking specification is named in data (entryNo); subject is not read.');
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
        Target.Add(ContractMgt.TargetEntry('data.entryNo', 'tracking specification entry no.', 'The Entry No. of the Tracking Specification record to delete, as returned by Inventory.Tracking.Assign or shown as entryNo on a TrackingSpecification row of Inventory.Tracking.Get.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The Entry No. of the Tracking Specification record to delete, a whole number.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the tracking specification record was deleted.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the deleted record, as sent.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number the record held before it was deleted.'));
        Fields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number the record held; blank when it had none.'));
        Fields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number the record held; blank when it had none.'));
        Fields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number the record held; blank when it had none.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'entryNo is required.', 'entryNo was not sent.', 'Send entryNo as a whole number. This is a plain error text, not MissingParameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Tracking specification %1 was not found.', 'No tracking specification record has that entry number (also when it was already deleted). This is a plain error text, not RecordNotFound.', 'Use the entryNo that Inventory.Tracking.Assign returned, or read it from a TrackingSpecification row of Inventory.Tracking.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native JSON or delete error text.', 'entryNo has a JSON type the call cannot read as a whole number, or the delete fails; Business Central raises its own text.', 'Send entryNo as a JSON number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Tracking domain is turned off for the company.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change tracking specifications.', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change the Tracking Specification table.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Item Tracking domain is turned on in Inventory Setup.');
        Preconditions.Add('A Tracking Specification record with that entry number exists.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Deletes the Tracking Specification record with that entry number, and commits the deletion when the call finishes. Nothing is posted and no ledger entry changes.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Effect.Add('preconditions', Preconditions);
        Effect.Add('writes', 'Tracking Specification');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking instead of deleting it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read tracking availability before deleting a specification.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking rows of an item or document line; a TrackingSpecification row carries the entryNo to delete.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Get', 'Read the tracking rows of the document line and find the entryNo of a TrackingSpecification row.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Delete', 'Delete the specification by its entryNo.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Assign', 'Create a specification with other numbers when that is wanted.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(
            'Delete the tracking specification with entry number 1',
            '{"type":"Inventory.Tracking.Delete","data":{"entryNo":1}}',
            '{"status":"Success","entryNo":1,"itemNo":"1000","lotNo":"LOT0001","serialNo":"","packageNo":""}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Deletes one tracking specification record by its entry number and returns what the record held.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Deletes the Tracking Specification record with that entry number, whatever item or source it belongs to; the call does not check what the record is tied to. The answer gives the item, lot, serial and package numbers the record held before the deletion. ' +
            'An unknown entryNo, also one that was already deleted, is answered as BusinessCentralError with the text shown in errors, not as RecordNotFound. ' +
            'Bifrost commits the deletion when the call finishes; under Omit Commit the caller''s transaction commits instead. ' +
            'The Item Tracking domain must be turned on in Inventory Setup and the caller needs BIFROST Full ori and write permission on the Tracking Specification table.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TrackingSpecification: Record "Tracking Specification";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        EntryNo: Integer;
        MissingEntryErr: Label 'entryNo is required.', Comment = 'is-IS=entryNo er nauðsynlegt.';
        NotFoundErr: Label 'Tracking specification %1 was not found.', Comment = '%1 = entry no., is-IS=Rakningarforskrift %1 fannst ekki.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('entryNo', Token) then begin
            Argument.RespondWithError(MissingEntryErr);
            exit;
        end;
        EntryNo := Token.AsValue().AsInteger();
        if not TrackingSpecification.Get(EntryNo) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, Format(EntryNo)));
            exit;
        end;

        ItemTrackingManagement.SetPointerFilter(TrackingSpecification);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', EntryNo);
        ResponseJson.Add('itemNo', TrackingSpecification."Item No.");
        ResponseJson.Add('lotNo', TrackingSpecification."Lot No.");
        ResponseJson.Add('serialNo', TrackingSpecification."Serial No.");
        ResponseJson.Add('packageNo', TrackingSpecification."Package No.");
        TrackingSpecification.Delete(true);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
