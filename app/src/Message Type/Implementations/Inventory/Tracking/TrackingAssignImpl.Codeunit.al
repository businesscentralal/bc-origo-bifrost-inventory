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
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Tracking Specification");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates a tracking specification record with a lot, serial or package number and a quantity for an item.', Comment = 'is-IS=Stofnar rakningarforskrift með lotu-, rað- eða pakkanúmeri og magni fyrir vöru.';
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
        SelectionDescriptionLbl: Label 'Creates one tracking specification from itemNo, quantity and a lot, serial or package number; it is not tied to a document line.', Comment = 'is-IS=Stofnar eina rakningarforskrift út frá itemNo, quantity og lotu-, rað- eða pakkanúmeri; hún er ekki tengd skjalalínu.';
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
        Subject.Add('description', 'The item is named in data (itemNo); subject is not read.');
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
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The No. of the Item the tracking specification is created for. No existing record is addressed; a new Tracking Specification record is inserted and its entryNo is returned.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, 'The item number, up to 20 characters; a longer text is cut off. It is not looked up in the Item table.'));
        Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, 'The quantity in the base unit of measure, stored as Quantity (Base). Any number is accepted, including zero and negative values; it is not checked against stock.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'The lot number, up to 50 characters; a longer text is cut off. At least one of lotNo, serialNo and packageNo must be a non-blank text.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'The serial number, up to 50 characters; a longer text is cut off.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'The package number, up to 50 characters; a longer text is cut off.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the tracking specification record was inserted.'));
        Fields.Add(ContractMgt.ResponseField('entryNo', 'integer', 'The entry number of the new record. Pass it to Inventory.Tracking.Delete to remove the record.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The item number that was stored.'));
        Fields.Add(ContractMgt.ResponseField('lotNo', 'string', 'The lot number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('serialNo', 'string', 'The serial number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('packageNo', 'string', 'The package number that was stored; blank when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'The quantity that was stored, in the base unit of measure.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'itemNo is required.', 'itemNo was not sent.', 'Send itemNo. This is a plain error text, not MissingParameter.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'quantity is required.', 'quantity was not sent.', 'Send quantity as a number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'lotNo, serialNo, or packageNo is required.', 'None of lotNo, serialNo and packageNo was sent, or all that were sent are blank.', 'Send at least one of lotNo, serialNo and packageNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The native JSON or insert error text.', 'A key has a JSON type the call cannot read (for example an object where text or a number is expected), or the insert fails; Business Central raises its own text.', 'Send itemNo, lotNo, serialNo and packageNo as JSON strings and quantity as a JSON number.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Item Tracking domain is turned off for the company.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot change tracking specifications.', 'Assign BIFROST Full ori (extended by BIFROST InvWrite ori) and a Business Central permission set that can change the Tracking Specification table.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The Item Tracking domain is turned on in Inventory Setup.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts one Tracking Specification record with the item, quantity and lot, serial or package number sent, and commits it when the call finishes. The record is not linked to a document line or an entry, and nothing is posted.');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete the tracking specification you created, by its entryNo, instead of assigning one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read which lots, serial and package numbers exist and what is available before assigning.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Get', 'Read the tracking of an item or document line instead of creating a specification.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TrackingAvailability.Get', 'Read which lot, serial and package numbers the item has and what is available.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Assign', 'Create the tracking specification and keep entryNo from the answer.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Tracking.Delete', 'Delete the specification by its entryNo when it is no longer wanted.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example(
            'Create a tracking specification of 5 units of lot LOT0001 for item 1000',
            '{"type":"Inventory.Tracking.Assign","data":{"itemNo":"1000","quantity":5,"lotNo":"LOT0001"}}',
            '{"status":"Success","entryNo":1,"itemNo":"1000","lotNo":"LOT0001","serialNo":"","packageNo":"","quantity":5}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates one tracking specification record with a lot, serial or package number and a quantity for an item. The record is not tied to a document line.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Creates one Tracking Specification record from itemNo, quantity and at least one of lotNo, serialNo and packageNo. The call checks only that these keys are present: the item is not looked up, the quantity is not checked against stock or the item tracking code, and over-long codes are cut off. ' +
            'The record has no source document line or ledger entry, so Inventory.Tracking.Get, which reads by item or by document line, does not show it; use the entryNo of the answer with Inventory.Tracking.Delete to remove it. ' +
            'Every call inserts a new record, so repeating a call creates a duplicate. Bifrost commits the record when the call finishes; under Omit Commit the caller''s transaction commits instead. ' +
            'The Item Tracking domain must be turned on in Inventory Setup and the caller needs BIFROST Full ori and write permission on the Tracking Specification table. A missing key is answered as BusinessCentralError with the text shown in errors.';
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
        ItemNo: Code[20];
        LotNo: Code[50];
        SerialNo: Code[50];
        PackageNo: Code[50];
        Quantity: Decimal;
        MissingItemErr: Label 'itemNo is required.', Comment = 'is-IS=itemNo er nauðsynlegt.';
        MissingQuantityErr: Label 'quantity is required.', Comment = 'is-IS=quantity er nauðsynlegt.';
        MissingTrackingErr: Label 'lotNo, serialNo, or packageNo is required.', Comment = 'is-IS=lotNo, serialNo eða packageNo er nauðsynlegt.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Tracking Specification", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError(MissingItemErr);
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ItemNo));
        if not RequestJson.Get('quantity', Token) then begin
            Argument.RespondWithError(MissingQuantityErr);
            exit;
        end;
        Quantity := Token.AsValue().AsDecimal();
        if RequestJson.Get('lotNo', Token) then
            LotNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(LotNo));
        if RequestJson.Get('serialNo', Token) then
            SerialNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(SerialNo));
        if RequestJson.Get('packageNo', Token) then
            PackageNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(PackageNo));
        if (LotNo = '') and (SerialNo = '') and (PackageNo = '') then begin
            Argument.RespondWithError(MissingTrackingErr);
            exit;
        end;

        TrackingSpecification.Init();
        TrackingSpecification."Item No." := ItemNo;
        TrackingSpecification."Lot No." := LotNo;
        TrackingSpecification."Serial No." := SerialNo;
        TrackingSpecification."Package No." := PackageNo;
        TrackingSpecification."Quantity (Base)" := Quantity;
        TrackingSpecification.Insert(true);
        ItemTrackingManagement.SetPointerFilter(TrackingSpecification);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('entryNo', TrackingSpecification."Entry No.");
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('lotNo', LotNo);
        ResponseJson.Add('serialNo', SerialNo);
        ResponseJson.Add('packageNo', PackageNo);
        ResponseJson.Add('quantity', Quantity);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
