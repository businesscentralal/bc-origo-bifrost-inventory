namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Origo.Bifrost;

/// <summary>
/// Runs report 795. itemNoFilter and itemCategoryFilter map to InitializeRequest.
/// postToGL maps to SetPostToGL and posts the correction in the same run. It does not also run report 1002.
/// </summary>
codeunit 70013461 "Adjust Cost Run Process ori"
{
    Access = Internal;

    procedure RunAdjustCost(var Argument: Record "Message Argument ori")
    var
        AdjustCost: Report "Adjust Cost - Item Entries";
        RequestJson: JsonObject;
        ItemNoFilter: Text;
        ItemCategoryFilter: Text;
        PostToGL: Boolean;
        ResponseJson: JsonObject;
    begin
        RequestJson := Argument.GetRequestJson();
        ItemNoFilter := ReadText(RequestJson, 'itemNoFilter');
        ItemCategoryFilter := ReadText(RequestJson, 'itemCategoryFilter');
        PostToGL := ReadBoolean(RequestJson, 'postToGL');
        AdjustCost.InitializeRequest(CopyStr(ItemNoFilter, 1, 250), CopyStr(ItemCategoryFilter, 1, 250));
        AdjustCost.SetPostToGL(PostToGL);
        AdjustCost.UseRequestPage(false);
        if not AdjustCost.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidOperation, GetLastErrorText(), '', '', '', '');
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNoFilter', ItemNoFilter);
        ResponseJson.Add('itemCategoryFilter', ItemCategoryFilter);
        ResponseJson.Add('postToGL', PostToGL);
        Argument.RespondWithSuccess(ResponseJson);
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

    local procedure ReadBoolean(RequestJson: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not RequestJson.Get(Name, Token) then
            exit(false);
        if Token.IsValue() then
            exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
