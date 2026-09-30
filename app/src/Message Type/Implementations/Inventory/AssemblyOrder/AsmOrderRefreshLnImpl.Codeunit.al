namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.RefreshLines message type.
/// Refreshes the component lines of an assembly order from the parent item's BOM
/// by calling Assembly Header.RefreshBOM().
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013421 "Asm. Order RefreshLn Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit('Refreshes assembly order component lines from the parent item''s BOM (RefreshBOM).');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'refresh assembly lines, update components from bom, reload bill of materials, recalculate components', Comment = 'is-IS=uppfæra samsetningarlínur, uppfæra íhluti úr uppskrift, endurhlaða íhlutalista, endurreikna íhluti';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Refreshes assembly components from the parent item BOM; use Create to create a new assembly order.', Comment = 'is-IS=Uppfærir samsetningarhluti úr uppskrift móðurvöru; notaðu Create til að búa til nýja samsetningarpöntun.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Envelope := Parts.GetEnvelope('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetTarget(var Target: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Target := Parts.GetTarget('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetParameters(var Parameters: JsonArray): Boolean begin exit(false); end;
    procedure GetResponse(var Response: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Response := Parts.GetResponse('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetErrors(var Errors: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Errors := Parts.GetErrors('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetEffect(var Effect: JsonObject): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Effect := Parts.GetEffect('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetMetering(var Metering: JsonObject): Boolean begin exit(false); end;
    procedure GetRelated(var Related: JsonArray): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Related := Parts.GetRelated('Inventory.AssemblyOrder.RefreshLines'); exit(true); end;
    procedure GetWorkflow(var Workflow: JsonObject): Boolean begin exit(false); end;
    procedure GetExamples(var Examples: JsonArray): Boolean begin exit(false); end;
    procedure GetOverview(var Overview: Text): Boolean
    var Parts: Codeunit "Inventory Contract Parts ori";
    begin Overview := Parts.GetOverview('Inventory.AssemblyOrder.RefreshLines'); exit(Overview <> ''); end;
    procedure GetNotes(var Notes: Text): Boolean begin exit(false); end;

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
        AssemblyLine: Record "Assembly Line";
        ResponseJson: JsonObject;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindAssemblyHeader(AssemblyHeader) then
            exit;

        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        LinesBefore := AssemblyLine.Count();

        AssemblyHeader.SetHideValidationDialog(true);
        AssemblyHeader.Validate("Item No.", AssemblyHeader."Item No.");
        AssemblyHeader.Modify(true);

        LinesAfter := AssemblyLine.Count();
        AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.");

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', AssemblyHeader."No.");
        ResponseJson.Add('itemNo', AssemblyHeader."Item No.");
        ResponseJson.Add('quantity', AssemblyHeader.Quantity);
        ResponseJson.Add('linesBefore', LinesBefore);
        ResponseJson.Add('linesAfter', LinesAfter);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
