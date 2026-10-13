namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Provides the codeunit-run error boundary for native inventory cost posting.</summary>
codeunit 70013430 "Inventory Cost Post Proc. ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        CostReports: Codeunit "Inventory Cost Reports ori";
        Response: JsonObject;
    begin
        CostReports.PostCostToGL(Rec.GetRequestJson(), Response);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
