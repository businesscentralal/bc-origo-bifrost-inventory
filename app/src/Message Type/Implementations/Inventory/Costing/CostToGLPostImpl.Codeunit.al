namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Inventory.CostToGL.Post. Runs report 1002 when Adjust Cost was run with postToGL false.
/// </summary>
codeunit 70013462 "Cost To GL Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Costing, Database::Item, true, true));
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        PostInventoryCost: Report "Post Inventory Cost to G/L";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Costing, Database::Item, true, true) then
            exit;
        RequestJson := Argument.GetRequestJson();
        PostInventoryCost.UseRequestPage(false);
        if not PostInventoryCost.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidOperation, GetLastErrorText(), '', '', '', '');
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNoFilter', ReadText(RequestJson, 'itemNoFilter'));
        ResponseJson.Add('documentNoFilter', ReadText(RequestJson, 'documentNoFilter'));
        Argument.RespondWithSuccess(ResponseJson);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Post inventory value entries that are not yet posted to the general ledger.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('post inventory cost,general ledger,report 1002');
    end;

    local procedure ReadText(RequestJson: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(Name, Token) then
            exit('');
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        exit('');
    end;
}
