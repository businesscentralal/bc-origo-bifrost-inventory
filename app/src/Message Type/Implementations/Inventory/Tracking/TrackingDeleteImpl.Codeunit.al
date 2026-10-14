namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013471 "Tracking Delete Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Removes tracking from the selected source through native reservation APIs.', Comment = 'is-IS=Fjarlægir rakningu af völdum uppruna með innbyggðum frátektaraðgerðum.';
        SelectionLbl: Label 'Select source.type and source.systemId; omit entryNos for all source tracking or send distinct entry numbers.', Comment = 'is-IS=Veldu source.type og source.systemId; slepptu entryNos fyrir alla rakningu upprunans eða sendu aðgreind færslunúmer.';
        KeywordsLbl: Label 'remove tracking,delete lot,delete serial,source tracking', Comment = 'is-IS=fjarlægja rakningu,eyða lotu,eyða raðnúmeri,rakning uppruna';
        OverviewLbl: Label 'Removes tracking from the selected source through native reservation APIs.', Comment = 'is-IS=Fjarlægir rakningu af völdum uppruna með innbyggðum frátektaraðgerðum.';
        NotesLbl: Label 'Omitted entryNos removes all tracking on the source; an empty array changes nothing. Duplicate entry numbers are counted once. All selected entries must belong to this source and carry tracking; validation finishes before the first change. Native reservation pairing remains active; no posting occurs.', Comment = 'is-IS=Ef entryNos vantar er öll rakning upprunans fjarlægð; tómt fylki breytir engu. Tvítekin færslunúmer eru talin einu sinni. Allar valdar færslur verða að tilheyra upprunanum og bera rakningu; sannprófun lýkur áður en breytingar hefjast. Innbyggð pörun frátekta gildir áfram; engin bókun fer fram.';

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Inventory Setup ori", false, false) and Resolver.HasTrackingWritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Tracking Specification");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Tracking.Delete');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Item Tracking Management');
        Target.Add(TargetJson);
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ParameterJson: JsonObject;
    begin
        Clear(Parameters);
        ParameterJson.Add('name', 'source');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', 'Object with type (SalesLine, PurchaseLine, TransferLine, AssemblyHeader, AssemblyLine or ItemJournalLine) and systemId (GUID). transferDirection is Outbound (default) or Inbound.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'entryNos');
        ParameterJson.Add('type', 'array');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Reservation entry numbers belonging to this source. Omit to remove all source tracking; an empty array changes nothing.');
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success after the operation completes.'));
        Fields.Add(ContractMgt.ResponseField('entriesDeleted', 'integer', 'Distinct selected source tracking rows removed; zero for an empty entryNos array.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Errors);
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required source, document identifier or quantity is absent.', 'Supply the required selector and data described in parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A source object, identifier, number, date, filter or array has an invalid type or range.', 'Use the declared JSON types and valid ranges.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'The source, pairing or tracking values are unsupported, quantity is unavailable, the source is closed, or the company domain is disabled.', 'Correct the selection and quantity; check Inventory Setup and native source rules.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A selected source or explicit entry does not exist or does not match the filters.', 'Read the source again and use identifiers belonging to it.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks required domain or native table permissions.', 'Ask an administrator for the required permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native source, tracking or reservation validation raises an error in the isolated write transaction.', 'Resolve the native error before retrying; failed native writes roll back.'));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Source tracking through native tracking and reservation APIs');
        Effect.Add('posts', false);
        exit(true);
    end;

    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking instead of deleting it.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.TrackingAvailability.Get', 'Read tracking availability before deleting a specification.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Remove tracking from an owned purchase line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Tracking.Delete","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"}}}}]');
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingWrite: Codeunit "Inventory Tracking Write ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Inventory Setup ori", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingWrite.SetDeleteMode();
        if Argument."Omit Commit" then
            TrackingWrite.Run(Argument)
        else
            if not TrackingWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
