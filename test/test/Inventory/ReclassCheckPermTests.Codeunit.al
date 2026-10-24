namespace Origo.Bifrost.Inventory.Test;

using Microsoft.Inventory.Journal;
using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Issue 159: Check requires reads only; real posting preview retains the posting gate.</summary>
codeunit 96972 "Reclass Check Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    [Test]
    procedure Scenario_AC03_ReadOnlyCaller_ChecksWithoutPostOrWrite()
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Setup: Record "Inventory Setup ori";
        TempArgument: Record "Message Argument ori" temporary;
        LibraryInventory: Codeunit "Library - Inventory";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        CheckImpl: Codeunit "Reclass Check Impl ori";
        PreviewImpl: Codeunit "Reclass Preview Impl ori";
        PostGate: Codeunit "Inv. Posting Gate ori";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        LineId: Guid;
    begin
        // Story #159 AC03 | Time: none | Risk: discovery and execution require unrelated posting/write access.
        LowerPermissions.AddPermissionSet('BIFROST InvPost ori');
        Setup.InsertIfNotExists();
        Setup.Get();
        Setup.Reclassification := true;
        Setup.Modify(true);
        LibraryInventory.CreateItemJournalTemplateByType(JournalTemplate, JournalTemplate.Type::Transfer);
        LibraryInventory.CreateItemJournalBatch(Batch, JournalTemplate.Name);
        Line.Init();
        Line."Journal Template Name" := JournalTemplate.Name;
        Line."Journal Batch Name" := Batch.Name;
        Line."Line No." := 10000;
        Line."Entry Type" := Line."Entry Type"::Transfer;
        Line.Insert(false);
        LineId := Line.SystemId;
        Request.Add('templateName', JournalTemplate.Name);
        Request.Add('batchName', Batch.Name);
        TempArgument.Init();
        TempArgument.Version := "Message Version ori"::"1.0";
        TempArgument.Insert(true);
        TempArgument.SetRequestJson(Request);
        LowerPermissions.PushPermissionSetWithoutDefaults('BIFROST Read ori');
        LowerPermissions.AddPermissionSet('Inv Reclass Read');
        Assert.IsTrue(Line.ReadPermission(), 'Caller has native journal read permission.');
        Assert.IsFalse(Line.WritePermission(), 'Caller has no native journal write permission.');
        Assert.IsFalse(PostGate.HasPostingPermission(), 'Caller has no posting token.');
        Assert.IsTrue(CheckImpl.IsEnabled(), 'Check discovery permits read-only callers.');
        Assert.IsFalse(PreviewImpl.IsEnabled(), 'Real preview retains the native posting gate.');
        CheckImpl.ExecuteBifrostTask(TempArgument);
        Response := TempArgument.GetResponseJson();
        Response.Get('status', Token);
        Assert.AreEqual('Success', Token.AsValue().AsText(), TempArgument.GetResponseText());
        Response.Get('postedLineCount', Token);
        Assert.AreEqual(1, Token.AsValue().AsInteger(), 'Existing compatibility field counts rather than posts.');
        Assert.IsTrue(Line.GetBySystemId(LineId), 'Read leaves the owned journal intact.');
    end;
}
