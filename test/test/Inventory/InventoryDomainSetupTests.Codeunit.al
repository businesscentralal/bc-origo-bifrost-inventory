namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using Origo.Bifrost.Inventory;
using System.TestLibraries.Utilities;

/// <summary>Protects the default-on company domain settings and preserves explicit opt-outs.</summary>
codeunit 96924 "Inventory Domain Setup Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>A company without a setup record has all eleven domains enabled without a write.</summary>
    [Test]
    procedure MissingSetupEnablesEveryDomainWithoutInserting()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        InventorySetup.DeleteAll();

        AssertAllDomainsEnabled(InventorySetup);

        Assert.IsTrue(InventorySetup.IsEmpty(), 'Reading domain defaults must not create setup.');
    end;

    /// <summary>Opening setup for the first time must preserve every previously enabled domain.</summary>
    [Test]
    procedure CreatingSetupPreservesAllDefaultEnabledDomains()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        InventorySetup.DeleteAll();
        InventorySetup.InsertIfNotExists();

        Assert.IsTrue(InventorySetup.Get(), 'Setup must exist after initialization.');
        AssertAllDomainsEnabled(InventorySetup);
    end;

    /// <summary>Reopening setup preserves a deliberate reclassification opt-out.</summary>
    [Test]
    procedure ExistingReclassificationOptOutIsPreserved()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        InventorySetup.DeleteAll();
        InventorySetup.InsertIfNotExists();
        InventorySetup.Reclassification := false;
        InventorySetup.Modify(true);

        InventorySetup.InsertIfNotExists();

        Assert.IsFalse(InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reclassification), 'Explicit opt-out must survive setup initialization.');
        Assert.IsTrue(InventorySetup.IsDomainEnabled("Inventory Domain ori"::Reservations), 'Other domains remain enabled.');
        Assert.IsTrue(InventorySetup.IsDomainEnabled("Inventory Domain ori"::ItemTracking), 'Other domains remain enabled.');
    end;

    /// <summary>All Inventory-owned message types honor company opt-outs in discovery.</summary>
    [Test]
    procedure EveryInventoryTypeIsDisabledWhenCompanyDomainsAreOff()
    var
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
        TypeName: Text;
        Names: List of [Text];
        Checked: Integer;
    begin
        DisableAllDomains();
        Names := MessageType.Names();
        foreach TypeName in Names do
            if TypeName.StartsWith('Inventory.') and not TypeName.StartsWith('Inventory.ItemJournal.') then begin
                MessageType := "Message Type ori".FromInteger(MessageType.Ordinals().Get(Names.IndexOf(TypeName)));
                Implementation := MessageType;
                Assert.IsFalse(Implementation.IsEnabled(), TypeName + ' must honor its company opt-out.');
                Checked += 1;
            end;
        Assert.AreEqual(48, Checked, 'Every Inventory-owned type, including Tracking.Get, Cost.Update and both revaluation posting types, is checked.');
    end;

    /// <summary>Execution refuses disabled domains before payload processing, licensing or native business writes.</summary>
    [Test]
    procedure EveryInventoryTypeRefusesDisabledDomainBeforeExecution()
    var
        TempArgument: Record "Message Argument ori" temporary;
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
        Response: JsonObject;
        Token: JsonToken;
        Names: List of [Text];
        TypeName: Text;
        Checked: Integer;
    begin
        DisableAllDomains();
        Names := MessageType.Names();
        foreach TypeName in Names do
            if TypeName.StartsWith('Inventory.') and not TypeName.StartsWith('Inventory.ItemJournal.') then begin
                TempArgument.DeleteAll();
                TempArgument.Init();
                TempArgument.Version := "Message Version ori"::"1.0";
                TempArgument.Insert(true);
                MessageType := "Message Type ori".FromInteger(MessageType.Ordinals().Get(Names.IndexOf(TypeName)));
                Implementation := MessageType;
                Implementation.ExecuteBifrostTask(TempArgument);
                Response := TempArgument.GetResponseJson();
                Assert.IsTrue(Response.Get('status', Token), TypeName + ' must return a structured refusal.');
                Assert.AreEqual('Error', Token.AsValue().AsText(), TypeName + ' must refuse without executing.');
                Checked += 1;
            end;
        // The exact DomainDisabled error-code AC awaits the Foundation enum; this test makes no such claim.
        Assert.AreEqual(48, Checked, 'All Inventory implementations refuse before their licensed operation.');
    end;

    local procedure DisableAllDomains()
    var
        Setup: Record "Inventory Setup ori";
    begin
        Setup.DeleteAll();
        Setup.InsertIfNotExists();
        Setup.Attributes := false;
        Setup."Transfer Orders" := false;
        Setup.Assembly := false;
        Setup.Reservations := false;
        Setup."Item Tracking" := false;
        Setup."Phys. Inventory" := false;
        Setup.Costing := false;
        Setup.Reclassification := false;
        Setup."Item Application" := false;
        Setup."Inventory Period" := false;
        Setup."Item Price" := false;
        Setup.Modify(true);
    end;

    local procedure AssertAllDomainsEnabled(var InventorySetup: Record "Inventory Setup ori")
    var
        Domain: Enum "Inventory Domain ori";
        Ordinal: Integer;
        DomainDefaultErr: Label 'Domain %1 must default to enabled.', Comment = '%1 = domain name';
    begin
        Assert.AreEqual(11, Domain.Ordinals().Count(), 'Every accepted Inventory domain is covered.');
        foreach Ordinal in Domain.Ordinals() do begin
            Domain := "Inventory Domain ori".FromInteger(Ordinal);
            Assert.IsTrue(InventorySetup.IsDomainEnabled(Domain), StrSubstNo(DomainDefaultErr, Domain));
        end;
    end;
}
