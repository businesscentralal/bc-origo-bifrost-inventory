namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>Reads direct substitutions and current on-hand inventory without changing native records.</summary>
codeunit 10077020 "Item Subst. Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingLbl: Label 'itemNo is required.', Comment = 'is-IS=itemNo er nauðsynlegt.';
        MissingNextLbl: Label 'Send the source item number in data.itemNo.', Comment = 'is-IS=Sendu vörunúmer upprunavörunnar í data.itemNo.';
        FormatLbl: Label '%1 must be JSON text.', Comment = '%1 = parameter; is-IS=%1 verður að vera JSON-texti.';
        FormatNextLbl: Label 'Send itemNo and variantCode as text, not null, numbers, arrays or objects.', Comment = 'is-IS=Sendu itemNo og variantCode sem texta, ekki null, tölur, fylki eða hluti.';
        LengthLbl: Label '%1 exceeds %2 characters.', Comment = '%1 = parameter, %2 = maximum length; is-IS=%1 er lengra en %2 stafir.';
        LengthNextLbl: Label 'Use at most 20 characters for itemNo and 10 for variantCode.', Comment = 'is-IS=Notaðu mest 20 stafi fyrir itemNo og 10 fyrir variantCode.';
        UnknownLbl: Label 'The request contains an unknown parameter.', Comment = 'is-IS=Beiðnin inniheldur óþekkta færibreytu.';
        UnknownNextLbl: Label 'Send only itemNo and optional variantCode under data.', Comment = 'is-IS=Sendu aðeins itemNo og valkvætt variantCode undir data.';
        NotFoundLbl: Label 'The item or variant does not exist.', Comment = 'is-IS=Varan eða afbrigðið er ekki til.';
        NotFoundNextLbl: Label 'Check the source and substitute item numbers and variants in Business Central.', Comment = 'is-IS=Athugaðu vörunúmer og afbrigði upprunavörunnar og staðgengilsins í Business Central.';
        PermissionLbl: Label 'Read permission is required for inventory setup, substitutions, items, variants and item ledger entries.', Comment = 'is-IS=Lesheimild þarf fyrir uppsetningu birgða, vöruskipti, vörur, afbrigði og vörufærslur.';
        PermissionNextLbl: Label 'Ask an administrator for BIFROST Read and read permission to the native tables used by this type.', Comment = 'is-IS=Biddu stjórnanda um BIFROST Read og lesheimild að stöðluðu töflunum sem þessi tegund notar.';
        DisabledLbl: Label 'The Item Substitution domain is disabled.', Comment = 'is-IS=Slökkt er á vöruskiptasviðinu.';
        DisabledNextLbl: Label 'Ask an administrator to enable Item Substitution on Inventory Setup.', Comment = 'is-IS=Biddu stjórnanda að virkja Vöruskipti í Uppsetningu birgða.';

    /// <summary>Checks company setup and all native read permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        Setup: Record "Inventory Setup ori";
    begin
        if not CanReadTables() then
            exit(false);
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::ItemSubstitution));
    end;

    /// <summary>Returns the native substitution table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Substitution");
    end;

    /// <summary>Returns the localized discovery description.</summary>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Reads direct item substitutes and their current on-hand inventory.', Comment = 'is-IS=Les beina staðgengla vöru og núverandi birgðir þeirra.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns localized search terms.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'item substitution, substitute, variant, inventory', Comment = 'is-IS=vöruskipti, staðgengill, afbrigði, birgðir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized picker text.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        SubjectLbl: Label 'Send the item in data.itemNo; subject is not used.', Comment = 'is-IS=Sendu vöruna í data.itemNo; subject er ekki notað.';
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', SubjectLbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the source item selector.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', MissingNextLbl));
        exit(true);
    end;

    /// <summary>Documents every request key and its limits.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ItemLbl: Label 'Existing source item number, at most 20 characters.', Comment = 'is-IS=Vörunúmer fyrirliggjandi upprunavöru, mest 20 stafir.';
        VariantLbl: Label 'Source variant code, at most 10 characters. Omitted or empty selects only substitutions for the blank variant.', Comment = 'is-IS=Afbrigðiskóði upprunavöru, mest 10 stafir. Ef honum er sleppt eða hann er tómur eru aðeins valin vöruskipti fyrir tómt afbrigði.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, ItemLbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, VariantLbl));
        exit(true);
    end;

    /// <summary>Documents the result and each substitute row.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        Children: JsonArray;
        Substitutes: JsonObject;
        StatusLbl: Label 'Success; refusals use the standard error envelope.', Comment = 'is-IS=Success; höfnun notar staðlað villusvar.';
        ItemLbl: Label 'Source item number.', Comment = 'is-IS=Vörunúmer upprunavöru.';
        VariantLbl: Label 'Exact source variant code, including blank.', Comment = 'is-IS=Nákvæmur afbrigðiskóði upprunavöru, þar með talið tómt gildi.';
        RowsLbl: Label 'Direct substitution records; an empty array is a successful result.', Comment = 'is-IS=Beinar vöruskiptafærslur; tómt fylki er árangursrík niðurstaða.';
        TypeLbl: Label 'item or nonstockItem, independent of the session language.', Comment = 'is-IS=item eða nonstockItem, óháð tungumáli setunnar.';
        NoLbl: Label 'Substitute item number or catalog entry number.', Comment = 'is-IS=Vörunúmer staðgengils eða færslunúmer vörulista.';
        SubVariantLbl: Label 'Substitute variant code.', Comment = 'is-IS=Afbrigðiskóði staðgengils.';
        DescriptionLbl: Label 'Description stored on the substitution.', Comment = 'is-IS=Lýsing vistuð á vöruskiptunum.';
        InterchangeableLbl: Label 'Native interchangeable flag; no reverse relationships are inferred.', Comment = 'is-IS=Staðlað merki um gagnkvæm vöruskipti; öfug tengsl eru ekki ályktuð.';
        InventoryLbl: Label 'Current on-hand quantity in base units for the exact substitute variant across all locations. Zero for catalog items; not a promise or a deduction of reservations.', Comment = 'is-IS=Núverandi birgðamagn í grunneiningum fyrir nákvæmt afbrigði staðgengils á öllum birgðastöðum. Núll fyrir vörulistavörur; ekki loforð um afhendingu og frátektir eru ekki dregnar frá.';
        KnownLbl: Label 'True for an item with calculated inventory; false for a catalog substitute.', Comment = 'is-IS=True fyrir vöru með reiknaðar birgðir; false fyrir staðgengil úr vörulista.';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', ItemLbl));
        Fields.Add(ContractMgt.ResponseField('variantCode', 'string', VariantLbl));
        Children.Add(ContractMgt.ResponseField('substituteType', 'string', TypeLbl));
        Children.Add(ContractMgt.ResponseField('substituteNo', 'string', NoLbl));
        Children.Add(ContractMgt.ResponseField('substituteVariantCode', 'string', SubVariantLbl));
        Children.Add(ContractMgt.ResponseField('description', 'string', DescriptionLbl));
        Children.Add(ContractMgt.ResponseField('interchangeable', 'boolean', InterchangeableLbl));
        Children.Add(ContractMgt.ResponseField('inventory', 'number', InventoryLbl));
        Children.Add(ContractMgt.ResponseField('inventoryKnown', 'boolean', KnownLbl));
        Substitutes := ContractMgt.ResponseField('substitutes', 'array', RowsLbl);
        Substitutes.Add('children', Children);
        Fields.Add(Substitutes);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Documents coded refusals and their next steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatNextLbl, FormatNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, LengthNextLbl, LengthNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, DisabledLbl, DisabledNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownLbl, UnknownNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, NotFoundNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, PermissionNextLbl));
        exit(true);
    end;

    /// <summary>Declares the real read-only effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ChangesLbl: Label 'Reads substitutions and inventory; does not update cached quantities or create items.', Comment = 'is-IS=Les vöruskipti og birgðir; uppfærir ekki vistuð magn eða stofnar vörur.';
    begin
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('idempotent', true);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        exit(true);
    end;

    /// <summary>No separate metering contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>No workflow contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Links to period availability for planning.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        RelatedLbl: Label 'Read availability over periods for an item.', Comment = 'is-IS=Lesa framboð vöru eftir tímabilum.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.AvailabilityByPeriod.Get', RelatedLbl));
        exit(true);
    end;

    /// <summary>Shows a complete illustrative request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Read substitutes for an item without a variant', Comment = 'is-IS=Lesa staðgengla vöru án afbrigðis';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemSubstitution.Get","data":{"itemNo":"1000"}}', '{"status":"Success","itemNo":"1000","variantCode":"","substitutes":[{"substituteType":"item","substituteNo":"1001","substituteVariantCode":"","description":"Substitute","interchangeable":false,"inventory":5,"inventoryKnown":true}]}'));
        exit(true);
    end;

    /// <summary>Returns the localized overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Explains exact variants, catalog items and availability limitations.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Reads direct table 5715 rows for the item and exact source variant, including blank. Inventory is current on-hand quantity in base units for the exact substitute variant across all locations, not promised availability; reservations and future supply are not included. Catalog substitutes have inventoryKnown=false and inventory=0. No recursive search, cached inventory update or item creation occurs. A valid item with no substitutions returns an empty array.', Comment = 'is-IS=Les beinar færslur í töflu 5715 fyrir vöruna og nákvæmt afbrigði upprunavöru, þar með talið tómt gildi. Inventory er núverandi birgðamagn í grunneiningum fyrir nákvæmt afbrigði staðgengils á öllum birgðastöðum, ekki lofað framboð; frátektir og væntanleg aðföng eru ekki innifalin. Staðgenglar úr vörulista hafa inventoryKnown=false og inventory=0. Engin endurkvæm leit, uppfærsla vistaðra birgða eða vörustofnun á sér stað. Gild vara án vöruskipta skilar tómu fylki.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Returns the outbound read direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and reads native substitutions.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Setup: Record "Inventory Setup ori";
        Request: JsonObject;
        Token: JsonToken;
        KeyName: Text;
        ItemText: Text;
        VariantText: Text;
        ItemNo: Code[20];
        VariantCode: Code[10];
    begin
        if not CanReadTables() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, 'permissionSet', '', 'BIFROST Read ori', PermissionNextLbl);
            exit;
        end;
        if not Setup.IsDomainEnabled("Inventory Domain ori"::ItemSubstitution) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DisabledLbl, 'domain', '', '', DisabledNextLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not (KeyName in ['itemNo', 'variantCode']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownLbl, CopyStr(KeyName, 1, 250), '', 'itemNo, variantCode', UnknownNextLbl);
                exit;
            end;
        if Request.Get('itemNo', Token) then
            if not ReadText(Argument, Token, 'itemNo', 20, ItemText) then
                exit;
        if Request.Get('variantCode', Token) then
            if not ReadText(Argument, Token, 'variantCode', 10, VariantText) then
                exit;
        ItemNo := CopyStr(ItemText, 1, MaxStrLen(ItemNo));
        VariantCode := CopyStr(VariantText, 1, MaxStrLen(VariantCode));
        if ItemNo = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingLbl, 'itemNo', '', '', MissingNextLbl);
            exit;
        end;
        if not CheckItemVariant(Argument, ItemNo, VariantCode) then
            exit;
        ReadSubstitutes(Argument, ItemNo, VariantCode);
    end;

    local procedure CanReadTables(): Boolean
    var
        Setup: Record "Inventory Setup ori";
        Item: Record Item;
        Variant: Record "Item Variant";
        Substitution: Record "Item Substitution";
        Ledger: Record "Item Ledger Entry";
    begin
        exit(Setup.ReadPermission() and Item.ReadPermission() and Variant.ReadPermission() and Substitution.ReadPermission() and Ledger.ReadPermission());
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Token: JsonToken; Name: Text; MaxLength: Integer; var Value: Text): Boolean
    var
        Raw: Text;
    begin
        Clear(Value);
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name, CopyStr(Raw, 1, 250), 'string', FormatNextLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if StrLen(Value) > MaxLength then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(LengthLbl, Name, MaxLength), Name, CopyStr(Value, 1, 250), '', LengthNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure CheckItemVariant(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; VariantCode: Code[10]): Boolean
    var
        Item: Record Item;
        Variant: Record "Item Variant";
    begin
        Item.ReadIsolation := IsolationLevel::ReadCommitted;
        Variant.ReadIsolation := IsolationLevel::ReadCommitted;
        if not Item.Get(ItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'itemNo', ItemNo, '', NotFoundNextLbl);
            exit(false);
        end;
        if VariantCode <> '' then
            if not Variant.Get(ItemNo, VariantCode) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'variantCode', VariantCode, '', NotFoundNextLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadSubstitutes(var Argument: Record "Message Argument ori"; ItemNo: Code[20]; VariantCode: Code[10])
    var
        Substitution: Record "Item Substitution";
        Substitute: Record Item;
        Rows: JsonArray;
        Row: JsonObject;
        Response: JsonObject;
    begin
        Substitution.ReadIsolation := IsolationLevel::ReadCommitted;
        Substitution.SetRange(Type, Substitution.Type::Item);
        Substitution.SetRange("No.", ItemNo);
        Substitution.SetRange("Variant Code", VariantCode);
        Substitute.ReadIsolation := IsolationLevel::ReadCommitted;
        Substitute.SetAutoCalcFields(Inventory);
        if Substitution.FindSet() then
            repeat
                Clear(Row);
                Row.Add('substituteNo', Substitution."Substitute No.");
                Row.Add('substituteVariantCode', Substitution."Substitute Variant Code");
                Row.Add('description', Substitution.Description);
                Row.Add('interchangeable', Substitution.Interchangeable);
                Row.Add('inventoryKnown', Substitution."Substitute Type" = Substitution."Substitute Type"::Item);
                if Substitution."Substitute Type" = Substitution."Substitute Type"::Item then begin
                    if not CheckItemVariant(Argument, Substitution."Substitute No.", Substitution."Substitute Variant Code") then
                        exit;
                    Substitute.SetRange("Variant Filter", Substitution."Substitute Variant Code");
                    Substitute.Get(Substitution."Substitute No.");
                    Row.Add('substituteType', 'item');
                    Row.Add('inventory', Substitute.Inventory);
                end else begin
                    Row.Add('substituteType', 'nonstockItem');
                    Row.Add('inventory', 0);
                end;
                Rows.Add(Row);
            until Substitution.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('itemNo', ItemNo);
        Response.Add('variantCode', VariantCode);
        Response.Add('substitutes', Rows);
        Argument.SetResponseJson(Response);
    end;
}
