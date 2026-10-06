namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.Reopen message type.
/// Reopens a released assembly order (status Released -> Open) via codeunit 414 Release Assembly Document.
/// Wraps the BC call in Codeunit.Run for clean transactional error handling.
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013427 "Assembly Order Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.WritePermission());
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Reopens a released assembly order so it can be edited again (status Released -> Open).');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reopen assembly order, change released assembly, unlock assembly order', Comment = 'is-IS=opna samsetningarpöntun aftur, breyta staðfestri samsetningu, aflæsa samsetningarpöntun';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Reopens a released assembly order for editing; use Release to prepare it for posting again.', Comment = 'is-IS=Opnar leyfða samsetningarpöntun aftur til breytinga; notaðu Release til að undirbúa hana fyrir bókun á ný.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Reopen');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Target := Parts.GetTarget('Inventory.AssemblyOrder.Reopen');
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Response := Parts.GetResponse('Inventory.AssemblyOrder.Reopen');
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Errors := Parts.GetErrors('Inventory.AssemblyOrder.Reopen');
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Effect := Parts.GetEffect('Inventory.AssemblyOrder.Reopen');
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Related := Parts.GetRelated('Inventory.AssemblyOrder.Reopen');
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
        Parts: Codeunit "Inventory Contract Parts ori";
    begin
        Overview := Parts.GetOverview('Inventory.AssemblyOrder.Reopen');
        exit(Overview <> '');
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := '';
        exit(false);
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        DocumentLookup: Codeunit "Document Lookup ori";
        ResponseJson: JsonObject;
        StatusBefore: Text;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not DocumentLookup.FindAssemblyHeader(Argument, AssemblyHeader) then
            exit;

        StatusBefore := StatusToText(AssemblyHeader.Status);

        // Idempotent: already Open -> respond success
        if AssemblyHeader.Status = AssemblyHeader.Status::Open then begin
            BuildSuccessResponse(AssemblyHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Asm. Order Reopen Process ori", AssemblyHeader)
        else
            if not Codeunit.Run(Codeunit::"Asm. Order Reopen Process ori", AssemblyHeader) then begin
                Argument.RespondWithError(GetLastErrorText());
                exit;
            end;
        AssemblyHeader.Find();

        BuildSuccessResponse(AssemblyHeader, StatusBefore, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildSuccessResponse(AssemblyHeader: Record "Assembly Header"; StatusBefore: Text; var ResponseJson: JsonObject)
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('systemId', Format(AssemblyHeader.SystemId, 0, 4));
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('statusBefore', StatusBefore);
        ResponseJson.Add('statusAfter', StatusToText(AssemblyHeader.Status));
    end;

    local procedure StatusToText(StatusValue: Option Open,Released): Text
    begin
        case StatusValue of
            StatusValue::Open:
                exit('Open');
            StatusValue::Released:
                exit('Released');
        end;
        exit('');
    end;
}
