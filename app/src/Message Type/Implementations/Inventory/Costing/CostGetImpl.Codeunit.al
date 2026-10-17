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
        ItemNoDescriptionTxt: Label 'Item number. The message subject is the same item number when this key is omitted.', Comment = 'is-IS=Vörunúmer. Subject er sama vörunúmer þegar lykillinn er ekki sendur.';
    begin
        ParameterJson.Add('name', 'itemNo');
        ParameterJson.Add('type', 'code');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', ItemNoDescriptionTxt);
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemNo is required.', 'Neither data.itemNo nor subject was sent.', 'Send data.itemNo or the item number as subject.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'subject and itemNo name different items.', 'subject and data.itemNo were both sent and do not match.', 'Send one item number, or make them the same.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'itemNo must be a JSON value.', 'data.itemNo is an object or an array.', 'Send the item number as text.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Item {itemNo} was not found.', 'The item number matches no item.', 'Check the item number.'));
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
    var
        OverviewTxt: Label 'Reads item cost and inventory for one item.', Comment = 'is-IS=Les kostnað og birgðir fyrir eina vöru.';
    begin
        Overview := OverviewTxt;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesTxt: Label 'Read only. Intentional cost writes stay on the revaluation journal. data.itemNo or subject names the item.', Comment = 'is-IS=Aðeins lestur. Viljandi kostnaðarfærslur fara á endurmatsbókina. data.itemNo eða subject nefnir vöruna.';
    begin
        Notes := NotesTxt;
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
        ContractParts: Codeunit "Inventory Contract Parts ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemNo: Code[20];
        NotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = item no.||is-IS=Vara %1 fannst ekki.';
        NotFoundExpectedTxt: Label 'The number of an existing item.', Comment = 'is-IS=Númer vöru sem er til.';
        NotFoundNextStepTxt: Label 'Check the item number, then send it as data.itemNo or subject.', Comment = 'is-IS=Athugaðu vörunúmerið og sendu það sem data.itemNo eða subject.';
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not ContractParts.TryResolveItemNo(Argument, RequestJson, true, ItemNo) then
            exit;
        if not Item.Get(ItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ItemNo), 'itemNo', ItemNo, NotFoundExpectedTxt, NotFoundNextStepTxt);
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
