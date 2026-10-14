namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Self-posted native application fixtures verify both-side selection, joins, exact filters and read-only behavior.</summary>
codeunit 96982 "Inv Application Read Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";
        NativeRead: Codeunit "Inventory Application Read ori";

    [Test]
    procedure Read_ByItem_DeduplicatesAndJoinsBothSides()
    var
        Item: Record Item;
        Application: Record "Item Application Entry";
        Request: JsonObject;
        Response: JsonObject;
        Row: JsonObject;
        Entries: JsonArray;
        Token: JsonToken;
        Joined: JsonToken;
        EntryNos: List of [Integer];
        Inbound: Integer;
        Outbound: Integer;
        BeforeCount: Integer;
        FoundPair: Boolean;
    begin
        CreateApplication(Item, Inbound, Outbound);
        BeforeCount := Application.Count();
        Request.Add('itemNo', Item."No.");
        Response := Read(Request);
        Response.Get('entries', Token);
        Entries := Token.AsArray();
        Assert.IsTrue(Entries.Count() >= 2, 'Includes the inbound origin and real outbound application.');
        foreach Token in Entries do begin
            Row := Token.AsObject();
            Row.Get('entryNo', Joined);
            Assert.IsFalse(EntryNos.Contains(Joined.AsValue().AsInteger()), 'Both-side query must not duplicate an application.');
            EntryNos.Add(Joined.AsValue().AsInteger());
            Row.Get('outboundItemEntryNo', Joined);
            if Joined.AsValue().AsInteger() = Outbound then begin
                FoundPair := true;
                Row.Get('inboundEntry', Joined);
                Joined.AsObject().Get('entryNo', Token);
                Assert.AreEqual(Inbound, Token.AsValue().AsInteger(), 'Joined actual inbound ledger.');
                Joined.AsObject().Get('itemNo', Token);
                Assert.AreEqual(Item."No.", Token.AsValue().AsText(), 'Joined item.');
                Row.Get('outboundEntry', Joined);
                Joined.AsObject().Get('entryNo', Token);
                Assert.AreEqual(Outbound, Token.AsValue().AsInteger(), 'Joined actual outbound ledger.');
                Joined.AsObject().Get('quantity', Token);
                Assert.AreEqual(-3, Token.AsValue().AsDecimal(), 'Outbound quantity is preserved.');
            end;
        end;
        Assert.IsTrue(FoundPair, 'Application connecting the two entries must be present.');
        Assert.AreEqual(BeforeCount, Application.Count(), 'Read does not change applications.');
    end;

    [Test]
    procedure Read_ByInboundAndOutbound_SelectsConnectedApplication()
    var
        Item: Record Item;
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
    begin
        CreateApplication(Item, Inbound, Outbound);
        Request.Add('itemLedgerEntryNo', Outbound);
        Assert.AreEqual(1, Count(Read(Request)), 'Outbound selection finds its real application.');
        Clear(Request);
        Request.Add('itemLedgerEntryNo', Inbound);
        Assert.IsTrue(Count(Read(Request)) >= 2, 'Inbound selection includes origin and connected outbound.');
        Request.Add('locationCode', 'NO-MATCH');
        Assert.AreEqual(0, Count(Read(Request)), 'Exact location filter restricts selected ledger.');
        Request.Replace('locationCode', '');
        Request.Add('variantCode', 'NO-MATCH');
        Assert.AreEqual(0, Count(Read(Request)), 'Exact variant filter restricts selected ledger.');
    end;

    [Test]
    procedure Read_RefusesAmbiguousMalformedAndUnboundedScope()
    var
        Request: JsonObject;
    begin
        asserterror Read(Request);
        Assert.ExpectedError('exactly one');
        Request.Add('itemNo', 'OWNED');
        Request.Add('itemLedgerEntryNo', 1);
        asserterror Read(Request);
        Assert.ExpectedError('exactly one');
        Request.Remove('itemNo');
        Request.Replace('itemLedgerEntryNo', '1');
        asserterror Read(Request);
        Assert.ExpectedError('itemLedgerEntryNo');
        Request.Replace('itemLedgerEntryNo', 1.5);
        asserterror Read(Request);
        Assert.ExpectedError('itemLedgerEntryNo');
        Request.Remove('itemLedgerEntryNo');
        Request.Add('itemNo', '');
        asserterror Read(Request);
        Assert.ExpectedError('itemNo');
        Request.Replace('itemNo', '123456789012345678901');
        asserterror Read(Request);
        Assert.ExpectedError('itemNo');
    end;

    local procedure Read(Request: JsonObject): JsonObject
    var
        TempArgument: Record "Message Argument ori" temporary;
    begin
        TempArgument.Init();
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        NativeRead.Read(TempArgument);
        exit(TempArgument.GetResponseJson());
    end;

    local procedure Count(Response: JsonObject): Integer
    var
        Token: JsonToken;
    begin
        Response.Get('count', Token);
        exit(Token.AsValue().AsInteger());
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
