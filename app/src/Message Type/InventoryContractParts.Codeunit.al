namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Builds shared contract chapters for the Inventory message types.</summary>
codeunit 70013445 "Inventory Contract Parts ori"
{
    Access = Internal;

    var
        AttributeGetOverviewLbl: Label 'Reads attribute definitions and assigned values for one or more Items without changing Business Central data.', Comment = 'is-IS=Les eigindaskilgreiningar og úthlutuð gildi fyrir eina eða fleiri vörur án þess að breyta gögnum í Business Central.';
        AttributeCreateOverviewLbl: Label 'Assigns one or more attribute values to an Item. Existing equal mappings are idempotent; conflicts require overwrite or the update message.', Comment = 'is-IS=Úthlutar einu eða fleiri eigindagildum á vöru. Fyrirliggjandi tengingar með sama gildi eru óbreyttar; árekstrar krefjast yfirskriftar eða uppfærsluskilaboða.';
        AttributeUpdateOverviewLbl: Label 'Changes existing Item attribute mappings and returns the resulting values. Use Item.Attribute.Create when a mapping does not exist.', Comment = 'is-IS=Breytir fyrirliggjandi eigindatengingum vöru og skilar gildunum eftir breytingu. Notaðu Item.Attribute.Create þegar tengingu vantar.';
        AttributeDefinitionOverviewLbl: Label 'Creates an Item Attribute definition and optional Option values independently of an Item.', Comment = 'is-IS=Stofnar eigindaskilgreiningu fyrir vörur og valfrjáls valkostagildi án tengingar við tiltekna vöru.';
        TransferCreateOverviewLbl: Label 'Creates a Transfer Order header and optional lines. The call allocates a new document number and is not idempotent.', Comment = 'is-IS=Stofnar haus flutningspöntunar og valfrjálsar línur. Kallið úthlutar nýju skjalanúmeri og endurtekið kall stofnar nýtt skjal.';
        TransferReleaseOverviewLbl: Label 'Releases an open Transfer Order so it can be posted.', Comment = 'is-IS=Útgefur opna flutningspöntun svo hægt sé að bóka hana.';
        TransferReopenOverviewLbl: Label 'Reopens a released Transfer Order so it can be edited again.', Comment = 'is-IS=Opnar útgefna flutningspöntun aftur svo hægt sé að breyta henni.';
        TransferPostOverviewLbl: Label 'Posts a Transfer Order as Ship, Receive or direct transfer and writes the corresponding inventory documents and ledger entries.', Comment = 'is-IS=Bókar flutningspöntun sem afhendingu, móttöku eða beinan flutning og stofnar samsvarandi birgðaskjöl og færslur.';
        TransferPreviewOverviewLbl: Label 'Simulates Transfer Order posting, returns predicted entries and always rolls back the transaction.', Comment = 'is-IS=Hermir eftir bókun flutningspöntunar, skilar fyrirhuguðum færslum og afturkallar alltaf gagnagrunnsbreytingarnar.';
        TransferStatisticsOverviewLbl: Label 'Reads Transfer Order line counts, quantities, parcels, weights and volume without writing data.', Comment = 'is-IS=Les línufjölda, magn, pakkafjölda, þyngd og rúmmál flutningspöntunar án þess að breyta gögnum.';
        AssemblyCreateOverviewLbl: Label 'Creates an Assembly Order for a parent Item and optionally refreshes its component lines from the BOM.', Comment = 'is-IS=Stofnar samsetningarpöntun fyrir yfirvöru og endurnýjar valfrjálst íhlutalínur úr uppskrift hennar.';
        AssemblyRefreshOverviewLbl: Label 'Refreshes Assembly Order component lines from the parent Item BOM.', Comment = 'is-IS=Endurnýjar íhlutalínur samsetningarpöntunar úr uppskrift yfirvöru.';
        AssemblyReleaseOverviewLbl: Label 'Releases an open Assembly Order so it can be posted.', Comment = 'is-IS=Útgefur opna samsetningarpöntun svo hægt sé að bóka hana.';
        AssemblyReopenOverviewLbl: Label 'Reopens a released Assembly Order so it can be edited again.', Comment = 'is-IS=Opnar útgefna samsetningarpöntun aftur svo hægt sé að breyta henni.';
        AssemblyPostOverviewLbl: Label 'Posts an Assembly Order and returns the posted document number.', Comment = 'is-IS=Bókar samsetningarpöntun og skilar númeri bókaða skjalsins.';
        AssemblyPreviewOverviewLbl: Label 'Simulates Assembly Order posting and returns predicted entries without committing changes.', Comment = 'is-IS=Hermir eftir bókun samsetningarpöntunar og skilar fyrirhuguðum færslum án þess að vista breytingar.';
        AssemblyStatisticsOverviewLbl: Label 'Reads Assembly Order header, line-count and cost statistics without writing data.', Comment = 'is-IS=Les haus, línufjölda og kostnaðartölfræði samsetningarpöntunar án þess að breyta gögnum.';
        AttributeCreateNotesLbl: Label 'Attribute values are typed according to the definition. Set createValueIfMissing on an attribute object when an Option value may need to be created. Blocked items require allowBlocked.', Comment = 'is-IS=Eigindagildi fylgja gagnategund skilgreiningarinnar. Stilltu createValueIfMissing á eigindahlut þegar stofna þarf valkostagildi. Lokaðar vörur krefjast allowBlocked.';
        AttributeUpdateNotesLbl: Label 'Update is intentionally limited to mappings that already exist. The operation is isolated through its write process.', Comment = 'is-IS=Uppfærsla nær aðeins til tenginga sem þegar eru til. Aðgerðin fer fram í aðskildu skrifferli.';
        TransferCreateNotesLbl: Label 'The request is all-or-nothing. When lines are supplied, field names are camelCase and the line limit is 200. Dates use YYYY-MM-DD.', Comment = 'is-IS=Beiðnin er framkvæmd í heild eða alls ekki. Þegar línur eru gefnar nota svæðisheiti camelCase og hámarksfjöldi lína er 200. Dagsetningar nota YYYY-MM-DD.';
        TransferPostNotesLbl: Label 'Non-direct orders require postingType Ship or Receive. Direct transfers use Inventory Setup direct-transfer posting configuration.', Comment = 'is-IS=Pantanir án beins flutnings krefjast postingType Ship eða Receive. Beinir flutningar nota bókunarstillingu beinna flutninga í birgðagrunni.';
        TransferPreviewNotesLbl: Label 'A successful preview includes rollback true. Nothing is persisted, including posted document numbers.', Comment = 'is-IS=Heppnuð forskoðun inniheldur rollback true. Ekkert er vistað, þar á meðal númer bókaðra skjala.';
        AssemblyCreateNotesLbl: Label 'refreshLines defaults to true. PostingDate defaults to WorkDate when omitted. Quantity must be positive.', Comment = 'is-IS=refreshLines er sjálfgefið true. postingDate er vinnudagsetning þegar henni er sleppt. quantity verður að vera jákvætt.';
        AssemblyPostNotesLbl: Label 'The posting gate requires BIFROST InvPost ori. Optional postingDate and quantityToAssemble are applied before posting.', Comment = 'is-IS=Bókunarhlið krefst BIFROST InvPost ori. Valfrjáls postingDate og quantityToAssemble eru notuð fyrir bókun.';
        AssemblyPreviewNotesLbl: Label 'The preview is rolled back and does not create posted documents or ledger entries.', Comment = 'is-IS=Forskoðun er afturkölluð og stofnar hvorki bókuð skjöl né fjárhags- eða birgðafærslur.';

    /// <summary>Builds the existing envelope chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetEnvelope(MessageType: Text): JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
        Envelope: JsonObject;
    begin
        if MessageType in ['Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create'] then begin
            Subject.Add('use', 'notUsed');
            Subject.Add('forms', Forms);
            Subject.Add('description', 'The attribute definition is created from data; no subject record is used.');
        end else begin
            Forms.Add('guid');
            Forms.Add('document no.');
            Subject.Add('use', 'optional');
            Subject.Add('forms', Forms);
            Subject.Add('description', 'The subject identifies the Item, Transfer Header or Assembly Header; use data identifiers when subject is omitted.');
        end;
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(Envelope);
    end;

    /// <summary>Builds the existing target chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetTarget(MessageType: Text) Target: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create'] then
            exit;
        if MessageType in ['Item.Attribute.Get', 'Inventory.Attribute.Get', 'Item.Attribute.Create', 'Inventory.Attribute.Create', 'Item.Attribute.Update', 'Inventory.Attribute.Update'] then begin
            Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the Item.'));
            Target.Add(ContractMgt.TargetEntry('subject', 'item no.', 'The No. of the Item.'));
            Target.Add(ContractMgt.TargetEntry('data.itemNo', 'item no.', 'The Item No. to read or change.'));
            Target.Add(ContractMgt.TargetEntry('data.itemId, data.id, data.systemId, data.recordSystemId', 'guid or item no.', 'Additional Item identifiers accepted by the resolver.'));
            Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view used to resolve one or more Items.'));
            exit;
        end;
        Target.Add(ContractMgt.TargetEntry('subject', 'guid', 'The SystemId of the document header.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'document no.', 'The No. of the document header.'));
        Target.Add(ContractMgt.TargetEntry('data.systemId, data.recordSystemId, data.id', 'guid', 'The SystemId of the document header.'));
        if MessageType.StartsWith('Inventory.TransferOrder.') then
            Target.Add(ContractMgt.TargetEntry('data.documentNo, data.transferOrderNo, data.no', 'document no.', 'The Transfer Order No.'))
        else
            Target.Add(ContractMgt.TargetEntry('data.documentNo, data.assemblyOrderNo, data.no', 'document no.', 'The Assembly Order No.'));
    end;

    /// <summary>Builds the existing parameters chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('includeUnassigned', 'boolean', false, 'Include defined attributes with no value assigned to the item. Default false.'));
                    Parameters.Add(ContractMgt.Parameter('attributeNames', 'array', false, 'Filter attributes by name.'));
                    Parameters.Add(ContractMgt.Parameter('attributeIds', 'array', false, 'Filter attributes by numeric attribute id.'));
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('attributes', 'array', true, 'Attribute mapping objects containing name or id, value, and optional type-specific values.'));
                    Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Allow writing to a blocked item. Default false.'));
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Parameters.Add(ContractMgt.Parameter('attributes', 'array', true, 'Existing attribute mapping objects containing name or id and the replacement value.'));
                    Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Allow writing to a blocked item. Default false.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('name', 'string', true, 'The new attribute definition name.'));
                    Parameters.Add(ContractMgt.Parameter('type', 'string', true, 'Option, Text, Integer, Decimal or Date.'));
                    Parameters.Add(ContractMgt.Parameter('unitOfMeasure', 'string', false, 'Optional unit of measure for the definition.'));
                    Parameters.Add(ContractMgt.Parameter('optionValues', 'array', false, 'Initial option values when type is Option.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('transferFromCode', 'string', true, 'Source location code.'));
                    Parameters.Add(ContractMgt.Parameter('transferToCode', 'string', true, 'Destination location code.'));
                    Parameters.Add(ContractMgt.Parameter('directTransfer', 'boolean', false, 'Create a direct transfer without an in-transit location. Default false.'));
                    Parameters.Add(ContractMgt.Parameter('inTransitCode', 'string', false, 'In-transit location when directTransfer is false.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in YYYY-MM-DD format; WorkDate when omitted.'));
                    Parameters.Add(ContractMgt.Parameter('shipmentDate', 'string', false, 'Shipment date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('receiptDate', 'string', false, 'Receipt date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('externalDocumentNo', 'string', false, 'External document number.'));
                    Parameters.Add(ContractMgt.Parameter('lines', 'array', false, 'Transfer lines; at most 200.'));
                end;
            'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost':
                Parameters.Add(ContractMgt.Parameter('postingType', 'string', false, 'Ship or Receive for a non-direct transfer; ignored for a direct transfer.'));
            'Inventory.AssemblyOrder.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, 'Parent item number.'));
                    Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, 'Assembly order quantity; must be greater than zero.'));
                    Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Item variant code.'));
                    Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Location code.'));
                    Parameters.Add(ContractMgt.Parameter('binCode', 'string', false, 'Bin code.'));
                    Parameters.Add(ContractMgt.Parameter('unitOfMeasureCode', 'string', false, 'Unit of measure code.'));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Assembly order description.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('dueDate', 'string', false, 'Due date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('startingDate', 'string', false, 'Starting date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('endingDate', 'string', false, 'Ending date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('quantityToAssemble', 'number', false, 'Optional quantity to assemble.'));
                    Parameters.Add(ContractMgt.Parameter('refreshLines', 'boolean', false, 'Refresh component lines from the BOM. Default true.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Replacement posting date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('quantityToAssemble', 'number', false, 'Optional quantity to assemble before posting.'));
                end;
        end;
    end;

    /// <summary>Builds the existing response chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when item attributes were read.'));
                    Fields.Add(ContractMgt.ResponseField('items', 'array', 'Items and their attribute values.'));
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create', 'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the mappings were written.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The resolved Item No.'));
                    Fields.Add(ContractMgt.ResponseField('results', 'array', 'The resulting attribute mappings, including changed and value information.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the definition was created.'));
                    Fields.Add(ContractMgt.ResponseField('attributeId', 'integer', 'The new attribute id.'));
                    Fields.Add(ContractMgt.ResponseField('attributeName', 'string', 'The created definition name.'));
                    Fields.Add(ContractMgt.ResponseField('type', 'string', 'The created definition type.'));
                    Fields.Add(ContractMgt.ResponseField('createdValues', 'array', 'Option values created with the definition.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the transfer order was created.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The new Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new Transfer Header SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('transferFromCode', 'string', 'Validated source location.'));
                    Fields.Add(ContractMgt.ResponseField('transferToCode', 'string', 'Validated destination location.'));
                    Fields.Add(ContractMgt.ResponseField('inTransitCode', 'string', 'Validated in-transit location.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order is direct.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'The created order status.'));
                    Fields.Add(ContractMgt.ResponseField('lines', 'array', 'Created transfer lines when lines were supplied.'));
                    Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Created line totals when lines were supplied.'));
                end;
            'Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the status transition completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('statusBefore', 'string', 'Status before the operation.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'Status after the operation.'));
                end;
            'Inventory.TransferOrder.Post':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when posting completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The original Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('postingType', 'string', 'Ship, Receive or DirectTransfer.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order was direct.'));
                    Fields.Add(ContractMgt.ResponseField('postedShipmentNo', 'string', 'Posted shipment number when one was created.'));
                    Fields.Add(ContractMgt.ResponseField('postedReceiptNo', 'string', 'Posted receipt number when one was created.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when preview captured entries.'));
                    Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total predicted entries.'));
                    Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Predicted G/L entry count.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true; the preview is rolled back.'));
                    Fields.Add(ContractMgt.ResponseField('summary', 'string', 'Human-readable preview summary.'));
                    Fields.Add(ContractMgt.ResponseField('predictedNumbers', 'object', 'Predicted posted document numbers.'));
                    Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Predicted G/L totals when applicable.'));
                    Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Captured entries grouped by table.'));
                end;
            'Inventory.TransferOrder.Statistics':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when statistics were read.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Quantity, parcels, weights, volume and line count.'));
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the assembly order was created.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The new Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new Assembly Header SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('quantity', 'number', 'Assembly quantity.'));
                    Fields.Add(ContractMgt.ResponseField('quantityToAssemble', 'number', 'Quantity to assemble.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'The created order status.'));
                    Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Assembly component line count.'));
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when component lines were refreshed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('quantity', 'number', 'Assembly quantity.'));
                    Fields.Add(ContractMgt.ResponseField('linesBefore', 'integer', 'Component line count before refresh.'));
                    Fields.Add(ContractMgt.ResponseField('linesAfter', 'integer', 'Component line count after refresh.'));
                end;
            'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the status transition completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('statusBefore', 'string', 'Status before the operation.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'Status after the operation.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when posting completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The original Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('postedDocumentNo', 'string', 'The posted assembly document number.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when preview captured entries.'));
                    Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total predicted entries.'));
                    Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Predicted G/L entry count.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true; the preview is rolled back.'));
                    Fields.Add(ContractMgt.ResponseField('summary', 'string', 'Human-readable preview summary.'));
                    Fields.Add(ContractMgt.ResponseField('predictedNumbers', 'object', 'Predicted posted document numbers.'));
                    Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Predicted G/L totals when applicable.'));
                    Fields.Add(ContractMgt.ResponseField('preview', 'array', 'Captured entries grouped by table.'));
                end;
            'Inventory.AssemblyOrder.Statistics':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when statistics were read.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('totals', 'object', 'Assembly line counts and cost breakdown.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Builds the existing errors chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Item.Attribute.Get', 'Inventory.Attribute.Get', 'Item.Attribute.Create', 'Inventory.Attribute.Create', 'Item.Attribute.Update', 'Inventory.Attribute.Update'] then
            AddLookupErrors(Errors, 'Item');
        if MessageType in ['Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen', 'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost', 'Inventory.TransferOrder.Statistics'] then
            AddDocumentLookupErrors(Errors, 'Transfer Header', 'transferOrderNo');
        if MessageType in ['Inventory.AssemblyOrder.RefreshLines', 'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen', 'Inventory.AssemblyOrder.Post', 'Inventory.AssemblyOrder.PreviewPost', 'Inventory.AssemblyOrder.Statistics'] then
            AddDocumentLookupErrors(Errors, 'Assembly Header', 'assemblyOrderNo');
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                Errors.Add(ContractMgt.TextErrorEntry('No items found matching the specified criteria.', 'The Item range resolved to no records.', 'Send a subject, item identifier or tableView that matches an Item.'));
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'Request data.attributes must be a non-empty array.', 'Send at least one attribute object.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Item "%1" already has attribute "%2" with a different value.', 'The mapping conflicts and overwrite is false.', 'Set overwrite to true or use Item.Attribute.Update.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Item "%1" is blocked. Pass allowBlocked: true to override.', 'The resolved Item is blocked.', 'Set allowBlocked to true only when the write is intentional.'));
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'Request data.attributes must be a non-empty array.', 'Send at least one attribute object.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Item "%1" has no mapping for attribute "%2". Use Item.Attribute.Create first.', 'The mapping does not exist.', 'Create the mapping first or identify an existing mapping.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Attribute definition requires data.name.', 'Send a non-empty name.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Attribute definition requires data.type.', 'Send Option, Text, Integer, Decimal or Date.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'Unknown attribute type.', 'Use Option, Text, Integer, Decimal or Date.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Item attribute "%1" already exists.', 'The definition name is already used.', 'Use the existing definition or choose another name.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'transferFromCode must be specified in the request JSON.', 'Send the source location code.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'transferToCode must be specified in the request JSON.', 'Send the destination location code.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'One or more transfer lines are invalid.', 'Correct the reported line fields and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, 'A request can contain at most 200 lines.', 'Send no more than 200 lines.'));
                end;
            'Inventory.TransferOrder.Post':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'For a non-direct transfer order, postingType must be Ship or Receive.', 'Send a supported postingType or create a direct transfer.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Posting denied: missing ''BIFROST InvPost ori'' permission set.', 'The caller lacks the inventory posting permission.', 'Assign BIFROST InvPost ori in addition to the Foundation API permission.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Business Central''s own posting error text.', 'TransferOrder-Post rejected the operation.', 'Read the error text and correct the order or setup.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview produced no entries. Nothing would be posted.', 'Add a line quantity to ship or receive and retry.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Business Central''s own posting error text.', 'The transfer posting preview failed.', 'Read the error text and correct the order or setup.'));
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemNo must be specified in the request JSON.', 'Send the parent item number.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'quantity must be specified and greater than 0 in the request JSON.', 'Send a positive quantity.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Field %1 is restricted for write. Cannot use value ''%2''.', 'A field-level write restriction blocks the requested value.', 'Remove the restricted field or grant the required permission.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Business Central''s own validation error text.', 'Assembly Header validation rejected the request.', 'Read the error text and correct the item, location, dates or quantity.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Errors.Add(ContractMgt.TextErrorEntry('Posting denied: missing ''BIFROST InvPost ori'' permission set.', 'The caller lacks the inventory posting permission.', 'Assign BIFROST InvPost ori in addition to the Foundation API permission.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Business Central''s own posting error text.', 'Assembly-Post rejected the operation.', 'Read the error text and correct the order or setup.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview produced no entries. Nothing would be posted.', 'Add a quantity to assemble and retry.'));
                    Errors.Add(ContractMgt.TextErrorEntry('Business Central''s own posting error text.', 'The assembly posting preview failed.', 'Read the error text and correct the order or setup.'));
                end;
        end;
    end;

    local procedure AddDocumentLookupErrors(var Errors: JsonArray; RecordName: Text; DocumentAlias: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter,
            'No ' + RecordName + ' identifier in subject or data.', 'Send subject or an identifier key under data.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound,
            'An identifier was given but matches no ' + RecordName + '.', 'Check the value or look the record up first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers,
            'Two identifiers were given that point to different records.', 'Send one identifier.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat,
            'data is not a JSON object (parameter data); an identifier key under data (documentNo, ' + DocumentAlias + ', no, systemId, recordSystemId, id) is not a JSON string (null, a number, a boolean, an object or an array); or a SystemId is not a GUID. parameter names the key.',
            'Send data as a JSON object, each identifier as a JSON string and a SystemId as a GUID. Nothing is looked up while one is wrong.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors,
            'More than one identifier key is of the wrong type; errors[] lists each, in the order the keys are read. Nothing is looked up while one is wrong.',
            'Fix every listed key and send the request again.'));
    end;

    local procedure AddLookupErrors(var Errors: JsonArray; RecordName: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter,
            'No ' + RecordName + ' identifier in subject or data.', 'Send subject or an identifier key under data.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound,
            'An identifier was given but matches no ' + RecordName + '.', 'Check the value or look the record up first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers,
            'Two identifiers were given that point to different records.', 'Send one identifier.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat,
            'A SystemId or document identifier cannot be read.', 'Send a GUID for SystemId keys and text for document numbers.'));
    end;

    /// <summary>Builds the existing effect chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    begin
        if MessageType in ['Inventory.TransferOrder.Post', 'Inventory.AssemblyOrder.Post'] then
            Effect.Add('effect', 'irreversible')
        else
            if MessageType in ['Item.Attribute.Create', 'Inventory.Attribute.Create', 'Item.Attribute.Update', 'Inventory.Attribute.Update', 'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create', 'Inventory.TransferOrder.Create', 'Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen', 'Inventory.AssemblyOrder.Create', 'Inventory.AssemblyOrder.RefreshLines', 'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen'] then
                Effect.Add('effect', 'write')
            else
                Effect.Add('effect', 'read');
        Effect.Add('changes', 'The operation changes Business Central inventory records only as described by the message type.');
        Effect.Add('idempotent', MessageType in ['Item.Attribute.Get', 'Inventory.Attribute.Get', 'Inventory.TransferOrder.PreviewPost', 'Inventory.TransferOrder.Statistics', 'Inventory.AssemblyOrder.PreviewPost', 'Inventory.AssemblyOrder.Statistics', 'Inventory.AssemblyOrder.RefreshLines', 'Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen', 'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen']);
        Effect.Add('permissionSet', 'BIFROST API ori; BIFROST InvPost ori for posting');
        Effect.Add('preconditions', 'The target record exists, the caller has the required permission and Business Central setup permits the operation.');
    end;

    /// <summary>Builds the existing related chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetRelated(MessageType: Text) Related: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Create', 'Assign a missing attribute value.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Update', 'Replace an existing attribute mapping.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AttributeDefinition.Create', 'Create a new attribute definition.'));
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Update', 'Change an existing mapping instead of creating it.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Get', 'Read assigned and unassigned values.'));
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Create', 'Create a mapping that does not exist.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Get', 'Read the current mapping first.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Get', 'Read definitions and values.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.Attribute.Create', 'Assign the new definition to an item.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Release', 'Release the order after its lines are ready.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Statistics', 'Inspect line totals.'));
                end;
            'Inventory.TransferOrder.Release':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Reopen', 'Reopen the order for editing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', 'Post the released order.'));
                end;
            'Inventory.TransferOrder.Reopen':
                Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Release', 'Release the order again after editing.'));
            'Inventory.TransferOrder.Post':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.PreviewPost', 'Preview the posting without committing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Release', 'Release before posting.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', 'Actually post after the preview is correct.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Statistics', 'Inspect quantities before previewing.'));
                end;
            'Inventory.TransferOrder.Statistics':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.PreviewPost', 'Preview predicted entries.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.TransferOrder.Post', 'Ship or receive the order.'));
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.RefreshLines', 'Refresh components from the BOM.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Release', 'Release the order after preparation.'));
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Create', 'Create a new assembly order.'));
            'Inventory.AssemblyOrder.Release':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Reopen', 'Reopen the order for editing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Post the released order.'));
                end;
            'Inventory.AssemblyOrder.Reopen':
                Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Release', 'Release the order again after editing.'));
            'Inventory.AssemblyOrder.Post':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting without committing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Release', 'Release before posting.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Actually post after the preview is correct.'));
            'Inventory.AssemblyOrder.Statistics':
                Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.PreviewPost', 'Preview predicted entries.'));
        end;
    end;

    /// <summary>Builds the existing workflow chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetWorkflow(MessageType: Text) Workflow: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        case MessageType of
            'Inventory.TransferOrder.Create':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Create', 'Create the transfer header and optional lines.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Release', 'Release the completed order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship or receive the transfer.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Statistics', 'Check quantities and totals.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Post after the preview is acceptable.'));
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Create', 'Create the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Release', 'Release the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post the assembly order.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Statistics', 'Inspect the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post after the preview is acceptable.'));
                end;
            else
                exit;
        end;
        Workflow.Add('steps', Steps);
    end;

    /// <summary>Builds the existing examples chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetExamples(MessageType: Text) Examples: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                Examples.Add(ContractMgt.Example('Read item attributes', '{"subject":"1000","data":{"includeUnassigned":true}}', '{"status":"Success","items":[]}'));
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                Examples.Add(ContractMgt.Example('Create an option definition', '{"data":{"name":"Finish","type":"Option","optionValues":["Matte","Gloss"]}}', '{"status":"Success","attributeId":2,"attributeName":"Finish","type":"Option","createdValues":[]}'));
            'Inventory.TransferOrder.Create':
                Examples.Add(ContractMgt.Example('Create a transfer order', '{"data":{"transferFromCode":"BLUE","transferToCode":"RED","directTransfer":true}}', '{"status":"Success","documentNo":"TO000456","statusAfter":"Open"}'));
            'Inventory.AssemblyOrder.Create':
                Examples.Add(ContractMgt.Example('Create an assembly order', '{"data":{"itemNo":"1000","quantity":1}}', '{"status":"Success","documentNo":"AO000456","statusAfter":"Open"}'));
        end;
    end;

    /// <summary>Builds the existing overview chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetOverview(MessageType: Text) Overview: Text
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                Overview := AttributeGetOverviewLbl;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                Overview := AttributeCreateOverviewLbl;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                Overview := AttributeUpdateOverviewLbl;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                Overview := AttributeDefinitionOverviewLbl;
            'Inventory.TransferOrder.Create':
                Overview := TransferCreateOverviewLbl;
            'Inventory.TransferOrder.Release':
                Overview := TransferReleaseOverviewLbl;
            'Inventory.TransferOrder.Reopen':
                Overview := TransferReopenOverviewLbl;
            'Inventory.TransferOrder.Post':
                Overview := TransferPostOverviewLbl;
            'Inventory.TransferOrder.PreviewPost':
                Overview := TransferPreviewOverviewLbl;
            'Inventory.TransferOrder.Statistics':
                Overview := TransferStatisticsOverviewLbl;
            'Inventory.AssemblyOrder.Create':
                Overview := AssemblyCreateOverviewLbl;
            'Inventory.AssemblyOrder.RefreshLines':
                Overview := AssemblyRefreshOverviewLbl;
            'Inventory.AssemblyOrder.Release':
                Overview := AssemblyReleaseOverviewLbl;
            'Inventory.AssemblyOrder.Reopen':
                Overview := AssemblyReopenOverviewLbl;
            'Inventory.AssemblyOrder.Post':
                Overview := AssemblyPostOverviewLbl;
            'Inventory.AssemblyOrder.PreviewPost':
                Overview := AssemblyPreviewOverviewLbl;
            'Inventory.AssemblyOrder.Statistics':
                Overview := AssemblyStatisticsOverviewLbl;
        end;
    end;

    /// <summary>Builds the existing notes chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetNotes(MessageType: Text) Notes: Text
    begin
        case MessageType of
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                Notes := AttributeCreateNotesLbl;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                Notes := AttributeUpdateNotesLbl;
            'Inventory.TransferOrder.Create':
                Notes := TransferCreateNotesLbl;
            'Inventory.TransferOrder.Post':
                Notes := TransferPostNotesLbl;
            'Inventory.TransferOrder.PreviewPost':
                Notes := TransferPreviewNotesLbl;
            'Inventory.AssemblyOrder.Create':
                Notes := AssemblyCreateNotesLbl;
            'Inventory.AssemblyOrder.Post':
                Notes := AssemblyPostNotesLbl;
            'Inventory.AssemblyOrder.PreviewPost':
                Notes := AssemblyPreviewNotesLbl;
        end;
    end;

    /// <summary>
    /// Adds the error entries of TryResolveItemNo to an errors chapter.
    /// </summary>
    /// <param name="Errors">The errors chapter to extend.</param>
    /// <param name="Required">True when the message type refuses a call with neither data.itemNo nor subject.</param>
    procedure AddItemNoSubjectErrors(var Errors: JsonArray; Required: Boolean)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ItemNoRequiredErr: Label 'itemNo is required.', Comment = 'is-IS=itemNo er nauðsynlegt.';
        ItemNoRequiredWhenTxt: Label 'Neither data.itemNo nor subject was sent.', Comment = 'is-IS=Hvorki data.itemNo né subject var sent.';
        ItemNoNextStepTxt: Label 'Send data.itemNo or the item number as subject.', Comment = 'is-IS=Sendu data.itemNo eða vörunúmerið sem subject.';
        ConflictErr: Label 'subject and itemNo name different items.', Comment = 'is-IS=subject og itemNo nefna ólíkar vörur.';
        ConflictWhenTxt: Label 'subject and data.itemNo were both sent and do not match.', Comment = 'is-IS=Bæði subject og data.itemNo voru send og þau passa ekki saman.';
        ConflictNextStepTxt: Label 'Send one item number, or make subject and data.itemNo the same.', Comment = 'is-IS=Sendu eitt vörunúmer, eða láttu subject og data.itemNo vera eins.';
        ItemNoFormatErr: Label 'itemNo must be a JSON value.', Comment = 'is-IS=itemNo verður að vera JSON-gildi.';
        ItemNoFormatWhenTxt: Label 'data.itemNo is an object or an array.', Comment = 'is-IS=data.itemNo er hlutur eða fylki.';
        ItemNoFormatNextStepTxt: Label 'Send the item number as text in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið sem texta í data.itemNo.';
    begin
        if Required then
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ItemNoRequiredErr, ItemNoRequiredWhenTxt, ItemNoNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, ConflictWhenTxt, ConflictNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ItemNoFormatErr, ItemNoFormatWhenTxt, ItemNoFormatNextStepTxt));
    end;

    /// <summary>
    /// Resolves one item number from data.itemNo and the message subject.
    /// The subject is the item number when itemNo is omitted. Different values are refused.
    /// </summary>
    /// <param name="Argument">The message argument. An error response is set when resolution fails.</param>
    /// <param name="RequestJson">The data object.</param>
    /// <param name="Required">True when a call with neither value must be MissingParameter.</param>
    /// <param name="ItemNo">The resolved item number, or blank when the call does not require one.</param>
    /// <returns>False when the response is already an error.</returns>
    procedure TryResolveItemNo(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; Required: Boolean; var ItemNo: Code[20]): Boolean
    var
        Token: JsonToken;
        DataItemNo: Code[20];
        SubjectItemNo: Code[20];
        ItemNoRequiredErr: Label 'itemNo is required.', Comment = 'is-IS=itemNo er nauðsynlegt.';
        ItemNoExpectedTxt: Label 'A non-empty item number in data.itemNo or subject.', Comment = 'is-IS=Ótómt vörunúmer í data.itemNo eða subject.';
        ItemNoNextStepTxt: Label 'Send data.itemNo or the item number as subject.', Comment = 'is-IS=Sendu data.itemNo eða vörunúmerið sem subject.';
        ItemNoFormatErr: Label 'itemNo must be a JSON value.', Comment = 'is-IS=itemNo verður að vera JSON-gildi.';
        ItemNoFormatExpectedTxt: Label 'A JSON string or number.', Comment = 'is-IS=JSON-strengur eða tala.';
        ItemNoFormatNextStepTxt: Label 'Send the item number as text in data.itemNo.', Comment = 'is-IS=Sendu vörunúmerið sem texta í data.itemNo.';
        ConflictErr: Label 'subject %1 and itemNo %2 name different items.', Comment = '%1 = subject, %2 = item no.||is-IS=subject %1 og itemNo %2 nefna ólíkar vörur.';
        ConflictExpectedTxt: Label 'The same item number in subject and data.itemNo, or only one of them.', Comment = 'is-IS=Sama vörunúmer í subject og data.itemNo, eða aðeins annað.';
        ConflictNextStepTxt: Label 'Send one item number, or make subject and data.itemNo the same.', Comment = 'is-IS=Sendu eitt vörunúmer, eða láttu subject og data.itemNo vera eins.';
    begin
        Clear(ItemNo);
        if RequestJson.Get('itemNo', Token) then begin
            if not Token.IsValue() then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, ItemNoFormatErr, 'itemNo', '', ItemNoFormatExpectedTxt, ItemNoFormatNextStepTxt);
                exit(false);
            end;
            if not Token.AsValue().IsNull() then
                DataItemNo := CopyStr(DelChr(Token.AsValue().AsText(), '<>', ' '), 1, MaxStrLen(DataItemNo));
        end;
        SubjectItemNo := CopyStr(DelChr(Argument.Subject, '<>', ' '), 1, MaxStrLen(SubjectItemNo));
        if (DataItemNo <> '') and (SubjectItemNo <> '') and (DataItemNo <> SubjectItemNo) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(ConflictErr, SubjectItemNo, DataItemNo), 'itemNo', DataItemNo, ConflictExpectedTxt, ConflictNextStepTxt);
            exit(false);
        end;
        if DataItemNo <> '' then
            ItemNo := DataItemNo
        else
            ItemNo := SubjectItemNo;
        if ItemNo <> '' then
            exit(true);
        if not Required then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, ItemNoRequiredErr, 'itemNo', '', ItemNoExpectedTxt, ItemNoNextStepTxt);
        exit(false);
    end;
}
