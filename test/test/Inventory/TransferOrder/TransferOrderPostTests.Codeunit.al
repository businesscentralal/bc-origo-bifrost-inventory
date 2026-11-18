namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Transfer;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Unit tests for Inventory.TransferOrder.Post message type.
/// </summary>
codeunit 96914 "Transfer Order Post Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then exit;
        IsInitialized := true;
    end;

    [Test]
    procedure UndoShipment_SelectedDocumentOnly()
    begin
        VerifyShipmentUndo(false);
    end;

    [Test]
    procedure UndoShipment_SecondLineFailureRollsBackAll()
    begin
        VerifyShipmentUndo(true);
    end;

    [Test]
    procedure UndoShipment_ReceivedIsCodedAndPreserved_EN()
    begin
        VerifyReceivedRefusal(1033);
    end;

    [Test]
    procedure UndoShipment_ReceivedIsCodedAndPreserved_IS()
    begin
        VerifyReceivedRefusal(1039);
    end;

    [Test]
    procedure UndoReceipt_PostedReceipt_RefusesInEnglish()
    begin
        // Story #150, AC3 | Time: WorkDate from the transfer posting helper | Risk: None
        VerifyReceiptUndoRefusal(1033);
    end;

    [Test]
    procedure UndoReceipt_PostedReceipt_RefusesInIcelandic()
    begin
        // Story #150, AC3 | Time: WorkDate from the transfer posting helper | Risk: None
        VerifyReceiptUndoRefusal(1039);
    end;

    [Test]
    procedure Scenario_AC01_SelectedLine_OtherLinePreserved_EN()
    begin
        // Issue #39 AC01 | Time: WorkDate for posting | Risk: None.
        VerifySelectedLine(1033);
    end;

    [Test]
    procedure Scenario_AC01_SelectedLine_OtherLinePreserved_IS()
    begin
        // Issue #39 AC01 | Time: WorkDate for posting | Risk: None.
        VerifySelectedLine(1039);
    end;

    local procedure VerifySelectedLine(LanguageId: Integer)
    var
        Line: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        LineNos: JsonArray;
        Token: JsonToken;
        ShipmentNo: Code[20];
        SelectedLineNo: Integer;
        OtherLineNo: Integer;
        BeforeCount: Integer;
    begin
        // [GIVEN] A real two-line shipment created by this test.
        Initialize();
        ShipmentNo := CreateUndoShipment();
        Line.SetRange("Document No.", ShipmentNo);
        Line.FindSet();
        SelectedLineNo := Line."Line No.";
        Line.Next();
        OtherLineNo := Line."Line No.";
        LineNos.Add(SelectedLineNo);
        Request.Add('documentNo', ShipmentNo);
        Request.Add('lineNos', LineNos);
        // [WHEN] Undo only the first posted line through the public dispatcher.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, LanguageId, Response);
        // [THEN] Native correction entries exist and the other line remains untouched.
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Selected line undone. ' + JsonText(Response));
        Line.Get(ShipmentNo, SelectedLineNo);
        Assert.IsTrue(Line."Correction Line", 'Selected original line marked corrected.');
        Line.Get(ShipmentNo, OtherLineNo);
        Assert.IsFalse(Line."Correction Line", 'Unselected line remains available.');
        Assert.AreEqual(5, Line.Quantity, 'Unselected line quantity is preserved.');
        BeforeCount := Entries.Count();
        Clear(Response);
        // [WHEN] The same explicit line is requested again.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, LanguageId, Response);
        Response.Get('code', Token);
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Already-undone line refused.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Repeated undo posts nothing.');
    end;

    [Test]
    procedure Scenario_AC02_InvalidSelection_NoEntriesWritten()
    var
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        LineNos: JsonArray;
        Token: JsonToken;
        ShipmentNo: Code[20];
        BeforeCount: Integer;
    begin
        // Issue #39 AC02 | Time: WorkDate for fixture posting | Risk: None.
        Initialize();
        // [GIVEN] A real shipment and an invalid string instead of an integer.
        ShipmentNo := CreateUndoShipment();
        BeforeCount := Entries.Count();
        LineNos.Add('10000');
        Request.Add('documentNo', ShipmentNo);
        Request.Add('lineNos', LineNos);
        // [WHEN] The public message validates the selection before native undo.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        // [THEN] The format error is coded and no corrective entry is posted.
        Response.Get('code', Token);
        Assert.AreEqual('InvalidParameterFormat', Token.AsValue().AsText(), 'String line numbers refused.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Invalid request changes no entries.');
        Clear(LineNos);
        Request.Replace('lineNos', LineNos);
        Clear(Response);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        Response.Get('code', Token);
        Assert.AreEqual('InvalidParameter', Token.AsValue().AsText(), 'Empty selection must not undo every line.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Empty selection changes no entries.');
        LineNos.Add(10000);
        LineNos.Add(10000);
        Request.Replace('lineNos', LineNos);
        Clear(Response);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        Response.Get('code', Token);
        Assert.AreEqual('InvalidParameter', Token.AsValue().AsText(), 'Duplicate selection refused.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Duplicate selection changes no entries.');
        Clear(LineNos);
        LineNos.Add(10000);
        LineNos.Add(999999);
        Request.Replace('lineNos', LineNos);
        Clear(Response);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        Response.Get('code', Token);
        Assert.AreEqual('RecordNotFound', Token.AsValue().AsText(), 'Missing selected line refused after checking the valid first line.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Missing selection reverses no part of the valid first line.');
    end;

    [Test]
    procedure Scenario_AC06_CountUnits_LocalizedForChangedPostTypes()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Implementation: Interface "Msg Contract ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        Effect: JsonToken;
        Changes: JsonToken;
        Parameter: JsonToken;
        Name: JsonToken;
        AppParameters: JsonArray;
        Examples: JsonArray;
        ExampleText: Text;
        Types: List of [Enum "Message Type ori"];
        PreviousLanguage: Integer;
        LanguageId: Integer;
        Languages: List of [Integer];
        DeclaresCount: Boolean;
    begin
        // Issue #39 AC06 | Time: no date dependency | Risk: None.
        // Foundation owns expectedCount. The app documents the one-document unit in effect help and examples.
        Initialize();
        Types.Add("Message Type ori"::"Inventory.TransferOrder.Post");
        Types.Add("Message Type ori"::"Inventory.Transfer.UndoShipment");
        Types.Add("Message Type ori"::"Inventory.Assembly.UndoPost");
        PreviousLanguage := GlobalLanguage();
        // [GIVEN] All three irreversible types changed by this issue, in both supported languages.
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            GlobalLanguage(LanguageId);
            foreach MessageType in Types do begin
                Clear(Contract);
                // [WHEN] The registered help contract is composed by Foundation.
                ContractMgt.GetContract(MessageType, Contract);
                // [THEN] Effect help names the one-document unit, including in Icelandic.
                Contract.Get('effect', Effect);
                Effect.AsObject().Get('changes', Changes);
                Assert.IsTrue(Changes.AsValue().AsText().Contains('expectedCount'), 'Effect names the confirmation count.');
                Assert.IsTrue(Changes.AsValue().AsText().Contains('1'), 'Count is one order or posted document.');
                if LanguageId = 1039 then
                    Assert.IsTrue(Changes.AsValue().AsText().Contains('telur'), 'Count unit is translated into Icelandic.');
                Implementation := MessageType;
                Clear(AppParameters);
                Assert.IsTrue(Implementation.GetParameters(AppParameters), 'App parameters exist.');
                DeclaresCount := false;
                foreach Parameter in AppParameters do begin
                    Parameter.AsObject().Get('name', Name);
                    if Name.AsValue().AsText() = 'expectedCount' then
                        DeclaresCount := true;
                end;
                Assert.IsFalse(DeclaresCount, 'expectedCount stays with Foundation.');
                Clear(Examples);
                Assert.IsTrue(Implementation.GetExamples(Examples), 'Examples exist.');
                Examples.WriteTo(ExampleText);
                Assert.IsTrue(ExampleText.Contains('expectedCount'), 'Example includes the confirmation count.');
            end;
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure VerifyReceivedRefusal(LanguageId: Integer)
    var
        Shipment: Record "Transfer Shipment Header";
        Line: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShipmentNo: Code[20];
        BeforeCount: Integer;
        SavedLanguage: Integer;
    begin
        ShipmentNo := CreateUndoShipment();
        Shipment.Get(ShipmentNo);
        Request.Add('postingType', 'Receive');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", Request);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", Shipment."Transfer Order No.", Request, Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Own shipment is actually received before refusal verification.');
        BeforeCount := Entries.Count();
        Clear(Request);
        Request.Add('documentNo', ShipmentNo);
        Confirm("Message Type ori"::"Inventory.Transfer.UndoShipment", Request);
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        GlobalLanguage(SavedLanguage);
        Assert.IsTrue(Response.Get('code', Token), 'A received shipment has a coded refusal.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'Received shipment is a precondition failure.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'Refusal provides the return-transfer next step.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Next step is not empty.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Refusal writes no reversing entries.');
        Line.SetRange("Document No.", ShipmentNo);
        Line.SetRange("Correction Line", true);
        Assert.IsTrue(Line.IsEmpty(), 'The already-received shipment is preserved.');
    end;

    local procedure VerifyShipmentUndo(FailSecondLine: Boolean)
    var
        Line: Record "Transfer Shipment Line";
        OtherLine: Record "Transfer Shipment Line";
        Entries: Record "Item Ledger Entry";
        Observer: Codeunit "Inventory Cost Write Observer";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ShipmentNo: Code[20];
        OtherShipmentNo: Code[20];
        BeforeCount: Integer;
    begin
        ShipmentNo := CreateUndoShipment();
        OtherShipmentNo := CreateUndoShipment();
        BeforeCount := Entries.Count();
        if FailSecondLine then begin
            Observer.SetUndoFailure(ShipmentNo, '');
            BindSubscription(Observer);
        end;
        Request.Add('documentNo', ShipmentNo);
        Confirm("Message Type ori"::"Inventory.Transfer.UndoShipment", Request);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoShipment", Request, Response);
        if FailSecondLine then
            UnbindSubscription(Observer);
        Response.Get('status', Token);
        Line.SetRange("Document No.", ShipmentNo);
        Line.SetRange("Correction Line", true);
        if FailSecondLine then begin
            Assert.AreEqual('Error', Token.AsValue().AsText(), 'Injected native failure is returned.');
            Response.Get('error', Token);
            Assert.AreNotEqual(0, StrPos(Token.AsValue().AsText(), 'Owned second undo line failure'), 'The second native line was reached.');
            Assert.AreEqual(2, Observer.UndoCallbacks(), 'Failure after native writes for two selected lines.');
            Assert.AreEqual(0, Line.Count(), 'All selected correction flags roll back.');
            Assert.AreEqual(BeforeCount, Entries.Count(), 'All reversing ledger entries roll back.');
        end else begin
            Assert.AreEqual('Success', Token.AsValue().AsText(), 'Selected shipment undone.');
            Assert.IsTrue(Line.Count() >= 2, 'Both selected lines are reversed.');
            Assert.IsTrue(Entries.Count() > BeforeCount, 'Native reversing entries were posted.');
        end;
        OtherLine.SetRange("Document No.", OtherShipmentNo);
        OtherLine.SetRange("Correction Line", true);
        Assert.AreEqual(0, OtherLine.Count(), 'Another owned shipment is untouched.');
        OtherLine.SetRange("Correction Line", false);
        Assert.AreEqual(2, OtherLine.Count(), 'Both other shipment lines remain unchanged.');
    end;

    local procedure VerifyReceiptUndoRefusal(LanguageId: Integer)
    var
        ReceiptHeader: Record "Transfer Receipt Header";
        Entries: Record "Item Ledger Entry";
        Impl: Codeunit "Transf Undo Rcpt Impl ori";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        ReceiptNo: Code[20];
        BeforeCount: Integer;
        SavedLanguage: Integer;
        Description: Text;
        ErrorText: Text;
    begin
        ReceiptNo := CreatePostedReceipt();
        Assert.IsTrue(ReceiptHeader.Get(ReceiptNo), 'Owned receipt exists before the refusal.');
        BeforeCount := Entries.Count();
        Request.Add('documentNo', ReceiptNo);
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Assert.IsFalse(Impl.IsEnabled(), 'The compatibility identifier stays out of discovery.');
        Description := Impl.GetDescription();
        if LanguageId = 1039 then
            Assert.AreEqual('Óvirkt samhæfnisauðkenni; afturköllun bókaðrar flutningsmóttöku er ekki studd.', Description, 'Icelandic description does not advertise a working undo.')
        else
            Assert.AreEqual('Unavailable compatibility identifier; posted transfer receipt undo is not supported.', Description, 'English description does not advertise a working undo.');
        // A language id of 0 selects the company default inside the dispatcher, so the call must pass 1033 or 1039 itself.
        Helper.ProcessMessage("Message Type ori"::"Inventory.Transfer.UndoReceipt", Request, LanguageId, Response);
        GlobalLanguage(SavedLanguage);
        Assert.IsTrue(Response.Get('status', Token), 'Refusal has a status. ' + JsonText(Response));
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'UndoReceipt never succeeds.');
        Assert.IsTrue(Response.Get('code', Token), 'An existing receipt has a coded refusal.');
        Assert.AreEqual('PreconditionFailed', Token.AsValue().AsText(), 'An existing receipt is PreconditionFailed.');
        Assert.IsTrue(Response.Get('error', Token), 'Refusal carries the error text.');
        ErrorText := Token.AsValue().AsText();
        if LanguageId = 1039 then
            Assert.AreEqual('Ekki er hægt að afturkalla bókaðar millifærslumóttökur í þessari útgáfu Business Central.', ErrorText, 'Icelandic refusal.')
        else
            Assert.AreEqual('Posted transfer receipts cannot be undone in this Business Central version.', ErrorText, 'English refusal.');
        Assert.IsTrue(Response.Get('nextStep', Token), 'Refusal names the next step.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Next step is not empty.');
        Assert.AreEqual(BeforeCount, Entries.Count(), 'Refusal posts no further item ledger entry.');
        Assert.IsTrue(ReceiptHeader.Get(ReceiptNo), 'The posted receipt remains.');
    end;

    local procedure CreatePostedReceipt() ReceiptNo: Code[20]
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        Header: Record "Transfer Header";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(Header, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", Header);
        DocumentNo := Header."No.";
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", Request);
        Request.Add('postingType', 'Ship');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, Request, Response);
        Assert.IsTrue(Response.Get('status', Token), 'Ship status missing.');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned shipment posts before the receipt. ' + JsonText(Response));
        Clear(Request);
        Clear(Response);
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", Request);
        Request.Add('postingType', 'Receive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, Request, Response);
        Assert.IsTrue(Response.Get('status', Token), 'Receive status missing.');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned receipt posts. ' + JsonText(Response));
        Assert.IsTrue(Response.Get('postedReceiptNo', Token), 'postedReceiptNo missing.');
        ReceiptNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
    end;

    local procedure CreateUndoShipment() ShipmentNo: Code[20]
    var
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Item: Record Item;
        Header: Record "Transfer Header";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(Header, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(Header, Item."No.", 10);
        Helper.CreateTransferLine(Header, Item."No.", 5);
        Codeunit.Run(Codeunit::"Release Transfer Document", Header);
        Request.Add('postingType', 'Ship');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", Request);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", Header."No.", Request, Response);
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Owned shipment fixture posts. ' + JsonText(Response));
        Response.Get('postedShipmentNo', Token);
        ShipmentNo := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
    end;

    [Test]
    procedure Post_Ship_ReturnsPostedShipmentNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ShipmentToken : JsonToken;
    begin
        // [SCENARIO] Posting Ship on a released transfer returns postedShipmentNo
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Ship');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.AreNotEqual('', ShipmentToken.AsValue().AsText(), 'postedShipmentNo should be populated');
    end;

    [Test]
    procedure Post_InvalidPostingType_ReturnsError()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] Invalid postingType value returns Error
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'Bogus');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
    end;

    [Test]
    procedure Post_ShipReceive_RefusesCombinedPosting()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken: JsonToken;
        ResponseText: Text;
    begin
        // [SCENARIO] #159 ShipReceive is refused and is not described as a valid postingType
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 100);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);

        RequestJson.Add('postingType', 'ShipReceive');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);

        ResponseJson.WriteTo(ResponseText);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'Status should be Error');
        Assert.IsTrue(ResponseText.Contains('not accepted'), 'The refusal must say ShipReceive is not accepted.');
        Assert.IsFalse(ResponseText.Contains('or "ShipReceive"'), 'The refusal must not list ShipReceive as a valid postingType.');
    end;

    [Test]
    procedure Post_DirectTransfer_ReceiptAndShipment_ReturnsBothDocuments()
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        OriginalSetup: Record "Inventory Setup";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ShipmentToken: JsonToken;
        ReceiptToken: JsonToken;
        ShipmentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Receipt and Shipment on a direct transfer posts the shipment and the receipt together.
        Initialize();
        Helper.SetDirectTransferPosting(false, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Ship", 4);
        TransferLine.Modify(true);

        // The owned request names one transfer document, even when both posting legs run.
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ShipmentNo := CopyStr(ShipmentToken.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ShipmentNo, 'postedShipmentNo should be populated');
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferShipmentHeader.Get(ShipmentNo), 'Posted transfer shipment should exist');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(TransferHeader."No."), 'A partial direct transfer should keep the order');
    end;

    [Test]
    [HandlerFunctions('DirectTransferPostedMessageHandler')]
    procedure Post_DirectTransfer_SingleDocument_CreatesDirectTransfer()
    var
        OriginalSetup: Record "Inventory Setup";
        DirectTransHeader: Record "Direct Trans. Header";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        TransferHeader: Record "Transfer Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        // [SCENARIO] #228 The selected single-document mode posts a direct transfer, not a shipment and receipt.
        Initialize();
        Helper.SetDirectTransferPosting(true, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        DocumentNo := TransferHeader."No.";
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Direct transfer should succeed. ' + JsonText(ResponseJson));
        DirectTransHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.AreEqual(1, DirectTransHeader.Count(), 'Exactly one posted direct transfer exists for the order');
        DirectTransHeader.FindFirst();
        // The public response uses both number fields for the same posted direct transfer.
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', Token), 'postedShipmentNo missing');
        Assert.AreEqual(DirectTransHeader."No.", Token.AsValue().AsText(), 'Shipment response identifies the posted direct transfer');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', Token), 'postedReceiptNo missing');
        Assert.AreEqual(DirectTransHeader."No.", Token.AsValue().AsText(), 'Receipt response identifies the same posted direct transfer');
        TransferShipmentHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.IsTrue(TransferShipmentHeader.IsEmpty(), 'Single-document posting creates no shipment header');
        TransferReceiptHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.IsTrue(TransferReceiptHeader.IsEmpty(), 'Single-document posting creates no receipt header');
        Assert.IsFalse(TransferHeader.Get(DocumentNo), 'Full direct transfer removes the order');
    end;

    [Test]
    procedure Post_Receive_Full_ReturnsPostedReceiptNoAfterHeaderDeleted()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken : JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Full Receive after Ship deletes the transfer order and still returns Success with postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Full receive must not return an error after the posting committed. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated. ' + JsonText(ResponseJson));
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist. postedReceiptNo=' + ReceiptNo + ' ' + JsonText(ResponseJson));
        Assert.IsFalse(TransferHeader.Get(DocumentNo), 'A full receive deletes the transfer order');
        Assert.IsTrue(ResponseJson.Get('orderDeleted', StatusToken), 'orderDeleted missing');
        Assert.IsTrue(StatusToken.AsValue().AsBoolean(), 'orderDeleted must be true after a full receive');
    end;

    [Test]
    procedure Post_Receive_Partial_KeepsOrderAndReturnsPostedReceiptNo()
    var
        FromLocation, ToLocation, InTransitLocation : Record Location;
        Item: Record Item;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        RequestJson, ResponseJson : JsonObject;
        StatusToken, ReceiptToken : JsonToken;
        DocumentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Partial Receive after Ship keeps the transfer order and returns postedReceiptNo.
        Initialize();
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, 10);
        Helper.CreateTransferHeader(TransferHeader, FromLocation.Code, ToLocation.Code, InTransitLocation.Code);
        Helper.CreateTransferLine(TransferHeader, Item."No.", 10);
        Codeunit.Run(Codeunit::"Release Transfer Document", TransferHeader);
        DocumentNo := TransferHeader."No.";

        RequestJson.Add('postingType', 'Ship');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'ship status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Ship should succeed');

        TransferLine.SetRange("Document No.", DocumentNo);
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Receive", 4);
        TransferLine.Modify(true);

        Clear(RequestJson);
        Clear(ResponseJson);
        RequestJson.Add('postingType', 'Receive');
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'receive status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Partial receive should succeed');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(DocumentNo), 'A partial receive keeps the transfer order');
        Assert.IsTrue(ResponseJson.Get('orderDeleted', StatusToken), 'orderDeleted missing');
        Assert.IsFalse(StatusToken.AsValue().AsBoolean(), 'orderDeleted must be false after a partial receive');
    end;

    /// <summary>Handles the native confirmation message after a direct transfer is fully posted.</summary>
    [MessageHandler]
    procedure DirectTransferPostedMessageHandler(Message: Text[1024])
    begin
        // The test verifies the resulting posted document and order deletion independently of the localized message.
        Assert.AreNotEqual('', Message, 'Native posting message should be populated');
    end;

    local procedure Confirm(MessageType: Enum "Message Type ori"; var Request: JsonObject)
    var
        Library: Codeunit "Inventory Test Library ori";
    begin
        // Foundation 28.0.10 rejects an undeclared expectedCount. Send it only when the composed contract declares it.
        Library.ConfirmRequest(MessageType, Request);
    end;

    local procedure JsonText(ResponseJson: JsonObject): Text
    var
        TextValue: Text;
    begin
        ResponseJson.WriteTo(TextValue);
        exit(TextValue);
    end;


    [Test]
    procedure Post_ExistingOrder_SetupChanged_ShipmentReceipt()
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        OriginalSetup: Record "Inventory Setup";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ShipmentToken: JsonToken;
        ReceiptToken: JsonToken;
        ShipmentNo: Code[20];
        ReceiptNo: Code[20];
    begin
        // [SCENARIO] Receipt and Shipment on a direct transfer posts the shipment and the receipt together.
        Initialize();
        Helper.SetDirectTransferPosting(false, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        // [WHEN] Setup changes after the order captured its posting mode.
        Helper.ChangeSetupAfterOrder(TransferHeader, true);
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.FindFirst();
        TransferLine.Validate("Qty. to Ship", 4);
        TransferLine.Modify(true);

        // The owned request names one transfer document, even when both posting legs run.
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);
        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", TransferHeader."No.", RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Status should be Success. ' + JsonText(ResponseJson));
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', ShipmentToken), 'postedShipmentNo missing');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', ReceiptToken), 'postedReceiptNo missing');
        ShipmentNo := CopyStr(ShipmentToken.AsValue().AsText(), 1, MaxStrLen(ShipmentNo));
        ReceiptNo := CopyStr(ReceiptToken.AsValue().AsText(), 1, MaxStrLen(ReceiptNo));
        Assert.AreNotEqual('', ShipmentNo, 'postedShipmentNo should be populated');
        Assert.AreNotEqual('', ReceiptNo, 'postedReceiptNo should be populated');
        Assert.IsTrue(TransferShipmentHeader.Get(ShipmentNo), 'Posted transfer shipment should exist');
        Assert.IsTrue(TransferReceiptHeader.Get(ReceiptNo), 'Posted transfer receipt should exist');
        Assert.IsTrue(TransferHeader.Get(TransferHeader."No."), 'A partial direct transfer should keep the order');
    end;

    [Test]
    [HandlerFunctions('DirectTransferPostedMessageHandler')]
    procedure Post_ExistingOrder_SetupChanged_SingleDocument()
    var
        OriginalSetup: Record "Inventory Setup";
        DirectTransHeader: Record "Direct Trans. Header";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        TransferHeader: Record "Transfer Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        DocumentNo: Code[20];
    begin
        // [SCENARIO] #228 The selected single-document mode posts a direct transfer, not a shipment and receipt.
        Initialize();
        Helper.SetDirectTransferPosting(true, OriginalSetup);
        Helper.CreateReleasedDirectTransfer(TransferHeader, 10);
        // [WHEN] Setup changes after the order captured its posting mode.
        Helper.ChangeSetupAfterOrder(TransferHeader, false);
        DocumentNo := TransferHeader."No.";
        Confirm("Message Type ori"::"Inventory.TransferOrder.Post", RequestJson);

        Helper.ProcessMessage("Message Type ori"::"Inventory.TransferOrder.Post", DocumentNo, RequestJson, ResponseJson);
        Helper.RestoreDirectTransferPosting(OriginalSetup);

        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing');
        Assert.AreEqual('Success', Token.AsValue().AsText(), 'Direct transfer should succeed. ' + JsonText(ResponseJson));
        DirectTransHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.AreEqual(1, DirectTransHeader.Count(), 'Exactly one posted direct transfer exists for the order');
        DirectTransHeader.FindFirst();
        // The public response uses both number fields for the same posted direct transfer.
        Assert.IsTrue(ResponseJson.Get('postedShipmentNo', Token), 'postedShipmentNo missing');
        Assert.AreEqual(DirectTransHeader."No.", Token.AsValue().AsText(), 'Shipment response identifies the posted direct transfer');
        Assert.IsTrue(ResponseJson.Get('postedReceiptNo', Token), 'postedReceiptNo missing');
        Assert.AreEqual(DirectTransHeader."No.", Token.AsValue().AsText(), 'Receipt response identifies the same posted direct transfer');
        TransferShipmentHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.IsTrue(TransferShipmentHeader.IsEmpty(), 'Single-document posting creates no shipment header');
        TransferReceiptHeader.SetRange("Transfer Order No.", DocumentNo);
        Assert.IsTrue(TransferReceiptHeader.IsEmpty(), 'Single-document posting creates no receipt header');
        Assert.IsFalse(TransferHeader.Get(DocumentNo), 'Full direct transfer removes the order');
    end;
}
