namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 10076862 "Cost To GL Test Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, false, true));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Counts the items that match an item filter before inventory cost is posted to G/L; nothing is posted.', Comment = 'is-IS=Telur vörurnar sem passa við vörusíu áður en birgðakostnaður er bókaður á fjárhag; ekkert er bókað.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'test post inventory cost to gl, cost to gl test', Comment = 'is-IS=prófa bókun birgðakostnaðar í fjárhag, prófun kostnaðarbókunar í fjárhag';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns the item filter and the number of items it matches. Nothing is posted and no value entries are read.', Comment = 'is-IS=Skilar vörusíunni og fjölda vara sem hún passar við. Ekkert er bókað og engar virðisfærslur eru lesnar.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read by this type."},"dataRequired":false,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Clear(Target);
        Target.ReadFrom('[]');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNoFilter', 'string', false, 'Optional item number filter in Business Central filter syntax, for example 1000 or 1000..2000. When it is empty every item is counted. Send it as JSON text.'));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('posted', 'boolean', 'Always false: nothing is posted.'));
        Fields.Add(ContractMgt.ResponseField('itemNoFilter', 'string', 'The item number filter that was applied; empty when none was sent.'));
        Fields.Add(ContractMgt.ResponseField('itemCount', 'integer', 'The number of items that match the filter; all items when no filter was sent.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The Costing domain is turned off in Inventory Setup.', 'Turn on the Costing domain in Inventory Setup.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the Inv. Posting Gate permission set.', 'Ask an administrator to assign Inv. Posting Gate.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The Business Central filter error text.', 'itemNoFilter is not a valid Business Central filter, or it is not a text value. The error text is returned as it is, with code BusinessCentralError.', 'Send a valid item number filter as JSON text, or leave itemNoFilter out.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. Counts the items that match the filter and reports that nothing is posted. No value entries and no ledger entries are read.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'the Bifrost "Read-Only" permission set and Inv. Posting Gate');
        Preconditions.Add('The Costing domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller holds the Inv. Posting Gate permission set and can read items.');
        Effect.Add('preconditions', Preconditions);
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
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.CostToGL.Post', 'Use it to start the inventory cost posting batch job; this type checks nothing that the batch job would post.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Use it to adjust item costs, and to post the adjustments to the general ledger with postToGL true.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(ContractMgt.WorkflowStep('Inventory.CostToGL.Test', 'Count the items that are in scope; nothing is checked or posted.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.AdjustCost.Run', 'Adjust the item costs; postToGL true posts the adjustments to the general ledger in the same run.'));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.Cost.Get', 'Read costIsAdjusted and costIsPostedToGL afterwards.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(
            'Count the items that match item number 1000',
            '{"type":"Inventory.CostToGL.Test","data":{"itemNoFilter":"1000"}}',
            '{"status":"Success","posted":false,"itemNoFilter":"1000","itemCount":1}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Clear(Overview);
        Overview := 'Counts the items that match an optional item number filter and confirms that nothing is posted. It is a scope check only: it does not run the posting batch job or look at value entries.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Clear(Notes);
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNoFilter: Text;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, true) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('itemNoFilter', Token) then
            ItemNoFilter := Token.AsValue().AsText();
        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('posted', false);
        ResponseJson.Add('itemNoFilter', ItemNoFilter);
        ResponseJson.Add('itemCount', Item.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
