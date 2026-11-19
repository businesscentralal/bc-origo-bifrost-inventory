namespace Origo.Bifrost.Inventory;

using Microsoft.Foundation.Company;
using Microsoft.Inventory.BOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using System.Upgrade;

/// <summary>
/// Reads the Business Central setup and works out which Inventory domains the company can use. Every rule is one
/// filtered IsEmpty check. Suggest Setup only turns switches on, so running it twice gives the same result and an
/// administrator's switch is never turned off.
/// </summary>
codeunit 10076950 "Inventory Suggest Setup ori"
{
    Access = Internal;

    /// <summary>Gives a new company its Inventory Setup row with every domain off. Suggest Setup turns domains on.</summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", OnCompanyInitialize, '', false, false)]
    local procedure CreateSetupOnCompanyInitialize()
    var
        InventorySetup: Record "Inventory Setup ori";
    begin
        if InventorySetup.WritePermission() then
            InventorySetup.InsertIfNotExists();
    end;

    /// <summary>Identifies the one-time install and upgrade Suggest Setup run.</summary>
    procedure GetSuggestSetupTag(): Code[250]
    begin
        exit('Origo.Bifrost.Inventory-SuggestSetup-20261119');
    end;

    /// <summary>
    /// Install and upgrade entry: once per company, behind the upgrade tag, without confirmation, and only when the
    /// company has no Inventory Setup row. An existing row is the administrator's choice and is never changed.
    /// </summary>
    procedure RunOncePerCompany()
    var
        InventorySetup: Record "Inventory Setup ori";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(GetSuggestSetupTag()) then
            exit;
        if not InventorySetup.Get() then begin
            InventorySetup.Init();
            ApplyTo(InventorySetup);
            InventorySetup.Insert(true);
        end;
        UpgradeTag.SetUpgradeTag(GetSuggestSetupTag());
    end;

    /// <summary>Turns on every domain the rules support and returns whether a switch changed. Does not write the row.</summary>
    procedure ApplyTo(var InventorySetup: Record "Inventory Setup ori"): Boolean
    var
        Domain: Enum "Inventory Domain ori";
        Reason: Text;
        Changed: Boolean;
        Ordinal: Integer;
    begin
        foreach Ordinal in Domain.Ordinals() do begin
            Domain := Enum::"Inventory Domain ori".FromInteger(Ordinal);
            if not InventorySetup.IsSwitchOn(Domain) then
                if Evaluate(Domain, Reason) then begin
                    InventorySetup.SetDomainEnabled(Domain, true);
                    Changed := true;
                end;
        end;
        exit(Changed);
    end;

    /// <summary>Builds one proposal line per domain: what Suggest Setup would turn on or leave off, and why.</summary>
    procedure BuildProposal(InventorySetup: Record "Inventory Setup ori"; var WouldChange: Boolean) Proposal: Text
    var
        Domain: Enum "Inventory Domain ori";
        Reason: Text;
        Verdict: Text;
        NewLine: Text[1];
        Ordinal: Integer;
    begin
        NewLine[1] := 10;
        foreach Ordinal in Domain.Ordinals() do begin
            Domain := Enum::"Inventory Domain ori".FromInteger(Ordinal);
            if InventorySetup.IsSwitchOn(Domain) then begin
                Verdict := AlreadyOnLbl;
                Reason := '';
            end else
                if Evaluate(Domain, Reason) then begin
                    Verdict := TurnOnLbl;
                    WouldChange := true;
                end else
                    Verdict := LeaveOffLbl;
            if Proposal <> '' then
                Proposal += NewLine;
            if Reason = '' then
                Proposal += StrSubstNo(LineLbl, Format(Domain), Verdict)
            else
                Proposal += StrSubstNo(LineReasonLbl, Verdict, Reason);
        end;
    end;

    /// <summary>Shows the proposal and applies it only after the administrator confirms. Used by the setup page and the wizard.</summary>
    procedure RunWithConfirmation(var InventorySetup: Record "Inventory Setup ori"): Boolean
    var
        ProposalPage: Page "Inventory Suggest Setup ori";
        Proposal: Text;
        WouldChange: Boolean;
    begin
        InventorySetup.InsertIfNotExists();
        InventorySetup.Get();
        Proposal := BuildProposal(InventorySetup, WouldChange);
        if not WouldChange then begin
            Message(NothingToChangeMsg);
            exit(false);
        end;
        ProposalPage.SetProposal(Proposal);
        if ProposalPage.RunModal() <> Action::OK then
            exit(false);
        ApplyTo(InventorySetup);
        InventorySetup.Modify(true);
        exit(true);
    end;

    /// <summary>Reports whether the rules turn the domain on, with the reason text for the proposal.</summary>
    procedure Evaluate(Domain: Enum "Inventory Domain ori"; var Reason: Text): Boolean
    begin
        case Domain of
            Domain::TransferOrders:
                exit(EvaluateTransfer(Reason));
            Domain::Assembly:
                exit(EvaluateAssembly(Reason));
            Domain::ItemTracking:
                exit(EvaluateTracking(Reason));
            Domain::ItemCharge:
                exit(EvaluateItemCharge(Reason));
            Domain::InventoryPeriod:
                exit(EvaluatePeriod(Reason));
        end;
        exit(EvaluateHasItems(Domain, Reason));
    end;

    local procedure EvaluateTransfer(var Reason: Text): Boolean
    var
        Location: Record Location;
    begin
        Location.SetRange("Use As In-Transit", true);
        if Location.IsEmpty() then begin
            Reason := NoInTransitLbl;
            exit(false);
        end;
        Location.SetRange("Use As In-Transit", false);
        if Location.Count() < 2 then begin
            Reason := FewLocationsLbl;
            exit(false);
        end;
        Reason := TransferOnLbl;
        exit(true);
    end;

    local procedure EvaluateAssembly(var Reason: Text): Boolean
    var
        BOMComponent: Record "BOM Component";
    begin
        BOMComponent.SetRange(Type, BOMComponent.Type::Item);
        if BOMComponent.IsEmpty() then begin
            Reason := NoAssemblyBomLbl;
            exit(false);
        end;
        Reason := AssemblyOnLbl;
        exit(true);
    end;

    local procedure EvaluateTracking(var Reason: Text): Boolean
    var
        Item: Record Item;
    begin
        Item.SetFilter("Item Tracking Code", '<>%1', '');
        if Item.IsEmpty() then begin
            Reason := NoTrackingLbl;
            exit(false);
        end;
        Reason := TrackingOnLbl;
        exit(true);
    end;

    local procedure EvaluateItemCharge(var Reason: Text): Boolean
    var
        ItemCharge: Record "Item Charge";
    begin
        if ItemCharge.IsEmpty() then begin
            Reason := NoItemChargeLbl;
            exit(false);
        end;
        Reason := ItemChargeOnLbl;
        exit(true);
    end;

    local procedure EvaluatePeriod(var Reason: Text): Boolean
    var
        InventoryPeriod: Record "Inventory Period";
    begin
        if InventoryPeriod.IsEmpty() then begin
            Reason := NoPeriodLbl;
            exit(false);
        end;
        Reason := PeriodOnLbl;
        exit(true);
    end;

    local procedure EvaluateHasItems(Domain: Enum "Inventory Domain ori"; var Reason: Text): Boolean
    var
        Item: Record Item;
    begin
        if Item.IsEmpty() then begin
            Reason := StrSubstNo(NoItemsLbl, Format(Domain));
            exit(false);
        end;
        Reason := StrSubstNo(HasItemsLbl, Format(Domain));
        exit(true);
    end;

    var
        AlreadyOnLbl: Label 'already on', Comment = 'is-IS=þegar virkt';
        TurnOnLbl: Label 'turn on', Comment = 'is-IS=virkja';
        LeaveOffLbl: Label 'leave off', Comment = 'is-IS=hafa óvirkt';
        LineLbl: Label '%1: %2', Comment = '%1 = domain, %2 = verdict, is-IS=%1: %2';
        LineReasonLbl: Label '%1 - %2', Comment = '%1 = verdict, %2 = reason that names the domain, is-IS=%1 - %2';
        NothingToChangeMsg: Label 'Suggest Setup would not turn on any domain.', Comment = 'is-IS=Tillaga að uppsetningu myndi ekki virkja nein svið.';
        NoInTransitLbl: Label 'Transfer Orders: no in-transit location (Use As In-Transit) is set up', Comment = 'is-IS=Flutningspantanir: engin flutningsstaðsetning (Nota sem í flutningi) er uppsett';
        FewLocationsLbl: Label 'Transfer Orders: fewer than two other locations are set up', Comment = 'is-IS=Flutningspantanir: færri en tvær aðrar staðsetningar eru uppsettar';
        TransferOnLbl: Label 'Transfer Orders: an in-transit location and at least two other locations are set up', Comment = 'is-IS=Flutningspantanir: flutningsstaðsetning og að minnsta kosti tvær aðrar staðsetningar eru uppsettar';
        NoAssemblyBomLbl: Label 'Assembly: no assembly BOM (BOM Component of type Item) is set up', Comment = 'is-IS=Samsetning: enginn samsetningarlisti (efnislínur af gerðinni Vara) er uppsettur';
        AssemblyOnLbl: Label 'Assembly: an assembly BOM is set up', Comment = 'is-IS=Samsetning: samsetningarlisti er uppsettur';
        NoTrackingLbl: Label 'Item Tracking: no item uses an item tracking code', Comment = 'is-IS=Vörurakning: engin vara notar rakningarkóða';
        TrackingOnLbl: Label 'Item Tracking: an item uses an item tracking code', Comment = 'is-IS=Vörurakning: vara notar rakningarkóða';
        NoItemChargeLbl: Label 'Item Charge: no item charge is set up', Comment = 'is-IS=Kostnaðarauki: enginn kostnaðarauki er uppsettur';
        ItemChargeOnLbl: Label 'Item Charge: an item charge is set up', Comment = 'is-IS=Kostnaðarauki: kostnaðarauki er uppsettur';
        NoPeriodLbl: Label 'Inventory Period: no inventory period is set up', Comment = 'is-IS=Birgðatímabil: ekkert birgðatímabil er uppsett';
        PeriodOnLbl: Label 'Inventory Period: an inventory period is set up', Comment = 'is-IS=Birgðatímabil: birgðatímabil er uppsett';
        NoItemsLbl: Label '%1: the company has no items', Comment = '%1 = domain, is-IS=%1: fyrirtækið á engar vörur';
        HasItemsLbl: Label '%1: the company has items', Comment = '%1 = domain, is-IS=%1: fyrirtækið á vörur';
}
