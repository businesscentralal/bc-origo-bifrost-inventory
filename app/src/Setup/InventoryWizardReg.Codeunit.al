namespace Origo.Bifrost.Inventory;

using System.Environment.Configuration;
using System.Media;

/// <summary>Registers the Inventory guide without changing setup or user permissions.</summary>
codeunit 10076924 "Inventory Wizard Reg. ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", OnRegisterAssistedSetup, '', false, false)]
    local procedure OnRegisterAssistedSetup()
    begin
        Register();
    end;

    /// <summary>Idempotently registers the five-minute Inventory assisted setup.</summary>
    procedure Register()
    var
        GuidedExperience: Codeunit "Guided Experience";
        TitleLbl: Label 'Set up Bifrost Inventory', Comment = 'is-IS=Setja upp Bifröst birgðir';
        ShortTitleLbl: Label 'Bifrost Inventory', Comment = 'is-IS=Bifröst birgðir';
        DescriptionLbl: Label 'Review Inventory operations, outbound HTTP, user access and company domains.', Comment = 'is-IS=Farðu yfir birgðaaðgerðir, útleið HTTP, aðgang notenda og svið fyrirtækisins.';
    begin
        GuidedExperience.InsertAssistedSetup(TitleLbl, ShortTitleLbl, DescriptionLbl, 5,
            ObjectType::Page, Page::"Inventory Setup Wizard ori", Enum::"Assisted Setup Group"::Extensions,
            '', Enum::"Video Category"::Uncategorized, '', false);
    end;
}
