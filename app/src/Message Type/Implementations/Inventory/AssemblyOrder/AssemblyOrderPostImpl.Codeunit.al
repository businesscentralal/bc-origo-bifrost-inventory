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

codeunit 70013425 "Assembly Order Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        AssemblyHeader: Record "Assembly Header";
        PostingGate: Codeunit "Inv. Posting Gate ori";
    begin
        if not AssemblyHeader.WritePermission() then
            exit(false);
        exit(PostingGate.HasPostingPermission());
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
    var
        SelectionDescriptionLbl: Label 'Posts an assembly order and consumes components; use PreviewPost to inspect predicted entries first.', Comment = 'is-IS=Bókar samsetningarpöntun og notar íhluti; notaðu PreviewPost til að skoða væntanlegar færslur fyrst.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Target := Parts.GetTarget('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Parameters := Parts.GetParameters('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Response := Parts.GetResponse('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Errors := Parts.GetErrors('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Effect := Parts.GetEffect('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Related := Parts.GetRelated('Inventory.AssemblyOrder.Post'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Overview := Parts.GetOverview('Inventory.AssemblyOrder.Post'); exit(Overview <> ''); end;
    procedure GetNotes(var Notes: Text): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Notes := Parts.GetNotes('Inventory.AssemblyOrder.Post'); exit(Notes <> ''); end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    begin
        Argument.SetResponseMarkdown('');
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        AssemblyHeader: Record "Assembly Header";
        PostedAsmHeader: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
        PostingGate: Codeunit "Inv. Posting Gate ori";
        Dispatcher: Codeunit "Dispatcher ori";
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
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        RequestJson := Argument.GetRequestJson();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        // Optional: posting date override
        if not Dispatcher.TryReadDate(Argument, RequestJson, 'postingDate', false, PostingDate) then
            exit;
        ReplacePostingDate := PostingDate <> 0D;

        // Optional: quantity to assemble override
        if not Dispatcher.TryReadDecimal(Argument, RequestJson, 'quantityToAssemble', false, QuantityToAssemble) then
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
