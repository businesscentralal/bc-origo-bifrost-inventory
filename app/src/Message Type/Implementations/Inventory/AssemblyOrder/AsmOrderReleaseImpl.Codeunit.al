namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.Release message type.
/// Releases an open assembly order (status Open -> Released) via codeunit 414 Release Assembly Document.
/// Idempotent: returns Success without action when already Released.
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013426 "Asm. Order Release Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
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
        exit('Releases an open assembly order so it can be posted (status Open -> Released).');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'release assembly order, assembly ready, lock the assembly order', Comment = 'is-IS=losa samsetningarpöntun, staðfesta samsetningarpöntun, samsetning tilbúin';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Asm. Order Release Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        ReleaseAssemblyDoc: Codeunit "Release Assembly Document";
        ResponseJson: JsonObject;
        StatusBefore: Text;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        StatusBefore := StatusToText(AssemblyHeader.Status);

        // Idempotent: already Released -> just respond success
        if AssemblyHeader.Status = AssemblyHeader.Status::Released then begin
            BuildSuccessResponse(AssemblyHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;

        ReleaseAssemblyDoc.Run(AssemblyHeader);
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
