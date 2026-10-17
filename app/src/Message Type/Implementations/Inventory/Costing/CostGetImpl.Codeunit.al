namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 70013468 "Cost Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, false, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads item cost fields that are not exposed by the foundation app.', Comment = 'is-IS=Les kostnaðarreiti vöru sem grunnforritið birtir ekki.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'read item cost, unit cost, inventory value', Comment = 'is-IS=lesa vörukostnað, einingarkostnaður, birgðavirði';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Returns unit cost, last direct cost, and inventory for an item.', Comment = 'is-IS=Skilar einingarkostnaði, síðasta beina kostnaði og birgðum vöru.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Cost.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('table', 'Item');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('unitCost', 0);
        Response.Add('lastDirectCost', 0);
        Response.Add('inventory', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemNo is required.', 'data.itemNo was not sent.', 'Send the item number in data.itemNo.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Item %1 was not found.', 'The item number matches no item.', 'Check the item number.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.AdjustCost.Run', 'Adjust item costs with report 795.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Revaluation.Calculate', 'Write a new cost on the revaluation journal.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads item cost and inventory for one item.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Intentional cost writes stay on the revaluation journal.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        DomainGate: Codeunit "Inventory Domain Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ItemNo: Code[20];
        ItemNoRequiredErr: Label 'itemNo is required.', Comment = 'is-IS=itemNo er nauðsynlegt.';
        ItemNoExpectedTxt: Label 'A non-empty item number in data.itemNo.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo.';
        ItemNoNextStepTxt: Label 'Send the item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið í data.itemNo.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, ItemNoRequiredErr, 'itemNo', '', ItemNoExpectedTxt, ItemNoNextStepTxt);
            exit;
        end;
        ItemNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ItemNo));
        if not Item.Get(ItemNo) then begin
            Argument.RespondWithError('Item ' + ItemNo + ' was not found.');
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNo', Item."No.");
        ResponseJson.Add('unitCost', Item."Unit Cost");
        ResponseJson.Add('lastDirectCost', Item."Last Direct Cost");
        ResponseJson.Add('standardCost', Item."Standard Cost");
        ResponseJson.Add('inventory', Item.Inventory);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
