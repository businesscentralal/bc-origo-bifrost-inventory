namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

codeunit 70013476 "Reservation Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        Resolver: Codeunit "Inventory Source Resolve ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::Reservations, Database::"Inventory Setup ori", false, false) and Resolver.HasReservationWritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Creates a reservation through Reservation Management.');
    end;

    procedure GetKeywords(): Text
    begin
        exit('create manual reservation, explicit supply, reserve item');
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit('Reserves quantity for an item through Reservation Management.');
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Reservation.Create');
        Envelope.Add('version', 1);
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetJson: JsonObject;
    begin
        TargetJson.Add('codeunit', 'Reservation Management');
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
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'W1 reservation source type and systemId; transferDirection selects Outbound or Inbound.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'supply');
        ParameterJson.Add('type', 'object');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Explicit opposite source type and systemId. Otherwise use itemLedgerEntryNo, or matching posted inventory in entry order.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'quantity');
        ParameterJson.Add('type', 'decimal');
        ParameterJson.Add('required', true);
        ParameterJson.Add('description', 'Positive quantity in the source unit of measure.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'expectedDate');
        ParameterJson.Add('type', 'date');
        ParameterJson.Add('required', false);
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentType');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Legacy document type, for example Sales.Order.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'documentNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document number used with documentType and lineNo.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lineNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document line number.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'systemId');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Document line SystemId used with documentType.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'transferDirection');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Outbound or Inbound transfer side.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'itemLedgerEntryNo');
        ParameterJson.Add('type', 'integer');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Specific posted supply instead of the supply object.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'lotNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested lot; must match selected inventory.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'serialNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested serial; one base unit only.');
        Parameters.Add(ParameterJson);
        Clear(ParameterJson);
        ParameterJson.Add('name', 'packageNo');
        ParameterJson.Add('type', 'string');
        ParameterJson.Add('required', false);
        ParameterJson.Add('description', 'Exact requested package; must match selected inventory.');
        Parameters.Add(ParameterJson);
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('quantity', 0);
        Response.Add('quantityBase', 0);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'itemNo or quantity is missing');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', 'Reservation Entry');
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
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Get', 'Read reservations before creating one.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Reservation.Cancel', 'Cancel a reservation instead of creating one.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Manually reserves the requested quantity against explicit supply or matching posted inventory through native W1 adapters.';
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Uses native source adapters and Create Reserv. Entry. Quantity is in the source unit of measure; pairing and availability checks apply.';
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        ReservationWrite: Codeunit "Inventory Reserv. Write ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Reservations, Database::"Inventory Setup ori", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if Argument."Omit Commit" then
            ReservationWrite.Run(Argument)
        else
            if not ReservationWrite.Run(Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', '');
    end;
}
