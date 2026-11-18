namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item.Catalog;
using Origo.Bifrost;

/// <summary>Saves a fully validated item reference in the caller or isolated transaction.</summary>
codeunit 10076955 "Item Ref. Set Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Reference: Record "Item Reference";
        TempValidated: Record "Item Reference" temporary;
        Impl: Codeunit "Item Ref. Set Impl ori";
        Request: JsonObject;
        Response: JsonObject;
        Created: Boolean;
    begin
        Request := Rec.GetRequestJson();
        // Recheck conflicts in the save transaction.
        Reference.LockTable();
        if not Impl.ValidateRequest(Rec, Request, TempValidated, true) then
            exit;
        Created := not Reference.Get(TempValidated."Item No.", TempValidated."Variant Code", TempValidated."Unit of Measure", TempValidated."Reference Type", TempValidated."Reference Type No.", TempValidated."Reference No.");
        if Created then begin
            Reference.Init();
            Reference.Validate("Item No.", TempValidated."Item No.");
            Reference.Validate("Variant Code", TempValidated."Variant Code");
            Reference.Validate("Unit of Measure", TempValidated."Unit of Measure");
            Reference.Validate("Reference Type", TempValidated."Reference Type");
            Reference.Validate("Reference Type No.", TempValidated."Reference Type No.");
            Reference.Validate("Reference No.", TempValidated."Reference No.");
        end;
        Reference.Validate(Description, TempValidated.Description);
        // Clear both first so a valid move of the whole interval does not compare to old dates.
        Reference."Starting Date" := 0D;
        Reference."Ending Date" := 0D;
        Reference.Validate("Starting Date", TempValidated."Starting Date");
        Reference.Validate("Ending Date", TempValidated."Ending Date");
        if Created then
            Reference.Insert(true)
        else
            Reference.Modify(true);
        Response.Add('status', 'Success');
        Response.Add('created', Created);
        Response.Add('itemNo', Reference."Item No.");
        Response.Add('variantCode', Reference."Variant Code");
        Response.Add('unitOfMeasure', Reference."Unit of Measure");
        Response.Add('referenceType', ReadText(Request, 'referenceType'));
        Response.Add('referenceTypeNo', Reference."Reference Type No.");
        Response.Add('referenceNo', Reference."Reference No.");
        Response.Add('description', Reference.Description);
        Response.Add('startingDate', DateText(Reference."Starting Date"));
        Response.Add('endingDate', DateText(Reference."Ending Date"));
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure DateText(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure ReadText(Request: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Request.Get(KeyName, Token);
        exit(Token.AsValue().AsText());
    end;
}
