namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Reopen message type.
/// Reopens a released transfer order so it can be edited again.
/// </summary>

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013417 "Transfer Order Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
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
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Reopens a transfer order, changing its status from Released to Open.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reopen transfer order, change released transfer, unlock transfer', Comment = 'is-IS=opna millifærslupöntun aftur, breyta staðfestri millifærslu, aflæsa millifærslu';
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
        HelpCodeunit: Codeunit "Transfer Order Reopen Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        ResponseJson: JsonObject;
        StatusBefore: Option Open,Released;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindTransferHeader(TransferHeader) then
            exit;

        StatusBefore := TransferHeader.Status;

        if TransferHeader.Status = TransferHeader.Status::Open then begin
            BuildSuccessResponse(TransferHeader, StatusBefore, ResponseJson);
            Argument.SetResponseJson(ResponseJson);
            Argument."Content Type" := Argument.GetContentTypeJson();
            exit;
        end;

        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Transf. Order Reopen Proc. ori", TransferHeader)
        else
            if not Codeunit.Run(Codeunit::"Transf. Order Reopen Proc. ori", TransferHeader) then begin
                Argument.RespondWithError(GetLastErrorText());
                exit;
            end;

        TransferHeader.Find();

        BuildSuccessResponse(TransferHeader, StatusBefore, ResponseJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure BuildSuccessResponse(TransferHeader: Record "Transfer Header"; StatusBefore: Option Open,Released; var ResponseJson: JsonObject)
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', TransferHeader."No.");
        ResponseJson.Add('transferFromCode', TransferHeader."Transfer-from Code");
        ResponseJson.Add('transferToCode', TransferHeader."Transfer-to Code");
        ResponseJson.Add('directTransfer', TransferHeader."Direct Transfer");
        ResponseJson.Add('statusBefore', StatusToText(StatusBefore));
        ResponseJson.Add('statusAfter', StatusToText(TransferHeader.Status));
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
