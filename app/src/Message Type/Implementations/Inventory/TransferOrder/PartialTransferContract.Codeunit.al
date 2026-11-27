namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Localized contracts for partial transfer shipment and receipt.</summary>
codeunit 10077024 "Partial Transfer Contract ori"
{
    Access = Internal;

    var
        TargetLbl: Label 'One non-direct transfer order, identified by document number or SystemId.', Comment = 'is-IS=Ein flutningspöntun sem er ekki bein, auðkennd með skjalanúmeri eða SystemId.';
        LinesLbl: Label '1 to 200 distinct top-level transfer lines. Omitted lines are not posted.', Comment = 'is-IS=1 til 200 aðskildar aðallínur flutningspöntunar. Línur sem er sleppt eru ekki bókaðar.';
        LineNoLbl: Label 'The existing transfer line number, for example 10000.', Comment = 'is-IS=Númer fyrirliggjandi flutningslínu, til dæmis 10000.';
        ShipQtyLbl: Label 'Positive quantity to ship, no greater than quantity minus quantity shipped.', Comment = 'is-IS=Jákvætt magn til afhendingar, ekki meira en magn að frádregnu afhentu magni.';
        ReceiveQtyLbl: Label 'Positive quantity to receive, no greater than quantity shipped minus quantity received.', Comment = 'is-IS=Jákvætt magn til móttöku, ekki meira en afhent magn að frádregnu mótteknu magni.';
        CountLbl: Label 'expectedCount counts transfer orders: send 1 for the one selected order, regardless of the number of lines or their quantities.', Comment = 'is-IS=expectedCount telur flutningspantanir: sendu 1 fyrir eina valda pöntun, óháð fjölda lína eða magni þeirra.';
        ShipOverviewLbl: Label 'Posts the specified qtyToShip on the selected transfer lines and returns postedShipmentNo.', Comment = 'is-IS=Bókar tilgreint qtyToShip á völdum flutningslínum og skilar postedShipmentNo.';
        ReceiveOverviewLbl: Label 'Posts the specified qtyToReceive on the selected transfer lines and returns postedReceiptNo.', Comment = 'is-IS=Bókar tilgreint qtyToReceive á völdum flutningslínum og skilar postedReceiptNo.';
        NotesLbl: Label 'All lines are validated before any quantity changes. Duplicate, missing, zero, negative and excessive quantities are refused. Receipt is limited to shipped-but-unreceived quantities. Direct transfers use Inventory.TransferOrder.Post. Native posting failures roll back quantity changes and entries. A successful call commits and ignores Omit Commit; do not retry a successful call blindly. A final receipt may delete the completed order.', Comment = 'is-IS=Allar línur eru sannreyndar áður en magni er breytt. Tvítekningum, vöntun, núlli, neikvæðu magni og of miklu magni er hafnað. Móttaka takmarkast við afhent en ómóttekið magn. Beinir flutningar nota Inventory.TransferOrder.Post. Villur í innbyggðri bókun afturkalla magnbreytingar og færslur. Heppnað kall vistar og hunsar Omit Commit; ekki endurtaka heppnað kall í blindni. Lokamóttaka getur eytt fullgerðri pöntun.';
        EffectLbl: Label 'Posts inventory documents and ledger entries for one transfer order. Requires the Transfer Orders domain, BIFROST Full and the Inventory posting permission. A successful posting cannot be rolled back afterwards.', Comment = 'is-IS=Bókar birgðaskjöl og færslur fyrir eina flutningspöntun. Krefst sviðsins Flutningspantanir, BIFROST Full og bókunarheimildar birgða. Ekki er hægt að afturkalla heppnaða bókun eftir á.';
        StatusLbl: Label 'Success after posting.', Comment = 'is-IS=Success eftir bókun.';
        ShipmentLbl: Label 'Number of the posted transfer shipment; empty for Receive.', Comment = 'is-IS=Númer bókaðrar flutningsafhendingar; tómt fyrir Receive.';
        ReceiptLbl: Label 'Number of the posted transfer receipt; empty for Ship.', Comment = 'is-IS=Númer bókaðrar flutningsmóttöku; tómt fyrir Ship.';
        DeletedLbl: Label 'True when final receipt removed the completed order.', Comment = 'is-IS=True þegar lokamóttaka fjarlægði fullgerða pöntun.';
        PostingDateLbl: Label 'Posting date in YYYY-MM-DD format.', Comment = 'is-IS=Bókunardagsetning á sniðinu YYYY-MM-DD.';
        InvalidLbl: Label 'The line selection or a quantity is invalid or exceeds the remaining quantity.', Comment = 'is-IS=Línuval eða magn er ógilt eða fer yfir eftirstöðvar.';
        InvalidNextLbl: Label 'Read the transfer lines and send unique lineNo values with positive quantities within the remaining amount.', Comment = 'is-IS=Lestu flutningslínurnar og sendu einstök lineNo gildi með jákvæðu magni innan eftirstöðva.';
        LookupLbl: Label 'The order identifier is missing, malformed, conflicting or not found.', Comment = 'is-IS=Auðkenni pöntunar vantar, er rangt sniðið, stangast á eða finnst ekki.';
        LookupNextLbl: Label 'Send a documentNo or subject identifying one existing transfer order.', Comment = 'is-IS=Sendu documentNo eða subject sem auðkennir eina fyrirliggjandi flutningspöntun.';
        NativeLbl: Label 'Business Central refused the posting; quantity changes and posting entries were rolled back.', Comment = 'is-IS=Business Central hafnaði bókuninni; magnbreytingar og bókunarfærslur voru afturkallaðar.';
        NativeNextLbl: Label 'Correct the order or posting setup according to the native error and retry.', Comment = 'is-IS=Leiðréttu pöntunina eða bókunaruppsetningu samkvæmt innbyggðu villunni og reyndu aftur.';
        PermissionLbl: Label 'The transfer domain is disabled or the caller lacks the required permissions.', Comment = 'is-IS=Slökkt er á flutningssviðinu eða kallandinn hefur ekki nauðsynlegar heimildir.';
        PermissionNextLbl: Label 'Enable Transfer Orders in Inventory Setup and grant the required read, write and posting permissions.', Comment = 'is-IS=Virkjaðu flutningspantanir í birgðauppsetningu og veittu nauðsynlegar les-, skrif- og bókunarheimildir.';
        DirectLbl: Label 'The selected order is a direct transfer, or a supplied expectedCount is not the integer 1.', Comment = 'is-IS=Valda pöntunin er beinn flutningur eða tilgreint expectedCount er ekki heiltalan 1.';
        DirectNextLbl: Label 'Use Inventory.TransferOrder.Post for a direct transfer; otherwise send expectedCount 1 for one order.', Comment = 'is-IS=Notaðu Inventory.TransferOrder.Post fyrir beinan flutning; annars skaltu senda expectedCount 1 fyrir eina pöntun.';
        NoLinesLbl: Label 'The transfer order has no lines to ship or receive.', Comment = 'is-IS=Flutningspöntunin hefur engar línur til afhendingar eða móttöku.';
        NoLinesNextLbl: Label 'Add item lines to the transfer order, then send the call again.', Comment = 'is-IS=Bættu vörulínum við flutningspöntunina og sendu kallið aftur.';
        RelatedLbl: Label 'Post an order using its current quantities, including direct transfers.', Comment = 'is-IS=Bókaðu pöntun með núverandi magni hennar, þar á meðal beina flutninga.';
        ExampleLbl: Label 'Post part of one selected transfer line.', Comment = 'is-IS=Bókaðu hluta einnar valinnar flutningslínu.';

    /// <summary>Returns the common document envelope.</summary>
    procedure GetEnvelope(Ship: Boolean) Envelope: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Forms.Add('guid');
        Forms.Add('document no.');
        Subject.Add('use', 'optional');
        Subject.Add('forms', Forms);
        Subject.Add('description', TargetLbl);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Returns supported identifiers.</summary>
    procedure GetTarget(Ship: Boolean) Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'guid or document no.', TargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.documentNo, data.transferOrderNo, data.no', 'document no.', TargetLbl));
        Target.Add(ContractMgt.TargetEntry('data.systemId, data.recordSystemId, data.id', 'guid', TargetLbl));
    end;

    /// <summary>Returns line parameters and the exact confirmation counting unit.</summary>
    procedure GetParameters(Ship: Boolean) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        LineParameter: JsonObject;
        Children: JsonArray;
    begin
        Children.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        if Ship then
            Children.Add(ContractMgt.Parameter('qtyToShip', 'number', true, ShipQtyLbl))
        else
            Children.Add(ContractMgt.Parameter('qtyToReceive', 'number', true, ReceiveQtyLbl));
        LineParameter := ContractMgt.Parameter('lines', 'array', true, LinesLbl);
        LineParameter.Add('children', Children);
        Parameters.Add(LineParameter);
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', false, CountLbl));
    end;

    /// <summary>Describes posted document identifiers.</summary>
    procedure GetResponse(Ship: Boolean) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', TargetLbl));
        Fields.Add(ContractMgt.ResponseField('postedShipmentNo', 'string', ShipmentLbl));
        Fields.Add(ContractMgt.ResponseField('postedReceiptNo', 'string', ReceiptLbl));
        Fields.Add(ContractMgt.ResponseField('postingDate', 'string', PostingDateLbl));
        Fields.Add(ContractMgt.ResponseField('orderDeleted', 'boolean', DeletedLbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Returns coded refusal paths and corrective steps.</summary>
    procedure GetErrors(Ship: Boolean) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, InvalidLbl, InvalidNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, LookupLbl, LookupNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, LookupLbl, LookupNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, LookupLbl, LookupNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, LookupLbl, LookupNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, LookupLbl, LookupNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, PermissionLbl, PermissionNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, DirectLbl, DirectNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NoLinesLbl, NoLinesNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, NativeLbl, NativeNextLbl));
    end;

    /// <summary>Declares actual irreversible posting and the confirmation counting unit.</summary>
    procedure GetEffect(Ship: Boolean) Effect: JsonObject
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', EffectLbl + ' ' + CountLbl);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Full ori');
    end;

    /// <summary>Points to the existing direct/full posting operation.</summary>
    procedure GetRelated(Ship: Boolean) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', RelatedLbl));
    end;

    /// <summary>Provides a request and response example.</summary>
    procedure GetExamples(Ship: Boolean) Examples: JsonArray
    var
        Example: JsonObject;
        Request: JsonObject;
        Envelope: JsonObject;
        Response: JsonObject;
        LineObject: JsonObject;
        Lines: JsonArray;
    begin
        Request.Add('documentNo', 'XTRANSFER');
        Request.Add('expectedCount', 1);
        LineObject.Add('lineNo', 10000);
        if Ship then
            LineObject.Add('qtyToShip', 2)
        else
            LineObject.Add('qtyToReceive', 2);
        Lines.Add(LineObject);
        Request.Add('lines', Lines);
        Response.Add('status', 'Success');
        if Ship then
            Response.Add('postedShipmentNo', 'XSHIPMENT')
        else
            Response.Add('postedReceiptNo', 'XRECEIPT');
        if Ship then
            Envelope.Add('type', 'Inventory.TransferOrder.Ship')
        else
            Envelope.Add('type', 'Inventory.TransferOrder.Receive');
        Envelope.Add('data', Request);
        Example.Add('title', ExampleLbl);
        Example.Add('request', Envelope);
        Example.Add('response', Response);
        Examples.Add(Example);
    end;

    /// <summary>Describes the shipment followed by receipt workflow.</summary>
    procedure GetWorkflow() Workflow: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Ship', ShipOverviewLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Receive', ReceiveOverviewLbl));
        Workflow.Add('steps', Steps);
    end;

    /// <summary>Names the confirmation counting unit in the caller's language for the discovery catalogue.</summary>
    procedure GetCountingUnit(): Text
    begin
        exit(CountLbl);
    end;

    /// <summary>Returns the localized overview.</summary>
    procedure GetOverview(Ship: Boolean): Text
    begin
        if Ship then
            exit(ShipOverviewLbl);
        exit(ReceiveOverviewLbl);
    end;

    /// <summary>Explains confirmation, limits, transactions and retry behavior.</summary>
    procedure GetNotes(Ship: Boolean): Text
    begin
        exit(CountLbl + ' ' + NotesLbl);
    end;
}
