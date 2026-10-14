namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Manual native concurrency acceptance in an owned container; intentionally outside transaction-isolated unit runs.</summary>
codeunit 96993 "Inv Contention Coordinator"
{
    trigger OnRun()
    begin
        VerifyReservationContention();
        VerifyApplicationContention();
    end;

    var
        Assert: Codeunit "Library Assert";
        LibraryInventory: Codeunit "Library - Inventory";

    local procedure VerifyReservationContention()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        FirstLine: Record "Sales Line";
        SecondLine: Record "Sales Line";
        FirstProbe: Record "Inv Contention Probe";
        SecondProbe: Record "Inv Contention Probe";
        Ledger: Record "Item Ledger Entry";
        Reservation: Record "Reservation Entry";
        LibrarySales: Codeunit "Library - Sales";
        Inbound: Integer;
        RunId: Guid;
    begin
        CreateStock(Item, 2, Inbound);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
        LibrarySales.CreateSalesLine(FirstLine, SalesHeader, FirstLine.Type::Item, Item."No.", 2);
        LibrarySales.CreateSalesLine(SecondLine, SalesHeader, SecondLine.Type::Item, Item."No.", 2);
        RunId := CreateGuid();
        InitProbe(FirstProbe, RunId, Item."No.", Inbound, 0, 2, FirstLine.SystemId);
        InitProbe(SecondProbe, RunId, Item."No.", Inbound, 0, 2, SecondLine.SystemId);
        RunPair(FirstProbe, SecondProbe);
        Ledger.Get(Inbound);
        Ledger.CalcFields("Reserved Quantity");
        Assert.AreEqual(2, Ledger."Reserved Quantity", 'Two sessions cannot reserve the same two units twice.');
        Reservation.SetRange("Item No.", Item."No.");
        Reservation.SetRange("Reservation Status", Reservation."Reservation Status"::Reservation);
        Assert.AreEqual(2, Reservation.Count(), 'Exactly one balanced native reservation pair.');
        CancelSource(FirstLine.SystemId);
        CancelSource(SecondLine.SystemId);
        Ledger.Get(Inbound);
        Ledger.CalcFields("Reserved Quantity");
        Assert.AreEqual(0, Ledger."Reserved Quantity", 'Native cancellation releases all owned reservation quantities.');
        Assert.IsTrue(Reservation.IsEmpty(), 'No owned reservation pair remains.');
        MarkPassed(FirstProbe, SecondProbe);
    end;

    local procedure VerifyApplicationContention()
    var
        Item: Record Item;
        Batch: Record "Item Journal Batch";
        JournalTemplate: Record "Item Journal Template";
        Line: Record "Item Journal Line";
        Ledger: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        FirstProbe: Record "Inv Contention Probe";
        SecondProbe: Record "Inv Contention Probe";
        TempArgument: Record "Message Argument ori" temporary;
        NativeApplication: Codeunit "Inv Application Write ori";
        Request: JsonObject;
        Inbound: Integer;
        Outbound: Integer;
        RunId: Guid;
        EmptySource: Guid;
    begin
        CreateStock(Item, 10, Inbound);
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Negative Adjmt.", Item."No.", 3);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.FindLast();
        Outbound := Ledger."Entry No.";
        Request.Add('itemLedgerEntryNo', Outbound);
        TempArgument.Init();
        TempArgument.Type := "Message Type ori"::"Inventory.ItemApplication.Unapply";
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        NativeApplication.Unapply(TempArgument);
        RunId := CreateGuid();
        InitProbe(FirstProbe, RunId, Item."No.", Inbound, Outbound, 3, EmptySource);
        InitProbe(SecondProbe, RunId, Item."No.", Inbound, Outbound, 3, EmptySource);
        RunPair(FirstProbe, SecondProbe);
        Ledger.Get(Outbound);
        Assert.AreEqual(0, Ledger."Remaining Quantity", 'Exactly three outbound units were applied.');
        Ledger.Get(Inbound);
        Assert.AreEqual(7, Ledger."Remaining Quantity", 'Two sessions cannot consume inbound stock twice.');
        Application.SetRange("Inbound Item Entry No.", Inbound);
        Application.SetRange("Outbound Item Entry No.", Outbound);
        Application.CalcSums(Quantity);
        Assert.AreEqual(-3, Application.Quantity, 'Exactly one native three-unit application remains.');
        MarkPassed(FirstProbe, SecondProbe);
    end;

    local procedure InitProbe(var Probe: Record "Inv Contention Probe"; RunId: Guid; ItemNo: Code[20]; Inbound: Integer; Outbound: Integer; Qty: Decimal; SourceId: Guid)
    begin
        Probe.Init();
        Probe.Id := CreateGuid();
        Probe."Run Id" := RunId;
        Probe."Item No." := ItemNo;
        Probe."Inbound Entry No." := Inbound;
        Probe."Outbound Entry No." := Outbound;
        Probe."Source Id" := SourceId;
        Probe.Quantity := Qty;
        if Outbound <> 0 then
            Probe.Scenario := Probe.Scenario::Application;
        Probe.Insert();
    end;

    local procedure RunPair(var FirstProbe: Record "Inv Contention Probe"; var SecondProbe: Record "Inv Contention Probe")
    var
        FirstSession: Integer;
        SecondSession: Integer;
        Deadline: DateTime;
        ReleaseTime: DateTime;
    begin
        ReleaseTime := CurrentDateTime() + 5000;
        FirstProbe."Release At" := ReleaseTime;
        SecondProbe."Release At" := ReleaseTime;
        FirstProbe.Modify();
        SecondProbe.Modify();
        Commit();
        Assert.IsTrue(StartSession(FirstSession, Codeunit::"Inv Contention Worker", CompanyName(), FirstProbe), 'First real BC session started.');
        Assert.IsTrue(StartSession(SecondSession, Codeunit::"Inv Contention Worker", CompanyName(), SecondProbe), 'Second real BC session started.');
        Deadline := CurrentDateTime() + 60000;
        repeat
            Sleep(250);
            SelectLatestVersion();
            FirstProbe.Get(FirstProbe.Id);
            SecondProbe.Get(SecondProbe.Id);
        until ((FirstProbe.State in [FirstProbe.State::Succeeded, FirstProbe.State::Refused]) and
               (SecondProbe.State in [SecondProbe.State::Succeeded, SecondProbe.State::Refused])) or (CurrentDateTime() >= Deadline);
        Assert.IsTrue(FirstProbe."Session Id" <> SecondProbe."Session Id", 'Actual session IDs must differ.');
        Assert.IsTrue((FirstProbe.State = FirstProbe.State::Succeeded) xor (SecondProbe.State = SecondProbe.State::Succeeded), 'Exactly one independent request succeeds.');
        Assert.IsTrue((FirstProbe.State = FirstProbe.State::Refused) xor (SecondProbe.State = SecondProbe.State::Refused), 'Exactly one actual competing request refuses.');
        if FirstProbe.State = FirstProbe.State::Succeeded then
            AssertOverlap(FirstProbe, SecondProbe)
        else
            AssertOverlap(SecondProbe, FirstProbe);
    end;

    local procedure AssertOverlap(Winner: Record "Inv Contention Probe"; Contender: Record "Inv Contention Probe")
    begin
        Assert.IsTrue(Winner."Hold Started At" <> 0DT, 'Observed actual native insert event.');
        Assert.IsTrue(Winner."Hold Finished At" > Winner."Hold Started At", 'A real transaction was held.');
        Assert.IsTrue(Contender."Started At" < Winner."Hold Finished At", 'Second request began before native transaction release.');
        Assert.IsTrue(Contender."Finished At" >= Winner."Hold Started At", 'Requests actually overlapped the native transaction.');
        Assert.IsTrue((Contender."Error Text" <> '') or (Contender."Response Text" <> '{}'), 'Retain actual native refusal evidence.');
    end;

    local procedure MarkPassed(var FirstProbe: Record "Inv Contention Probe"; var SecondProbe: Record "Inv Contention Probe")
    begin
        FirstProbe."Assertion Passed" := true;
        SecondProbe."Assertion Passed" := true;
        FirstProbe.Modify();
        SecondProbe.Modify();
        Commit();
    end;

    local procedure CancelSource(SourceId: Guid)
    var
        TempArgument: Record "Message Argument ori" temporary;
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
        Source: JsonObject;
        Request: JsonObject;
    begin
        Source.Add('type', 'SalesLine');
        Source.Add('systemId', SourceId);
        Request.Add('source', Source);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        ReservationWrite.SetCancelMode();
        ReservationWrite.Run(TempArgument);
    end;

    local procedure CreateStock(var Item: Record Item; Qty: Decimal; var Inbound: Integer)
    var
        GLSetup: Record "General Ledger Setup";
        InventorySetup: Record "Inventory Setup";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Ledger: Record "Item Ledger Entry";
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
        Item.Rename(CopyStr('XW8' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, MaxStrLen(Item."No.")));
        LibraryInventory.CreateItemJournalTemplate(JournalTemplate);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(Line, JournalTemplate.Name, Batch.Name, Line."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        LibraryInventory.PostItemJournalLine(JournalTemplate.Name, Batch.Name);
        Ledger.SetRange("Item No.", Item."No.");
        Ledger.FindLast();
        Inbound := Ledger."Entry No.";
    end;
}
