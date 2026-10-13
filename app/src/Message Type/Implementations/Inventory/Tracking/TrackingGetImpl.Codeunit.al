namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Origo.Bifrost;

/// <summary>Reads lot, serial and package tracking for an item or document line.</summary>
codeunit 10036919 "Tracking Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Provides IsEnabled for Inventory.Tracking.Get.</summary>
    procedure IsEnabled(): Boolean
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        exit(DomainGate.IsEnabled("Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", false, false));
    end;

    /// <summary>Provides GetFilterTableNo for Inventory.Tracking.Get.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Reservation Entry");
    end;

    /// <summary>Provides GetDescription for Inventory.Tracking.Get.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit('Reads lot, serial and package tracking for an item or document line.');
    end;

    /// <summary>Provides GetKeywords for Inventory.Tracking.Get.</summary>
    procedure GetKeywords(): Text
    begin
        exit('tracking availability, lot availability, serial availability, package');
    end;

    /// <summary>Provides GetSelectionDescription for Inventory.Tracking.Get.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit('Reads lot, serial and package tracking for an item or document line.');
    end;

    /// <summary>Provides GetEnvelope for Inventory.Tracking.Get.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope.Add('messageType', 'Inventory.Tracking.Get');
        Envelope.Add('version', 1);
        exit(true);
    end;

    /// <summary>Provides GetTarget for Inventory.Tracking.Get.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetParameters for Inventory.Tracking.Get.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Clear(Parameters);
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', false, 'Item number; subject takes precedence.'));
        Parameters.Add(ContractMgt.Parameter('itemId', 'string', false, 'Item SystemId.'));
        Parameters.Add(ContractMgt.Parameter('id', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('systemId', 'string', false, 'Item SystemId, or document line SystemId with documentType.'));
        Parameters.Add(ContractMgt.Parameter('recordSystemId', 'string', false, 'Item SystemId alias.'));
        Parameters.Add(ContractMgt.Parameter('locationFilter', 'string', false, 'Business Central location filter.'));
        Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Exact location code; intersects locationFilter.'));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Exact variant code, including blank.'));
        Parameters.Add(ContractMgt.Parameter('lotNo', 'string', false, 'Exact lot number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('serialNo', 'string', false, 'Exact serial number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('packageNo', 'string', false, 'Exact package number, including blank.'));
        Parameters.Add(ContractMgt.Parameter('skip', 'integer', false, 'Number of rows to skip; default 0.'));
        Parameters.Add(ContractMgt.Parameter('take', 'integer', false, 'Page size 1..10000; default 100.'));
        Parameters.Add(ContractMgt.Parameter('source', 'object', false, 'Native source type and systemId; transferDirection selects transfer side.'));
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, 'Sales.Order, Sales.Invoice, Sales.CreditMemo, Sales.ReturnOrder, corresponding Purchase types, or Transfer.Order. Unqualified Order means Sales.Order.'));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', false, 'Document number with documentType and lineNo.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', false, 'Positive document line number.'));
        Parameters.Add(ContractMgt.Parameter('transferDirection', 'string', false, 'Outbound (default) or Inbound for transfers.'));
        exit(true);
    end;

    /// <summary>Provides GetResponse for Inventory.Tracking.Get.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response.Add('status', 'Success');
        Response.Add('trackingLines', 'array');
        Response.Add('noOfLines', 0);
        Response.Add('totalNoOfLines', 0);
        exit(true);
    end;

    /// <summary>Provides GetErrors for Inventory.Tracking.Get.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorJson: JsonObject;
    begin
        Clear(ErrorJson);
        ErrorJson.Add('code', 'MissingParameter');
        ErrorJson.Add('when', 'A required item or document identifier is absent.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'InvalidParameterFormat');
        ErrorJson.Add('when', 'An identifier, filter or paging value has the wrong type or range.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'InvalidParameter');
        ErrorJson.Add('when', 'The requested source or document type is unsupported, or the company domain is disabled.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'RecordNotFound');
        ErrorJson.Add('when', 'No record matches all requested criteria.');
        Errors.Add(ErrorJson);
        Clear(ErrorJson);
        ErrorJson.Add('code', 'PermissionDenied');
        ErrorJson.Add('when', 'The caller cannot read a required source table.');
        Errors.Add(ErrorJson);
        exit(true);
    end;

    /// <summary>Provides GetEffect for Inventory.Tracking.Get.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('writes', false);
        exit(true);
    end;

    /// <summary>Provides GetMetering for Inventory.Tracking.Get.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetRelated for Inventory.Tracking.Get.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Assign', 'Assign item tracking after reading availability.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.Tracking.Delete', 'Delete an item tracking specification instead of reading availability.'));
        exit(true);
    end;

    /// <summary>Provides GetWorkflow for Inventory.Tracking.Get.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetExamples for Inventory.Tracking.Get.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Provides GetOverview for Inventory.Tracking.Get.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reads lot, serial and package tracking for an item or document line.';
        exit(true);
    end;

    /// <summary>Provides GetNotes for Inventory.Tracking.Get.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Read only. Quantities are in base units. Entry expiration dates are returned as ISO dates or blank. Each reservation pair has two sides distinguished by positive and the native source pointer.';
        exit(true);
    end;

    /// <summary>Provides GetMessageDirection for Inventory.Tracking.Get.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Provides ExecuteBifrostTask for Inventory.Tracking.Get.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        DomainGate: Codeunit "Inventory Domain Gate ori";
        TrackingRead: Codeunit "Inventory Tracking Read ori";
    begin
        if not DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::ItemTracking, Database::"Reservation Entry", false, false) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        TrackingRead.ReadTracking(Argument);
    end;
}
