namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Native posted stock verifies unapply/reapply quantities and adjustment flags without protected-row fixture writes.</summary>
codeunit 96983 "Inv Application Write Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        NativeApplication: Codeunit "Inv Application Write ori";

    [Test]
    procedure Unapply_ReopensNativePairAndMarksAdjustment()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        Request.Add('itemLedgerEntryNo', Outbound);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        NativeApplication.Unapply(TempArgument);
        Ledger.Get(Outbound);
        Assert.AreEqual(-3, Ledger."Remaining Quantity", 'Outbound reopened by native unapply.');
        Assert.IsTrue(Ledger."Applied Entry to Adjust", 'Outbound marked for adjustment.');
        Ledger.Get(Inbound);
        Assert.AreEqual(10, Ledger."Remaining Quantity", 'Inbound quantity restored.');
        Assert.IsTrue(Ledger."Applied Entry to Adjust", 'Inbound marked for adjustment.');
        Application.SetRange("Outbound Item Entry No.", Outbound);
        Assert.IsTrue(Application.IsEmpty(), 'Native application removed through worksheet.');
        AssertNoInteractiveRecoveryMarkers(Inbound, Outbound);
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Repeated unapply refuses empty selection.');
        Assert.ExpectedError('no real application');
    end;

    [Test]
    procedure Reapply_ExplicitPartialBaseQuantity_IsExact()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        UnapplyEntry(Outbound);
        Request.Add('outboundEntryNo', Outbound);
        Request.Add('inboundEntryNo', Inbound);
        Request.Add('quantity', 1.5);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        NativeApplication.Reapply(TempArgument);
        Ledger.Get(Outbound);
        Assert.AreEqual(-1.5, Ledger."Remaining Quantity", 'Partial base quantity only.');
        Assert.IsTrue(Ledger.Open, 'Partial outbound remains open.');
        Ledger.Get(Inbound);
        Assert.AreEqual(8.5, Ledger."Remaining Quantity", 'Native inbound reduced by exactly 1.5.');
        Application.SetRange("Inbound Item Entry No.", Inbound);
        Application.SetRange("Outbound Item Entry No.", Outbound);
        Application.CalcSums(Quantity);
        Assert.AreEqual(-1.5, Application.Quantity, 'Actual native application quantity, not response-only.');
        Item.Get(Item."No.");
        Assert.IsFalse(Item."Cost is Adjusted", 'Adjustment remains required, no Adjust Cost run.');
        AssertNoInteractiveRecoveryMarkers(Inbound, Outbound);
    end;

    [Test]
    procedure Reapply_RejectsWrongSignsAndExcessQuantityWithoutWrites()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
        BeforeCount: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        UnapplyEntry(Outbound);
        Request.Add('outboundEntryNo', Inbound);
        Request.Add('inboundEntryNo', Outbound);
        Request.Add('quantity', 1);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        BeforeCount := Application.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Positive outbound is invalid.');
        Assert.ExpectedError('Positive');
        Request.Replace('outboundEntryNo', Outbound);
        Request.Replace('inboundEntryNo', Inbound);
        Request.Replace('quantity', 4);
        TempArgument.SetRequestJson(Request);
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Cannot exceed outbound base quantity.');
        Assert.ExpectedError('quantity');
        Assert.AreEqual(BeforeCount, Application.Count(), 'No application written by refused operations.');
        Ledger.Get(Outbound);
        Assert.AreEqual(-3, Ledger."Remaining Quantity", 'Outbound remains unchanged.');
    end;

    [Test]
    procedure Unapply_AfterNativeDeleteFailure_RollsBack()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inv Journal Write Observer";
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
        ApplicationNo: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        Application.SetRange("Outbound Item Entry No.", Outbound);
        Application.FindFirst();
        ApplicationNo := Application."Entry No.";
        Observer.SetApplication(ApplicationNo);
        BindSubscription(Observer);
        Request.Add('itemLedgerEntryNo', Outbound);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Actual native application delete must fail.');
        Assert.ExpectedError('Owned native journal insert failure');
        UnbindSubscription(Observer);
        Assert.IsTrue(Application.Get(ApplicationNo), 'Application deletion rolled back.');
        Ledger.Get(Outbound);
        Assert.AreEqual(0, Ledger."Remaining Quantity", 'Outbound reopen rolled back.');
        Ledger.Get(Inbound);
        Assert.AreEqual(7, Ledger."Remaining Quantity", 'Inbound reopen rolled back.');
    end;

    [Test]
    procedure Reapply_LegacySelectorsRetainFullQuantityDefault()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        UnapplyEntry(Outbound);
        Request.Add('itemLedgerEntryNo', Outbound);
        Request.Add('applyToEntryNo', Inbound);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        NativeApplication.Reapply(TempArgument);
        Ledger.Get(Outbound);
        Assert.AreEqual(0, Ledger."Remaining Quantity", 'Legacy selectors retain full available quantity behavior.');
        Assert.IsFalse(Ledger.Open, 'Legacy reapply closes the native outbound.');
    end;

    [Test]
    procedure Reapply_AfterNativeInsertFailure_RollsBack()
    var
        Item: Record Item;
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        TempArgument: Record "Message Argument ori" temporary;
        Observer: Codeunit "Inv Journal Write Observer";
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
        BeforeCount: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        UnapplyEntry(Outbound);
        Observer.SetApplicationOutbound(Outbound);
        BindSubscription(Observer);
        Request.Add('outboundEntryNo', Outbound);
        Request.Add('inboundEntryNo', Inbound);
        Request.Add('quantity', 1);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        BeforeCount := Application.Count();
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Actual native insertion failure must roll back.');
        Assert.ExpectedError('Owned native journal insert failure');
        UnbindSubscription(Observer);
        Assert.AreEqual(BeforeCount, Application.Count(), 'Native application insertion rolled back.');
        Ledger.Get(Outbound);
        Assert.AreEqual(-3, Ledger."Remaining Quantity", 'Outbound quantity unchanged after failed reapply.');
        Ledger.Get(Inbound);
        Assert.AreEqual(10, Ledger."Remaining Quantity", 'Inbound quantity unchanged after failed reapply.');
    end;

    [Test]
    procedure Reapply_RejectsMissingStringZeroAndMixedParameters()
    var
        Item: Record Item;
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        UnapplyEntry(Outbound);
        Request.Add('outboundEntryNo', Outbound);
        Request.Add('inboundEntryNo', Inbound);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Reapply");
        Commit();
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'New contract requires quantity.');
        Assert.ExpectedError('quantity');
        Request.Add('quantity', '1');
        TempArgument.SetRequestJson(Request);
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'String quantity is not a JSON number.');
        Assert.ExpectedError('quantity');
        Request.Replace('quantity', 0);
        TempArgument.SetRequestJson(Request);
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Zero quantity is refused.');
        Assert.ExpectedError('quantity');
        Request.Replace('quantity', 1);
        Request.Add('itemLedgerEntryNo', Outbound);
        TempArgument.SetRequestJson(Request);
        Assert.IsFalse(Codeunit.Run(Codeunit::"Inv Application Process ori", TempArgument), 'Ambiguous aliases are refused.');
        Assert.ExpectedError('outboundEntryNo');
    end;

    local procedure AssertNoInteractiveRecoveryMarkers(Inbound: Integer; Outbound: Integer)
    var
        History: Record "Item Application Entry History";
    begin
        History.SetRange("Entry No.", 0);
        History.SetFilter("Item Ledger Entry No.", '%1|%2', Inbound, Outbound);
        Assert.IsTrue(History.IsEmpty(), 'A completed API operation must not be restored as an abandoned interactive worksheet.');
    end;

    local procedure UnapplyEntry(Outbound: Integer)
    var
        TempArgument: Record "Message Argument ori" temporary;
        Request: JsonObject;
    begin
        Request.Add('itemLedgerEntryNo', Outbound);
        InitArgument(TempArgument, Request, "Message Type ori"::"Inventory.ItemApplication.Unapply");
        NativeApplication.Unapply(TempArgument);
    end;

    local procedure InitArgument(var TempArgument: Record "Message Argument ori" temporary; Request: JsonObject; MessageType: Enum "Message Type ori")
    begin
        TempArgument.Init();
        TempArgument.Type := MessageType;
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
    end;

    local procedure CreateApplication(var Item: Record Item; var Inbound: Integer; var Outbound: Integer)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Ledger: Record "Item Ledger Entry";
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
    begin
        GLSetup.Get();
        GLSetup."Journal Templ. Name Mandatory" := false;
        GLSetup."Allow Posting From" := 0D;
        GLSetup."Allow Posting To" := 0D;
        GLSetup.Modify();
        InventorySetup.Get();
        InventorySetup."Automatic Cost Posting" := false;
        InventorySetup."Automatic Cost Adjustment" := InventorySetup."Automatic Cost Adjustment"::Never;
        InventorySetup.Modify();
        LibraryInventory.CreateItem(Item);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", 10);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.FindLast();
        Inbound := Ledger."Entry No.";
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Negative Adjmt.", Item."No.", 3);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
        Ledger.FindLast();
        Outbound := Ledger."Entry No.";
    end;
}
