namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 40: item selectors, native unapplication and exact base-quantity reapplication.</summary>
codeunit 96994 "Item Application 40 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        Helper: Codeunit "Assembly Order Test Helper";

    /// <summary>Exercises ac01 roundtrip1033 preservesexactquantities.</summary>
    [Test]
    procedure Scenario_AC01_RoundTrip1033_PreservesExactQuantities()
    begin
        // Story #40, AC01-04 | Time: WorkDate for native posting | Risk: Foundation dispatcher.
        VerifyRoundTrip(1033);
    end;

    /// <summary>Exercises ac01 roundtrip1039 preservesexactquantities.</summary>
    [Test]
    procedure Scenario_AC01_RoundTrip1039_PreservesExactQuantities()
    begin
        // Story #40, AC01-04 | Time: WorkDate for native posting | Risk: Foundation dispatcher.
        VerifyRoundTrip(1039);
    end;

    /// <summary>Exercises ac02 filters selectexactlocationandvariant.</summary>
    [Test]
    procedure Scenario_AC02_Filters_SelectExactLocationAndVariant()
    var
        Item: Record Item;
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #40, AC02 | Time: WorkDate for native posting | Risk: None.
        CreatePair(Item, Inbound, Outbound);
        Request.Add('itemNo', Item."No.");
        Request.Add('locationCode', 'XMISSING');
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Get", Request, 1033, Response);
        AssertSuccess(Response);
        Assert.AreEqual(0, EntryCount(Response), 'No application from another location leaks into the result.');
        Request.Replace('locationCode', '');
        Request.Add('variantCode', 'XMISSING');
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Get", Request, 1039, Response);
        AssertSuccess(Response);
        Assert.AreEqual(0, EntryCount(Response), 'No application from another variant leaks into the result.');
        Request.Replace('variantCode', '');
        Request.Add('itemLedgerEntryNo', Outbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Get", Request, 1033, Response);
        AssertSuccess(Response);
        Assert.AreEqual(1, EntryCount(Response), 'Combined selectors intersect.');
        Request.Replace('itemNo', 'XMISSING');
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Get", Request, 1033, Response);
        AssertSuccess(Response);
        Assert.AreEqual(0, EntryCount(Response), 'An entry from a different item is not returned.');
    end;

    /// <summary>Exercises ac04 signmismatch1033 refuseswithoutmutation.</summary>
    [Test]
    procedure Scenario_AC04_SignMismatch1033_RefusesWithoutMutation()
    begin
        // Story #40, AC04 | Time: WorkDate for native posting | Risk: None.
        VerifySignMismatch(1033);
    end;

    /// <summary>Exercises ac04 signmismatch1039 refuseswithoutmutation.</summary>
    [Test]
    procedure Scenario_AC04_SignMismatch1039_RefusesWithoutMutation()
    begin
        // Story #40, AC04 | Time: WorkDate for native posting | Risk: None.
        VerifySignMismatch(1039);
    end;

    /// <summary>Exercises ac03 invalidquantity1033 refuses.</summary>
    [Test]
    procedure Scenario_AC03_InvalidQuantity1033_Refuses()
    begin
        // Story #40, AC03 | Time: None | Risk: None.
        VerifyInvalidQuantity(1033);
    end;

    /// <summary>Exercises ac03 invalidquantity1039 refuses.</summary>
    [Test]
    procedure Scenario_AC03_InvalidQuantity1039_Refuses()
    begin
        // Story #40, AC03 | Time: None | Risk: None.
        VerifyInvalidQuantity(1039);
    end;

    /// <summary>Exercises ac04 nonapplicationinbound refuses.</summary>
    [Test]
    procedure Scenario_AC04_NonApplicationInbound_Refuses()
    var
        Item: Record Item;
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #40, AC04 | Time: WorkDate for native posting | Risk: None.
        CreatePair(Item, Inbound, Outbound);
        Request.Add('itemLedgerEntryNo', Outbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Unapply", Request, 1033, Response);
        AssertSuccess(Response);
        Request.Replace('itemLedgerEntryNo', Inbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Unapply", Request, 1033, Response);
        AssertRefusal(Response, 'RecordNotFound');
        Inbound.Get(Inbound."Entry No.");
        Assert.AreEqual(10, Inbound."Remaining Quantity", 'The inbound self-application cannot be removed.');
    end;

    /// <summary>Exercises ac04 laternativerefusal rollsbackearlierunapplication.</summary>
    [Test]
    procedure Scenario_AC04_LaterNativeRefusal_RollsBackEarlierUnapplication()
    var
        Item: Record Item;
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        LaterOutbound: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #40, AC04 | Time: WorkDate for native posting | Risk: None.
        // [GIVEN] Two native applications; the later one has a native non-unappliable transfer type.
        CreatePair(Item, Inbound, Outbound);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        PostQuantity(Batch, Item."No.", false, 2);
        LaterOutbound.SetRange("Item No.", Item."No.");
        LaterOutbound.SetRange(Positive, false);
        LaterOutbound.FindLast();
        LaterOutbound."Entry Type" := LaterOutbound."Entry Type"::Transfer;
        LaterOutbound.Modify();
        Application.SetRange("Inbound Item Entry No.", Inbound."Entry No.");
        BeforeCount := Application.Count();
        Request.Add('itemLedgerEntryNo', Inbound."Entry No.");
        // [WHEN] The first application can be removed but the second native operation refuses.
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Unapply", Request, 1033, Response);
        // [THEN] The whole operation is rolled back, including the earlier successful native call.
        AssertRefusal(Response, 'BusinessCentralError');
        Assert.AreEqual(BeforeCount, Application.Count(), 'No application may be lost on a later refusal.');
        Inbound.Get(Inbound."Entry No.");
        Outbound.Get(Outbound."Entry No.");
        Assert.AreEqual(2, Inbound."Remaining Quantity", 'Receipt quantity is rolled back.');
        Assert.AreEqual(0, Outbound."Remaining Quantity", 'Earlier issue stays fully applied.');
    end;

    local procedure VerifyRoundTrip(LanguageId: Integer)
    var
        Item: Record Item;
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        Request: JsonObject;
        Response: JsonObject;
        EntriesToken: JsonToken;
        EntryToken: JsonToken;
        JoinedToken: JsonToken;
        ValueToken: JsonToken;
    begin
        // [GIVEN] A new item with a receipt of 10 and an applied issue of 6.
        CreatePair(Item, Inbound, Outbound);
        Request.Add('itemNo', Item."No.");
        Request.Add('locationCode', '');
        Request.Add('variantCode', '');
        // [WHEN] Read by item; both applications and joined ledger data are included once.
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Get", Request, LanguageId, Response);
        AssertSuccess(Response);
        Assert.AreEqual(2, EntryCount(Response), 'Inbound self-application and outbound application appear only once.');
        Response.Get('entries', EntriesToken);
        foreach EntryToken in EntriesToken.AsArray() do begin
            EntryToken.AsObject().Get('outboundItemEntryNo', ValueToken);
            if ValueToken.AsValue().AsInteger() = Outbound."Entry No." then begin
                EntryToken.AsObject().Get('inboundEntry', JoinedToken);
                JoinedToken.AsObject().Get('itemNo', ValueToken);
                Assert.AreEqual(Item."No.", ValueToken.AsValue().AsText(), 'Inbound joined item.');
                EntryToken.AsObject().Get('outboundEntry', JoinedToken);
                JoinedToken.AsObject().Get('quantity', ValueToken);
                Assert.AreEqual(-6, ValueToken.AsValue().AsDecimal(), 'Outbound joined quantity.');
            end;
        end;
        Item."Cost is Adjusted" := true;
        Item.Modify();
        Clear(Request);
        Request.Add('itemLedgerEntryNo', Outbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Unapply", Request, LanguageId, Response);
        AssertSuccess(Response);
        Inbound.Get(Inbound."Entry No.");
        Outbound.Get(Outbound."Entry No.");
        Item.Get(Item."No.");
        Assert.AreEqual(10, Inbound."Remaining Quantity", 'Native unapply restores receipt quantity.');
        Assert.AreEqual(-6, Outbound."Remaining Quantity", 'Native unapply restores issue quantity.');
        Assert.IsFalse(Item."Cost is Adjusted", 'Item remains marked for cost adjustment.');
        Assert.IsTrue(Outbound."Applied Entry to Adjust", 'Ledger remains marked for adjustment.');
        Clear(Request);
        Request.Add('outboundEntryNo', Outbound."Entry No.");
        Request.Add('inboundEntryNo', Inbound."Entry No.");
        Request.Add('quantity', 2.5);
        // [WHEN] Apply part of the outstanding base quantity.
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertSuccess(Response);
        Inbound.Get(Inbound."Entry No.");
        Outbound.Get(Outbound."Entry No.");
        // [THEN] Both ledger deltas and the native application equal the exact fractional quantity.
        Assert.AreEqual(7.5, Inbound."Remaining Quantity", 'Exact inbound delta.');
        Assert.AreEqual(-3.5, Outbound."Remaining Quantity", 'Exact outbound delta.');
        Application.SetRange("Outbound Item Entry No.", Outbound."Entry No.");
        Application.FindFirst();
        Assert.AreEqual(-2.5, Application.Quantity, 'Native application uses base quantity.');
        Request.Replace('quantity', 3.50001);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'BusinessCentralError');
        Outbound.Get(Outbound."Entry No.");
        Assert.AreEqual(-3.5, Outbound."Remaining Quantity", 'Overapplication preserves the ledger.');
        Clear(Request);
        Request.Add('itemLedgerEntryNo', Outbound."Entry No.");
        Request.Add('applyToEntryNo', Inbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertSuccess(Response);
        Outbound.Get(Outbound."Entry No.");
        Assert.AreEqual(0, Outbound."Remaining Quantity", 'Legacy parameters still apply the remaining quantity.');
        Clear(Request);
        Request.Add('itemLedgerEntryNo', Outbound."Entry No.");
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Unapply", Request, LanguageId, Response);
        AssertSuccess(Response);
        Assert.IsTrue(Application.IsEmpty(), 'All linked applications were unapplied atomically.');
    end;

    local procedure VerifySignMismatch(LanguageId: Integer)
    var
        Item: Record Item;
        Inbound: Record "Item Ledger Entry";
        Outbound: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        CreatePair(Item, Inbound, Outbound);
        Request.Add('outboundEntryNo', Inbound."Entry No.");
        Request.Add('inboundEntryNo', Outbound."Entry No.");
        Request.Add('quantity', 1);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'BusinessCentralError');
        Inbound.Get(Inbound."Entry No.");
        Outbound.Get(Outbound."Entry No.");
        Assert.AreEqual(4, Inbound."Remaining Quantity", 'Sign refusal preserves receipt.');
        Assert.AreEqual(0, Outbound."Remaining Quantity", 'Sign refusal preserves issue.');
    end;

    local procedure VerifyInvalidQuantity(LanguageId: Integer)
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Initialize();
        Request.Add('outboundEntryNo', 1);
        Request.Add('inboundEntryNo', 2);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'MissingParameter');
        Request.Add('quantity', 0);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'InvalidParameter');
        Request.Replace('quantity', -1);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'InvalidParameter');
        Request.Replace('quantity', '2.5');
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'InvalidParameterFormat');
        Request.Replace('quantity', 1);
        Request.Add('itemLedgerEntryNo', 1);
        Dispatch("Message Type ori"::"Inventory.ItemApplication.Reapply", Request, LanguageId, Response);
        AssertRefusal(Response, 'InvalidParameter');
    end;

    local procedure Initialize()
    var
        Setup: Record "Inventory Setup ori";
        InventorySetup: Record "Inventory Setup";
        GLSetup: Record "General Ledger Setup";
    begin
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup."Item Application" := true;
        Setup.Modify();
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
    end;

    local procedure CreatePair(var Item: Record Item; var Inbound: Record "Item Ledger Entry"; var Outbound: Record "Item Ledger Entry")
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
    begin
        Initialize();
        LibraryInventory.CreateItem(Item);
        Item.Rename(CopyStr('X40' + Format(CreateGuid(), 0, 4), 1, 20));
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        PostQuantity(Batch, Item."No.", true, 10);
        PostQuantity(Batch, Item."No.", false, 6);
        Inbound.SetRange("Item No.", Item."No.");
        Inbound.SetRange(Positive, true);
        Inbound.FindFirst();
        Outbound.SetRange("Item No.", Item."No.");
        Outbound.SetRange(Positive, false);
        Outbound.FindFirst();
    end;

    local procedure PostQuantity(Batch: Record "Item Journal Batch"; ItemNo: Code[20]; Positive: Boolean; Quantity: Decimal)
    var
        Line: Record "Item Journal Line";
        EntryType: Enum "Item Ledger Entry Type";
    begin
        EntryType := EntryType::"Negative Adjmt.";
        if Positive then
            EntryType := EntryType::"Positive Adjmt.";
        LibraryInventory.CreateItemJournalLine(Line, Batch."Journal Template Name", Batch.Name, EntryType, ItemNo, Quantity);
        Line.Validate("Posting Date", WorkDate());
        Line.Validate("Unit Amount", 10);
        Line.Modify(true);
        LibraryInventory.PostItemJournalLine(Batch."Journal Template Name", Batch.Name);
    end;

    local procedure Dispatch(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer; var Response: JsonObject)
    var
        PreviousLanguage: Integer;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Commit();
        Clear(Response);
        Helper.ProcessMessage(MessageType, Request, Response);
        GlobalLanguage(PreviousLanguage);
    end;

    local procedure AssertSuccess(Response: JsonObject)
    var
        Token: JsonToken;
    begin
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), Format(Response));
    end;

    local procedure AssertRefusal(Response: JsonObject; ErrorCode: Text)
    var
        Token: JsonToken;
    begin
        Response.Get('status', Token);
        Assert.AreEqual('Error', Token.AsValue().AsText(), Format(Response));
        Response.Get('code', Token);
        Assert.AreEqual(ErrorCode, Token.AsValue().AsText(), Format(Response));
        Assert.IsTrue(Response.Get('nextStep', Token), 'Refusal has recovery guidance.');
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Recovery guidance is not blank.');
    end;

    local procedure EntryCount(Response: JsonObject): Integer
    var
        Token: JsonToken;
    begin
        Response.Get('entries', Token);
        exit(Token.AsArray().Count());
    end;
}
