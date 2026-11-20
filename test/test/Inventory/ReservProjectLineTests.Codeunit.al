namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Sales.Customer;
using Microsoft.Service.Test;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Native tests for reserving and cancelling with a project planning line as the source (#276).</summary>
codeunit 97902 "Reserv. Project Line Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        DomainSetup: Codeunit "Inventory Test Library ori";
        Assert: Codeunit "Library Assert";
        Helper: Codeunit "Transfer Order Test Helper";

    [Test]
    procedure Scenario_AC01_AC02_PlanningLine_ReservesAndCancelsInBothLanguages()
    var
        Item: Record Item;
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        LanguageId: Integer;
        Languages: List of [Integer];
        EntryNo: Integer;
    begin
        DomainSetup.EnableReservations();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            // [GIVEN] An open project with an item planning line (usage link on) and 10 on hand.
            CreatePlanningLine(Item, Job, JobPlanningLine, 10, 4, true);

            // [WHEN] Reservation.Create reserves 3 for the planning line.
            Clear(Request);
            Clear(Response);
            AddSource(Request, Job."No.", JobPlanningLine."Job Task No.", JobPlanningLine."Line No.");
            Request.Add('quantity', 3);
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", '', Request, LanguageId, Response);

            // [THEN] Success, reserved 3, and the demand side is the planning line.
            AssertStatus(Response, 'Success');
            Assert.IsTrue(Response.Get('entryNo', Token), 'entryNo missing');
            EntryNo := Token.AsValue().AsInteger();
            Assert.IsTrue(Response.Get('quantity', Token), 'quantity missing');
            Assert.AreEqual(3, Token.AsValue().AsDecimal(), 'Reserved quantity');
            ReservationEntry.Reset();
            ReservationEntry.SetRange("Entry No.", EntryNo);
            ReservationEntry.SetRange(Positive, false);
            ReservationEntry.FindFirst();
            Assert.AreEqual(Database::"Job Planning Line", ReservationEntry."Source Type", 'Demand source type');
            Assert.AreEqual(Job."No.", ReservationEntry."Source ID", 'Demand source id');
            Assert.AreEqual(JobPlanningLine."Job Contract Entry No.", ReservationEntry."Source Ref. No.", 'Demand source ref');

            // [WHEN] Reservation.Cancel cancels by the planning line.
            Clear(Request);
            Clear(Response);
            AddSource(Request, Job."No.", JobPlanningLine."Job Task No.", JobPlanningLine."Line No.");
            Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Cancel", '', Request, LanguageId, Response);

            // [THEN] Success and the reservation pair is gone through the native cancel.
            AssertStatus(Response, 'Success');
            Assert.IsTrue(Response.Get('entriesCancelled', Token), 'entriesCancelled missing');
            Assert.AreEqual(1, Token.AsValue().AsInteger(), 'One pair cancelled');
            ReservationEntry.Reset();
            ReservationEntry.SetRange("Entry No.", EntryNo);
            ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
            Assert.IsTrue(ReservationEntry.IsEmpty(), 'The reservation pair is cancelled');
        end;
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Scenario_AC03_InvalidPlanningLines_AreRefusedWithNextStepInBothLanguages()
    var
        Item: Record Item;
        Job: Record Job;
        JobPlanningLine: Record "Job Planning Line";
        ReservationEntry: Record "Reservation Entry";
        Request: JsonObject;
        Response: JsonObject;
        LanguageId: Integer;
        Languages: List of [Integer];
        Variant: Integer;
    begin
        DomainSetup.EnableReservations();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do
            for Variant := 1 to 3 do begin
                // [GIVEN] 1 = usage link off, 2 = a resource line, 3 = a completed project.
                CreatePlanningLine(Item, Job, JobPlanningLine, 10, 4, Variant <> 1);
                if Variant = 2 then begin
                    JobPlanningLine.Validate(Type, JobPlanningLine.Type::Resource);
                    JobPlanningLine.Modify();
                end;
                if Variant = 3 then begin
                    Job.Validate(Status, Job.Status::Completed);
                    Job.Modify();
                end;

                // [WHEN] Reservation.Create is called for the line.
                Clear(Request);
                Clear(Response);
                AddSource(Request, Job."No.", JobPlanningLine."Job Task No.", JobPlanningLine."Line No.");
                Request.Add('quantity', 1);
                Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", '', Request, LanguageId, Response);

                // [THEN] It is refused with a nextStep and nothing is reserved.
                AssertStatus(Response, 'Error');
                AssertNextStep(Response);
                ReservationEntry.Reset();
                ReservationEntry.SetRange("Source Type", Database::"Job Planning Line");
                ReservationEntry.SetRange("Source ID", Job."No.");
                Assert.IsTrue(ReservationEntry.IsEmpty(), 'No reservation entry is written for a refused source');
            end;
    end;

    [Test]
    procedure Scenario_AC03_UnknownPlanningLine_AndMissingTask_AreRefused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        DomainSetup.EnableReservations();
        // [WHEN] The line does not exist.
        AddSource(Request, 'NOJOB', 'T1', 10000);
        Request.Add('quantity', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] A typed refusal with a nextStep.
        AssertStatus(Response, 'Error');
        AssertNextStep(Response);

        // [WHEN] sourceTaskNo is left out.
        Clear(Request);
        Clear(Response);
        Request.Add('sourceType', Database::"Job Planning Line");
        Request.Add('sourceNo', 'NOJOB');
        Request.Add('sourceLineNo', 10000);
        Request.Add('quantity', 1);
        Helper.ProcessMessage("Message Type ori"::"Inventory.Reservation.Create", Request, Response);
        // [THEN] It is refused as a missing parameter.
        AssertStatus(Response, 'Error');
        AssertNextStep(Response);
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;

    local procedure AddSource(var Request: JsonObject; JobNo: Code[20]; TaskNo: Code[20]; LineNo: Integer)
    begin
        Request.Add('sourceType', Database::"Job Planning Line");
        Request.Add('sourceNo', JobNo);
        Request.Add('sourceTaskNo', TaskNo);
        Request.Add('sourceLineNo', LineNo);
    end;

    local procedure CreatePlanningLine(var Item: Record Item; var Job: Record Job; var JobPlanningLine: Record "Job Planning Line"; OnHand: Decimal; LineQuantity: Decimal; UsageLink: Boolean)
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        Customer: Record Customer;
        JobTask: Record "Job Task";
    begin
        Helper.SetupLocationsAndItem(FromLocation, ToLocation, InTransitLocation, Item, OnHand);
        Item.Get(Item."No.");
        Item.Validate(Reserve, Item.Reserve::Optional);
        Item.Modify(true);
        Customer.Init();
        Customer."No." := CopyStr('RPL' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Customer."No."));
        Customer.Insert(true);
        Job.Init();
        Job."No." := CopyStr('RPJ' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(Job."No."));
        Job.Insert(true);
        Job.Validate("Bill-to Customer No.", Customer."No.");
        Job.Validate(Status, Job.Status::Open);
        Job.Modify(true);
        JobTask.Init();
        JobTask."Job No." := Job."No.";
        JobTask."Job Task No." := 'T1';
        JobTask."Job Task Type" := JobTask."Job Task Type"::Posting;
        JobTask.Insert(true);
        JobPlanningLine.Init();
        JobPlanningLine."Job No." := Job."No.";
        JobPlanningLine."Job Task No." := JobTask."Job Task No.";
        JobPlanningLine."Line No." := 10000;
        JobPlanningLine.Validate("Line Type", JobPlanningLine."Line Type"::Budget);
        JobPlanningLine.Insert(true);
        JobPlanningLine.Validate(Type, JobPlanningLine.Type::Item);
        JobPlanningLine.Validate("No.", Item."No.");
        JobPlanningLine.Validate("Location Code", FromLocation.Code);
        JobPlanningLine.Validate(Quantity, LineQuantity);
        JobPlanningLine.Validate("Planning Date", WorkDate());
        JobPlanningLine.Validate("Usage Link", UsageLink);
        JobPlanningLine.Validate(Reserve, JobPlanningLine.Reserve::Optional);
        JobPlanningLine.Modify(true);
        JobPlanningLine.Get(JobPlanningLine."Job No.", JobPlanningLine."Job Task No.", JobPlanningLine."Line No.");
        if JobPlanningLine."Usage Link" <> UsageLink then begin
            JobPlanningLine."Usage Link" := UsageLink;
            JobPlanningLine.Modify();
        end;
    end;

    local procedure AssertStatus(ResponseJson: JsonObject; Expected: Text)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        ResponseJson.WriteTo(Serialized);
        Assert.IsTrue(ResponseJson.Get('status', Token), 'status missing: ' + Serialized);
        Assert.AreEqual(Expected, Token.AsValue().AsText(), Serialized);
    end;

    local procedure AssertNextStep(ResponseJson: JsonObject)
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        ResponseJson.WriteTo(Serialized);
        Assert.IsTrue(ResponseJson.Get('nextStep', Token), 'nextStep missing: ' + Serialized);
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'nextStep must not be empty');
    end;
}
