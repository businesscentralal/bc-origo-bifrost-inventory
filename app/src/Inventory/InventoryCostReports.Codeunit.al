namespace Origo.Bifrost.Inventory;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using System.Utilities;

/// <summary>Runs native costing reports with explicit request options and validated selections.</summary>
codeunit 70013429 "Inventory Cost Reports ori"
{
    Access = Internal;

    var
        AutoPostErr: Label 'postToGL=true requires Automatic Cost Posting in Inventory Setup, as on report 795. No report was run.', Comment = 'is-IS=postToGL=true krefst sjálfvirkrar kostnaðarbókunar í birgðauppsetningu eins og á skýrslu 795. Engin skýrsla var keyrð.';
        InvalidFieldErr: Label 'Parameter %1 must be %2.', Comment = '%1 = parameter name, %2 = required type; is-IS=Færibreytan %1 verður að vera %2.';
        ConflictingAliasErr: Label 'Parameters %1 and %2 must have the same value when both are supplied.', Comment = '%1 = canonical name, %2 = legacy name; is-IS=Færibreyturnar %1 og %2 verða að hafa sama gildi þegar báðar eru gefnar upp.';
        UnsupportedFilterErr: Label 'Report %1 does not support the %2 filter. No report was run.', Comment = '%1 = report number, %2 = parameter name; is-IS=Skýrsla %1 styður ekki afmörkunina %2. Engin skýrsla var keyrð.';
        FilterTooLongErr: Label 'Parameter %1 must not exceed %2 characters.', Comment = '%1 = parameter name, %2 = maximum length; is-IS=Færibreytan %1 má ekki vera lengri en %2 stafir.';
        AdjustFiltersErr: Label 'Report 795 accepts either itemNo or itemCategoryCode, not both.', Comment = 'is-IS=Skýrsla 795 samþykkir annaðhvort itemNo eða itemCategoryCode, ekki bæði.';
        JournalTestErr: Label 'The native test report can consume a document number when journal template names are mandatory. This read-only operation refuses that setup.', Comment = 'is-IS=Innfædda prófunarskýrslan getur notað fylgiskjalsnúmer þegar heiti færslubókarsniðmáta eru áskilin. Þessi lesaðgerð hafnar þeirri uppsetningu.';
        DocumentOptionErr: Label 'documentNo is required only with perPostingGroup=true; it is an output document number, not a filter.', Comment = 'is-IS=documentNo er aðeins áskilið með perPostingGroup=true; það er úttaksnúmer fylgiskjals en ekki afmörkun.';

    /// <summary>Validates report 795 options without writing or silently truncating a filter.</summary>
    procedure PrepareAdjustment(Request: JsonObject; var Item: Record Item): Text
    var
        Document: XmlDocument;
        Root: XmlElement;
        Options: XmlElement;
        ItemFilter: Text;
        CategoryFilter: Text;
        Parameters: Text;
    begin
        Item.Reset();
        RejectFilter(Request, 'postingDate', 'postingDateFilter', 795);
        RejectFilter(Request, 'inventoryPostingGroup', 'inventoryPostingGroupFilter', 795);
        ItemFilter := ReadAlias(Request, 'itemNo', 'itemNoFilter');
        CategoryFilter := ReadAlias(Request, 'itemCategoryCode', 'itemCategoryFilter');
        CheckLength('itemNo', ItemFilter, 250);
        CheckLength('itemCategoryCode', CategoryFilter, 250);
        if (ItemFilter <> '') and (CategoryFilter <> '') then
            Error(AdjustFiltersErr);
        if ItemFilter <> '' then
            Item.SetFilter("No.", ItemFilter);
        if CategoryFilter <> '' then
            Item.SetFilter("Item Category Code", CategoryFilter);
        Root := XmlElement.Create('ReportParameters');
        Root.Add(XmlAttribute.Create('name', 'Adjust Cost - Item Entries'));
        Root.Add(XmlAttribute.Create('id', '795'));
        Options := XmlElement.Create('Options');
        AddOption(Options, 'ItemNoFilter', ItemFilter);
        AddOption(Options, 'ItemCategoryFilter', CategoryFilter);
        AddOption(Options, 'PostToGL', Format(ReadBoolean(Request, 'postToGL'), 0, 9));
        AddOption(Options, 'ByItemCommit', Format(ReadBoolean(Request, 'itemByItem'), 0, 9));
        Root.Add(Options);
        Root.Add(XmlElement.Create('DataItems'));
        Document := XmlDocument.Create();
        Document.Add(Root);
        Document.WriteTo(Parameters);
        exit(Parameters);
    end;

    /// <summary>Runs report 795 once, including its own optional G/L posting pass.</summary>
    procedure AdjustCost(Request: JsonObject; var Response: JsonObject)
    var
        Item: Record Item;
        InventorySetup: Record "Inventory Setup";
        Parameters: Text;
        SelectedItems: Integer;
    begin
        Parameters := PrepareAdjustment(Request, Item);
        if ReadBoolean(Request, 'postToGL') then begin
            InventorySetup.Get();
            if not InventorySetup."Automatic Cost Posting" then
                Error(AutoPostErr);
        end;
        SelectedItems := Item.Count();
        Report.Execute(Report::"Adjust Cost - Item Entries", Parameters);
        Clear(Response);
        Response.Add('status', 'Success');
        Response.Add('itemsSelected', SelectedItems);
        Response.Add('postToGL', ReadBoolean(Request, 'postToGL'));
        Response.Add('itemByItem', ReadBoolean(Request, 'itemByItem'));
    end;

    /// <summary>Validates the native pending-value-entry selection and request options before a report runs.</summary>
    procedure PrepareCostToGL(Request: JsonObject; var PendingEntry: Record "Post Value Entry to G/L"; var PerPostingGroup: Boolean; var DocumentNo: Code[20])
    var
        ItemFilter: Text;
        DateFilter: Text;
        DocumentText: Text;
    begin
        PendingEntry.Reset();
        RejectFilter(Request, 'documentNoFilter', '', 1002);
        ItemFilter := ReadAlias(Request, 'itemNo', 'itemNoFilter');
        DateFilter := ReadAlias(Request, 'postingDate', 'postingDateFilter');
        if ItemFilter <> '' then
            PendingEntry.SetFilter("Item No.", ItemFilter);
        if DateFilter <> '' then
            PendingEntry.SetFilter("Posting Date", DateFilter);
        PerPostingGroup := ReadBoolean(Request, 'perPostingGroup');
        DocumentText := ReadText(Request, 'documentNo');
        CheckLength('documentNo', DocumentText, MaxStrLen(DocumentNo));
        DocumentNo := CopyStr(DocumentText, 1, MaxStrLen(DocumentNo));
        if PerPostingGroup <> (DocumentNo <> '') then
            Error(DocumentOptionErr);
    end;

    /// <summary>Runs report 1003 without posting and returns its native warning text.</summary>
    procedure TestCostToGL(Request: JsonObject; var Response: JsonObject)
    var
        GLSetup: Record "General Ledger Setup";
        PendingEntry: Record "Post Value Entry to G/L";
        TestReport: Report "Post Invt. Cost to G/L - Test";
        TempBlob: Codeunit "Temp Blob";
        Output: OutStream;
        Input: InStream;
        Errors: JsonArray;
        DocumentNo: Code[20];
        PerPostingGroup: Boolean;
        SelectedEntries: Integer;
    begin
        PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        GLSetup.Get();
        if GLSetup."Journal Templ. Name Mandatory" then
            Error(JournalTestErr);
        SelectedEntries := PendingEntry.Count();
        TestReport.SetTableView(PendingEntry);
        if PerPostingGroup then
            TestReport.InitializeRequest(0, DocumentNo, false, false)
        else
            TestReport.InitializeRequest(1, DocumentNo, false, false);
        TempBlob.CreateOutStream(Output);
        TestReport.SaveAs('', ReportFormat::Xml, Output);
        TempBlob.CreateInStream(Input);
        ReadReportErrors(Input, Errors);
        Clear(Response);
        Response.Add('status', 'Success');
        Response.Add('posted', false);
        Response.Add('entriesSelected', SelectedEntries);
        Response.Add('errors', Errors);
    end;

    /// <summary>Runs report 1002 with Post explicitly enabled, using only the validated selection.</summary>
    procedure PostCostToGL(Request: JsonObject; var Response: JsonObject)
    var
        PendingEntry: Record "Post Value Entry to G/L";
        PostReport: Report "Post Inventory Cost to G/L";
        TempBlob: Codeunit "Temp Blob";
        Output: OutStream;
        Input: InStream;
        SkippedEntries: JsonArray;
        DocumentNo: Code[20];
        PerPostingGroup: Boolean;
        SelectedEntries: Integer;
    begin
        PrepareCostToGL(Request, PendingEntry, PerPostingGroup, DocumentNo);
        SelectedEntries := PendingEntry.Count();
        PostReport.SetTableView(PendingEntry);
        if PerPostingGroup then
            PostReport.InitializeRequest(0, DocumentNo, true)
        else
            PostReport.InitializeRequest(1, DocumentNo, true);
        TempBlob.CreateOutStream(Output);
        PostReport.SaveAs('', ReportFormat::Xml, Output);
        TempBlob.CreateInStream(Input);
        ReadSkippedEntries(Input, SkippedEntries);
        Clear(Response);
        Response.Add('status', 'Success');
        Response.Add('posted', true);
        Response.Add('entriesSelected', SelectedEntries);
        Response.Add('entriesRemaining', PendingEntry.Count());
        Response.Add('skippedEntries', SkippedEntries);
    end;

    local procedure ReadSkippedEntries(Input: InStream; var SkippedEntries: JsonArray)
    var
        Document: XmlDocument;
        Nodes: XmlNodeList;
        Node: XmlNode;
        EntryNo: Integer;
        SeenEntries: List of [Integer];
    begin
        Clear(SkippedEntries);
        XmlDocument.ReadFrom(Input, Document);
        Document.SelectNodes('//*[local-name()="Column" and @name="EntryNo_SkippedValueEntry"]', Nodes);
        foreach Node in Nodes do
            if Evaluate(EntryNo, Node.AsXmlElement().InnerText(), 9) then
                if EntryNo <> 0 then
                    if not SeenEntries.Contains(EntryNo) then begin
                        SeenEntries.Add(EntryNo);
                        SkippedEntries.Add(EntryNo);
                    end;
    end;

    local procedure ReadReportErrors(Input: InStream; var Errors: JsonArray)
    var
        Document: XmlDocument;
        Nodes: XmlNodeList;
        Node: XmlNode;
        ErrorJson: JsonObject;
    begin
        Clear(Errors);
        XmlDocument.ReadFrom(Input, Document);
        Document.SelectNodes('//*[local-name()="Column" and @name="ErrorText_Number_"]', Nodes);
        foreach Node in Nodes do
            if Node.AsXmlElement().InnerText() <> '' then begin
                Clear(ErrorJson);
                ErrorJson.Add('message', Node.AsXmlElement().InnerText());
                Errors.Add(ErrorJson);
            end;
    end;

    local procedure AddOption(var Options: XmlElement; Name: Text; Value: Text)
    var
        Field: XmlElement;
    begin
        Field := XmlElement.Create('Field');
        Field.Add(XmlAttribute.Create('name', Name));
        Field.Add(XmlText.Create(Value));
        Options.Add(Field);
    end;

    local procedure RejectFilter(Request: JsonObject; Name: Text; Alias: Text; ReportId: Integer)
    begin
        if ReadAlias(Request, Name, Alias) <> '' then
            Error(UnsupportedFilterErr, ReportId, Name);
    end;

    local procedure CheckLength(Name: Text; Value: Text; Maximum: Integer)
    begin
        if StrLen(Value) > Maximum then
            Error(FilterTooLongErr, Name, Maximum);
    end;

    local procedure ReadAlias(Request: JsonObject; Name: Text; Alias: Text): Text
    var
        Value: Text;
        AliasValue: Text;
    begin
        Value := ReadText(Request, Name);
        AliasValue := ReadText(Request, Alias);
        if Request.Contains(Name) then begin
            if Request.Contains(Alias) and (Value <> AliasValue) then
                Error(ConflictingAliasErr, Name, Alias);
            exit(Value);
        end;
        exit(AliasValue);
    end;

    local procedure ReadText(Request: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(Name, Token) then
            exit('');
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then
            Error(InvalidFieldErr, Name, 'text');
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadBoolean(Request: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(Name, Token) then
            exit(false);
        Token.WriteTo(Serialized);
        if not (Serialized in ['true', 'false']) then
            Error(InvalidFieldErr, Name, 'boolean');
        exit(Token.AsValue().AsBoolean());
    end;
}
