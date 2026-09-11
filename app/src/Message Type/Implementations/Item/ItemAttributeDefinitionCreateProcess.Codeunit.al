namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>
/// Isolated write process for Item.AttributeDefinition.Create.
/// </summary>
codeunit 10036907 "Item AttributeDefinition Create Process ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Resolve: Codeunit "Item Attribute Resolve ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
    begin
        RequestJson := Rec.GetRequestJson();
        Resolve.CreateDefinition(RequestJson, ResponseJson);
        Rec.SetResponseJson(ResponseJson);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
