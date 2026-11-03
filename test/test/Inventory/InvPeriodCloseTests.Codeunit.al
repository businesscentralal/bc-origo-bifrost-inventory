namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>
/// Proves Inventory.Period.Close and Inventory.Period.Reopen write the same period entries as the platform close.
/// </summary>
codeunit 96979 "Inv. Period Close Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        InventoryLibrary: Codeunit "Inventory Test Library ori";

    [Test]
    procedure Close_OpenPeriod_UsesPlatformClose()
    var
        InventoryPeriod: Record "Inventory Period";
        PeriodEntry: Record "Inventory Period Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ResponseText: Text;
    begin
        // [SCENARIO] #159 A close either writes a platform inventory period entry or returns the platform refusal and writes nothing.
        EnablePeriodDomain();
        CreateOpenPeriod(InventoryPeriod);

        RequestJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson := InventoryLibrary.ExecuteType("Message Type ori"::"Inventory.Period.Close", '', RequestJson, true);
        ResponseJson.WriteTo(ResponseText);
        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing. ' + ResponseText);

        PeriodEntry.SetRange("Ending Date", InventoryPeriod."Ending Date");
        PeriodEntry.SetRange("Entry Type", PeriodEntry."Entry Type"::Close);
        InventoryPeriod.Get(InventoryPeriod."Ending Date");
        if StatusToken.AsValue().AsText() = 'Success' then begin
            Assert.IsTrue(InventoryPeriod.Closed, 'A successful platform close sets Closed.');
            Assert.IsFalse(PeriodEntry.IsEmpty(), 'A successful platform close writes a Close inventory period entry.');
        end else begin
            Assert.AreEqual('Error', StatusToken.AsValue().AsText(), 'A refused close is an error. ' + ResponseText);
            Assert.IsTrue(StrPos(ResponseText, 'cannot be closed') > 0, 'The refusal must be the platform close text. ' + ResponseText);
            Assert.IsFalse(InventoryPeriod.Closed, 'A refused close must not set Closed.');
            Assert.IsTrue(PeriodEntry.IsEmpty(), 'A refused close must not write an inventory period entry.');
        end;
    end;

    [Test]
    procedure Close_AlreadyClosed_DoesNotRunPlatformClose()
    var
        InventoryPeriod: Record "Inventory Period";
        PeriodEntry: Record "Inventory Period Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] #159 A period that is already closed is Success and does not write another platform entry.
        EnablePeriodDomain();
        CreateOpenPeriod(InventoryPeriod);
        InventoryPeriod.Closed := true;
        InventoryPeriod.Modify();

        RequestJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson := InventoryLibrary.ExecuteType("Message Type ori"::"Inventory.Period.Close", '', RequestJson, true);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'An already closed period is Success.');
        InventoryPeriod.Get(InventoryPeriod."Ending Date");
        Assert.IsTrue(InventoryPeriod.Closed, 'The period stays closed.');
        PeriodEntry.SetRange("Ending Date", InventoryPeriod."Ending Date");
        Assert.IsTrue(PeriodEntry.IsEmpty(), 'The idempotent close must not write an inventory period entry.');
    end;

    [Test]
    procedure Reopen_ClosedPeriod_WritesReopenEntry()
    var
        InventoryPeriod: Record "Inventory Period";
        PeriodEntry: Record "Inventory Period Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
        ResponseText: Text;
    begin
        // [SCENARIO] #159 Reopen runs the platform codeunit and writes a Re-open inventory period entry.
        EnablePeriodDomain();
        CreateOpenPeriod(InventoryPeriod);
        InventoryPeriod.Closed := true;
        InventoryPeriod.Modify();

        RequestJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson := InventoryLibrary.ExecuteType("Message Type ori"::"Inventory.Period.Reopen", '', RequestJson, true);
        ResponseJson.WriteTo(ResponseText);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing. ' + ResponseText);
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'Platform reopen should succeed. ' + ResponseText);
        InventoryPeriod.Get(InventoryPeriod."Ending Date");
        Assert.IsFalse(InventoryPeriod.Closed, 'The period is open after reopen.');
        PeriodEntry.SetRange("Ending Date", InventoryPeriod."Ending Date");
        PeriodEntry.SetRange("Entry Type", PeriodEntry."Entry Type"::"Re-open");
        Assert.IsFalse(PeriodEntry.IsEmpty(), 'Platform reopen writes a Re-open inventory period entry.');
    end;

    [Test]
    procedure Reopen_AlreadyOpen_DoesNotRunPlatformReopen()
    var
        InventoryPeriod: Record "Inventory Period";
        PeriodEntry: Record "Inventory Period Entry";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        StatusToken: JsonToken;
    begin
        // [SCENARIO] #159 A period that is already open is Success and does not write a platform entry.
        EnablePeriodDomain();
        CreateOpenPeriod(InventoryPeriod);

        RequestJson.Add('endingDate', Format(InventoryPeriod."Ending Date", 0, 9));
        ResponseJson := InventoryLibrary.ExecuteType("Message Type ori"::"Inventory.Period.Reopen", '', RequestJson, true);

        Assert.IsTrue(ResponseJson.Get('status', StatusToken), 'status missing');
        Assert.AreEqual('Success', StatusToken.AsValue().AsText(), 'An already open period is Success.');
        InventoryPeriod.Get(InventoryPeriod."Ending Date");
        Assert.IsFalse(InventoryPeriod.Closed, 'The period stays open.');
        PeriodEntry.SetRange("Ending Date", InventoryPeriod."Ending Date");
        Assert.IsTrue(PeriodEntry.IsEmpty(), 'The idempotent reopen must not write an inventory period entry.');
    end;

    local procedure EnablePeriodDomain()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.InsertIfNotExists();
        Setup."Inventory Period" := true;
        Setup.Modify(true);
    end;

    local procedure CreateOpenPeriod(var InventoryPeriod: Record "Inventory Period")
    var
        Candidate: Date;
    begin
        Candidate := DMY2Date(31, 12, 2090);
        InventoryPeriod.Reset();
        if InventoryPeriod.FindLast() then
            if InventoryPeriod."Ending Date" >= Candidate then
                Candidate := CalcDate('<+1Y>', InventoryPeriod."Ending Date");
        InventoryPeriod.Init();
        InventoryPeriod.Validate("Ending Date", Candidate);
        InventoryPeriod.Insert(true);
    end;
}
