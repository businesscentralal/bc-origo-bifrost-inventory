namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.History;
using Origo.Bifrost;

codeunit 70013482 "Assembly Undo Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::AssemblyOrders, Database::"Posted Assembly Header", true, false));
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Posted Assembly Header");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Undoes a posted assembly document through the standard posted assembly undo.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('undo assembly, reverse posted assembly');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Undoes a posted assembly by document number.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
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
        exit(false);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        exit(false);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        PostedAssemblyHeader: Record "Posted Assembly Header";
        DomainGate: Codeunit "Inventory Domain Gate ori";
        UndoAssembly: Codeunit "Pstd. Assembly - Undo";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::AssemblyOrders, Database::"Posted Assembly Header", true, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('documentNo', Token) then begin
            Argument.RespondWithError('documentNo is required.');
            exit;
        end;
        DocumentNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(DocumentNo));
        if not PostedAssemblyHeader.Get(DocumentNo) then begin
            Argument.RespondWithError('Posted assembly ' + DocumentNo + ' was not found.');
            exit;
        end;

        UndoAssembly.SetHideDialog(true);
        UndoAssembly.Run(PostedAssemblyHeader);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', DocumentNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
