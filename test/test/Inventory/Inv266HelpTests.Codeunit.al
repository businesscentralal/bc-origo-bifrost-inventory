namespace Origo.Bifrost.Inventory.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 266: bilingual UAT help corrections without changing request or execution behavior.</summary>
codeunit 97900 "Inv. 266 Help Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>AC01 English discovery distinguishes legacy single-line counts from the counts array.</summary>
    [Test]
    procedure CountDescriptionsEnglish()
    begin
        // Story #266 AC01 | Time: independent | Risk: shared execution hides the counts-only contract.
        AssertCountDescriptions(1033);
    end;

    /// <summary>AC01 Icelandic discovery distinguishes the two count contracts.</summary>
    [Test]
    procedure CountDescriptionsIcelandic()
    begin
        // Story #266 AC01 | Time: independent | Risk: legacy and array descriptions collapse in Icelandic.
        AssertCountDescriptions(1039);
    end;

    /// <summary>AC03 All affected discovery texts are supplied in English.</summary>
    [Test]
    procedure DiscoveryEnglish()
    begin
        // Story #266 AC03 | Time: independent | Risk: discovery returns prose instead of search terms.
        AssertDiscovery(1033);
    end;

    /// <summary>AC03 All affected discovery texts are translated in Icelandic.</summary>
    [Test]
    procedure DiscoveryIcelandic()
    begin
        // Story #266 AC03 | Time: independent | Risk: missing translated discovery falls back to English.
        AssertDiscovery(1039);
    end;

    /// <summary>AC04 The response declares its processed-item count and empty-on-success error array in both locales.</summary>
    [Test]
    procedure AdjustCostResponseFields()
    var
        Contract: Interface "Msg Contract ori";
        Response: JsonObject;
        Token: JsonToken;
        Fields: JsonArray;
        SavedLanguage: Integer;
        LanguageId: Integer;
    begin
        // Story #266 AC04 | Time: independent | Risk: real response fields disappear from help.
        SavedLanguage := GlobalLanguage();
        Contract := "Message Type ori"::"Inventory.AdjustCost.Run";
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            Assert.IsTrue(Contract.GetResponse(Response), 'Response is declared.');
            Response.Get('fields', Token);
            Fields := Token.AsArray();
            AssertField(Fields, 'itemsProcessed', 'integer', 'scope of the run');
            AssertField(Fields, 'errors', 'array', 'Always empty on Success');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC05 Help declares itemFilter and an exact-item example, without advertising itemNo as input.</summary>
    [Test]
    procedure ValuationSelectorBothLanguages()
    var
        Contract: Interface "Msg Contract ori";
        Parameters: JsonArray;
        Token: JsonToken;
        Parameter: JsonObject;
        Notes: Text;
        FoundItemFilter: Boolean;
        SavedLanguage: Integer;
        LanguageId: Integer;
    begin
        // Story #266 AC05 | Time: independent | Risk: a response field is silently used as an unfiltered request.
        SavedLanguage := GlobalLanguage();
        Contract := "Message Type ori"::"Inventory.Valuation.Get";
        foreach LanguageId in Languages() do begin
            GlobalLanguage(LanguageId);
            FoundItemFilter := false;
            Assert.IsTrue(Contract.GetParameters(Parameters), 'Parameters are declared.');
            foreach Token in Parameters do begin
                Parameter := Token.AsObject();
                Assert.AreNotEqual('itemNo', TextOf(Parameter, 'name'), 'itemNo is not advertised as input.');
                if TextOf(Parameter, 'name') = 'itemFilter' then begin
                    FoundItemFilter := true;
                    Assert.IsTrue(TextOf(Parameter, 'description').Contains('{"itemFilter":"XITEM"}'), 'Exact-item example uses the declared key.');
                end;
            end;
            Assert.IsTrue(FoundItemFilter, 'itemFilter is declared.');
            Assert.IsTrue(Contract.GetNotes(Notes), 'Notes are supplied.');
            Assert.IsTrue(Notes.Contains('itemFilter'), 'Notes name the correct selector.');
            Assert.IsTrue(Notes.Contains('itemNo'), 'Notes explain the response-field distinction.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertCountDescriptions(LanguageId: Integer)
    var
        Legacy: Interface "Msg Interface ori";
        Count: Interface "Msg Interface ori";
        SavedLanguage: Integer;
        LegacyDescription: Text;
        CountDescription: Text;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Legacy := "Message Type ori"::"Inventory.PhysInventory.Record";
        Count := "Message Type ori"::"Inventory.PhysInventory.RecordCount";
        LegacyDescription := Legacy.GetDescription();
        CountDescription := Count.GetDescription();
        Assert.AreNotEqual(LegacyDescription, CountDescription, 'The two types have distinct descriptions.');
        Assert.IsTrue(LegacyDescription.Contains('lineNo'), 'Legacy description explains its single-line form.');
        Assert.IsTrue(CountDescription.Contains('counts'), 'RecordCount description explains its counts array.');
        Assert.IsFalse(CountDescription.Contains('lineNo'), 'RecordCount does not advertise legacy input.');
        Assert.AreEqual(Legacy.GetFilterTableNo(), Count.GetFilterTableNo(), 'The selection table is unchanged.');
        Assert.AreEqual(Legacy.GetMessageDirection(), Count.GetMessageDirection(), 'The direction is unchanged.');
        Assert.AreEqual(Legacy.IsEnabled(), Count.IsEnabled(), 'The domain and permission gates are unchanged.');
        if LanguageId = 1039 then begin
            Assert.IsTrue(LegacyDescription.StartsWith('Skráir'), 'Legacy description is Icelandic.');
            Assert.IsTrue(CountDescription.StartsWith('Skráir'), 'RecordCount description is Icelandic.');
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertDiscovery(LanguageId: Integer)
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        SavedLanguage: Integer;
        EnglishSelection: Text;
        EnglishKeywords: Text;
        Selection: Text;
        Keywords: Text;
    begin
        SavedLanguage := GlobalLanguage();
        foreach MessageType in DiscoveryTypes() do begin
            Discovery := MessageType;
            GlobalLanguage(1033);
            EnglishSelection := Discovery.GetSelectionDescription();
            EnglishKeywords := Discovery.GetKeywords();
            GlobalLanguage(LanguageId);
            Selection := Discovery.GetSelectionDescription();
            Keywords := Discovery.GetKeywords();
            Assert.AreNotEqual('', Selection, 'Selection text is supplied.');
            Assert.AreNotEqual('', Keywords, 'Keywords are supplied.');
            Assert.IsTrue(Keywords.Contains(','), 'Keywords are a comma-separated term list.');
            if LanguageId = 1039 then begin
                Assert.AreNotEqual(EnglishSelection, Selection, 'Selection text is translated.');
                Assert.AreNotEqual(EnglishKeywords, Keywords, 'Keywords are translated.');
            end;
            if MessageType in ["Message Type ori"::"Inventory.PhysInventoryOrder.Create", "Message Type ori"::"Inventory.PhysInventoryOrder.Finish", "Message Type ori"::"Inventory.PhysInventoryOrder.Post"] then begin
                Assert.IsFalse(Keywords.Contains('.'), 'Order keywords contain no description sentences.');
                Assert.IsFalse(Keywords.Contains('expectedCount'), 'Order keywords contain no confirmation prose.');
            end;
        end;
        GlobalLanguage(SavedLanguage);
    end;

    local procedure AssertField(Fields: JsonArray; FieldName: Text; FieldType: Text; DescriptionPart: Text)
    var
        Token: JsonToken;
        Field: JsonObject;
        Found: Boolean;
    begin
        foreach Token in Fields do begin
            Field := Token.AsObject();
            if TextOf(Field, 'name') = FieldName then begin
                Found := true;
                Assert.AreEqual(FieldType, TextOf(Field, 'type'), 'Response field has its existing wire type.');
                Assert.IsTrue(TextOf(Field, 'description').Contains(DescriptionPart), 'Response field explains its actual semantics.');
            end;
        end;
        Assert.IsTrue(Found, 'The response field is declared: ' + FieldName);
    end;

    local procedure TextOf(Value: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Value.Get(KeyName, Token), 'Contract key exists: ' + KeyName);
        exit(Token.AsValue().AsText());
    end;

    local procedure Languages() Result: List of [Integer]
    begin
        Result.Add(1033);
        Result.Add(1039);
    end;

    local procedure DiscoveryTypes() Result: List of [Enum "Message Type ori"]
    begin
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Create");
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Finish");
        Result.Add("Message Type ori"::"Inventory.PhysInventoryOrder.Post");
        Result.Add("Message Type ori"::"Inventory.StandardCost.Suggest");
        Result.Add("Message Type ori"::"Inventory.StandardCost.Implement");
        Result.Add("Message Type ori"::"Inventory.Tracking.Assign");
        Result.Add("Message Type ori"::"Inventory.Tracking.Delete");
    end;
}
