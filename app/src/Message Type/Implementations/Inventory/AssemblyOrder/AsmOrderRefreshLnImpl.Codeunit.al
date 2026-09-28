namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.AssemblyOrder.RefreshLines message type.
/// Refreshes the component lines of an assembly order from the parent item's BOM
/// by calling Assembly Header.RefreshBOM().
/// </summary>

using Microsoft.Assembly.Document;
using Origo.Bifrost;

codeunit 70013421 "Asm. Order RefreshLn Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
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
    begin
        exit(GetDescription());
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Asm. Order RefreshLn Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
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
