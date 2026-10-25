namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;

using System.TestLibraries.Utilities;

/// <summary>
/// Catalogue quality guard (inventory#152): every Inventory message type must describe itself in translatable text.
/// The description, selection description and keywords are read through the catalogue interfaces in 1033 and 1039:
/// they must be non-empty, must differ between the languages (Icelandic is present), and a text that the compiler
/// marks as Locked cannot be translated, so a Locked catalogue label fails here.
/// </summary>
codeunit 96971 "Inv. Catalogue Quality Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Every Inventory type has a description, selection description and keywords, translated at 1039.</summary>
    [Test]
    procedure EveryType_CatalogueTextsTranslatableAt1039()
    var
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        OriginalLanguage: Integer;
        TypeName: Text;
        EnglishDescription: Text;
        EnglishSelection: Text;
        EnglishKeywords: Text;
        TypeCount: Integer;
        CheckCount: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Implementation := MessageType;
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishDescription := Implementation.GetDescription();
            EnglishSelection := Discovery.GetSelectionDescription();
            EnglishKeywords := Discovery.GetKeywords();
            GlobalLanguage(1039);
            Assert.AreNotEqual('', EnglishDescription, TypeName + ' has a description at 1033.');
            Assert.AreNotEqual('', EnglishSelection, TypeName + ' has a selection description at 1033.');
            Assert.AreNotEqual('', EnglishKeywords, TypeName + ' has keywords at 1033.');
            Assert.AreNotEqual('', Implementation.GetDescription(), TypeName + ' has a description at 1039.');
            Assert.AreNotEqual('', Discovery.GetSelectionDescription(), TypeName + ' has a selection description at 1039.');
            Assert.AreNotEqual('', Discovery.GetKeywords(), TypeName + ' has keywords at 1039.');
            Assert.AreNotEqual(EnglishDescription, Implementation.GetDescription(), TypeName + ' description at 1039 differs from 1033.');
            Assert.AreNotEqual(EnglishSelection, Discovery.GetSelectionDescription(), TypeName + ' selection description at 1039 differs from 1033.');
            Assert.AreNotEqual(EnglishKeywords, Discovery.GetKeywords(), TypeName + ' keywords at 1039 differ from 1033.');
            GlobalLanguage(OriginalLanguage);
            TypeCount += 1;
            CheckCount += 9;
        end;
        GlobalLanguage(OriginalLanguage);
        Assert.IsTrue(TypeCount >= 59, 'Every Inventory type is checked (' + Format(TypeCount) + ').');
        Assert.IsTrue(CheckCount >= 531, 'All catalogue texts of every type are checked in both languages.');
    end;

    /// <summary>The Icelandic catalogue texts are real translations, not a second copy of the English text.</summary>
    [Test]
    procedure EveryType_CatalogueTextsAreNotCopyPasted()
    var
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        OriginalLanguage: Integer;
        TypeName: Text;
        EnglishDescription: Text;
        EnglishSelection: Text;
        EnglishKeywords: Text;
        TypeCount: Integer;
    begin
        OriginalLanguage := GlobalLanguage();
        foreach MessageType in InventoryTypes() do begin
            TypeName := TypeNameOf(MessageType);
            Implementation := MessageType;
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishDescription := Implementation.GetDescription();
            EnglishSelection := Discovery.GetSelectionDescription();
            EnglishKeywords := Discovery.GetKeywords();
            GlobalLanguage(1039);
            Assert.AreNotEqual(EnglishDescription, Implementation.GetDescription(), TypeName + ' description at 1039 differs from 1033.');
            Assert.AreNotEqual(EnglishSelection, Discovery.GetSelectionDescription(), TypeName + ' selection description at 1039 differs from 1033.');
            Assert.AreNotEqual(EnglishKeywords, Discovery.GetKeywords(), TypeName + ' keywords at 1039 differ from 1033.');
            GlobalLanguage(OriginalLanguage);
            TypeCount += 1;
        end;
        GlobalLanguage(OriginalLanguage);
        Assert.IsTrue(TypeCount >= 59, 'Every Inventory type is checked (' + Format(TypeCount) + ').');
    end;

    /// <summary>Every message type of this app: its implementation id is its enum value inside the app object range.</summary>
    local procedure InventoryTypes() Types: List of [Enum "Message Type ori"]
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := Enum::"Message Type ori".Names();
        Ordinals := Enum::"Message Type ori".Ordinals();
        for Index := 1 to Names.Count() do
            if (Ordinals.Get(Index) >= AppRangeFrom()) and (Ordinals.Get(Index) <= AppRangeTo()) then
                Types.Add(Enum::"Message Type ori".FromInteger(Ordinals.Get(Index)));
    end;

    local procedure AppRangeFrom(): Integer
    begin
        exit(10076835);
    end;

    local procedure AppRangeTo(): Integer
    begin
        exit(10077034);
    end;

    local procedure TypeNameOf(MessageType: Enum "Message Type ori"): Text
    begin
        exit(Enum::"Message Type ori".Names().Get(Enum::"Message Type ori".Ordinals().IndexOf(MessageType.AsInteger())));
    end;
}
