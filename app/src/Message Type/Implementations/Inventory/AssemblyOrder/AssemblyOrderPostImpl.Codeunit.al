namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.Post message type.
/// Posts an assembly order via codeunit 900 Assembly-Post and returns the posted document number.
/// Supports overriding the posting date and adjusting the quantity to assemble before posting.
/// </summary>

using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Assembly.Posting;
using Origo.Bifrost;

codeunit 70013425 "Assembly Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        AssemblyHeader: Record "Assembly Header";
        PostingGate: Codeunit "Posting Gate ori";
    begin
        if not AssemblyHeader.WritePermission() then
            exit(false);
        exit(PostingGate.HasPostingPermission(Enum::"Posting Type ori"::Item));
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Assembly Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Posts an assembly order via codeunit 900 Assembly-Post and returns the posted assembly document number.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post assembly, finish assembly, assembled, output the kit, consume components', Comment = 'is-IS=bóka samsetningu, ljúka samsetningu, samsett, nota íhluti';
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
        HelpCodeunit: Codeunit "Assembly Order Post Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        PostedAsmHeader: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        PostingGate: Codeunit "Posting Gate ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        PostingDate: Date;
        QuantityToAssemble: Decimal;
        ReplacePostingDate: Boolean;
        PostingNoBefore: Code[20];
        AssembledQtyBefore: Decimal;
        PostedDocNo: Code[20];
        AssembleToOrder: Boolean;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not PostingGate.AssertCanPost(Argument, Enum::"Posting Type ori"::Item) then
            exit;
        RequestJson := Argument.GetRequestJson();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        // Optional: posting date override
        if not Argument.TryReadDate(RequestJson, 'postingDate', false, PostingDate) then
            exit;
        ReplacePostingDate := PostingDate <> 0D;

        // Optional: quantity to assemble override
        if not Argument.TryReadDecimal(RequestJson, 'quantityToAssemble', false, QuantityToAssemble) then
            exit;
        if QuantityToAssemble > 0 then begin
            AssemblyHeader.SetHideValidationDialog(true);
            AssemblyHeader.Validate("Quantity to Assemble", QuantityToAssemble);
            AssemblyHeader.Modify(true);
        end;

        PostingNoBefore := AssemblyHeader."Posting No.";
        AssembledQtyBefore := AssemblyHeader."Assembled Quantity";
        AssembleToOrder := AssemblyHeader."Assemble to Order";

        if ReplacePostingDate then
            AssemblyPost.SetPostingDate(true, PostingDate);

        Commit();

        if not AssemblyPost.Run(AssemblyHeader) then begin
            Argument.RespondWithError(GetLastErrorText());
            exit;
        end;

        // Determine the posted document number. After post, the AssemblyHeader is usually deleted.
        PostedDocNo := PostingNoBefore;
        if PostedDocNo = '' then
            PostedDocNo := AssemblyHeader."No.";

        // Try to find the posted header
        PostedAsmHeader.SetCurrentKey("Order No.");
        PostedAsmHeader.SetRange("Order No.", AssemblyHeader."No.");
        if PostedAsmHeader.FindLast() then
            PostedDocNo := PostedAsmHeader."No.";

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('postedDocumentNo', PostedDocNo);
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('postingDate', Format(AssemblyHeader."Posting Date", 0, 9));
        ResponseJson.Add('assembledQuantityBefore', AssembledQtyBefore);
        ResponseJson.Add('assembleToOrder', AssembleToOrder);
        if PostedAsmHeader."No." <> '' then begin
            ResponseJson.Add('postedSystemId', Format(PostedAsmHeader.SystemId, 0, 4));
            ResponseJson.Add('postedQuantity', PostedAsmHeader.Quantity);
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
