namespace Origo.Bifrost.Inventory;

using Microsoft.Pricing.PriceList;
using Origo.Bifrost;

/// <summary>Shared bilingual discovery, contracts and execution boundary for price-list maintenance.</summary>
codeunit 10076983 "Price List Contract ori"
{
    Access = Internal;

    var
        Activating: Boolean;
        SetDescriptionLbl: Label 'Creates or updates a Draft sales or purchase price list and its numbered lines.', Comment = 'is-IS=Stofnar eða uppfærir sölu- eða innkaupaverðlista í Drögum og númeraðar línur hans.';
        ActivateDescriptionLbl: Label 'Verifies a Draft price list, refuses conflicting lines and activates the list.', Comment = 'is-IS=Yfirfer verðlista í Drögum, hafnar línum sem stangast á og virkjar listann.';
        SetKeywordsLbl: Label 'price list, sales prices, purchase prices, discounts', Comment = 'is-IS=verðlisti,söluverð,innkaupaverð,afslættir';
        ActivateKeywordsLbl: Label 'activate price list, verify prices, duplicate prices', Comment = 'is-IS=virkja verðlista,yfirfara verð,tvítekin verð';
        SelectionLbl: Label 'Selects one price list by data.code. Subjects and table views are not supported.', Comment = 'is-IS=Velur einn verðlista með data.code. Subject og töflusýn eru ekki studd.';
        SetNotesLbl: Label 'Send code, priceType (Sales or Purchase), and 1..200 lines. Each line needs a unique positive integer lineNo and productNo. New lines default to Item; assetType also accepts Resource, Resource Group, Item Discount Group or G/L Account. Optional line fields: unitOfMeasureCode, minimumQuantity, unitPrice, lineDiscountPercent, startingDate and endingDate. unitPrice updates Unit Price for Sales and Direct Unit Cost for Purchase. Numbers must be JSON numbers; dates use yyyy-mm-dd. Omitted fields and omitted lines are preserved; no line is deleted. Only Draft lists can be changed; the existing priceType cannot change. New lists default to All Customers or All Vendors; sourceType can instead be Customer or Vendor with sourceNo. Header fields description, currencyCode and dates are optional and native header-default rules apply. Native validation runs for every change. An unknown key, oversized text, duplicate lineNo or invalid scalar is refused. A normal failed native operation rolls back the entire call. With Omit Commit, the caller owns the transaction and must roll it back on an error.', Comment = 'is-IS=Sendu code, priceType (Sales eða Purchase) og 1..200 línur. Hver lína þarf einkvætt jákvætt heiltölugildi lineNo og productNo. Nýjar línur miðast við Item; assetType samþykkir einnig Resource, Resource Group, Item Discount Group eða G/L Account. Valfrjálsir línureitir: unitOfMeasureCode, minimumQuantity, unitPrice, lineDiscountPercent, startingDate og endingDate. unitPrice uppfærir einingarverð fyrir Sales og beinan einingarkostnað fyrir Purchase. Tölur verða að vera JSON-tölur; dagsetningar nota yyyy-mm-dd. Reitir og línur sem er sleppt haldast óbreytt; engri línu er eytt. Aðeins má breyta listum í Drögum; ekki má breyta priceType sem er til. Nýir listar miðast við All Customers eða All Vendors; sourceType getur í staðinn verið Customer eða Vendor með sourceNo. Hausreitirnir description, currencyCode og dagsetningar eru valfrjálsir og hefðbundnar reglur um sjálfgefin hausgildi gilda. Hefðbundin sannprófun keyrir fyrir hverja breytingu. Óþekktum lykli, of löngum texta, tvíteknu lineNo eða ógildu skalgildi er hafnað. Venjuleg mistök í staðlaðri aðgerð bakfæra allt kallið. Með Omit Commit ber kallandi ábyrgð á færslunni og verður að bakfæra hana við villu.';
        ActivateNotesLbl: Label 'Send only code. The list must be Draft and contain at least one line. Native Price List Management verifies all lines and checks duplicate prices inside the list and against other lists before the native status validation activates the header and lines. A conflict answers PreconditionFailed with conflicts[] containing the price-list code and lineNo of each conflicting line. No duplicate is removed or resolved automatically. Activation changes prices used by subsequent price calculations; it does not post or rewrite existing documents. With Omit Commit, the caller owns the transaction and must roll it back on an error.', Comment = 'is-IS=Sendu aðeins code. Listinn verður að vera í Drögum og hafa að minnsta kosti eina línu. Hefðbundin verðlistastjórnun yfirfer allar línur og leitar að tvíteknum verðum innan listans og gagnvart öðrum listum áður en hefðbundin stöðusannprófun virkjar haus og línur. Árekstur svarar PreconditionFailed með conflicts[] sem inniheldur verðlistakóða og lineNo hverrar línu sem stangast á. Engin tvítekning er fjarlægð eða leyst sjálfkrafa. Virkjun breytir verðum sem síðari verðútreikningar nota; hún bókar ekki eða endurskrifar skjöl sem eru til. Með Omit Commit ber kallandi ábyrgð á færslunni og verður að bakfæra hana við villu.';
        CodeParameterLbl: Label 'The price-list code, non-empty text of at most 20 characters.', Comment = 'is-IS=Verðlistakóði sem er ekki tómur og er að hámarki 20 stafir.';
        PriceTypeParameterLbl: Label 'Sales or Purchase. Must match an existing list.', Comment = 'is-IS=Sales eða Purchase. Verður að samsvara lista sem er til.';
        SourceTypeParameterLbl: Label 'All Customers or Customer for Sales; All Vendors or Vendor for Purchase.', Comment = 'is-IS=All Customers eða Customer fyrir Sales; All Vendors eða Vendor fyrir Purchase.';
        SourceNoParameterLbl: Label 'Customer or vendor number for the selected sourceType, at most 20 characters.', Comment = 'is-IS=Viðskiptamanns- eða lánardrottinsnúmer fyrir valið sourceType, að hámarki 20 stafir.';
        DescriptionParameterLbl: Label 'Price-list description, at most 250 characters.', Comment = 'is-IS=Lýsing verðlista, að hámarki 250 stafir.';
        CurrencyParameterLbl: Label 'Native currency code, at most 10 characters; empty means local currency.', Comment = 'is-IS=Hefðbundinn gjaldmiðilskóði, að hámarki 10 stafir; tómt merkir staðbundinn gjaldmiðil.';
        DateParameterLbl: Label 'Default validity date in yyyy-mm-dd format.', Comment = 'is-IS=Sjálfgefin gildisdagsetning á sniðinu yyyy-mm-dd.';
        LineNumberLbl: Label 'Unique positive integer line number within the list. Existing line numbers are updated.', Comment = 'is-IS=Einkvætt jákvætt heiltölulínunúmer innan listans. Línunúmer sem eru til eru uppfærð.';
        ProductNumberLbl: Label 'Native product number, non-empty text of at most 20 characters.', Comment = 'is-IS=Hefðbundið vörunúmer sem er ekki tómt og er að hámarki 20 stafir.';
        AssetTypeLbl: Label 'Item (default for new lines), Resource, Resource Group, Item Discount Group or G/L Account.', Comment = 'is-IS=Item (sjálfgefið fyrir nýjar línur), Resource, Resource Group, Item Discount Group eða G/L Account.';
        UnitLbl: Label 'Native unit of measure code, at most 10 characters.', Comment = 'is-IS=Hefðbundinn mælieiningarkóði, að hámarki 10 stafir.';
        NonnegativeNumberLbl: Label 'Nonnegative JSON number. Omitted values are preserved on an unchanged product.', Comment = 'is-IS=JSON-tala sem er ekki neikvæð. Gildi sem er sleppt haldast ef varan er óbreytt.';
        UnitPriceLbl: Label 'Nonnegative JSON number; Unit Price for Sales, Direct Unit Cost for Purchase.', Comment = 'is-IS=JSON-tala sem er ekki neikvæð; einingarverð fyrir Sales, beinn einingarkostnaður fyrir Purchase.';
        DiscountLbl: Label 'JSON number from 0 through 100 for the line discount percentage.', Comment = 'is-IS=JSON-tala frá 0 til 100 fyrir línuafsláttarprósentu.';
        LinesParameterLbl: Label '1..200 objects: required lineNo (unique positive integer) and productNo (text up to 20 characters); optional assetType, unitOfMeasureCode, minimumQuantity, unitPrice, lineDiscountPercent (0..100), startingDate and endingDate. See notes for native field mapping and defaults.', Comment = 'is-IS=1..200 hlutir: lineNo (einkvætt jákvætt heiltölugildi) og productNo (texti að 20 stöfum) eru nauðsynleg; valfrjálst assetType, unitOfMeasureCode, minimumQuantity, unitPrice, lineDiscountPercent (0..100), startingDate og endingDate. Sjá athugasemdir um vörpun hefðbundinna reita og sjálfgefin gildi.';
        SetChangesLbl: Label 'Creates or updates Draft price-list headers and numbered lines using native validation; does not activate, delete or post.', Comment = 'is-IS=Stofnar eða uppfærir verðlistahausa í Drögum og númeraðar línur með hefðbundinni sannprófun; virkjar ekki, eyðir ekki eða bókar.';
        ActivateChangesLbl: Label 'Activates one verified Draft price list and its lines using native status validation; changes subsequent price calculations without posting or deleting.', Comment = 'is-IS=Virkjar einn yfirfarinn verðlista í Drögum og línur hans með hefðbundinni stöðusannprófun; breytir síðari verðútreikningum án bókunar eða eyðingar.';
        PreconditionsLbl: Label 'The Item Price domain must be enabled. The caller needs write permission on both Price List Header and Price List Line.', Comment = 'is-IS=Kveikt verður að vera á sviðinu Vöruverð. Kallandi þarf skrifheimild á bæði verðlistahausa og verðlistalínur.';
        ErrorWhenLbl: Label 'The request is malformed, the list is missing or not Draft, lines conflict, permissions or the domain prevent the operation, or native validation fails.', Comment = 'is-IS=Beiðnin er ógild, listann vantar eða hann er ekki í Drögum, línur stangast á, heimildir eða sviðið hindra aðgerðina eða hefðbundin sannprófun bregst.';
        ErrorFixLbl: Label 'Use the returned parameter and nextStep to correct the request or review the list on the Price Lists page before retrying.', Comment = 'is-IS=Notaðu færibreytuna og nextStep í svarinu til að leiðrétta beiðnina eða yfirfarðu listann á síðunni Verðlistar áður en reynt er aftur.';
        PermissionErrLbl: Label 'Write permission is required on Price List Header and Price List Line.', Comment = 'is-IS=Skrifheimild þarf á verðlistahausa og verðlistalínur.';
        PermissionNextLbl: Label 'Ask an administrator for the Bifrost Full Access permission set and native permission to maintain price lists.', Comment = 'is-IS=Biddu kerfisstjóra um fullan aðgang Bifröst og hefðbundna heimild til að viðhalda verðlistum.';
        NativeNextLbl: Label 'Correct the native validation error on the Price Lists page or in the request, then retry. A normal failed call rolls back; an Omit Commit caller must roll back its transaction.', Comment = 'is-IS=Leiðréttu hefðbundna sannprófunarvilluna á síðunni Verðlistar eða í beiðninni og reyndu aftur. Venjulegt misheppnað kall bakfærir; kallandi með Omit Commit verður að bakfæra sína færslu.';
        SubjectErrLbl: Label 'Price-list messages select only by data.code.', Comment = 'is-IS=Verðlistaskilaboð velja aðeins með data.code.';
        SubjectNextLbl: Label 'Remove the subject and use data.code for one price list.', Comment = 'is-IS=Fjarlægðu subject og notaðu data.code fyrir einn verðlista.';

    /// <summary>Selects the contract for Set or Activate.</summary>
    procedure Configure(IsActivation: Boolean)
    begin
        Activating := IsActivation;
    end;

    /// <summary>Checks the company domain and both native table permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        Header: Record "Price List Header";
        Line: Record "Price List Line";
        Setup: Record "Inventory Setup ori";
    begin
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::ItemPrice) and Header.WritePermission() and Line.WritePermission());
    end;

    /// <summary>Returns localized discovery text.</summary>
    procedure GetDescription(): Text[250]
    begin
        if Activating then
            exit(ActivateDescriptionLbl);
        exit(SetDescriptionLbl);
    end;

    /// <summary>Returns localized discovery keywords.</summary>
    procedure GetKeywords(): Text
    begin
        if Activating then
            exit(ActivateKeywordsLbl);
        exit(SetKeywordsLbl);
    end;

    /// <summary>Explains the single-list selector.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Declares the supported envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed"},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Declares the only supported target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Target);
        Target.Add(Contract.TargetEntry('data.code', 'string', CodeParameterLbl));
        exit(true);
    end;

    /// <summary>Declares supported request keys.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        LineParameter: JsonObject;
        Children: JsonArray;
    begin
        Clear(Parameters);
        Parameters.Add(Contract.Parameter('code', 'string', true, CodeParameterLbl));
        if not Activating then begin
            Parameters.Add(Contract.Parameter('priceType', 'string', true, PriceTypeParameterLbl));
            Parameters.Add(Contract.Parameter('sourceType', 'string', false, SourceTypeParameterLbl));
            Parameters.Add(Contract.Parameter('sourceNo', 'string', false, SourceNoParameterLbl));
            Parameters.Add(Contract.Parameter('description', 'string', false, DescriptionParameterLbl));
            Parameters.Add(Contract.Parameter('currencyCode', 'string', false, CurrencyParameterLbl));
            Parameters.Add(Contract.Parameter('startingDate', 'string', false, DateParameterLbl));
            Parameters.Add(Contract.Parameter('endingDate', 'string', false, DateParameterLbl));
            Children.Add(Contract.Parameter('lineNo', 'integer', true, LineNumberLbl));
            Children.Add(Contract.Parameter('productNo', 'string', true, ProductNumberLbl));
            Children.Add(Contract.Parameter('assetType', 'string', false, AssetTypeLbl));
            Children.Add(Contract.Parameter('unitOfMeasureCode', 'string', false, UnitLbl));
            Children.Add(Contract.Parameter('minimumQuantity', 'number', false, NonnegativeNumberLbl));
            Children.Add(Contract.Parameter('unitPrice', 'number', false, UnitPriceLbl));
            Children.Add(Contract.Parameter('lineDiscountPercent', 'number', false, DiscountLbl));
            Children.Add(Contract.Parameter('startingDate', 'string', false, DateParameterLbl));
            Children.Add(Contract.Parameter('endingDate', 'string', false, DateParameterLbl));
            LineParameter := Contract.Parameter('lines', 'array', true, LinesParameterLbl);
            LineParameter.Add('children', Children);
            Parameters.Add(LineParameter);
        end;
        exit(true);
    end;

    /// <summary>Declares the stored native result.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(Contract.ResponseField('status', 'string', 'Success'));
        Fields.Add(Contract.ResponseField('priceListCode', 'string', CodeParameterLbl));
        Fields.Add(Contract.ResponseField('priceListStatus', 'string', 'Draft / Active'));
        if Activating then
            Fields.Add(Contract.ResponseField('linesActivated', 'integer', LinesParameterLbl))
        else begin
            Fields.Add(Contract.ResponseField('created', 'boolean', SetDescriptionLbl));
            Fields.Add(Contract.ResponseField('priceType', 'string', PriceTypeParameterLbl));
            Fields.Add(Contract.ResponseField('linesWritten', 'integer', LinesParameterLbl));
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Declares coded refusals and recovery guidance.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ErrorWhenLbl, ErrorFixLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, ErrorWhenLbl, ErrorFixLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ErrorWhenLbl, MissingNextStep()));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, ErrorWhenLbl, ErrorFixLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErrLbl, PermissionNextLbl));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ErrorWhenLbl, NativeNextLbl));
        exit(true);
    end;

    /// <summary>Declares a reversible native price maintenance write.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        if Activating then
            Effect.Add('changes', ActivateChangesLbl)
        else
            Effect.Add('changes', SetChangesLbl);
        Effect.Add('idempotent', not Activating);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        Preconditions.Add(PreconditionsLbl);
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Links the two maintenance steps.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Related);
        Related.Add(Contract.RelatedEntry('Price.List.Set', SetDescriptionLbl));
        Related.Add(Contract.RelatedEntry('Price.List.Activate', ActivateDescriptionLbl));
        exit(true);
    end;

    /// <summary>Declares draft maintenance followed by verification and activation.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Clear(Workflow);
        Steps.Add(Contract.WorkflowStep('Price.List.Set', SetDescriptionLbl));
        Steps.Add(Contract.WorkflowStep('Price.List.Activate', ActivateDescriptionLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides executable request examples.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Examples);
        if Activating then
            Examples.Add(Contract.Example(ActivateDescriptionLbl, '{"type":"Price.List.Activate","data":{"code":"BIFROST-PRICE"}}', '{"status":"Success","priceListCode":"BIFROST-PRICE","priceListStatus":"Active","linesActivated":1}'))
        else
            Examples.Add(Contract.Example(SetDescriptionLbl, '{"type":"Price.List.Set","data":{"code":"BIFROST-PRICE","priceType":"Sales","lines":[{"lineNo":10000,"assetType":"Item","productNo":"1000","unitPrice":25}]}}', '{"status":"Success","priceListCode":"BIFROST-PRICE","created":true,"priceType":"Sales","priceListStatus":"Draft","linesWritten":1}'));
        exit(true);
    end;

    /// <summary>Returns the localized operation overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := GetDescription();
        exit(true);
    end;

    /// <summary>Returns complete localized field mapping and transaction guidance.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        if Activating then
            Notes := ActivateNotesLbl
        else
            Notes := SetNotesLbl;
        exit(true);
    end;

    /// <summary>Checks permissions and licensing, validates inputs, then isolates native writes.</summary>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Setup: Record "Inventory Setup ori";
        Process: Codeunit "Price List Process ori";
    begin
        if not Setup.IsDomainEnabled("Inventory Domain ori"::ItemPrice) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, PreconditionsLbl, '', '', '', PermissionNextLbl);
            exit;
        end;
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErrLbl, '', '', '', PermissionNextLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument.Subject <> '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, SubjectErrLbl, 'subject', '', '', SubjectNextLbl);
            exit;
        end;
        if not Process.ValidateRequest(Argument, Activating) then
            exit;
        if Argument."Omit Commit" then
            Process.Run(Argument)
        else
            if not Process.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', NativeNextLbl);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure MissingNextStep(): Text
    var
        NextLbl: Label 'Create the list with Price.List.Set first.', Comment = 'is-IS=Stofnaðu listann fyrst með Price.List.Set.';
    begin
        exit(NextLbl);
    end;
}
