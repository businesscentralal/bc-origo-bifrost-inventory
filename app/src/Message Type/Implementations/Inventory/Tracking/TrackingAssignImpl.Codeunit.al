namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013470 "Tracking Assign Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DescriptionLbl: Label 'Assigns lot, serial and package tracking to an existing source through native Item Tracking Lines.', Comment = 'is-IS=Úthlutar lotu-, raðnúmera- og pakkarakningu á fyrirliggjandi uppruna með innbyggðum vörurakningarlínum.';
        SelectionLbl: Label 'Select source.type and source.systemId; entries supplies 1..200 tracking rows in base units.', Comment = 'is-IS=Veldu source.type og source.systemId; entries inniheldur 1..200 rakningarlínur í grunneiningum.';
        KeywordsLbl: Label 'assign lot,assign serial,assign package,item tracking', Comment = 'is-IS=úthluta lotu,úthluta raðnúmeri,úthluta pakka,vörurakning';
        OverviewLbl: Label 'Assigns lot, serial and package tracking to an existing source through native Item Tracking Lines.', Comment = 'is-IS=Úthlutar lotu-, raðnúmera- og pakkarakningu á fyrirliggjandi uppruna með innbyggðum vörurakningarlínum.';
        NotesLbl: Label 'Quantities use base units, unlike Reservation.Create. Every entry is validated before native registration. Serial quantity must be one. Native source, tracking-code, availability and expiration checks remain active. No posting or direct protected-table insertion occurs.', Comment = 'is-IS=Magn er í grunneiningum, ólíkt Reservation.Create. Allar línur eru sannprófaðar fyrir innbyggða skráningu. Magn raðnúmers verður að vera einn. Innbyggðar athuganir á uppruna, rakningarkóta, tiltæku magni og fyrningu gilda áfram. Engin bókun eða bein skráning í varðar töflur fer fram.';

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
        Envelope.Add('messageType', 'Inventory.Tracking.Assign');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('page', 'Item Tracking Lines');
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
        ParameterJson.Add('name', 'entries');
        ParameterJson.Add('type', 'array');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', '1..200 entries with lotNo, serialNo, packageNo, quantity in base units and optional expirationDate. Serial quantity must be one.');
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
        Fields.Add(ContractMgt.ResponseField('entriesAssigned', 'integer', 'Number of supplied tracking rows registered.'));
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete an item tracking specification instead of assigning one.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Clear(Examples);
        Examples.ReadFrom('[{"title":"Assign a lot to an owned purchase line","description":"Create your own compatible item, document line and stock first; replace illustrative identifiers with those owned records. Normal licensing and permissions apply.","request":{"type":"Inventory.Tracking.Assign","data":{"source":{"type":"PurchaseLine","systemId":"11111111-1111-1111-1111-111111111111"},"entries":[{"lotNo":"OWNED-LOT","quantity":2}]}}}]');
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
        if Argument."Omit Commit" then
            TrackingWrite.Run(Argument)
        else
            if not TrackingWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
