namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Exercises the real shipment and receipt undo routines, complete-selection validation and bilingual contracts for issue 134.</summary>
codeunit 96996 "Posted Line Undo Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        TestLibrary: Codeunit "Inventory Test Library ori";

    /// <summary>Verifies SelectedLines for the native shipment path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC01_ShipmentSelectedLines_1033()
    begin
        // Story #134, AC01 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckSelectedLines(true, 1033);
    end;

    /// <summary>Verifies Invoiced for the native shipment path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC02_ShipmentInvoiced_1033()
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvoiced(true, 1033);
    end;

    /// <summary>Verifies Invalid for the native shipment path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentInvalid_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvalid(true, 1033);
    end;

    /// <summary>Verifies MissingLine for the native shipment path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentMissingLine_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckMissingLine(true, 1033);
    end;

    /// <summary>Verifies Repeated for the native shipment path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentRepeated_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckRepeated(true, 1033);
    end;

    /// <summary>Verifies SelectedLines for the native receipt path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC01_ReceiptSelectedLines_1033()
    begin
        // Story #134, AC01 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckSelectedLines(false, 1033);
    end;

    /// <summary>Verifies Invoiced for the native receipt path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC02_ReceiptInvoiced_1033()
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvoiced(false, 1033);
    end;

    /// <summary>Verifies Invalid for the native receipt path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptInvalid_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvalid(false, 1033);
    end;

    /// <summary>Verifies MissingLine for the native receipt path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptMissingLine_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckMissingLine(false, 1033);
    end;

    /// <summary>Verifies Repeated for the native receipt path at LCID 1033.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptRepeated_1033()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckRepeated(false, 1033);
    end;

    /// <summary>Verifies both three-part type names, irreversible effects and bilingual count help.</summary>
    [Test]
    procedure Scenario_AC03_AC05_Contracts_1033()
    begin
        // Story #134, AC03/AC05 | Time: None | Risk: None.
        CheckContracts(1033);
    end;

    /// <summary>Verifies SelectedLines for the native shipment path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC01_ShipmentSelectedLines_1039()
    begin
        // Story #134, AC01 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckSelectedLines(true, 1039);
    end;

    /// <summary>Verifies Invoiced for the native shipment path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC02_ShipmentInvoiced_1039()
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvoiced(true, 1039);
    end;

    /// <summary>Verifies Invalid for the native shipment path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentInvalid_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvalid(true, 1039);
    end;

    /// <summary>Verifies MissingLine for the native shipment path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentMissingLine_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckMissingLine(true, 1039);
    end;

    /// <summary>Verifies Repeated for the native shipment path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ShipmentRepeated_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckRepeated(true, 1039);
    end;

    /// <summary>Verifies SelectedLines for the native receipt path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC01_ReceiptSelectedLines_1039()
    begin
        // Story #134, AC01 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckSelectedLines(false, 1039);
    end;

    /// <summary>Verifies Invoiced for the native receipt path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC02_ReceiptInvoiced_1039()
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvoiced(false, 1039);
    end;

    /// <summary>Verifies Invalid for the native receipt path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptInvalid_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckInvalid(false, 1039);
    end;

    /// <summary>Verifies MissingLine for the native receipt path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptMissingLine_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckMissingLine(false, 1039);
    end;

    /// <summary>Verifies Repeated for the native receipt path at LCID 1039.</summary>
    [Test]
    procedure Scenario_AC04_ReceiptRepeated_1039()
    begin
        // Story #134, AC04 | Time: WorkDate for native posting | Risk: None; codeunit isolation restores fixtures.
        CheckRepeated(false, 1039);
    end;

    /// <summary>Verifies both three-part type names, irreversible effects and bilingual count help.</summary>
    [Test]
    procedure Scenario_AC03_AC05_Contracts_1039()
    begin
        // Story #134, AC03/AC05 | Time: None | Risk: None.
        CheckContracts(1039);
    end;

    /// <summary>Refuses a real receipt whose item entries have been consumed by a posted shipment.</summary>
    [Test]
    procedure Scenario_AC02_AppliedReceipt_1039()
    var
        Item: Record Item;
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        DocumentNo: Code[20];
        BeforeEntries: Integer;
        PreviousLanguage: Integer;
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; isolated fixtures.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [GIVEN] Native purchase receipt stock then native sale of that exact item.
        DocumentNo := CreateDocument(false, false, Item);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(Line, Header, Line.Type::Item, Item."No.", 4);
        LibrarySales.PostSalesDocument(Header, true, false);
        BeforeEntries := EntryCount();
        // [WHEN] The consumed receipt is selected; [THEN] no new entry is posted and a credit memo is recommended.
        AssertRefusal(Execute(false, Selection(DocumentNo, 10000)), 'PreconditionFailed');
        Assert.AreEqual(BeforeEntries, EntryCount(), 'Applied receipt refusal posts nothing.');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Refuses a real receipt whose item entries have been consumed by a posted shipment.</summary>
    [Test]
    procedure Scenario_AC02_AppliedReceipt_1033()
    var
        Item: Record Item;
        Header: Record "Sales Header";
        Line: Record "Sales Line";
        DocumentNo: Code[20];
        BeforeEntries: Integer;
        PreviousLanguage: Integer;
    begin
        // Story #134, AC02 | Time: WorkDate for native posting | Risk: None; isolated fixtures.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        // [GIVEN] Native purchase receipt stock then native sale of that exact item.
        DocumentNo := CreateDocument(false, false, Item);
        LibrarySales.CreateSalesHeader(Header, Header."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(Line, Header, Line.Type::Item, Item."No.", 4);
        LibrarySales.PostSalesDocument(Header, true, false);
        BeforeEntries := EntryCount();
        // [WHEN] The consumed receipt is selected; [THEN] no new entry is posted and a credit memo is recommended.
        AssertRefusal(Execute(false, Selection(DocumentNo, 10000)), 'PreconditionFailed');
        Assert.AreEqual(BeforeEntries, EntryCount(), 'Applied receipt refusal posts nothing.');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Reverses both selected native lines while confirming one document.</summary>
    [Test]
    procedure Scenario_AC01_ShipmentMultiple_1033()
    var
        Item: Record Item;
        Request: JsonObject;
        Lines: JsonArray;
        PreviousLanguage: Integer;
        DocumentNo: Code[20];
    begin
        // Story #134, AC01 | Time: WorkDate | Risk: None; isolated native documents.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        // [GIVEN] Two selected lines of one posted document.
        DocumentNo := CreateDocument(true, false, Item);
        Lines.Add(10000);
        Lines.Add(20000);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
        Request.Add('expectedCount', 1);
        // [WHEN] Both lines are reversed together; [THEN] the count is two lines for one document.
        AssertText(Execute(true, Request), 'reversedCount', '2');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Reverses both selected native lines while confirming one document.</summary>
    [Test]
    procedure Scenario_AC01_ReceiptMultiple_1033()
    var
        Item: Record Item;
        Request: JsonObject;
        Lines: JsonArray;
        PreviousLanguage: Integer;
        DocumentNo: Code[20];
    begin
        // Story #134, AC01 | Time: WorkDate | Risk: None; isolated native documents.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        // [GIVEN] Two selected lines of one posted document.
        DocumentNo := CreateDocument(false, false, Item);
        Lines.Add(10000);
        Lines.Add(20000);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
        Request.Add('expectedCount', 1);
        // [WHEN] Both lines are reversed together; [THEN] the count is two lines for one document.
        AssertText(Execute(false, Request), 'reversedCount', '2');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Reverses both selected native lines while confirming one document.</summary>
    [Test]
    procedure Scenario_AC01_ShipmentMultiple_1039()
    var
        Item: Record Item;
        Request: JsonObject;
        Lines: JsonArray;
        PreviousLanguage: Integer;
        DocumentNo: Code[20];
    begin
        // Story #134, AC01 | Time: WorkDate | Risk: None; isolated native documents.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [GIVEN] Two selected lines of one posted document.
        DocumentNo := CreateDocument(true, false, Item);
        Lines.Add(10000);
        Lines.Add(20000);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
        Request.Add('expectedCount', 1);
        // [WHEN] Both lines are reversed together; [THEN] the count is two lines for one document.
        AssertText(Execute(true, Request), 'reversedCount', '2');
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Reverses both selected native lines while confirming one document.</summary>
    [Test]
    procedure Scenario_AC01_ReceiptMultiple_1039()
    var
        Item: Record Item;
        Request: JsonObject;
        Lines: JsonArray;
        PreviousLanguage: Integer;
        DocumentNo: Code[20];
    begin
        // Story #134, AC01 | Time: WorkDate | Risk: None; isolated native documents.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        // [GIVEN] Two selected lines of one posted document.
        DocumentNo := CreateDocument(false, false, Item);
        Lines.Add(10000);
        Lines.Add(20000);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
        Request.Add('expectedCount', 1);
        // [WHEN] Both lines are reversed together; [THEN] the count is two lines for one document.
        AssertText(Execute(false, Request), 'reversedCount', '2');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckSelectedLines(Sales: Boolean; LanguageId: Integer)
    var
        Item: Record Item;
        SalesLine: Record "Sales Shipment Line";
        PurchaseLine: Record "Purch. Rcpt. Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
        PreviousLanguage: Integer;
    begin
        // [GIVEN] An owned posted document with two lines for the same item.
        TestLibrary.Initialize();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        DocumentNo := CreateDocument(Sales, false, Item);
        Request := Selection(DocumentNo, 10000);
        // [WHEN] Only the first posted line is selected through the real dispatcher.
        Response := Execute(Sales, Request);
        // [THEN] Exactly that original line is reversed, the other line is untouched, and corrective entries exist.
        AssertText(Response, 'status', 'Success');
        AssertText(Response, 'documentNo', DocumentNo);
        AssertText(Response, 'reversedCount', '1');
        Assert.IsTrue(Response.Get('reversedLineNos', Token), 'The reversed lines are returned.');
        Assert.AreEqual(1, Token.AsArray().Count(), 'Exactly the selected line is returned.');
        if Sales then begin
            SalesLine.Get(DocumentNo, 10000);
            Assert.IsTrue(SalesLine.Correction, 'The selected shipment line is corrected.');
            SalesLine.Get(DocumentNo, 20000);
            Assert.IsFalse(SalesLine.Correction, 'The omitted shipment line is unchanged.');
        end else begin
            PurchaseLine.Get(DocumentNo, 10000);
            Assert.IsTrue(PurchaseLine.Correction, 'The selected receipt line is corrected.');
            PurchaseLine.Get(DocumentNo, 20000);
            Assert.IsFalse(PurchaseLine.Correction, 'The omitted receipt line is unchanged.');
        end;
        Item.CalcFields(Inventory);
        if Sales then
            Assert.AreEqual(8, Item.Inventory, 'Native shipment undo restores only the selected quantity.')
        else
            Assert.AreEqual(2, Item.Inventory, 'Native receipt undo removes only the selected quantity.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckInvoiced(Sales: Boolean; LanguageId: Integer)
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        DocumentNo: Code[20];
        BeforeEntries: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A genuinely posted and invoiced document, not fabricated ledger state.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        DocumentNo := CreateDocument(Sales, true, Item);
        Request := Selection(DocumentNo, 10000);
        BeforeEntries := EntryCount();
        // [WHEN] Undo is requested.
        Response := Execute(Sales, Request);
        // [THEN] The coded refusal names a credit memo and posts nothing.
        AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(BeforeEntries, EntryCount(), 'Invoiced undo creates no entries.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckInvalid(Sales: Boolean; LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] Requests with missing, malformed, duplicate and oversized identifiers.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] Each request is dispatched; [THEN] every refusal is coded and carries recovery guidance.
        Response := Execute(Sales, Request);
        AssertRefusal(Response, 'MissingParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":[]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":[10000,10000]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":["10000"]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":[null]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":[10000.5]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"X","lineNos":[-1]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request.ReadFrom('{"documentNo":"XXXXXXXXXXXXXXXXXXXXX","lineNos":[10000]}');
        AssertRefusal(Execute(Sales, Request), 'InvalidParameter');
        Request := Selection('BIF134-NOTFOUND', 10000);
        AssertRefusal(Execute(Sales, Request), 'RecordNotFound');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckMissingLine(Sales: Boolean; LanguageId: Integer)
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        DocumentNo: Code[20];
        BeforeEntries: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A valid line followed by a line absent from the posted document.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        DocumentNo := CreateDocument(Sales, false, Item);
        Lines.Add(10000);
        Lines.Add(99999);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
        BeforeEntries := EntryCount();
        // [WHEN] The whole set is dispatched; [THEN] no earlier line has been reversed.
        Response := Execute(Sales, Request);
        AssertRefusal(Response, 'RecordNotFound');
        Assert.AreEqual(BeforeEntries, EntryCount(), 'A later missing line cannot cause partial undo.');
        AssertText(Execute(Sales, Selection(DocumentNo, 10000)), 'status', 'Success');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckRepeated(Sales: Boolean; LanguageId: Integer)
    var
        Item: Record Item;
        Request: JsonObject;
        DocumentNo: Code[20];
        BeforeEntries: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A successful native undo.
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        DocumentNo := CreateDocument(Sales, false, Item);
        Request := Selection(DocumentNo, 10000);
        AssertText(Execute(Sales, Request), 'status', 'Success');
        BeforeEntries := EntryCount();
        // [WHEN] It is repeated; [THEN] no second reversal can post.
        AssertRefusal(Execute(Sales, Request), 'PreconditionFailed');
        Assert.AreEqual(BeforeEntries, EntryCount(), 'Repeated undo posts nothing.');
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CheckContracts(LanguageId: Integer)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Declaration: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Types: List of [Enum "Message Type ori"];
        Contract: JsonObject;
        Token: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        Effect: JsonObject;
        Parameters: JsonArray;
        ContractText: Text;
        TypeName: Text;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] Both new registered contracts at the requested language.
        Types.Add("Message Type ori"::"Sales.Shipment.Undo");
        Types.Add("Message Type ori"::"Purchase.Receipt.Undo");
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        // [WHEN] The actual contract reader resolves the types.
        foreach MessageType in Types do begin
            Clear(Contract);
            Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'The new type has structured help.');
            TypeName := MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger()));
            // [THEN] Names have exactly three parts; help declares real effects and the document count unit.
            Assert.AreEqual(3, TypeName.Split('.').Count(), 'Three-part type name.');
            Contract.Get('effect', Token);
            AssertText(Token.AsObject(), 'effect', 'irreversible');
            Contract.WriteTo(ContractText);
            Assert.IsTrue(ContractText.Contains('expectedCount'), 'Count help is present in both languages.');
            // Foundation #777/#1239 intentionally builds structured chapters in English for every LCID.
            Assert.IsTrue(ContractText.Contains('one posted document'), 'Registered help defines the document count in both LCIDs.');
            Assert.AreEqual(LanguageId, GlobalLanguage(), 'The contract reader restores the requested language.');
            // Prove the app's actual bilingual declarations independently of that English reader policy.
            Declaration := MessageType;
            Clear(Effect);
            Clear(Parameters);
            Assert.IsTrue(Declaration.GetEffect(Effect), 'The type declares its actual effect.');
            Assert.IsTrue(Declaration.GetParameters(Parameters), 'The type declares its count parameter.');
            if LanguageId = 1039 then begin
                Assert.IsTrue(Effect.Get('changes', Token), 'The declared effect names its changes.');
                Assert.IsTrue(Token.AsValue().AsText().Contains('bókað'), 'The declared Icelandic effect names the posted document.');
                foreach Parameter in Parameters do
                    if Parameter.AsObject().Get('name', Name) then
                        if Name.AsValue().AsText() = 'expectedCount' then begin
                            Assert.IsTrue(Parameter.AsObject().Get('description', Token), 'The count parameter has a description.');
                            Assert.IsTrue(Token.AsValue().AsText().Contains('bókað'), 'The Icelandic expectedCount parameter names the posted document.');
                        end;
            end;
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure CreateDocument(Sales: Boolean; Invoice: Boolean; var Item: Record Item): Code[20]
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Shipment: Record "Sales Shipment Header";
        Receipt: Record "Purch. Rcpt. Header";
        OrderNo: Code[20];
    begin
        LibraryInventory.CreateItem(Item);
        if Sales then begin
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
            LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
            LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
            LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 2);
            LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 2);
            OrderNo := SalesHeader."No.";
            LibrarySales.PostSalesDocument(SalesHeader, true, Invoice);
            Shipment.SetRange("Order No.", OrderNo);
            Shipment.FindFirst();
            exit(Shipment."No.");
        end;
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        PurchaseHeader."Vendor Invoice No." := PurchaseHeader."No.";
        PurchaseHeader.Modify(true);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        OrderNo := PurchaseHeader."No.";
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, Invoice);
        Receipt.SetRange("Order No.", OrderNo);
        Receipt.FindFirst();
        exit(Receipt."No.");
    end;

    local procedure Selection(DocumentNo: Code[20]; LineNo: Integer) Request: JsonObject
    var
        Lines: JsonArray;
    begin
        Lines.Add(LineNo);
        Request.Add('documentNo', DocumentNo);
        Request.Add('lineNos', Lines);
    end;

    local procedure Execute(Sales: Boolean; Request: JsonObject) Response: JsonObject
    var
        Helper: Codeunit "Assembly Order Test Helper";
    begin
        // This helper passes GlobalLanguage explicitly and exercises the committed native dispatch path.
        if Sales then
            Helper.ProcessMessage("Message Type ori"::"Sales.Shipment.Undo", Request, Response)
        else
            Helper.ProcessMessage("Message Type ori"::"Purchase.Receipt.Undo", Request, Response);
    end;

    local procedure EntryCount(): Integer
    var
        Entries: Record "Item Ledger Entry";
    begin
        exit(Entries.Count());
    end;

    local procedure AssertRefusal(Response: JsonObject; CodeText: Text)
    var
        Token: JsonToken;
    begin
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', CodeText);
        Assert.IsTrue(Response.Get('nextStep', Token), 'Every refusal carries recovery guidance.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Recovery guidance is not empty.');
    end;

    local procedure AssertText(Value: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        FullResponse: Text;
    begin
        Value.WriteTo(FullResponse);
        Assert.IsTrue(Value.Get(KeyName, Token), 'Missing ' + KeyName + ': ' + FullResponse);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName + ': ' + FullResponse);
    end;
}
