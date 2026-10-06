namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Origo.Bifrost;

codeunit 70013537 "Cost Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
    begin
        exit('Reads item cost fields that are not exposed by the foundation app.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('read item cost, unit cost, inventory value');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Returns unit cost, last direct cost, and inventory for an item.');
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
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'itemNo was not found');
        Errors.Add(ErrorJson);
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
    begin
        Related.Add('Inventory.AdjustCost.Run');
        Related.Add('Inventory.Revaluation.Calculate');
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
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('itemNo', Token) then begin
            Argument.RespondWithError('itemNo is required.');
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
