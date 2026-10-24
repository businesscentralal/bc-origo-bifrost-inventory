namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Origo.Bifrost;

/// <summary>
/// Runs report 795. itemNoFilter and itemCategoryFilter map to InitializeRequest.
/// postToGL maps to SetPostToGL and posts the correction in the same run. It does not also run report 1002.
/// </summary>
codeunit 10076859 "Adjust Cost Run Process ori"
{
    Access = Internal;

    procedure RunAdjustCost(var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Request Value Reader ori";
        RequestJson: JsonObject;
        ItemNoFilter: Text;
        ItemCategoryFilter: Text;
        PostToGL: Boolean;
        ResponseJson: JsonObject;
        ReadOk: Boolean;
        NativeExpectedTxt: Label 'Valid costing setup and one item or category filter.', Comment = 'is-IS=Gild kostnaðaruppsetning og ein vöru- eða flokkasía.';
        NativeNextStepTxt: Label 'Correct the reported costing or filter problem and inspect ledger state before retrying.', Comment = 'is-IS=Leiðréttu kostnaðar- eða síuvilluna og skoðaðu stöðu færslna áður en þú reynir aftur.';
    begin
        RequestJson := Argument.GetRequestJson();
        ReadOk := TryReadText(Argument, RequestJson, 'itemNoFilter', ItemNoFilter);
        if not TryReadText(Argument, RequestJson, 'itemCategoryFilter', ItemCategoryFilter) then
            ReadOk := false;
        if not Reader.TryReadBoolean(Argument, RequestJson, 'postToGL', RequestJson.Contains('postToGL'), PostToGL) then
            ReadOk := false;
        if not ReadOk then
            exit;
        if not TryRunAdjustCost(ItemNoFilter, ItemCategoryFilter, PostToGL) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'itemNoFilter', ItemNoFilter, NativeExpectedTxt, NativeNextStepTxt);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNoFilter', ItemNoFilter);
        ResponseJson.Add('itemCategoryFilter', ItemCategoryFilter);
        ResponseJson.Add('postToGL', PostToGL);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryRunAdjustCost(ItemNoFilter: Text; ItemCategoryFilter: Text; PostToGL: Boolean)
    var
        AdjustCost: Report "Adjust Cost - Item Entries";
    begin
        AdjustCost.InitializeRequest(CopyStr(ItemNoFilter, 1, 250), CopyStr(ItemCategoryFilter, 1, 250));
        AdjustCost.SetPostToGL(PostToGL);
        AdjustCost.UseRequestPage(false);
        AdjustCost.Run();
    end;

    local procedure TryReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Name: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        FormatErr: Label '%1 must be a JSON string.', Comment = '%1 = parameter name; is-IS=%1 verður að vera JSON-strengur.';
        ExpectedTxt: Label 'A JSON string containing a Business Central filter, or an empty string.', Comment = 'is-IS=JSON-strengur með Business Central-síu eða tómur strengur.';
        NextStepTxt: Label 'Send the filter as text; omit the parameter to leave the filter empty.', Comment = 'is-IS=Sendu síuna sem texta; slepptu færibreytunni til að hafa síuna tóma.';
    begin
        Clear(Value);
        if not RequestJson.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, Name), Name, Serialized, ExpectedTxt, NextStepTxt);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        exit(true);
    end;
}
