namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;

/// <summary>Reads inventory valuation from value entries up to a posting date, as report 1001 does.</summary>
codeunit 10077020 "Valuation Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Reads inventory quantity and expected and actual value at a date.', Comment = 'is-IS=Les birgðamagn og áætlað og raunverulegt virði á tilteknum degi.';
        SelectionLbl: Label 'Returns valuation by item, location and variant with filters and paging.', Comment = 'is-IS=Skilar birgðavirði eftir vöru, birgðageymslu og afbrigði með síum og síðuskiptingu.';
        KeywordsLbl: Label 'inventory valuation, expected cost, actual cost', Comment = 'is-IS=birgðamat, áætlaður kostnaður, raunverulegur kostnaður';
        NotesLbl: Label 'Read only. Like the Inventory Valuation report, sums Value Entry Item Ledger Entry Quantity, Cost Amount (Actual) and Cost Amount (Expected) through asOfDate by Posting Date, not Valuation Date. Costs are in LCY and quantity is in the base unit. Includes adjustments and expected-cost reversals posted by that date; does not run cost adjustment. Filters inventory items using their current Inventory Posting Group. Groups by item, location and variant, including blank codes and zero balances with entries. Items without matching value entries produce no row. Rows sort by item, location, variant; skip/take apply after aggregation. Paging is not a snapshot: postings between calls can change results. Omitted or empty filters select all; use the BC filter consisting of two single quotes to select a blank code. Costing must be enabled and the caller needs Item and Value Entry read permission.', Comment = 'is-IS=Eingöngu lestur. Eins og skýrslan Birgðamat er magn vörufærslu, raunverulegur kostnaður og áætlaður kostnaður lagt saman úr virðisfærslum til og með asOfDate eftir bókunardagsetningu, ekki matsdagsetningu. Kostnaður er í staðbundnum gjaldmiðli og magn í grunneiningu. Leiðréttingar og bakfærslur áætlaðs kostnaðar bókaðar fyrir dagsetninguna eru með; kostnaðarleiðrétting er ekki keyrð. Birgðavörur eru síaðar eftir núverandi birgðabókunarflokki. Hópað er eftir vöru, birgðageymslu og afbrigði, einnig auðum kótum og núllstöðu með færslum. Vörur án samsvarandi virðisfærslna mynda enga línu. Röðun er eftir vöru, birgðageymslu og afbrigði; skip/take gilda eftir samlagningu. Síðuskipting er ekki föst mynd: nýjar bókanir milli kalla geta breytt niðurstöðum. Engin eða auð sía velur allt; notaðu BC-síu með tveimur einföldum gæsalöppum til að velja auðan kóta. Kveikt verður að vera á kostnaðarsviði og notandi þarf lesheimild á vörur og virðisfærslur.';
        InvalidValueErr: Label 'Invalid value for %1.', Comment = '%1 = parameter; is-IS=Ógilt gildi fyrir %1.';
        TextNextStepLbl: Label 'Send the filter as JSON text using valid Business Central filter syntax.', Comment = 'is-IS=Sendu síuna sem JSON-texta með gildri Business Central-síusetningu.';
        PagingNextStepLbl: Label 'Send take as a JSON integer from 1 to 1000 and skip as a JSON integer from 0 to 2147483647.', Comment = 'is-IS=Sendu take sem JSON-heiltölu frá 1 til 1000 og skip sem JSON-heiltölu frá 0 til 2147483647.';
        PermissionErr: Label 'Read permission is required for Item and Value Entry.', Comment = 'is-IS=Lesheimild þarf á vörur og virðisfærslur.';
        PermissionNextStepLbl: Label 'Ask an administrator for read permission on Item and Value Entry.', Comment = 'is-IS=Biddu kerfisstjóra um lesheimild á vörur og virðisfærslur.';
        DomainErr: Label 'The Costing domain is disabled.', Comment = 'is-IS=Slökkt er á kostnaðarsviðinu.';
        DomainNextStepLbl: Label 'Ask an administrator to enable Costing in Inventory Setup.', Comment = 'is-IS=Biddu kerfisstjóra að virkja kostnaðarsviðið í uppsetningu birgða.';
        DateNextStepLbl: Label 'Send asOfDate as a nonzero ISO date in YYYY-MM-DD format.', Comment = 'is-IS=Sendu asOfDate sem ISO-dagsetningu aðra en núlldagsetningu á sniðinu YYYY-MM-DD.';

    /// <summary>Checks the domain and native read permissions for discovery.</summary>
    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        Setup: Record "Inventory Setup ori";
    begin
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::Costing) and Item.ReadPermission() and ValueEntry.ReadPermission());
    end;

    /// <summary>Identifies the item filter table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Describes the message.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies translated discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Describes the grouped selection.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Returns the outbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Executes the licensed read-only valuation message.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        ReadValuation(Argument);
    end;

    /// <summary>Validates the request and returns grouped value-entry totals without persistent writes.</summary>
    internal procedure ReadValuation(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        Setup: Record "Inventory Setup ori";
        TempBuffer: Record "Inventory Valuation Buffer ori" temporary;
        Reader: Codeunit "Request Value Reader ori";
        Request: JsonObject;
        Response: JsonObject;
        Rows: JsonArray;
        Row: JsonObject;
        ItemFilter: Text;
        LocationFilter: Text;
        VariantFilter: Text;
        PostingGroupFilter: Text;
        AsOfDate: Date;
        Take: Integer;
        Skip: Integer;
        Position: Integer;
    begin
        if not Setup.IsDomainEnabled("Inventory Domain ori"::Costing) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainErr, '', '', '', DomainNextStepLbl);
            exit;
        end;
        if not Item.ReadPermission() or not ValueEntry.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextStepLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not Reader.TryReadDate(Argument, Request, 'asOfDate', true, AsOfDate) then
            exit;
        if AsOfDate = 0D then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidValueErr, 'asOfDate'), 'asOfDate', '', '', DateNextStepLbl);
            exit;
        end;
        Take := 100;
        if not ReadPageInteger(Argument, Request, 'take', 1, 1000, Take) or
           not ReadPageInteger(Argument, Request, 'skip', 0, 2147483647, Skip) or
           not ReadFilter(Argument, Request, 'itemFilter', ItemFilter) or
           not ReadFilter(Argument, Request, 'locationFilter', LocationFilter) or
           not ReadFilter(Argument, Request, 'variantFilter', VariantFilter) or
           not ReadFilter(Argument, Request, 'inventoryPostingGroupFilter', PostingGroupFilter)
        then
            exit;
        if not TryCollect(ItemFilter, LocationFilter, VariantFilter, PostingGroupFilter, AsOfDate, TempBuffer) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', TextNextStepLbl);
            exit;
        end;
        Position := 0;
        if TempBuffer.FindSet() then
            repeat
                if (Position >= Skip) and (Rows.Count() < Take) then begin
                    Clear(Row);
                    Row.Add('itemNo', TempBuffer."Item No.");
                    Row.Add('locationCode', TempBuffer."Location Code");
                    Row.Add('variantCode', TempBuffer."Variant Code");
                    Row.Add('quantity', TempBuffer.Quantity);
                    Row.Add('actualCost', TempBuffer."Actual Cost");
                    Row.Add('expectedCost', TempBuffer."Expected Cost");
                    Row.Add('totalCost', TempBuffer."Actual Cost" + TempBuffer."Expected Cost");
                    Rows.Add(Row);
                end;
                Position += 1;
            until TempBuffer.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('asOfDate', Format(AsOfDate, 0, 9));
        Response.Add('take', Take);
        Response.Add('skip', Skip);
        Response.Add('totalCount', TempBuffer.Count());
        Response.Add('hasMore', (TempBuffer.Count() - Skip) > Rows.Count());
        Response.Add('rows', Rows);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryCollect(ItemFilter: Text; LocationFilter: Text; VariantFilter: Text; PostingGroupFilter: Text; AsOfDate: Date; var TempBuffer: Record "Inventory Valuation Buffer ori" temporary)
    var
        Item: Record Item;
        ValueEntry: Record "Value Entry";
    begin
        Item.ReadIsolation := IsolationLevel::ReadCommitted;
        ValueEntry.ReadIsolation := IsolationLevel::ReadCommitted;
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetFilter("No.", ItemFilter);
        Item.SetFilter("Inventory Posting Group", PostingGroupFilter);
        Item.SetLoadFields("No.");
        ValueEntry.SetRange("Posting Date", 0D, AsOfDate);
        ValueEntry.SetFilter("Location Code", LocationFilter);
        ValueEntry.SetFilter("Variant Code", VariantFilter);
        ValueEntry.SetLoadFields("Item No.", "Location Code", "Variant Code", "Item Ledger Entry Quantity", "Cost Amount (Actual)", "Cost Amount (Expected)");
        if Item.FindSet() then
            repeat
                ValueEntry.SetRange("Item No.", Item."No.");
                if ValueEntry.FindSet() then
                    repeat
                        if not TempBuffer.Get(ValueEntry."Item No.", ValueEntry."Location Code", ValueEntry."Variant Code") then begin
                            TempBuffer.Init();
                            TempBuffer."Item No." := ValueEntry."Item No.";
                            TempBuffer."Location Code" := ValueEntry."Location Code";
                            TempBuffer."Variant Code" := ValueEntry."Variant Code";
                            TempBuffer.Insert();
                        end;
                        TempBuffer.Quantity += ValueEntry."Item Ledger Entry Quantity";
                        TempBuffer."Actual Cost" += ValueEntry."Cost Amount (Actual)";
                        TempBuffer."Expected Cost" += ValueEntry."Cost Amount (Expected)";
                        TempBuffer.Modify();
                    until ValueEntry.Next() = 0;
            until Item.Next() = 0;
    end;

    local procedure ReadFilter(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not Serialized.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidValueErr, Name), Name, '', '', TextNextStepLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadPageInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; Minimum: Integer; Maximum: Integer; var Value: Integer): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
        Number: Decimal;
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if Evaluate(Number, Serialized, 9) then
            if (Number >= Minimum) and (Number <= Maximum) then
                if Round(Number, 1) = Number then begin
                    Value := Number;
                    exit(true);
                end;
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidValueErr, Name), Name, '', '', PagingNextStepLbl);
        exit(false);
    end;

    /// <summary>Supplies the envelope contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[]},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Supplies the target contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'Inventory items selected by the optional item filter.', Comment = 'is-IS=Birgðavörur valdar með valfrjálsri vörusíu.';
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.itemFilter', 'filter', TargetLbl));
        exit(true);
    end;

    /// <summary>Supplies the parameters contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Param0Lbl: Label 'Inclusive posting date cutoff, YYYY-MM-DD.', Comment = 'is-IS=Síðasti bókunardagur, að honum meðtöldum, YYYY-MM-DD.';
        Param1Lbl: Label 'Business Central filter on Item No.; omitted means all inventory items.', Comment = 'is-IS=Business Central-sía á vörunúmer; ef sleppt eru allar birgðavörur valdar.';
        Param2Lbl: Label 'Business Central filter on the value entry location code.', Comment = 'is-IS=Business Central-sía á birgðageymslukóta virðisfærslu.';
        Param3Lbl: Label 'Business Central filter on the value entry variant code.', Comment = 'is-IS=Business Central-sía á afbrigðiskóta virðisfærslu.';
        Param4Lbl: Label 'Business Central filter on the current item inventory posting group.', Comment = 'is-IS=Business Central-sía á núverandi birgðabókunarflokk vöru.';
        Param5Lbl: Label 'Number of grouped rows, 1..1000; default 100.', Comment = 'is-IS=Fjöldi samantekinna lína, 1..1000; sjálfgefið 100.';
        Param6Lbl: Label 'Number of grouped rows to skip, 0..2147483647; default 0.', Comment = 'is-IS=Fjöldi samantekinna lína sem sleppt er, 0..2147483647; sjálfgefið 0.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('asOfDate', 'string', true, Param0Lbl));
        Parameters.Add(ContractMgt.Parameter('itemFilter', 'string', false, Param1Lbl));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, Param2Lbl));
        Parameters.Add(ContractMgt.Parameter('variantFilter', 'string', false, Param3Lbl));
        Parameters.Add(ContractMgt.Parameter('inventoryPostingGroupFilter', 'string', false, Param4Lbl));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, Param5Lbl));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, Param6Lbl));
        exit(true);
    end;

    /// <summary>Supplies the response contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ResponseField: JsonObject;
        Fields: JsonArray;
        Children: JsonArray;
        Field0Lbl: Label 'Success when the valuation is read.', Comment = 'is-IS=Success þegar birgðamat hefur verið lesið.';
        Field1Lbl: Label 'Inclusive posting date cutoff.', Comment = 'is-IS=Síðasti bókunardagur, að honum meðtöldum.';
        Field2Lbl: Label 'Requested page size.', Comment = 'is-IS=Umbeðin síðustærð.';
        Field3Lbl: Label 'Number of skipped rows.', Comment = 'is-IS=Fjöldi lína sem sleppt er.';
        Field4Lbl: Label 'Number of groups before paging.', Comment = 'is-IS=Fjöldi hópa fyrir síðuskiptingu.';
        Field5Lbl: Label 'More groups remain after this page.', Comment = 'is-IS=Fleiri hópar eru eftir þessa síðu.';
        Field6Lbl: Label 'Groups ordered by item, location and variant.', Comment = 'is-IS=Hópar raðaðir eftir vöru, birgðageymslu og afbrigði.';
        Child0Lbl: Label 'Item number.', Comment = 'is-IS=Vörunúmer.';
        Child1Lbl: Label 'Location code; may be blank.', Comment = 'is-IS=Birgðageymslukóti; má vera auður.';
        Child2Lbl: Label 'Variant code; may be blank.', Comment = 'is-IS=Afbrigðiskóti; má vera auður.';
        Child3Lbl: Label 'Net item ledger entry quantity in the base unit.', Comment = 'is-IS=Nettómagn vörufærslna í grunneiningu.';
        Child4Lbl: Label 'Sum of actual costs in LCY.', Comment = 'is-IS=Samtala raunverulegs kostnaðar í staðbundnum gjaldmiðli.';
        Child5Lbl: Label 'Net expected costs in LCY, including reversals.', Comment = 'is-IS=Nettóáætlaður kostnaður í staðbundnum gjaldmiðli með bakfærslum.';
        Child6Lbl: Label 'Actual plus expected cost in LCY.', Comment = 'is-IS=Raunverulegur og áætlaður kostnaður í staðbundnum gjaldmiðli.';
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', Field0Lbl));
        Fields.Add(ContractMgt.ResponseField('asOfDate', 'string', Field1Lbl));
        Fields.Add(ContractMgt.ResponseField('take', 'integer', Field2Lbl));
        Fields.Add(ContractMgt.ResponseField('skip', 'integer', Field3Lbl));
        Fields.Add(ContractMgt.ResponseField('totalCount', 'integer', Field4Lbl));
        Fields.Add(ContractMgt.ResponseField('hasMore', 'boolean', Field5Lbl));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', Child0Lbl));
        Children.Add(ContractMgt.ResponseField('locationCode', 'string', Child1Lbl));
        Children.Add(ContractMgt.ResponseField('variantCode', 'string', Child2Lbl));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', Child3Lbl));
        Children.Add(ContractMgt.ResponseField('actualCost', 'decimal', Child4Lbl));
        Children.Add(ContractMgt.ResponseField('expectedCost', 'decimal', Child5Lbl));
        Children.Add(ContractMgt.ResponseField('totalCost', 'decimal', Child6Lbl));
        ResponseField := ContractMgt.ResponseField('rows', 'array', Field6Lbl);
        ResponseField.Add('children', Children);
        Fields.Add(ResponseField);
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the errors contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingLbl: Label 'asOfDate is required.', Comment = 'is-IS=asOfDate er nauðsynlegt.';
        FormatLbl: Label 'The date or a filter has an invalid format.', Comment = 'is-IS=Dagsetning eða sía er á ógildu sniði.';
        InvalidLbl: Label 'Paging is invalid or Costing is disabled.', Comment = 'is-IS=Síðuskipting er ógild eða slökkt er á kostnaðarsviði.';
        FilterLbl: Label 'A native filter cannot be applied.', Comment = 'is-IS=Ekki er hægt að nota innbyggða síu.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingLbl, DateNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatLbl, DateNextStepLbl + ' ' + TextNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidLbl, PagingNextStepLbl + ' ' + DomainNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErr, PermissionNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, FilterLbl, TextNextStepLbl));
        exit(true);
    end;

    /// <summary>Supplies the effect contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ChangesLbl: Label 'None. Reads inventory items and value entries only.', Comment = 'is-IS=Engar. Les aðeins birgðavörur og virðisfærslur.';
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('idempotent', true);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        exit(true);
    end;

    /// <summary>Supplies the metering contract.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the workflow contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RelatedLbl: Label 'Read current item card costs instead of historical ledger valuation.', Comment = 'is-IS=Lesa núverandi kostnað á vöruspjaldi í stað sögulegs birgðamats úr færslum.';
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.Cost.Get', RelatedLbl));
        exit(true);
    end;

    /// <summary>Supplies the examples contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ExampleLbl: Label 'Read inventory valuation for one item at a date.', Comment = 'is-IS=Lesa birgðamat einnar vöru á tilteknum degi.';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(ExampleLbl,
            '{"type":"Inventory.Valuation.Get","data":{"asOfDate":"2026-10-31","itemFilter":"XITEM","take":100,"skip":0}}',
            '{"status":"Success","asOfDate":"2026-10-31","take":100,"skip":0,"totalCount":1,"hasMore":false,"rows":[{"itemNo":"XITEM","locationCode":"","variantCode":"","quantity":10,"actualCost":80,"expectedCost":20,"totalCost":100}]}'));
        exit(true);
    end;

    /// <summary>Supplies the overview contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := DescriptionLbl;
        exit(true);
    end;

    /// <summary>Supplies the notes contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
