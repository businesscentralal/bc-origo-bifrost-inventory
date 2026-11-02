namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 10076911 "Transf Undo Rcpt Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::TransferOrders, Database::"Transfer Receipt Header", false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Transfer Receipt Header");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Undoes a posted transfer receipt by writing corrective item ledger entries.', Comment = 'is-IS=Afturkallar bókaða millifærslumóttöku með leiðréttingarfærslum í vörufærslum.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'undo transfer receipt', Comment = 'is-IS=afturkalla millifærslumóttöku';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Undoes a posted transfer receipt. Does not delete the posted document.', Comment = 'is-IS=Afturkallar bókaða millifærslumóttöku. Eyðir ekki bókaða skjalinu.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The posted transfer receipt is named under data.documentNo; subject is not read.');
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
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'document no.', 'The No. of the Transfer Receipt Header. It is looked up only to tell a missing receipt from one that exists but cannot be undone.'));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, 'No. of the posted transfer receipt, at most 20 characters; a longer value is cut to 20.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'This type never answers Success: a call that passes the checks is answered with the error status and the text that receipt undo is not available.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Transfer Orders domain is turned off for this company.', 'Turn the domain on from the Inventory Setup page, then send the call again.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the Inv. Posting Gate permission set.', 'Assign Inv. Posting Gate. Note that the type refuses every receipt anyway.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'documentNo must be specified.', 'documentNo was not sent. The answer carries the error text and no code.', 'Send documentNo, the number of the posted transfer receipt.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Posted transfer receipt %1 was not found.', 'No Transfer Receipt Header has that number. The answer carries the error text and no code.', 'Check the number of the posted transfer receipt.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Posted transfer receipts cannot be undone in this Business Central version.', 'The posted transfer receipt exists. Every such call is refused. The answer carries the error text and no code.', 'Do not call this type for a correction. Undo the shipment with Inventory.Transfer.UndoShipment, or correct the stock with a new posting.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'Nothing. The call only looks up the posted transfer receipt and then always answers an error, because receipt undo is not available in this Business Central version.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'Bifrost Full Access and Inv. Posting Gate');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Transfer.UndoShipment', 'Undo a posted transfer shipment. Receipt undo is not available in this version.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', 'Post the transfer order when the receipt was posted wrongly and a new posting is the way to correct it.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Transfer.UndoReceipt', 'Ask to undo the posted receipt; the answer is always an error because this version cannot undo a transfer receipt.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Create', 'Move the goods back with a new transfer order from the receiving location to the sending one.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship and receive the new transfer order.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Ask to undo posted transfer receipt 109001 (always refused)', '{"type":"Inventory.Transfer.UndoReceipt","data":{"documentNo":"109001"}}', '{"status":"Error","error":"Posted transfer receipts cannot be undone in this Business Central version."}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Refuses to undo a posted transfer receipt in this Business Central version. A receipt that exists is answered with an error, and nothing is changed.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Success is never returned: a posted transfer receipt that exists is answered with an error, and one that does not exist is answered with a not found error. Neither answer carries an error code. ' +
            'Nothing is changed, so nothing is committed and the call can be repeated. ' +
            'The caller needs the Transfer Orders domain turned on in Inventory Setup and the Inv. Posting Gate permission set, although nothing is posted. ' +
            'Use Inventory.Transfer.UndoShipment to undo a posted transfer shipment. The type does not read subject.';
        exit(true);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ReceiptHeader: Record "Transfer Receipt Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        MissingDocErr: Label 'documentNo must be specified.', Comment = 'is-IS=documentNo verður að vera tilgreint.';
        NotFoundErr: Label 'Posted transfer receipt %1 was not found.', Comment = '%1 = document no., is-IS=Bókuð millifærslumóttaka %1 fannst ekki.';
        NotSupportedErr: Label 'Posted transfer receipts cannot be undone in this Business Central version.', Comment = 'is-IS=Ekki er hægt að afturkalla bókaðar millifærslumóttökur í þessari útgáfu Business Central.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::TransferOrders, Database::"Transfer Receipt Header", false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError(MissingDocErr);
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsCode(), 1, MaxStrLen(DocumentNo));
        if not ReceiptHeader.Get(DocumentNo) then begin
            Argument.RespondWithError(StrSubstNo(NotFoundErr, DocumentNo));
            exit;
        end;
        Argument.RespondWithError(NotSupportedErr);
    end;
}
