namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Foundation.Address;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Inventory.TrackingInfo.Get reads lot, serial and package information cards (#106).</summary>
codeunit 96992 "Tracking Info Get Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Library: Codeunit "Inventory Test Library ori";
        LibraryInventory: Codeunit "Library - Inventory";

    /// <summary>AC01/AC03: a lot card answers its fields, comments, inventory and expired inventory, and nothing is written.</summary>
    [Test]
    procedure LotCard_ReturnsCardFieldsCommentsAndInventory()
    var
        Item: Record Item;
        LotInfo: Record "Lot No. Information";
        TrackingComment: Record "Item Tracking Comment";
        Ledger: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Comment: JsonObject;
        LotCount: Integer;
        CommentCount: Integer;
        LedgerCount: Integer;
    begin
        // [GIVEN] A lot card with test quality, certificate and two comments, 5 in stock of which 2 expired.
        Initialize(Item);
        CreateLotCard(Item."No.", '', 'TI-LOT-1', LotInfo);
        LotInfo.Description := 'Supplier batch';
        LotInfo."Test Quality" := LotInfo."Test Quality"::Good;
        LotInfo."Certificate Number" := 'CERT-106';
        LotInfo.Modify();
        AddComment("Item Tracking Comment Type"::"Lot No.", Item."No.", '', 'TI-LOT-1', 10000, WorkDate(), 'Checked on receipt');
        AddComment("Item Tracking Comment Type"::"Lot No.", Item."No.", '', 'TI-LOT-1', 20000, 0D, 'Second line');
        AddStock(Item."No.", '', 'TI-LOT-1', '', '', 3, 0D);
        AddStock(Item."No.", '', 'TI-LOT-1', '', '', 2, WorkDate() - 1);
        AddStock(Item."No.", '', 'TI-LOT-OTHER', '', '', 7, 0D);
        LotCount := LotInfo.Count();
        CommentCount := TrackingComment.Count();
        LedgerCount := Ledger.Count();
        Request.Add('itemNo', Item."No.");
        Request.Add('lotNo', 'TI-LOT-1');

        // [WHEN] The card is read.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);

        // [THEN] Every card field is answered and only this lot is counted.
        Library.AssertStatus(Response, 'Success');
        Library.AssertResponseContract("Message Type ori"::"Inventory.TrackingInfo.Get", Response);
        AssertText(Response, 'trackingType', 'Lot');
        AssertText(Response, 'itemNo', Item."No.");
        AssertText(Response, 'lotNo', 'TI-LOT-1');
        AssertText(Response, 'serialNo', '');
        AssertText(Response, 'description', 'Supplier batch');
        AssertText(Response, 'testQuality', 'Good');
        AssertText(Response, 'certificateNumber', 'CERT-106');
        AssertBoolean(Response, 'blocked', false);
        AssertBoolean(Response, 'hasComments', true);
        AssertDecimal(Response, 'inventory', 5);
        AssertDecimal(Response, 'expiredInventory', 2);
        Assert.IsTrue(Response.Get('comments', Token), 'comments missing');
        Assert.AreEqual(2, Token.AsArray().Count(), 'two comments');
        Token.AsArray().Get(0, Token);
        Comment := Token.AsObject();
        AssertDecimal(Comment, 'lineNo', 10000);
        AssertText(Comment, 'date', Format(WorkDate(), 0, 9));
        AssertText(Comment, 'comment', 'Checked on receipt');
        Assert.AreEqual(LotCount, LotInfo.Count(), 'The read writes no card.');
        Assert.AreEqual(CommentCount, TrackingComment.Count(), 'The read writes no comment.');
        Assert.AreEqual(LedgerCount, Ledger.Count(), 'The read writes no ledger entry.');
    end;

    /// <summary>AC01: a serial card answers blocked and blanks the lot-only fields; subject selects the item.</summary>
    [Test]
    procedure SerialCard_BySubject_AnswersBlockedAndBlanksLotFields()
    var
        Item: Record Item;
        SerialInfo: Record "Serial No. Information";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A blocked serial card with one unit in stock and no comments.
        Initialize(Item);
        SerialInfo.Init();
        SerialInfo."Item No." := Item."No.";
        SerialInfo."Serial No." := 'TI-SN-1';
        SerialInfo.Description := 'Unit one';
        SerialInfo.Blocked := true;
        SerialInfo.Insert();
        AddStock(Item."No.", '', '', 'TI-SN-1', '', 1, 0D);
        Request.Add('serialNo', 'TI-SN-1');

        // [WHEN] The card is read with the item number as subject.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", Item."No.", Request, false);

        // [THEN] Serial fields are answered; test quality and certificate are blank.
        Library.AssertStatus(Response, 'Success');
        Library.AssertResponseContract("Message Type ori"::"Inventory.TrackingInfo.Get", Response);
        AssertText(Response, 'trackingType', 'Serial');
        AssertText(Response, 'serialNo', 'TI-SN-1');
        AssertText(Response, 'lotNo', '');
        AssertText(Response, 'description', 'Unit one');
        AssertText(Response, 'testQuality', '');
        AssertText(Response, 'certificateNumber', '');
        AssertBoolean(Response, 'blocked', true);
        AssertBoolean(Response, 'hasComments', false);
        AssertDecimal(Response, 'inventory', 1);
        AssertDecimal(Response, 'expiredInventory', 0);
        Assert.IsTrue(Response.Get('comments', Token), 'comments missing');
        Assert.AreEqual(0, Token.AsArray().Count(), 'no comments');
    end;

    /// <summary>AC01: a package card answers country/region and certificate; a package comment is listed.</summary>
    [Test]
    procedure PackageCard_AnswersCountryRegionAndCertificate()
    var
        Item: Record Item;
        PackageInfo: Record "Package No. Information";
        CountryRegion: Record "Country/Region";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // [GIVEN] A package card with a country/region, certificate and one comment.
        Initialize(Item);
        CountryRegion.FindFirst();
        PackageInfo.Init();
        PackageInfo."Item No." := Item."No.";
        PackageInfo."Package No." := 'TI-PKG-1';
        PackageInfo."Country/Region Code" := CountryRegion.Code;
        PackageInfo."Certificate Number" := 'PKG-CERT';
        PackageInfo.Insert();
        AddComment("Item Tracking Comment Type"::"Package No.", Item."No.", '', 'TI-PKG-1', 10000, 0D, 'Pallet A');
        AddStock(Item."No.", '', '', '', 'TI-PKG-1', 4, 0D);
        Request.Add('itemNo', Item."No.");
        Request.Add('packageNo', 'TI-PKG-1');

        // [WHEN] The card is read.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);

        // [THEN] Package fields are answered.
        Library.AssertStatus(Response, 'Success');
        Library.AssertResponseContract("Message Type ori"::"Inventory.TrackingInfo.Get", Response);
        AssertText(Response, 'trackingType', 'Package');
        AssertText(Response, 'packageNo', 'TI-PKG-1');
        AssertText(Response, 'countryRegionCode', CountryRegion.Code);
        AssertText(Response, 'certificateNumber', 'PKG-CERT');
        AssertText(Response, 'testQuality', '');
        AssertDecimal(Response, 'inventory', 4);
        Assert.IsTrue(Response.Get('comments', Token), 'comments missing');
        Assert.AreEqual(1, Token.AsArray().Count(), 'one package comment');
    end;

    /// <summary>AC02: a lot with stock but no information card is refused with RecordNotFound and a nextStep.</summary>
    [Test]
    procedure LotWithoutCard_ReturnsRecordNotFound()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] Stock in a lot that has no Lot No. Information card.
        Initialize(Item);
        AddStock(Item."No.", '', 'TI-NO-CARD', '', '', 2, 0D);
        Request.Add('itemNo', Item."No.");
        Request.Add('lotNo', 'TI-NO-CARD');

        // [WHEN] The card is read.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);

        // [THEN] RecordNotFound names lotNo and says the number has no information card.
        AssertRefusal(Response, 'RecordNotFound', 'lotNo', 'has no information card');
    end;

    /// <summary>Edge: the card of a variant is found only with its variantCode; the blank variant has no card.</summary>
    [Test]
    procedure VariantCard_IsFoundOnlyWithItsVariantCode()
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        LotInfo: Record "Lot No. Information";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // [GIVEN] A lot card for a variant of the item only.
        Initialize(Item);
        LibraryInventory.CreateItemVariant(ItemVariant, Item."No.");
        CreateLotCard(Item."No.", ItemVariant.Code, 'TI-LOT-VAR', LotInfo);
        AddStock(Item."No.", ItemVariant.Code, 'TI-LOT-VAR', '', '', 6, 0D);
        AddStock(Item."No.", '', 'TI-LOT-VAR', '', '', 9, 0D);
        Request.Add('itemNo', Item."No.");
        Request.Add('lotNo', 'TI-LOT-VAR');

        // [WHEN] The card is read without a variant, [THEN] there is no card for the blank variant.
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        AssertRefusal(Response, 'RecordNotFound', 'lotNo', 'has no information card');

        // [WHEN] The card is read with its variant, [THEN] only the stock of that variant counts.
        Request.Add('variantCode', ItemVariant.Code);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        Library.AssertStatus(Response, 'Success');
        AssertText(Response, 'variantCode', ItemVariant.Code);
        AssertDecimal(Response, 'inventory', 6);
    end;

    /// <summary>AC04: invalid input is refused with a Bifröst code, the parameter and a nextStep.</summary>
    [Test]
    procedure InvalidRequests_ReturnCodedRefusals()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize(Item);

        // No item selection at all.
        Request.Add('lotNo', 'TI-LOT-1');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        AssertRefusal(Response, 'MissingParameter', 'itemNo', 'data.itemNo');

        // No tracking number.
        Clear(Request);
        Request.Add('itemNo', Item."No.");
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        AssertRefusal(Response, 'MissingParameter', 'lotNo|serialNo|packageNo', 'lotNo');

        // Two tracking numbers.
        Request.Add('lotNo', 'TI-LOT-1');
        Request.Add('serialNo', 'TI-SN-1');
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        AssertRefusal(Response, 'InvalidParameter', 'lotNo|serialNo|packageNo', 'lotNo');

        // A lot number longer than the field.
        Clear(Request);
        Request.Add('itemNo', Item."No.");
        Request.Add('lotNo', PadStr('', 51, 'L'));
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        AssertRefusal(Response, 'InvalidParameterFormat', 'variantCode|lotNo|serialNo|packageNo', 'Shorten');

        // A lot number that is not a JSON string.
        Clear(Request);
        Request.Add('itemNo', Item."No.");
        Request.Add('lotNo', 106);
        Response := Library.ExecuteType("Message Type ori"::"Inventory.TrackingInfo.Get", '', Request, false);
        Library.AssertStatus(Response, 'Error');
        AssertText(Response, 'code', 'InvalidParameterFormat');
    end;

    /// <summary>AC04/AC05: help is bilingual, read only and the name has three parts.</summary>
    [Test]
    procedure Help_IsBilingualReadOnlyAndThreePart()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageImpl: Interface "Msg Interface ori";
        Contract: JsonObject;
        Token: JsonToken;
        Parts: List of [Text];
        English: Text;
        Icelandic: Text;
        PreviousLanguage: Integer;
    begin
        Parts := Format("Message Type ori"::"Inventory.TrackingInfo.Get").Split('.');
        Assert.AreEqual(3, Parts.Count(), 'The message type name has three parts.');
        Assert.IsTrue(ContractMgt.GetContract("Message Type ori"::"Inventory.TrackingInfo.Get", Contract), 'contract');
        Assert.IsTrue(Contract.Get('effect', Token), 'effect chapter');
        Token.AsObject().Get('effect', Token);
        Assert.AreEqual('read', Token.AsValue().AsText(), 'The type declares a read effect.');
        MessageImpl := "Message Type ori"::"Inventory.TrackingInfo.Get";
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := MessageImpl.GetDescription();
        GlobalLanguage(1039);
        Icelandic := MessageImpl.GetDescription();
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Reads the lot, serial or package information card of an item, with its comments and inventory.', English, 'en-US description');
        Assert.AreEqual('Les upplýsingaspjald lotu, raðnúmers eða pakka fyrir vöru, með athugasemdum og birgðum.', Icelandic, 'is-IS description');
    end;

    /// <summary>AC04: the RecordNotFound refusal answers in Icelandic at 1039.</summary>
    [Test]
    procedure NoCard_RefusalIsIcelandicAt1039()
    var
        Item: Record Item;
        Helper: Codeunit "Transfer Order Test Helper";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize(Item);
        Request.Add('itemNo', Item."No.");
        Request.Add('packageNo', 'TI-PKG-NONE');
        Helper.ProcessMessage("Message Type ori"::"Inventory.TrackingInfo.Get", Request, 1039, Response);
        AssertRefusal(Response, 'RecordNotFound', 'packageNo', 'hefur ekkert upplýsingaspjald');
    end;

    local procedure Initialize(var Item: Record Item)
    var
        Setup: Record "Inventory Setup ori";
    begin
        Library.Initialize();
        Setup.InsertIfNotExists();
        if not Setup."Item Tracking" then begin
            Setup."Item Tracking" := true;
            Setup.Modify(true);
        end;
        LibraryInventory.CreateItem(Item);
    end;

    local procedure CreateLotCard(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; var LotInfo: Record "Lot No. Information")
    begin
        LotInfo.Init();
        LotInfo."Item No." := ItemNo;
        LotInfo."Variant Code" := VariantCode;
        LotInfo."Lot No." := LotNo;
        LotInfo.Insert();
    end;

    local procedure AddComment(CommentType: Enum "Item Tracking Comment Type"; ItemNo: Code[20]; VariantCode: Code[10]; TrackingNo: Code[50]; LineNo: Integer; CommentDate: Date; CommentText: Text[80])
    var
        TrackingComment: Record "Item Tracking Comment";
    begin
        TrackingComment.Init();
        TrackingComment.Type := CommentType;
        TrackingComment."Item No." := ItemNo;
        TrackingComment."Variant Code" := VariantCode;
        TrackingComment."Serial/Lot No." := TrackingNo;
        TrackingComment."Line No." := LineNo;
        TrackingComment.Date := CommentDate;
        TrackingComment.Comment := CommentText;
        TrackingComment.Insert();
    end;

    local procedure AddStock(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; SerialNo: Code[50]; PackageNo: Code[50]; Quantity: Decimal; ExpirationDate: Date)
    var
        Ledger: Record "Item Ledger Entry";
        EntryNo: Integer;
    begin
        // Test-only open stock; the test transaction is rolled back by the test runner.
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Item No." := ItemNo;
        Ledger."Variant Code" := VariantCode;
        Ledger."Lot No." := LotNo;
        Ledger."Serial No." := SerialNo;
        Ledger."Package No." := PackageNo;
        Ledger."Posting Date" := WorkDate();
        Ledger.Quantity := Quantity;
        Ledger."Remaining Quantity" := Quantity;
        Ledger.Open := true;
        Ledger.Positive := true;
        Ledger."Expiration Date" := ExpirationDate;
        Ledger.Insert();
    end;

    local procedure AssertRefusal(Response: JsonObject; ExpectedCode: Text; ExpectedParameter: Text; NextStepPart: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        AssertText(Response, 'status', 'Error');
        AssertText(Response, 'code', ExpectedCode);
        AssertText(Response, 'parameter', ExpectedParameter);
        Assert.IsTrue(Response.Get('nextStep', Token), 'nextStep missing: ' + Serialized);
        Assert.IsTrue(Token.AsValue().AsText().Contains(NextStepPart), Serialized);
    end;

    local procedure AssertText(Response: JsonObject; KeyName: Text; Expected: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get(KeyName, Token), KeyName + ' missing: ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), KeyName + ': ' + Serialized);
    end;

    local procedure AssertDecimal(Response: JsonObject; KeyName: Text; Expected: Decimal)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get(KeyName, Token), KeyName + ' missing: ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsDecimal(), KeyName + ': ' + Serialized);
    end;

    local procedure AssertBoolean(Response: JsonObject; KeyName: Text; Expected: Boolean)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        Response.WriteTo(Serialized);
        Assert.IsTrue(Response.Get(KeyName, Token), KeyName + ' missing: ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsBoolean(), KeyName + ': ' + Serialized);
    end;
}
