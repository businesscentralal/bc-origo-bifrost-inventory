namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Origo.Bifrost;

/// <summary>Reads the standard item availability event timeline without changing supply or demand.</summary>
codeunit 10076940 "Avail. By Event Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        MissingErr: Label 'A required parameter is missing.', Comment = 'is-IS=Nauðsynlega færibreytu vantar.';
        FormatErr: Label 'The parameter has an invalid format.', Comment = 'is-IS=Færibreytan er á ógildu sniði.';
        InputNextStepLbl: Label 'Send itemNo as text and from and to as YYYY-MM-DD dates. Optional variant and location must be exact codes.', Comment = 'is-IS=Sendu itemNo sem texta og from og to sem dagsetningar á forminu YYYY-MM-DD. Valfrjálsu færibreyturnar variant og location verða að vera nákvæmir kóðar.';
        NotFoundErr: Label 'The item, variant or location does not exist.', Comment = 'is-IS=Varan, afbrigðið eða staðsetningin er ekki til.';
        NotFoundNextStepLbl: Label 'Check itemNo and any variant or location code, then retry with an existing record.', Comment = 'is-IS=Athugaðu itemNo og afbrigðis- eða staðsetningarkóða og reyndu aftur með færslu sem er til.';
        RangeErr: Label 'from must be on or before to.', Comment = 'is-IS=from verður að vera á undan eða sama dag og to.';
        RangeNextStepLbl: Label 'Send an inclusive date range with from on or before to.', Comment = 'is-IS=Sendu dagsetningabil með báðum endadögum þar sem from er á undan eða sama dag og to.';
        DomainErr: Label 'The Availability domain is disabled.', Comment = 'is-IS=Slökkt er á framboðssviðinu.';
        DomainNextStepLbl: Label 'Ask an administrator to enable Availability in Inventory Setup.', Comment = 'is-IS=Biddu stjórnanda um að virkja framboð í birgðauppsetningu.';
        PermissionErr: Label 'Read permission is required.', Comment = 'is-IS=Lesheimild er nauðsynleg.';
        PermissionNextStepLbl: Label 'Ask an administrator for Bifrost Read-Only and Business Central inventory read permissions.', Comment = 'is-IS=Biddu stjórnanda um lesaðgang í Bifröst og lesheimildir á birgðum í Business Central.';
        StockErr: Label 'Availability requires an inventory item.', Comment = 'is-IS=Framboð krefst birgðavöru.';
        StockNextStepLbl: Label 'Use an item whose type is Inventory.', Comment = 'is-IS=Notaðu vöru af gerðinni Birgðir.';
        CalculationErr: Label 'Business Central could not calculate the event timeline.', Comment = 'is-IS=Business Central gat ekki reiknað tímalínu atburða.';
        CalculationNextStepLbl: Label 'Check this item in Item Availability by Event and resolve its source data or read permissions, then retry.', Comment = 'is-IS=Athugaðu vöruna í Framboð vöru eftir atburði og leiðréttu upprunagögn eða lesheimildir og reyndu aftur.';

    /// <summary>Checks the company domain and caller read permissions.</summary>
    procedure IsEnabled(): Boolean
    var
        Setup: Record "Inventory Setup ori";
    begin
        if not CanRead() then
            exit(false);
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::Availability));
    end;

    /// <summary>Returns the item table used for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Declares the outbound message direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>Supplies localized GetDescription help.</summary>
    procedure GetDescription(): Text[250]
    var
        HelpLbl: Label 'Reads dated supply and demand events and projected inventory for one item.', Comment = 'is-IS=Les dagsetta framboðs- og eftirspurnaratburði og áætlaðar birgðir fyrir eina vöru.';
    begin
        exit(HelpLbl);
    end;

    /// <summary>Supplies localized GetKeywords help.</summary>
    procedure GetKeywords(): Text
    var
        HelpLbl: Label 'availability, event, supply, demand, projected inventory', Comment = 'is-IS=framboð, atburður, aðföng, eftirspurn, áætlaðar birgðir';
    begin
        exit(HelpLbl);
    end;

    /// <summary>Supplies localized GetSelectionDescription help.</summary>
    procedure GetSelectionDescription(): Text
    var
        HelpLbl: Label 'Use this timeline to see which source documents change item availability in a date range.', Comment = 'is-IS=Notaðu tímalínuna til að sjá hvaða upprunaskjöl breyta framboði vöru á dagsetningabili.';
    begin
        exit(HelpLbl);
    end;

    /// <summary>Supplies localized GetOverview help.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        HelpLbl: Label 'Reads the same supply and demand calculation as Item Availability by Event, including the running projected inventory. It does not change business records.', Comment = 'is-IS=Les sama framboðs- og eftirspurnarreikning og Framboð vöru eftir atburði, þar á meðal hlaupandi áætlaðar birgðir. Breytir ekki viðskiptafærslum.';
    begin
        Overview := HelpLbl;
        exit(true);
    end;

    /// <summary>Supplies localized GetNotes help.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        HelpLbl: Label 'Dates are inclusive. Opening inventory includes current stock and events before from. Events are ordered by date, with supply before demand on the same date, as on the standard page. Quantities use the base unit; projected inventory follows the standard reservation calculation. Only sources accessible to the caller are included. Drop shipments, blanket orders, forecasts and planning suggestions are excluded. Omitted or empty variant and location include all codes. An empty range returns an empty events array and the opening inventory.', Comment = 'is-IS=Báðir endadagar teljast með. Upphafsbirgðir innihalda núverandi birgðir og atburði fyrir from. Atburðir raðast eftir dagsetningu, með framboð á undan eftirspurn sama dag, eins og á stöðluðu síðunni. Magn er í grunneiningu; áætlaðar birgðir fylgja stöðluðum frátektarreikningi. Aðeins upprunagögn sem kallandi hefur aðgang að eru tekin með. Beinar sendingar, rammapantanir, spár og áætlunartillögur eru undanskildar. Ef variant eða location vantar eða er tómt eru allir kóðar teknir með. Tómt bil skilar tómu events fylki og upphafsbirgðum.';
    begin
        Notes := HelpLbl;
        exit(true);
    end;

    /// <summary>Declares the data-based request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Use data.itemNo."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    /// <summary>Identifies the item being read.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemLbl: Label 'The item number.', Comment = 'is-IS=Vörunúmerið.';
    begin
        Clear(Target);
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', ItemLbl));
        exit(true);
    end;

    /// <summary>Lists the supported item selectors and date range.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter0Lbl: Label 'Existing inventory item number.', Comment = 'is-IS=Númer birgðavöru sem er til.';
        Parameter1Lbl: Label 'Exact variant code; omit to include all variants.', Comment = 'is-IS=Nákvæmur afbrigðiskóði; slepptu til að taka öll afbrigði með.';
        Parameter2Lbl: Label 'Exact location code; omit to include all locations.', Comment = 'is-IS=Nákvæmur staðsetningarkóði; slepptu til að taka allar staðsetningar með.';
        Parameter3Lbl: Label 'First event date, YYYY-MM-DD, inclusive.', Comment = 'is-IS=Fyrsti atburðadagur, YYYY-MM-DD, meðtalinn.';
        Parameter4Lbl: Label 'Last event date, YYYY-MM-DD, inclusive.', Comment = 'is-IS=Síðasti atburðadagur, YYYY-MM-DD, meðtalinn.';
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, Parameter0Lbl));
        Parameters.Add(ContractMgt.Parameter('variant', 'string', false, Parameter1Lbl));
        Parameters.Add(ContractMgt.Parameter('location', 'string', false, Parameter2Lbl));
        Parameters.Add(ContractMgt.Parameter('from', 'string', true, Parameter3Lbl));
        Parameters.Add(ContractMgt.Parameter('to', 'string', true, Parameter4Lbl));
        exit(true);
    end;

    /// <summary>Describes the timeline response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        Events: JsonObject;
        EventsLbl: Label 'Supply and demand events in the requested date range.', Comment = 'is-IS=Framboðs- og eftirspurnaratburðir á umbeðnu dagsetningabili.';
        Field0Lbl: Label 'Success.', Comment = 'is-IS=Tókst.';
        Field1Lbl: Label 'The item number.', Comment = 'is-IS=Vörunúmerið.';
        Field2Lbl: Label 'Projected inventory before the first returned event.', Comment = 'is-IS=Áætlaðar birgðir fyrir fyrsta skilaða atburðinn.';
        Field3Lbl: Label 'Event date, YYYY-MM-DD.', Comment = 'is-IS=Dagsetning atburðar, YYYY-MM-DD.';
        Field4Lbl: Label 'Standard event type name.', Comment = 'is-IS=Heiti staðlaðrar atburðagerðar.';
        Field5Lbl: Label 'Source document number.', Comment = 'is-IS=Númer upprunaskjals.';
        Field6Lbl: Label 'Signed remaining quantity in base units.', Comment = 'is-IS=Eftirstöðvar með formerki í grunneiningum.';
        Field7Lbl: Label 'Standard running projected inventory after this event.', Comment = 'is-IS=Staðlaðar hlaupandi áætlaðar birgðir eftir þennan atburð.';
        Field8Lbl: Label 'Event variant code.', Comment = 'is-IS=Afbrigðiskóði atburðar.';
        Field9Lbl: Label 'Event location code.', Comment = 'is-IS=Staðsetningarkóði atburðar.';
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', Field0Lbl));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', Field1Lbl));
        Fields.Add(ContractMgt.ResponseField('openingInventory', 'decimal', Field2Lbl));
        Children.Add(ContractMgt.ResponseField('date', 'string', Field3Lbl));
        Children.Add(ContractMgt.ResponseField('type', 'string', Field4Lbl));
        Children.Add(ContractMgt.ResponseField('sourceDocument', 'string', Field5Lbl));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', Field6Lbl));
        Children.Add(ContractMgt.ResponseField('projectedInventory', 'decimal', Field7Lbl));
        Children.Add(ContractMgt.ResponseField('variant', 'string', Field8Lbl));
        Children.Add(ContractMgt.ResponseField('location', 'string', Field9Lbl));
        Events := ContractMgt.ResponseField('events', 'array', EventsLbl);
        Events.Add('children', Children);
        Fields.Add(Events);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Lists coded refusals and recovery actions.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        UnknownLbl: Label 'An unsupported parameter was supplied.', Comment = 'is-IS=Óstudd færibreyta var send.';
        UnknownNextStepLbl: Label 'Remove unknown keys; use only itemNo, variant, location, from and to.', Comment = 'is-IS=Fjarlægðu óþekkta lykla; notaðu aðeins itemNo, variant, location, from og to.';
        InvalidLbl: Label 'The date range is reversed or Availability is disabled.', Comment = 'is-IS=Dagsetningabilið er öfugt eða slökkt er á framboði.';
        InvalidNextStepLbl: Label 'Use from on or before to and enable Availability in Inventory Setup.', Comment = 'is-IS=Notaðu from á undan eða sama dag og to og virkjaðu framboð í birgðauppsetningu.';
        PreconditionLbl: Label 'The item is not an inventory item or its standard calculation failed.', Comment = 'is-IS=Varan er ekki birgðavara eða staðlaður reikningur hennar mistókst.';
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingErr, InputNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, InputNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownLbl, UnknownNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, NotFoundNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidLbl, InvalidNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErr, PermissionNextStepLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, PreconditionLbl, CalculationNextStepLbl));
        exit(true);
    end;

    /// <summary>Declares the real read-only effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ChangesLbl: Label 'None. Reads item availability using temporary calculation buffers.', Comment = 'is-IS=Engar. Les framboð vöru með tímabundnum reiknibiðminnum.';
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

    /// <summary>Uses Foundation default metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Links to aggregate period availability.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RelatedLbl: Label 'Read aggregate availability by calendar period.', Comment = 'is-IS=Lesa samanlagt framboð eftir dagatalstímabili.';
    begin
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.AvailabilityByPeriod.Get', RelatedLbl));
        exit(true);
    end;

    /// <summary>No multi-step workflow is required for a read.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Shows an empty event timeline.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ExampleLbl: Label 'Read one month of events', Comment = 'is-IS=Lesa atburði eins mánaðar';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(ExampleLbl, '{"type":"Inventory.AvailabilityByEvent.Get","data":{"itemNo":"ITEM","from":"2026-11-01","to":"2026-11-30"}}', '{"status":"Success","itemNo":"ITEM","openingInventory":0,"events":[]}'));
        exit(true);
    end;

    /// <summary>Validates selectors and returns the standard read-only timeline.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Setup: Record "Inventory Setup ori";
        RequestJson: JsonObject;
        Response: JsonObject;
        ItemNo: Text;
        VariantCode: Text;
        LocationCode: Text;
        FromDate: Date;
        ToDate: Date;
    begin
        if not CanRead() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextStepLbl);
            exit;
        end;
        if not Setup.IsDomainEnabled("Inventory Domain ori"::Availability) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, DomainErr, '', '', '', DomainNextStepLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not ValidateKeys(Argument, RequestJson) then
            exit;
        if not ReadText(RequestJson, 'itemNo', Argument, true, ItemNo) then
            exit;
        if not ReadText(RequestJson, 'variant', Argument, false, VariantCode) then
            exit;
        if not ReadText(RequestJson, 'location', Argument, false, LocationCode) then
            exit;
        if not ReadDate(RequestJson, 'from', Argument, FromDate) then
            exit;
        if not ReadDate(RequestJson, 'to', Argument, ToDate) then
            exit;
        if FromDate > ToDate then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, RangeErr, 'from', Format(FromDate, 0, 9), Format(ToDate, 0, 9), RangeNextStepLbl);
            exit;
        end;
        if not LoadItem(Argument, ItemNo, VariantCode, LocationCode, Item) then
            exit;
        ClearLastError();
        if not BuildTimeline(Item, FromDate, ToDate, Response) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, CalculationErr, 'itemNo', ItemNo, '', CalculationNextStepLbl);
            exit;
        end;
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CanRead(): Boolean
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        Location: Record Location;
        Setup: Record "Inventory Setup ori";
    begin
        exit(Setup.ReadPermission() and Item.ReadPermission() and Variant.ReadPermission() and Location.ReadPermission());
    end;

    local procedure ValidateKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownErr: Label 'The parameter is not supported.', Comment = 'is-IS=Færibreytan er ekki studd.';
        NextStepLbl: Label 'Remove unknown keys; use only itemNo, variant, location, from and to.', Comment = 'is-IS=Fjarlægðu óþekkta lykla; notaðu aðeins itemNo, variant, location, from og to.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in ['itemNo', 'variant', 'location', 'from', 'to']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownErr, KeyName, KeyName, '', NextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure ReadText(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; Required: Boolean; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not RequestJson.Get(KeyName, Token) then begin
            if Required then
                Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', 'text', InputNextStepLbl);
            exit(not Required);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Raw, 1, 250), 'text', InputNextStepLbl);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value = '') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', 'nonempty text', InputNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDate(RequestJson: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"; var Value: Date): Boolean
    var
        DateText: Text;
    begin
        if not ReadText(RequestJson, KeyName, Argument, true, DateText) then
            exit(false);
        if Evaluate(Value, DateText, 9) then
            if (Value <> 0D) and (StrLen(DateText) = 10) and (Format(Value, 0, 9) = DateText) then
                exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(DateText, 1, 250), 'YYYY-MM-DD', InputNextStepLbl);
        exit(false);
    end;

    local procedure LoadItem(var Argument: Record "Message Argument ori"; ItemNo: Text; VariantCode: Text; LocationCode: Text; var Item: Record Item): Boolean
    var
        Variant: Record "Item Variant";
        Location: Record Location;
    begin
        if StrLen(ItemNo) > MaxStrLen(Item."No.") then
            exit(RefuseNotFound(Argument, 'itemNo', ItemNo));
        if not Item.Get(CopyStr(ItemNo, 1, MaxStrLen(Item."No."))) then
            exit(RefuseNotFound(Argument, 'itemNo', ItemNo));
        if Item.Type <> Item.Type::Inventory then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StockErr, 'itemNo', ItemNo, 'Inventory', StockNextStepLbl);
            exit(false);
        end;
        if VariantCode <> '' then begin
            if StrLen(VariantCode) > MaxStrLen(Variant.Code) then
                exit(RefuseNotFound(Argument, 'variant', VariantCode));
            if not Variant.Get(Item."No.", CopyStr(VariantCode, 1, MaxStrLen(Variant.Code))) then
                exit(RefuseNotFound(Argument, 'variant', VariantCode));
            Item.SetRange("Variant Filter", Variant.Code);
        end;
        if LocationCode <> '' then begin
            if StrLen(LocationCode) > MaxStrLen(Location.Code) then
                exit(RefuseNotFound(Argument, 'location', LocationCode));
            if not Location.Get(CopyStr(LocationCode, 1, MaxStrLen(Location.Code))) then
                exit(RefuseNotFound(Argument, 'location', LocationCode));
            Item.SetRange("Location Filter", Location.Code);
        end;
        Item.SetRange("Drop Shipment Filter", false);
        exit(true);
    end;

    local procedure RefuseNotFound(var Argument: Record "Message Argument ori"; KeyName: Text; Value: Text): Boolean
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, KeyName, CopyStr(Value, 1, 250), '', NotFoundNextStepLbl);
        exit(false);
    end;

    [TryFunction]
    local procedure BuildTimeline(var Item: Record Item; FromDate: Date; ToDate: Date; var Response: JsonObject)
    var
        TempPageData: Record "Inventory Page Data" temporary;
        CalcInventoryPageData: Codeunit "Calc. Inventory Page Data";
        Events: JsonArray;
        EventJson: JsonObject;
        RunningInventory: Decimal;
        RunningForecast: Decimal;
        RunningSuggestion: Decimal;
        OpeningInventory: Decimal;
    begin
        // Calculate the complete opening balance before selecting the requested dates.
        CalcInventoryPageData.Initialize(Item, '', false, 0D, false);
        CalcInventoryPageData.CreatePeriodEntries(TempPageData, 0);
        TempPageData.SetCurrentKey("Period Start", "Line No.");
        TempPageData.SetRange(Level, 0);
        if TempPageData.FindSet() then
            repeat
                CalcInventoryPageData.DetailsForPeriodEntry(TempPageData, true);
                CalcInventoryPageData.DetailsForPeriodEntry(TempPageData, false);
            until TempPageData.Next() = 0;
        TempPageData.SetRange(Level, 1);
        TempPageData.SetFilter("Period Start", '<=%1', ToDate);
        if TempPageData.FindSet() then
            repeat
                TempPageData.UpdateInventorys(RunningInventory, RunningForecast, RunningSuggestion);
                if TempPageData."Period Start" < FromDate then
                    OpeningInventory := RunningInventory
                else begin
                    Clear(EventJson);
                    EventJson.Add('date', Format(TempPageData."Availability Date", 0, 9));
                    EventJson.Add('type', TempPageData.Type.Names().Get(TempPageData.Type.Ordinals().IndexOf(TempPageData.Type.AsInteger())));
                    EventJson.Add('sourceDocument', TempPageData."Document No.");
                    EventJson.Add('quantity', TempPageData."Remaining Quantity (Base)");
                    EventJson.Add('projectedInventory', TempPageData."Projected Inventory");
                    EventJson.Add('variant', TempPageData."Variant Code");
                    EventJson.Add('location', TempPageData."Location Code");
                    Events.Add(EventJson);
                end;
            until TempPageData.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('itemNo', Item."No.");
        Response.Add('openingInventory', OpeningInventory);
        Response.Add('events', Events);
    end;
}
