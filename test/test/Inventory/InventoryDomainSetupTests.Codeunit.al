namespace Origo.Bifrost.Inventory.Test;

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
