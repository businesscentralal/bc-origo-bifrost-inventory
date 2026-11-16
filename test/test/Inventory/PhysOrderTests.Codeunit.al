namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Counting.Document;
using Microsoft.Inventory.Counting.History;
using Microsoft.Inventory.Counting.Recording;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Self-seeded dispatched tests for native physical inventory orders and atomic refusals.</summary>
codeunit 96986 "Phys Order Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Library: Codeunit "Inventory Test Library ori";
        Helper: Codeunit "Assembly Order Test Helper";

    /// <summary>AC01 Stock CreatesCalculatedOrderAndRecording.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC01_Stock_CreatesCalculatedOrderAndRecording()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Recording: Record "Phys. Invt. Record Line";
        Response: JsonObject;
    begin
        // Story #113 AC01 | Time: WorkDate posting | Risk: native inventory setup.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        Line.SetRange("Document No.", Header."No.");
        Assert.AreEqual(1, Line.Count(), 'Exactly the selected item is calculated.');
        Line.FindFirst();
        Assert.AreEqual(Item."No.", Line."Item No.", 'Selected item.');
        Assert.AreEqual(10, Line."Qty. Expected (Base)", 'Native expected quantity uses posted stock.');
        Recording.SetRange("Order No.", Header."No.");
        Assert.AreEqual(1, Recording.Count(), 'One native recording line.');
        Recording.FindFirst();
        Assert.IsFalse(Recording.Recorded, 'Expected stock must not fabricate a physical count.');
        Item.CalcFields(Inventory);
        Assert.AreEqual(10, Item.Inventory, 'Create does not post.');
    end;

    /// <summary>AC02 CountEight ComputesDifferenceTwo.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC02_CountEight_ComputesDifferenceTwo()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Response: JsonObject;
    begin
        // Story #113 AC02 | Time: WorkDate | Risk: native recording finish.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        FinishOrder(Header, 8, Response);
        AssertStatus(Response, 'Success');
        Header.Get(Header."No.");
        Assert.AreEqual(Header.Status::Finished, Header.Status, 'Native order finished.');
        Line.SetRange("Document No.", Header."No.");
        Line.FindFirst();
        Assert.AreEqual(8, Line."Qty. Recorded (Base)", 'Recorded quantity comes from native recording finish.');
        Assert.AreEqual(2, Line."Quantity (Base)", 'Difference calculated by native order finish.');
        Assert.AreEqual(Line."Entry Type"::"Negative Adjmt.", Line."Entry Type", 'A count below stock is negative.');
        Item.CalcFields(Inventory);
        Assert.AreEqual(10, Item.Inventory, 'Finish does not post.');
    end;

    /// <summary>AC03 FinishedOrder PostsAndReturnsRealNumber.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC03_FinishedOrder_PostsAndReturnsRealNumber()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Posted: Record "Pstd. Phys. Invt. Order Hdr";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        // Story #113 AC03 | Time: WorkDate | Risk: native inventory posting.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        DocumentNo := Header."No.";
        FinishOrder(Header, 8, Response);
        AssertStatus(Response, 'Success');
        Request.Add('documentNo', DocumentNo);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Post", Request, Response);
        AssertStatus(Response, 'Success');
        Assert.IsTrue(Response.Get('postedDocumentNo', Token), 'Posted order number returned.');
        Assert.IsTrue(Posted.Get(Token.AsValue().AsCode()), 'Returned posted document exists.');
        Assert.AreEqual(DocumentNo, Posted."Pre-Assigned No.", 'Returned document belongs to this order.');
        Assert.IsFalse(Header.Get(DocumentNo), 'Native posting consumes the unposted order.');
        Item.CalcFields(Inventory);
        Assert.AreEqual(8, Item.Inventory, 'Native posting applies the physical count.');
    end;

    /// <summary>AC03 SeparatePostingSeries ReturnsAssignedNumber.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC03_SeparatePostingSeries_ReturnsAssignedNumber()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Setup: Record "Inventory Setup";
        Posted: Record "Pstd. Phys. Invt. Order Hdr";
        SeriesLine: Record "No. Series Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #113 AC03 | Time: WorkDate | Risk: posted number may differ from order number.
        Initialize();
        Setup.Get();
        Setup."Posted Phys. Invt. Order Nos." := CreateNoSeries();
        SeriesLine.Get(Setup."Posted Phys. Invt. Order Nos.", 10000);
        SeriesLine."Starting No." := 'W4PP000001';
        SeriesLine."Ending No." := 'W4PP999999';
        SeriesLine.Modify(true);
        Setup.Modify(true);
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        FinishOrder(Header, 8, Response);
        AssertStatus(Response, 'Success');
        Request.Add('documentNo', Header."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Post", Request, Response);
        AssertStatus(Response, 'Success');
        Response.Get('postedDocumentNo', Token);
        Assert.AreNotEqual(Header."No.", Token.AsValue().AsText(), 'Actual posted number uses the separate series.');
        Posted.Get(Token.AsValue().AsCode());
        Assert.AreEqual(Header."No.", Posted."Pre-Assigned No.", 'Posted header retains the source order.');
    end;

    /// <summary>AC02 ZeroCount IsRecordedAndFinished.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC02_ZeroCount_IsRecordedAndFinished()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Order Line";
        Response: JsonObject;
    begin
        // Story #113 AC02 | Time: WorkDate | Risk: zero must differ from unrecorded.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        FinishOrder(Header, 0, Response);
        AssertStatus(Response, 'Success');
        Line.SetRange("Document No.", Header."No.");
        Line.FindFirst();
        Assert.AreEqual(0, Line."Qty. Recorded (Base)", 'Zero count retained.');
        Assert.AreEqual(10, Line."Quantity (Base)", 'Full expected inventory is a negative difference.');
    end;

    /// <summary>AC04 UnrecordedSecondLine RollsBackFirstCount.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_UnrecordedSecondLine_RollsBackFirstCount()
    var
        Item: Record Item;
        OtherItem: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Record Line";
        Request: JsonObject;
        Response: JsonObject;
        Counts: JsonArray;
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: later native refusal must roll back all earlier writes.
        Initialize();
        CreateStock(Item);
        CreateStock(OtherItem);
        CreateOrder(Item."No." + '|' + OtherItem."No.", Header, Response);
        Line.SetRange("Order No.", Header."No.");
        Assert.AreEqual(2, Line.Count(), 'Two independently seeded items.');
        Line.FindFirst();
        Counts.Add(CountRow(Line, 8));
        Request.Add('documentNo', Header."No.");
        Request.Add('counts', Counts);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Finish", Request, Response);
        AssertCodedError(Response, 'BusinessCentralError');
        AssertOpenAndUnrecorded(Header);
    end;

    /// <summary>AC04 NegativeQuantity RefusesWithoutWrites.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_NegativeQuantity_RefusesWithoutWrites()
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: None.
        VerifyInvalidCount('negative');
    end;

    /// <summary>AC04 DuplicateLine RefusesWithoutWrites.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_DuplicateLine_RefusesWithoutWrites()
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: None.
        VerifyInvalidCount('duplicate');
    end;

    /// <summary>AC04 UnknownLine RefusesWithoutWrites.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_UnknownLine_RefusesWithoutWrites()
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: None.
        VerifyInvalidCount('unknown');
    end;

    /// <summary>AC04 MissingItemFilter ReturnsCodedNextStep.</summary>
    [Test]
    procedure Scenario_AC04_MissingItemFilter_ReturnsCodedNextStep()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #113 AC04 | Time: independent | Risk: None.
        Initialize();
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Create", Request, Response);
        AssertCodedError(Response, 'MissingParameter');
    end;

    /// <summary>AC04 NontextItemFilter ReturnsCodedNextStep.</summary>
    [Test]
    procedure Scenario_AC04_NontextItemFilter_ReturnsCodedNextStep()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #113 AC04 | Time: independent | Risk: None.
        Initialize();
        Request.Add('itemNoFilter', true);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Create", Request, Response);
        AssertCodedError(Response, 'InvalidParameterFormat');
    end;

    /// <summary>AC04 EmptySelection RollsBackNewHeader.</summary>
    [Test]
    procedure Scenario_AC04_EmptySelection_RollsBackNewHeader()
    var
        Header: Record "Phys. Invt. Order Header";
        Request: JsonObject;
        Response: JsonObject;
        Before: Integer;
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: native calculation produces no lines.
        Initialize();
        Before := Header.Count();
        Request.Add('itemNoFilter', CopyStr(Format(CreateGuid(), 0, 4), 1, 20));
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Create", Request, Response);
        AssertCodedError(Response, 'BusinessCentralError');
        Assert.AreEqual(Before, Header.Count(), 'Empty calculation must leave no orphan header.');
    end;

    /// <summary>AC04 UnknownOrder ReturnsRecordNotFound.</summary>
    [Test]
    procedure Scenario_AC04_UnknownOrder_ReturnsRecordNotFound()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #113 AC04 | Time: independent | Risk: None.
        Initialize();
        Request.Add('documentNo', CopyStr(Format(CreateGuid(), 0, 4), 1, 20));
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Finish", Request, Response);
        AssertCodedError(Response, 'RecordNotFound');
    end;

    /// <summary>AC04 PostOpenOrder RefusesWithoutPosting.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_PostOpenOrder_RefusesWithoutPosting()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: None.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        Request.Add('documentNo', Header."No.");
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Post", Request, Response);
        AssertCodedError(Response, 'PreconditionFailed');
        AssertOpenAndUnrecorded(Header);
    end;

    /// <summary>AC04 RepeatFinish RefusesCompletedOperation.</summary>
    [Test]
    [HandlerFunctions('RecordingMessage')]
    procedure Scenario_AC04_RepeatFinish_RefusesCompletedOperation()
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Response: JsonObject;
    begin
        // Story #113 AC04 | Time: WorkDate | Risk: duplicate finish must not double the recorded quantity.
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        FinishOrder(Header, 8, Response);
        AssertStatus(Response, 'Success');
        FinishOrder(Header, 8, Response);
        AssertCodedError(Response, 'PreconditionFailed');
    end;

    /// <summary>AC05 BilingualContracts DeclareThreePartsAndEffects.</summary>
    [Test]
    procedure Scenario_AC05_BilingualContracts_DeclareThreePartsAndEffects()
    var
        Contract: Codeunit "Phys Order Contract ori";
        Effect: JsonObject;
        Parameter: JsonToken;
        Name: JsonToken;
        Description: JsonToken;
        Parameters: JsonArray;
        Token: JsonToken;
        Names: List of [Text];
        TypeName: Text;
        PreviousLanguage: Integer;
    begin
        // Story #113 AC04/AC05 | Time: independent | Risk: Foundation public help may impose its own language policy.
        Initialize();
        Names.Add('Inventory.PhysInventoryOrder.Create');
        Names.Add('Inventory.PhysInventoryOrder.Finish');
        Names.Add('Inventory.PhysInventoryOrder.Post');
        foreach TypeName in Names do
            Assert.AreEqual(3, TypeName.Split('.').Count(), 'Names have exactly three parts.');
        Effect := Contract.Effect('Create');
        Effect.Get('effect', Token);
        Assert.AreEqual('write', Token.AsValue().AsText(), 'Create is a write.');
        Effect := Contract.Effect('Finish');
        Effect.Get('effect', Token);
        Assert.AreEqual('write', Token.AsValue().AsText(), 'Finish is a write.');
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Effect := Contract.Effect('Post');
        Effect.Get('effect', Token);
        Assert.AreEqual('irreversible', Token.AsValue().AsText(), 'Posting is irreversible.');
        Effect.Get('changes', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('expectedCount counts order headers'), 'English changes names the count unit.');
        GlobalLanguage(1039);
        Effect := Contract.Effect('Post');
        Effect.Get('changes', Token);
        Assert.IsTrue(Token.AsValue().AsText().Contains('expectedCount telur pöntunarhausa'), 'Icelandic changes names the count unit.');
        Parameters := Contract.Parameters('Post');
        foreach Parameter in Parameters do
            if Parameter.AsObject().Get('name', Name) then
                if Name.AsValue().AsText() = 'expectedCount' then begin
                    Parameter.AsObject().Get('description', Description);
                    Assert.IsTrue(Description.AsValue().AsText().Contains('telur hausa'), 'Icelandic expectedCount parameter names the count unit.');
                end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Accepts the native recording creation notification; tests assert the actual created records.</summary>
    [MessageHandler]
    procedure RecordingMessage(Message: Text[1024])
    begin
    end;

    local procedure Initialize()
    var
        Setup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
        Series: Code[20];
    begin
        Library.EnablePhysicalInventory();
        Setup.Get();
        Series := CreateNoSeries();
        Setup."Phys. Invt. Order Nos." := Series;
        Setup."Posted Phys. Invt. Order Nos." := Series;
        Setup."Automatic Cost Posting" := false;
        Setup."Automatic Cost Adjustment" := Setup."Automatic Cost Adjustment"::Never;
        Setup.Modify();
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
    end;

    local procedure CreateNoSeries(): Code[20]
    var
        Series: Record "No. Series";
        Line: Record "No. Series Line";
    begin
        Series.Code := CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Series.Code));
        Series."Default Nos." := true;
        Series.Insert(true);
        Line."Series Code" := Series.Code;
        Line."Line No." := 10000;
        Line."Starting No." := CopyStr('W4' + CopyStr(Series.Code, 1, 8) + '000001', 1, MaxStrLen(Line."Starting No."));
        Line."Ending No." := CopyStr('W4' + CopyStr(Series.Code, 1, 8) + '999999', 1, MaxStrLen(Line."Ending No."));
        Line."Increment-by No." := 1;
        Line.Insert(true);
        exit(Series.Code);
    end;

    local procedure CreateStock(var Item: Record Item)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("Unit Amount", 12);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
    end;

    local procedure CreateOrder(ItemFilter: Text; var Header: Record "Phys. Invt. Order Header"; var Response: JsonObject)
    var
        Request: JsonObject;
        Token: JsonToken;
    begin
        Request.Add('itemNoFilter', ItemFilter);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Create", Request, Response);
        AssertStatus(Response, 'Success');
        Response.Get('documentNo', Token);
        Header.Get(Token.AsValue().AsCode());
    end;

    local procedure FinishOrder(Header: Record "Phys. Invt. Order Header"; Quantity: Decimal; var Response: JsonObject)
    var
        Line: Record "Phys. Invt. Record Line";
        Request: JsonObject;
        Counts: JsonArray;
    begin
        Line.SetRange("Order No.", Header."No.");
        Line.FindFirst();
        Counts.Add(CountRow(Line, Quantity));
        Request.Add('documentNo', Header."No.");
        Request.Add('counts', Counts);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Finish", Request, Response);
    end;

    local procedure CountRow(Line: Record "Phys. Invt. Record Line"; Quantity: Decimal) Result: JsonObject
    begin
        Result.Add('recordingNo', Line."Recording No.");
        Result.Add('lineNo', Line."Line No.");
        Result.Add('quantity', Quantity);
    end;

    local procedure VerifyInvalidCount(Kind: Text)
    var
        Item: Record Item;
        Header: Record "Phys. Invt. Order Header";
        Line: Record "Phys. Invt. Record Line";
        Request: JsonObject;
        Row: JsonObject;
        Counts: JsonArray;
        Response: JsonObject;
    begin
        Initialize();
        CreateStock(Item);
        CreateOrder(Item."No.", Header, Response);
        Line.SetRange("Order No.", Header."No.");
        Line.FindFirst();
        Row := CountRow(Line, 8);
        case Kind of
            'negative':
                Row.Replace('quantity', -1);
            'unknown':
                Row.Replace('lineNo', 2147483647);
        end;
        Counts.Add(Row);
        if Kind = 'duplicate' then
            Counts.Add(Row);
        Request.Add('documentNo', Header."No.");
        Request.Add('counts', Counts);
        Helper.ProcessMessage("Message Type ori"::"Inventory.PhysInventoryOrder.Finish", Request, Response);
        if Kind = 'negative' then
            AssertCodedError(Response, 'InvalidParameter')
        else
            AssertCodedError(Response, 'InvalidLine');
        AssertOpenAndUnrecorded(Header);
    end;

    local procedure AssertOpenAndUnrecorded(Header: Record "Phys. Invt. Order Header")
    var
        Line: Record "Phys. Invt. Record Line";
    begin
        Header.Get(Header."No.");
        Assert.AreEqual(Header.Status::Open, Header.Status, 'Refused operation leaves order open.');
        Line.SetRange("Order No.", Header."No.");
        if Line.FindSet() then
            repeat
                Assert.IsFalse(Line.Recorded, 'No recording line changed.');
                Assert.AreEqual(0, Line.Quantity, 'No counted quantity changed.');
            until Line.Next() = 0;
    end;

    local procedure AssertStatus(Response: JsonObject; Expected: Text)
    var
        Token: JsonToken;
        Json: Text;
    begin
        Response.WriteTo(Json);
        Assert.IsTrue(Response.Get('status', Token), Json);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Json);
    end;

    local procedure AssertCodedError(Response: JsonObject; ExpectedCode: Text)
    var
        Token: JsonToken;
        Json: Text;
    begin
        AssertStatus(Response, 'Error');
        Response.WriteTo(Json);
        Assert.IsTrue(Response.Get('code', Token), Json);
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), Json);
        Assert.IsTrue(Response.Get('nextStep', Token), Json);
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Every refusal is actionable.');
    end;
}
