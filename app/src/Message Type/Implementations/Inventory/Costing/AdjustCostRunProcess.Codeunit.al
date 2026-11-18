namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
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
        ErrorsJson: JsonArray;
        ReadOk: Boolean;
        ItemsProcessed: Integer;
        NativeExpectedTxt: Label 'Valid costing setup and one item or category filter.', Comment = 'is-IS=Gild kostnaðaruppsetning og ein vöru- eða flokkasía.';
        NativeNextStepTxt: Label 'Correct the reported costing or filter problem and inspect ledger state before retrying.', Comment = 'is-IS=Leiðréttu kostnaðar- eða síuvilluna og skoðaðu stöðu færslna áður en þú reynir aftur.';
    begin
        RequestJson := Argument.GetRequestJson();
        if not CheckUnsupportedParameters(Argument, RequestJson) then
            exit;
        ReadOk := TryReadText(Argument, RequestJson, 'itemNoFilter', ItemNoFilter);
        if not TryReadText(Argument, RequestJson, 'itemCategoryFilter', ItemCategoryFilter) then
            ReadOk := false;
        if not Reader.TryReadBoolean(Argument, RequestJson, 'postToGL', RequestJson.Contains('postToGL'), PostToGL) then
            ReadOk := false;
        if not ReadOk then
            exit;
        if not CheckSelection(Argument, ItemNoFilter, ItemCategoryFilter, ItemsProcessed) then
            exit;
        if not TryRunAdjustCost(ItemNoFilter, ItemCategoryFilter, PostToGL) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), 'itemNoFilter', ItemNoFilter, NativeExpectedTxt, NativeNextStepTxt);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('itemNoFilter', ItemNoFilter);
        ResponseJson.Add('itemCategoryFilter', ItemCategoryFilter);
        ResponseJson.Add('postToGL', PostToGL);
        ResponseJson.Add('itemsProcessed', ItemsProcessed);
        ResponseJson.Add('errors', ErrorsJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CheckUnsupportedParameters(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        ParameterName: Text;
        UnknownErr: Label 'The parameter is not supported by this operation.', Comment = 'is-IS=Færibreytan er ekki studd af þessari aðgerð.';
        ExpectedLbl: Label 'Only parameters listed in this message contract.', Comment = 'is-IS=Aðeins færibreytur sem eru taldar upp í samningi þessara skilaboða.';
        NextStepLbl: Label 'Remove the unsupported parameter and send the request again. Nothing was run.', Comment = 'is-IS=Fjarlægðu óstuddu færibreytuna og sendu beiðnina aftur. Ekkert var keyrt.';
    begin
        foreach ParameterName in RequestJson.Keys() do
            if ParameterName in ['postingDate', 'inventoryPostingGroup', 'itemByItem'] then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownErr, CopyStr(ParameterName, 1, 250), '', ExpectedLbl, NextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure CheckSelection(var Argument: Record "Message Argument ori"; ItemNoFilter: Text; ItemCategoryFilter: Text; var ItemsProcessed: Integer): Boolean
    var
        Item: Record Item;
        BothErr: Label 'itemNoFilter and itemCategoryFilter cannot both be used in the same run, as on the request page of report 795.', Comment = 'is-IS=Ekki er hægt að nota itemNoFilter og itemCategoryFilter bæði í sömu keyrslu, eins og á beiðnisíðu skýrslu 795.';
        BothExpectedTxt: Label 'One of itemNoFilter or itemCategoryFilter, or neither.', Comment = 'is-IS=Annaðhvort itemNoFilter eða itemCategoryFilter, eða hvorug.';
        BothNextStepTxt: Label 'Send only one of the two filters. Nothing was adjusted.', Comment = 'is-IS=Sendu aðeins aðra síuna. Engu var breytt.';
        BadFilterErr: Label '%1 is not a valid Business Central filter: %2', Comment = '%1 = parameter name, %2 = error text; is-IS=%1 er ekki gild Business Central sía: %2';
        FilterExpectedTxt: Label 'A valid Business Central filter on the item number or item category code.', Comment = 'is-IS=Gild Business Central sía á vörunúmer eða vöruflokkskóða.';
        FilterNextStepTxt: Label 'Correct the filter and send the request again. Nothing was adjusted.', Comment = 'is-IS=Leiðréttu síuna og sendu beiðnina aftur. Engu var breytt.';
    begin
        if (CopyStr(ItemNoFilter, 1, 250) <> '') and (CopyStr(ItemCategoryFilter, 1, 250) <> '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, BothErr, 'itemCategoryFilter', ItemCategoryFilter, BothExpectedTxt, BothNextStepTxt);
            exit(false);
        end;
        if not TrySetItemFilters(Item, CopyStr(ItemNoFilter, 1, 250), CopyStr(ItemCategoryFilter, 1, 250)) then begin
            if ItemNoFilter <> '' then
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(BadFilterErr, 'itemNoFilter', GetLastErrorText()), 'itemNoFilter', ItemNoFilter, FilterExpectedTxt, FilterNextStepTxt)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(BadFilterErr, 'itemCategoryFilter', GetLastErrorText()), 'itemCategoryFilter', ItemCategoryFilter, FilterExpectedTxt, FilterNextStepTxt);
            exit(false);
        end;
        ItemsProcessed := Item.Count();
        exit(true);
    end;

    [TryFunction]
    local procedure TrySetItemFilters(var Item: Record Item; ItemNoFilter: Text; ItemCategoryFilter: Text)
    begin
        if ItemNoFilter <> '' then
            Item.SetFilter("No.", ItemNoFilter);
        if ItemCategoryFilter <> '' then
            Item.SetFilter("Item Category Code", ItemCategoryFilter);
        if Item.IsEmpty() then
            exit;
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
