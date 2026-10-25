namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Builds shared contract chapters for the Inventory message types.</summary>
codeunit 10076919 "Inventory Contract Parts ori"
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
        TransferPostNotesLbl: Label 'Non-direct orders require postingType Ship or Receive; ShipReceive is refused. Direct transfers ignore postingType and use the Inventory Setup direct-transfer posting configuration. A Receive that receives the last quantity deletes the transfer order; the response is still Success with postedReceiptNo and orderDeleted true. The call commits: it commits the transaction before posting starts, Business Central''s own posting commits as well, and Omit Commit is not honoured, so a successful posting cannot be rolled back. It requires BIFROST InvPost ori in addition to BIFROST Full ori. Use Inventory.TransferOrder.PreviewPost first to see the entries.', Comment = 'is-IS=Pantanir án beins flutnings krefjast postingType Ship eða Receive; ShipReceive er hafnað. Beinir flutningar hunsa postingType og nota bókunarstillingu beinna flutninga í birgðagrunni. Móttaka sem tekur við síðasta magninu eyðir millifærslupöntuninni; svarið er samt Success með postedReceiptNo og orderDeleted true. Kallið vistar breytingar: það vistar færslu áður en bókun hefst, bókun Business Central vistar einnig og Omit Commit er ekki virt, svo ekki er hægt að afturkalla heppnaða bókun. Það krefst BIFROST InvPost ori auk BIFROST Full ori. Notaðu Inventory.TransferOrder.PreviewPost fyrst til að sjá færslurnar.';
        TransferPreviewNotesLbl: Label 'A successful preview includes rollback true. Nothing is persisted, including posted document numbers.', Comment = 'is-IS=Heppnuð forskoðun inniheldur rollback true. Ekkert er vistað, þar á meðal númer bókaðra skjala.';
        AssemblyCreateNotesLbl: Label 'refreshLines defaults to true. PostingDate defaults to WorkDate when omitted. Quantity must be positive.', Comment = 'is-IS=refreshLines er sjálfgefið true. postingDate er vinnudagsetning þegar henni er sleppt. quantity verður að vera jákvætt.';
        AssemblyPostNotesLbl: Label 'Requires BIFROST InvPost ori in addition to BIFROST Full ori. Optional postingDate replaces the posting date, and quantityToAssemble (used only when greater than zero) is written to the order before posting. The call commits: it commits the transaction before posting starts and Omit Commit is not honoured, so a quantityToAssemble change is kept even when the posting then fails. Use Inventory.AssemblyOrder.PreviewPost first to see the entries.', Comment = 'is-IS=Krefst BIFROST InvPost ori auk BIFROST Full ori. Valfrjáls postingDate kemur í stað bókunardagsetningar og quantityToAssemble (notað aðeins þegar það er stærra en núll) er vistað á pöntuninni fyrir bókun. Kallið vistar breytingar: það vistar færslu áður en bókun hefst og Omit Commit er ekki virt, svo breyting á quantityToAssemble helst þótt bókunin mistakist.';
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
            Target.Add(ContractMgt.TargetEntry('data.tableView', 'table view', 'An Item table view used to resolve one or more Items. Inventory.Attribute.Get returns every Item it resolves to; Create and Update write to the first one.'));
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

    /// <summary>Builds the parameters chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetParameters(MessageType: Text) Parameters: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    Parameters.Add(ContractMgt.Parameter('includeUnassigned', 'boolean', false, 'Include defined attributes with no value assigned to the item. Default false.'));
                    Parameters.Add(ContractMgt.Parameter('attributeNames', 'array', false, 'Array of attribute names; only attributes with exactly these names are returned. When attributeIds is sent as well, only attributeNames is applied.'));
                    Parameters.Add(ContractMgt.Parameter('attributeIds', 'array', false, 'Array of numeric attribute ids; only these attributes are returned. Ignored when attributeNames is sent.'));
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Parameter := ContractMgt.Parameter('attributes', 'array', true, 'Attribute mapping objects containing name or id, value, and optional type-specific values.');
                    Parameter.Add('children', AttributeChildren(true));
                    Parameters.Add(Parameter);
                    Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Allow writing to a blocked item. Default false.'));
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Parameter := ContractMgt.Parameter('attributes', 'array', true, 'Existing attribute mapping objects containing name or id and the replacement value.');
                    Parameter.Add('children', AttributeChildren(false));
                    Parameters.Add(Parameter);
                    Parameters.Add(ContractMgt.Parameter('allowBlocked', 'boolean', false, 'Allow writing to a blocked item. Default false.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('name', 'string', true, 'The new attribute definition name.'));
                    Parameters.Add(ContractMgt.Parameter('type', 'string', true, 'Option, Text, Integer, Decimal or Date (not case-sensitive).'));
                    Parameters.Add(ContractMgt.Parameter('unitOfMeasure', 'string', false, 'Optional unit of measure for the definition.'));
                    Parameters.Add(ContractMgt.Parameter('optionValues', 'array', false, 'Array of text values created as the initial option values. Used only when type is Option; entries that are not plain values are skipped.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('transferFromCode', 'string', true, 'Source location code.'));
                    Parameters.Add(ContractMgt.Parameter('transferToCode', 'string', true, 'Destination location code.'));
                    Parameters.Add(ContractMgt.Parameter('directTransfer', 'boolean', false, 'Create a direct transfer without an in-transit location. Default false.'));
                    Parameters.Add(ContractMgt.Parameter('inTransitCode', 'string', false, 'In-transit location. Required when directTransfer is false; not used for a direct transfer.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in YYYY-MM-DD format; WorkDate when omitted.'));
                    Parameters.Add(ContractMgt.Parameter('shipmentDate', 'string', false, 'Shipment date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('receiptDate', 'string', false, 'Receipt date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('externalDocumentNo', 'string', false, 'External document number.'));
                    Parameter := ContractMgt.Parameter('lines', 'array', false, 'Transfer lines; at most 200. All lines are checked before anything is created. A line may also carry variantCode, the item variant code.');
                    Parameter.Add('children', TransferLineChildren());
                    Parameters.Add(Parameter);
                end;
            'Inventory.TransferOrder.Post':
                Parameters.Add(ContractMgt.Parameter('postingType', 'string', false, 'Ship or Receive. Required for a non-direct transfer; ignored for a direct transfer. ShipReceive is refused.'));
            'Inventory.TransferOrder.PreviewPost':
                Parameters.Add(ContractMgt.Parameter('postingType', 'string', false, 'Ship or Receive. Required for a non-direct transfer; ignored for a direct transfer.'));
            'Inventory.AssemblyOrder.Create':
                begin
                    Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, 'Parent item number.'));
                    Parameters.Add(ContractMgt.Parameter('quantity', 'number', true, 'Assembly order quantity; must be greater than zero.'));
                    Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, 'Item variant code.'));
                    Parameters.Add(ContractMgt.Parameter('locationCode', 'string', false, 'Location code.'));
                    Parameters.Add(ContractMgt.Parameter('binCode', 'string', false, 'Bin code.'));
                    Parameters.Add(ContractMgt.Parameter('unitOfMeasureCode', 'string', false, 'Unit of measure code.'));
                    Parameters.Add(ContractMgt.Parameter('description', 'string', false, 'Assembly order description.'));
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Posting date in YYYY-MM-DD format; WorkDate when omitted.'));
                    Parameters.Add(ContractMgt.Parameter('dueDate', 'string', false, 'Due date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('startingDate', 'string', false, 'Starting date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('endingDate', 'string', false, 'Ending date in YYYY-MM-DD format.'));
                    Parameters.Add(ContractMgt.Parameter('quantityToAssemble', 'number', false, 'Optional quantity to assemble; used only when greater than zero.'));
                    Parameters.Add(ContractMgt.Parameter('refreshLines', 'boolean', false, 'Refresh component lines from the BOM. Default true.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Parameters.Add(ContractMgt.Parameter('postingDate', 'string', false, 'Replacement posting date in YYYY-MM-DD format; the date on the order is used when omitted.'));
                    Parameters.Add(ContractMgt.Parameter('quantityToAssemble', 'number', false, 'Optional quantity to assemble before posting; written to the order and committed before posting, used only when greater than zero.'));
                end;
        end;
    end;

    local procedure AttributeChildren(WithOverwrite: Boolean) Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.Parameter('attributeId', 'integer', false, 'Numeric id of the attribute definition. Tried first when it is not 0; the name is used when no attribute has that id.'));
        Children.Add(ContractMgt.Parameter('name', 'string', false, 'Name of the attribute definition. Send name or attributeId.'));
        Children.Add(ContractMgt.Parameter('attributeName', 'string', false, 'Alias of name; read only when name is empty.'));
        Children.Add(ContractMgt.Parameter('type', 'string', false, 'Optional check: Option, Text, Integer, Decimal or Date. An element whose type differs from the definition is refused; an unrecognised type text is ignored.'));
        Children.Add(ContractMgt.Parameter('value', 'string', false, 'The value as text. Required for Option and Text. For Integer, Decimal and Date it is used when numericValue or dateValue is not sent (decimal point as separator, dates as YYYY-MM-DD).'));
        Children.Add(ContractMgt.Parameter('numericValue', 'number', false, 'Value of an Integer or Decimal attribute; takes precedence over value.'));
        Children.Add(ContractMgt.Parameter('dateValue', 'string', false, 'Value of a Date attribute in YYYY-MM-DD format; takes precedence over value.'));
        Children.Add(ContractMgt.Parameter('createValueIfMissing', 'boolean', false, 'Create the option value when it does not exist. Default false. Only Option attributes need it; Text, Integer, Decimal and Date values are created when missing.'));
        if WithOverwrite then
            Children.Add(ContractMgt.Parameter('overwrite', 'boolean', false, 'Replace a different value the item already has for this attribute. Default false: a different value is refused.'));
    end;

    local procedure TransferLineChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.Parameter('itemNo', 'string', true, 'Item number of the line.'));
        Children.Add(ContractMgt.Parameter('quantity', 'number', true, 'Quantity to transfer.'));
        Children.Add(ContractMgt.Parameter('unitOfMeasureCode', 'string', false, 'Unit of measure code.'));
        Children.Add(ContractMgt.Parameter('shipmentDate', 'string', false, 'Shipment date of the line in YYYY-MM-DD format.'));
        Children.Add(ContractMgt.Parameter('description', 'string', false, 'Line description.'));
    end;

    /// <summary>Builds the response chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetResponse(MessageType: Text) Response: JsonObject
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Field: JsonObject;
    begin
        Response.Add('contentType', 'text/json');
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when item attributes were read.'));
                    Field := ContractMgt.ResponseField('items', 'array', 'Items and their attribute values.');
                    Field.Add('children', ItemChildren());
                    Fields.Add(Field);
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the mappings were written.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The resolved Item No.'));
                    Field := ContractMgt.ResponseField('results', 'array', 'The resulting attribute mappings, including changed and value information.');
                    Field.Add('children', MappingResultChildren(false));
                    Fields.Add(Field);
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the mappings were written.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The resolved Item No.'));
                    Field := ContractMgt.ResponseField('results', 'array', 'The resulting attribute mappings, with the value before and after the change.');
                    Field.Add('children', MappingResultChildren(true));
                    Fields.Add(Field);
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the definition was created.'));
                    Fields.Add(ContractMgt.ResponseField('attributeId', 'integer', 'The new attribute id.'));
                    Fields.Add(ContractMgt.ResponseField('attributeName', 'string', 'The created definition name.'));
                    Fields.Add(ContractMgt.ResponseField('type', 'string', 'The created definition type.'));
                    Field := ContractMgt.ResponseField('createdValues', 'array', 'Option values created with the definition.');
                    Field.Add('children', CreatedValueChildren());
                    Fields.Add(Field);
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
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('shipmentDate', 'string', 'Shipment date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('receiptDate', 'string', 'Receipt date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('externalDocumentNo', 'string', 'External document number.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'The created order status.'));
                    Field := ContractMgt.ResponseField('lines', 'array', 'Created transfer lines when lines were supplied.');
                    Field.Add('children', TransferLineResponseChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('totals', 'object', 'Created line totals when lines were supplied.');
                    Field.Add('children', QuantityTotalChildren());
                    Fields.Add(Field);
                end;
            'Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the status transition completed, or the order already had the target status.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('transferFromCode', 'string', 'Source location.'));
                    Fields.Add(ContractMgt.ResponseField('transferToCode', 'string', 'Destination location.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order is direct.'));
                    Fields.Add(ContractMgt.ResponseField('statusBefore', 'string', 'Status before the operation.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'Status after the operation.'));
                end;
            'Inventory.TransferOrder.Post':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when posting completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The original Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('postingType', 'string', 'Ship, Receive or DirectTransfer.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order was direct.'));
                    Fields.Add(ContractMgt.ResponseField('postedShipmentNo', 'string', 'Posted shipment number when one was created (the direct transfer number for a direct transfer).'));
                    Fields.Add(ContractMgt.ResponseField('postedReceiptNo', 'string', 'Posted receipt number when one was created (the direct transfer number for a direct transfer).'));
                    Fields.Add(ContractMgt.ResponseField('orderDeleted', 'boolean', 'True when the posting completed the order and Business Central deleted it (a full receive or a direct transfer).'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when preview captured entries.'));
                    Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total predicted entries.'));
                    Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Predicted G/L entry count.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true; the preview is rolled back.'));
                    Fields.Add(ContractMgt.ResponseField('summary', 'string', 'Human-readable preview summary.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('transferFromCode', 'string', 'Source location.'));
                    Fields.Add(ContractMgt.ResponseField('transferToCode', 'string', 'Destination location.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order is direct.'));
                    Fields.Add(ContractMgt.ResponseField('postingType', 'string', 'Ship, Receive or DirectTransfer as previewed.'));
                    Fields.Add(ContractMgt.ResponseField('lcyCode', 'string', 'The local currency code of the company.'));
                    Field := ContractMgt.ResponseField('predictedNumbers', 'object', 'Predicted posted document numbers.');
                    Field.Add('children', TransferPredictedChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('totals', 'object', 'Predicted G/L totals when applicable.');
                    Field.Add('children', PreviewTotalsChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('preview', 'array', 'Captured entries grouped by table.');
                    Field.Add('children', PreviewTableChildren());
                    Fields.Add(Field);
                end;
            'Inventory.TransferOrder.Statistics':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when statistics were read.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Transfer Order No.'));
                    Fields.Add(ContractMgt.ResponseField('transferFromCode', 'string', 'Source location.'));
                    Fields.Add(ContractMgt.ResponseField('transferToCode', 'string', 'Destination location.'));
                    Fields.Add(ContractMgt.ResponseField('directTransfer', 'boolean', 'Whether the order is direct.'));
                    Fields.Add(ContractMgt.ResponseField('statusValue', 'string', 'The order status, Open or Released.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('shipmentDate', 'string', 'Shipment date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('receiptDate', 'string', 'Receipt date in YYYY-MM-DD format.'));
                    Field := ContractMgt.ResponseField('totals', 'object', 'Quantity, parcels, weights, volume and line count.');
                    Field.Add('children', TransferStatisticsChildren());
                    Fields.Add(Field);
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the assembly order was created.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The new Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The new Assembly Header SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('variantCode', 'string', 'Item variant code.'));
                    Fields.Add(ContractMgt.ResponseField('description', 'string', 'Assembly order description.'));
                    Fields.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code.'));
                    Fields.Add(ContractMgt.ResponseField('binCode', 'string', 'Bin code.'));
                    Fields.Add(ContractMgt.ResponseField('unitOfMeasureCode', 'string', 'Unit of measure code.'));
                    Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Assembly quantity.'));
                    Fields.Add(ContractMgt.ResponseField('quantityToAssemble', 'decimal', 'Quantity to assemble.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('dueDate', 'string', 'Due date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('startingDate', 'string', 'Starting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('endingDate', 'string', 'Ending date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'The created order status.'));
                    Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Assembly component line count.'));
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when component lines were refreshed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Assembly quantity.'));
                    Fields.Add(ContractMgt.ResponseField('linesBefore', 'integer', 'Component line count before refresh.'));
                    Fields.Add(ContractMgt.ResponseField('linesAfter', 'integer', 'Component line count after refresh.'));
                end;
            'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the status transition completed, or the order already had the target status.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The Assembly Header SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('statusBefore', 'string', 'Status before the operation.'));
                    Fields.Add(ContractMgt.ResponseField('statusAfter', 'string', 'Status after the operation.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when posting completed.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The original Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('postedDocumentNo', 'string', 'The posted assembly document number.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('assembledQuantityBefore', 'decimal', 'Quantity already assembled before this posting.'));
                    Fields.Add(ContractMgt.ResponseField('assembleToOrder', 'boolean', 'Whether the order is linked to a sales order (assemble-to-order).'));
                    Fields.Add(ContractMgt.ResponseField('postedSystemId', 'string', 'SystemId of the posted assembly order; only when the posted document was found.'));
                    Fields.Add(ContractMgt.ResponseField('postedQuantity', 'decimal', 'Quantity of the posted assembly order; only when the posted document was found.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when preview captured entries.'));
                    Fields.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Total predicted entries.'));
                    Fields.Add(ContractMgt.ResponseField('glEntryCount', 'integer', 'Predicted G/L entry count.'));
                    Fields.Add(ContractMgt.ResponseField('rollback', 'boolean', 'Always true; the preview is rolled back.'));
                    Fields.Add(ContractMgt.ResponseField('summary', 'string', 'Human-readable preview summary.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code.'));
                    Fields.Add(ContractMgt.ResponseField('quantityToAssemble', 'decimal', 'Quantity to assemble on the order.'));
                    Fields.Add(ContractMgt.ResponseField('lcyCode', 'string', 'The local currency code of the company.'));
                    Field := ContractMgt.ResponseField('predictedNumbers', 'object', 'Predicted posted document numbers.');
                    Field.Add('children', AssemblyPredictedChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('totals', 'object', 'Predicted G/L totals when applicable.');
                    Field.Add('children', PreviewTotalsChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('preview', 'array', 'Captured entries grouped by table.');
                    Field.Add('children', PreviewTableChildren());
                    Fields.Add(Field);
                end;
            'Inventory.AssemblyOrder.Statistics':
                begin
                    Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when statistics were read.'));
                    Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The Assembly Order No.'));
                    Fields.Add(ContractMgt.ResponseField('systemId', 'string', 'The Assembly Header SystemId.'));
                    Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'Parent item number.'));
                    Fields.Add(ContractMgt.ResponseField('variantCode', 'string', 'Item variant code.'));
                    Fields.Add(ContractMgt.ResponseField('description', 'string', 'Assembly order description.'));
                    Fields.Add(ContractMgt.ResponseField('locationCode', 'string', 'Location code.'));
                    Fields.Add(ContractMgt.ResponseField('unitOfMeasureCode', 'string', 'Unit of measure code.'));
                    Fields.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Assembly quantity.'));
                    Fields.Add(ContractMgt.ResponseField('quantityToAssemble', 'decimal', 'Quantity to assemble.'));
                    Fields.Add(ContractMgt.ResponseField('assembledQuantity', 'decimal', 'Quantity already assembled.'));
                    Fields.Add(ContractMgt.ResponseField('remainingQuantity', 'decimal', 'Quantity still to assemble.'));
                    Fields.Add(ContractMgt.ResponseField('reservedQuantity', 'decimal', 'Quantity reserved.'));
                    Fields.Add(ContractMgt.ResponseField('assembleToOrder', 'boolean', 'Whether the order is linked to a sales order (assemble-to-order).'));
                    Fields.Add(ContractMgt.ResponseField('status_', 'string', 'The order status, Open or Released. The name carries a trailing underscore because status holds the call result.'));
                    Fields.Add(ContractMgt.ResponseField('postingDate', 'string', 'Posting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('dueDate', 'string', 'Due date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('startingDate', 'string', 'Starting date in YYYY-MM-DD format.'));
                    Fields.Add(ContractMgt.ResponseField('endingDate', 'string', 'Ending date in YYYY-MM-DD format.'));
                    Field := ContractMgt.ResponseField('lines', 'object', 'Component line counts by line type.');
                    Field.Add('children', AssemblyLineCountChildren());
                    Fields.Add(Field);
                    Field := ContractMgt.ResponseField('costs', 'object', 'Expected and actual cost breakdown and the unit cost of the order.');
                    Field.Add('children', AssemblyCostChildren());
                    Fields.Add(Field);
                end;
        end;
        Response.Add('fields', Fields);
    end;

    local procedure ItemChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Field: JsonObject;
    begin
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'The Item No.'));
        Children.Add(ContractMgt.ResponseField('itemSystemId', 'string', 'The Item SystemId.'));
        Field := ContractMgt.ResponseField('attributes', 'array', 'The attributes of the item that passed the filters.');
        Field.Add('children', AttributeValueChildren());
        Children.Add(Field);
    end;

    local procedure AttributeValueChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('attributeId', 'integer', 'Numeric attribute id.'));
        Children.Add(ContractMgt.ResponseField('attributeName', 'string', 'Attribute name.'));
        Children.Add(ContractMgt.ResponseField('type', 'string', 'Option, Text, Integer, Decimal or Date.'));
        Children.Add(ContractMgt.ResponseField('unitOfMeasure', 'string', 'Unit of measure of the definition.'));
        Children.Add(ContractMgt.ResponseField('valueId', 'integer', 'Id of the assigned value; 0 when no value is assigned.'));
        Children.Add(ContractMgt.ResponseField('value', 'string', 'The assigned value as text; empty when none.'));
        Children.Add(ContractMgt.ResponseField('numericValue', 'decimal', 'The number for Integer and Decimal attributes with a value; empty text otherwise.'));
        Children.Add(ContractMgt.ResponseField('dateValue', 'string', 'The date in YYYY-MM-DD format for Date attributes with a value; empty text otherwise.'));
    end;

    local procedure MappingResultChildren(ForUpdate: Boolean) Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('attributeName', 'string', 'Attribute name.'));
        Children.Add(ContractMgt.ResponseField('attributeId', 'integer', 'Numeric attribute id.'));
        Children.Add(ContractMgt.ResponseField('valueId', 'integer', 'Id of the value now assigned.'));
        if ForUpdate then begin
            Children.Add(ContractMgt.ResponseField('before', 'string', 'The value before the change; empty when it could not be read.'));
            Children.Add(ContractMgt.ResponseField('after', 'string', 'The value after the change.'));
        end else begin
            Children.Add(ContractMgt.ResponseField('value', 'string', 'The value now assigned.'));
            Children.Add(ContractMgt.ResponseField('changed', 'boolean', 'False when the item already had this value.'));
            Children.Add(ContractMgt.ResponseField('before', 'string', 'The replaced value; only when overwrite replaced a different value.'));
        end;
    end;

    local procedure CreatedValueChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('valueId', 'integer', 'Id of the created option value.'));
        Children.Add(ContractMgt.ResponseField('value', 'string', 'The created option value.'));
    end;

    local procedure TransferLineResponseChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('lineNo', 'integer', 'Line number; the first line is 10000 and each next one adds 10000.'));
        Children.Add(ContractMgt.ResponseField('itemNo', 'string', 'Item number.'));
        Children.Add(ContractMgt.ResponseField('description', 'string', 'Line description.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Quantity.'));
        Children.Add(ContractMgt.ResponseField('unitOfMeasureCode', 'string', 'Unit of measure code.'));
    end;

    local procedure QuantityTotalChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Sum of the line quantities.'));
    end;

    local procedure TransferPredictedChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('postedShipmentNo', 'string', 'Predicted shipment number; only for postingType Ship.'));
        Children.Add(ContractMgt.ResponseField('postedReceiptNo', 'string', 'Predicted receipt number; only for postingType Receive.'));
        Children.Add(ContractMgt.ResponseField('postedDirectTransferNo', 'string', 'Predicted direct transfer number; only for a direct transfer.'));
    end;

    local procedure AssemblyPredictedChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('postedAssemblyNo', 'string', 'Predicted posted assembly document number; empty when no assembly output entry was captured.'));
    end;

    local procedure PreviewTotalsChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('balanced', 'boolean', 'Whether the predicted G/L entries balance; only present when G/L entries were captured.'));
        Children.Add(ContractMgt.ResponseField('totalDebitLCY', 'decimal', 'Total predicted debit in local currency.'));
        Children.Add(ContractMgt.ResponseField('totalCreditLCY', 'decimal', 'Total predicted credit in local currency.'));
    end;

    local procedure PreviewTableChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('tableId', 'integer', 'Business Central table number of the captured entries.'));
        Children.Add(ContractMgt.ResponseField('tableName', 'string', 'Table name.'));
        Children.Add(ContractMgt.ResponseField('tableCaption', 'string', 'Table caption.'));
        Children.Add(ContractMgt.ResponseField('entryCount', 'integer', 'Number of captured entries in this table.'));
        Children.Add(ContractMgt.ResponseField('entries', 'array', 'The captured entries as field-value objects.'));
    end;

    local procedure TransferStatisticsChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Number of top-level lines.'));
        Children.Add(ContractMgt.ResponseField('quantity', 'decimal', 'Sum of the line quantities.'));
        Children.Add(ContractMgt.ResponseField('parcels', 'decimal', 'Sum of quantity divided by units per parcel, rounded up per line.'));
        Children.Add(ContractMgt.ResponseField('netWeight', 'decimal', 'Sum of line quantity times net weight.'));
        Children.Add(ContractMgt.ResponseField('grossWeight', 'decimal', 'Sum of line quantity times gross weight.'));
        Children.Add(ContractMgt.ResponseField('volume', 'decimal', 'Sum of line quantity times unit volume.'));
    end;

    local procedure AssemblyLineCountChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('total', 'integer', 'All component lines.'));
        Children.Add(ContractMgt.ResponseField('item', 'integer', 'Lines of type Item.'));
        Children.Add(ContractMgt.ResponseField('resource', 'integer', 'Lines of type Resource.'));
        Children.Add(ContractMgt.ResponseField('text', 'integer', 'Text lines (type blank).'));
    end;

    local procedure AssemblyCostChildren() Children: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Children.Add(ContractMgt.ResponseField('totalExpectedCost', 'decimal', 'Sum of the expected cost of the component lines.'));
        Children.Add(ContractMgt.ResponseField('totalActualCost', 'decimal', 'Sum of the actual costs below.'));
        Children.Add(ContractMgt.ResponseField('actualMaterialCost', 'decimal', 'Actual material cost.'));
        Children.Add(ContractMgt.ResponseField('actualResourceCost', 'decimal', 'Actual resource cost.'));
        Children.Add(ContractMgt.ResponseField('actualCapacityCost', 'decimal', 'Actual capacity cost.'));
        Children.Add(ContractMgt.ResponseField('actualCapacityOverhead', 'decimal', 'Actual capacity overhead.'));
        Children.Add(ContractMgt.ResponseField('actualMfgOverhead', 'decimal', 'Actual manufacturing overhead.'));
        Children.Add(ContractMgt.ResponseField('unitCost', 'decimal', 'Unit cost of the order.'));
        Children.Add(ContractMgt.ResponseField('indirectCostPercent', 'decimal', 'Indirect cost percentage of the order.'));
        Children.Add(ContractMgt.ResponseField('overheadRate', 'decimal', 'Overhead rate of the order.'));
    end;

    /// <summary>Builds the errors chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetErrors(MessageType: Text) Errors: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType in ['Item.Attribute.Get', 'Inventory.Attribute.Get', 'Item.Attribute.Create', 'Inventory.Attribute.Create', 'Item.Attribute.Update', 'Inventory.Attribute.Update'] then
            AddLookupErrors(Errors, 'Item');
        if MessageType in ['Inventory.TransferOrder.Release', 'Inventory.TransferOrder.Reopen', 'Inventory.TransferOrder.Post', 'Inventory.TransferOrder.PreviewPost', 'Inventory.TransferOrder.Statistics'] then
            AddDocumentLookupErrors(Errors, 'Transfer Header', 'transferOrderNo', '', '');
        if MessageType in ['Inventory.AssemblyOrder.RefreshLines', 'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen', 'Inventory.AssemblyOrder.Post', 'Inventory.AssemblyOrder.PreviewPost', 'Inventory.AssemblyOrder.Statistics'] then
            if MessageType = 'Inventory.AssemblyOrder.Post' then
                AddDocumentLookupErrors(Errors, 'Assembly Header', 'assemblyOrderNo', ' postingDate is not YYYY-MM-DD, or quantityToAssemble is not a number; nothing is posted.', ' Send postingDate as YYYY-MM-DD and quantityToAssemble as a JSON number.')
            else
                AddDocumentLookupErrors(Errors, 'Assembly Header', 'assemblyOrderNo', '', '');
        if MessageType in ['Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create', 'Inventory.AssemblyOrder.Create', 'Inventory.TransferOrder.Create'] then begin
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several independent request values are invalid; no header or definition is inserted.', 'Correct every errors[] entry before retrying.'));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A supplied text, number, boolean, date or array has the wrong JSON format.', 'Use the named parameter, received value, expected format and nextStep.'));
            Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'An item or location named in a create request does not exist.', 'Choose existing records and correct all reported values.'));
        end;
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
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The definition name is already used.', 'Use the existing definition or choose another name.'));
                end;
            'Inventory.TransferOrder.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'transferFromCode must be specified in the request JSON.', 'Send the source location code.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'transferToCode must be specified in the request JSON.', 'Send the destination location code.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'inTransitCode must be specified when directTransfer is false.', 'Send inTransitCode, or set directTransfer to true.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'directTransfer is not a boolean, a date key is not YYYY-MM-DD, or lines is not an array.', 'Send true or false, dates as YYYY-MM-DD and lines as an array.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidLine, 'One or more transfer lines are invalid.', 'Correct the reported line fields and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::LimitExceeded, 'A request can contain at most 200 lines.', 'Send no more than 200 lines.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Field %1 is restricted for write. Cannot use value ''%2''.', 'A field-level write restriction blocks the requested value.', 'Remove the restricted field or grant the required permission.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own validation error text.', 'Transfer Header validation rejected a location, date or other value.', 'Read the error text and correct the request.'));
                    AddDomainErrors(Errors, 'Transfer Orders', 'the caller cannot write Transfer Header records');
                end;
            'Inventory.TransferOrder.Release':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own release error text.', 'Business Central refused to release the order.', 'Read the error text and correct the order.'));
                    AddDomainErrors(Errors, 'Transfer Orders', 'the caller cannot write Transfer Header records');
                end;
            'Inventory.TransferOrder.Reopen':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own reopen error text.', 'Business Central refused to reopen the order.', 'Read the error text and correct the order.'));
                    AddDomainErrors(Errors, 'Transfer Orders', 'the caller cannot write Transfer Header records');
                end;
            'Inventory.TransferOrder.Post':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'For a non-direct transfer order, postingType must be "Ship" or "Receive".', 'postingType is missing for a non-direct transfer order.', 'Send postingType Ship or Receive, or create a direct transfer.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'postingType must be "Ship" or "Receive". Received: %1', 'postingType is not Ship or Receive (ShipReceive is refused too).', 'Send Ship or Receive in two separate calls.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own posting error text.', 'Business Central refused the posting, for example because the order is not ready to ship or receive.', 'Read the error text and correct the order or setup.'));
                    AddDomainErrors(Errors, 'Transfer Orders', 'the caller lacks BIFROST InvPost ori, which posting requires in addition to BIFROST Full ori');
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview produced no entries. Nothing would be posted.', 'Add a line quantity to ship or receive and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'Transfer order %1 has no lines to post.', 'The order has no lines.', 'Create the lines first and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'For a non-direct transfer order, postingType must be "Ship" or "Receive".', 'postingType is missing for a non-direct transfer order.', 'Send postingType Ship or Receive.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'postingType must be "Ship" or "Receive". Received: %1', 'postingType is neither Ship nor Receive.', 'Send Ship or Receive.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own posting error text.', 'The transfer posting preview failed.', 'Read the error text and correct the order or setup.'));
                    AddDomainErrors(Errors, 'Transfer Orders', 'the caller cannot read Transfer Header records');
                end;
            'Inventory.TransferOrder.Statistics':
                AddDomainErrors(Errors, 'Transfer Orders', 'the caller cannot read Transfer Header records');
            'Inventory.AssemblyOrder.Create':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A supplied quantity is zero or negative.', 'Send a quantity greater than zero.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'itemNo must be specified in the request JSON.', 'Send the parent item number.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'quantity must be specified and greater than 0 in the request JSON.', 'Send a positive quantity.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'quantity or quantityToAssemble is not a number, refreshLines is not a boolean, or a date key is not YYYY-MM-DD.', 'Send numbers as JSON numbers, true or false for refreshLines and dates as YYYY-MM-DD.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Field %1 is restricted for write. Cannot use value ''%2''.', 'A field-level write restriction blocks the requested value.', 'Remove the restricted field or grant the required permission.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own validation error text.', 'Assembly Header validation rejected the request.', 'Read the error text and correct the item, location, dates or quantity.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller cannot write Assembly Header records');
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own validation error text.', 'Business Central refused to re-validate the Item No. of the order.', 'Read the error text and correct the order.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller cannot write Assembly Header records');
                end;
            'Inventory.AssemblyOrder.Release':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own release error text.', 'Business Central refused to release the order.', 'Read the error text and correct the order.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller cannot write Assembly Header records');
                end;
            'Inventory.AssemblyOrder.Reopen':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own reopen error text.', 'Business Central refused to reopen the order.', 'Read the error text and correct the order.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller cannot write Assembly Header records');
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own posting error text.', 'Business Central refused the posting, for example because the components are not available.', 'Read the error text and correct the order or setup.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller lacks BIFROST InvPost ori, which posting requires in addition to BIFROST Full ori');
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'The preview produced no entries. Nothing would be posted.', 'Add a quantity to assemble and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::NothingToPreview, 'Assembly order %1 has no lines to post.', 'The order has no component lines.', 'Refresh the lines with Inventory.AssemblyOrder.RefreshLines and retry.'));
                    Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central''s own posting error text.', 'The assembly posting preview failed.', 'Read the error text and correct the order or setup.'));
                    AddDomainErrors(Errors, 'Assembly', 'the caller cannot read Assembly Header records');
                end;
            'Inventory.AssemblyOrder.Statistics':
                AddDomainErrors(Errors, 'Assembly', 'the caller cannot read Assembly Header records');
        end;
    end;

    local procedure AddDomainErrors(var Errors: JsonArray; DomainCaption: Text; PermissionReason: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter,
            'The ' + DomainCaption + ' domain is turned off for this company. Turn it on from Inventory Setup.',
            'The ' + DomainCaption + ' domain is turned off on the Inventory Setup page.', 'Turn the domain on from the Inventory Setup page.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied,
            'Permission denied for this inventory message type.',
            'The domain is on, but ' + PermissionReason + '.', 'Assign the missing permission set to the caller.'));
    end;

    local procedure AddDocumentLookupErrors(var Errors: JsonArray; RecordName: Text; DocumentAlias: Text; ExtraWhen: Text; ExtraNextStep: Text)
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
            'data is not a JSON object (parameter data); an identifier key under data (documentNo, ' + DocumentAlias + ', no, systemId, recordSystemId, id) is not a JSON string (null, a number, a boolean, an object or an array); or a SystemId is not a GUID. parameter names the key.' + ExtraWhen,
            'Send data as a JSON object, each identifier as a JSON string and a SystemId as a GUID. Nothing is looked up while one is wrong.' + ExtraNextStep));
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

    /// <summary>Builds the effect chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetEffect(MessageType: Text) Effect: JsonObject
    var
        Preconditions: JsonArray;
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                begin
                    SetEffect(Effect, 'read', 'Reads Item attribute definitions and the values assigned to the resolved Items. Nothing is changed.', true, 'BIFROST Read ori');
                    Preconditions.Add('The Attributes domain is turned on in Inventory Setup.');
                    Preconditions.Add('At least one Item matches the subject, identifiers or tableView.');
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    SetEffect(Effect, 'write', 'Assigns attribute values to one Item. A missing value is created (an Option value only when createValueIfMissing is set) and an existing different value is replaced only when overwrite is set. The Item must not be blocked unless allowBlocked is set.', false, 'BIFROST Full ori');
                    Preconditions.Add('The Attributes domain is turned on in Inventory Setup.');
                    Preconditions.Add('The Item exists and is not blocked, or allowBlocked is true.');
                    Preconditions.Add('Each attribute definition already exists; create it with Inventory.AttributeDefinition.Create.');
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    SetEffect(Effect, 'write', 'Replaces the value of attribute mappings the Item already has. A missing value is created (an Option value only when createValueIfMissing is set). The Item must not be blocked unless allowBlocked is set.', false, 'BIFROST Full ori');
                    Preconditions.Add('The Attributes domain is turned on in Inventory Setup.');
                    Preconditions.Add('The Item exists and is not blocked, or allowBlocked is true.');
                    Preconditions.Add('The Item already has a mapping for each attribute; use Inventory.Attribute.Create for a new one.');
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    SetEffect(Effect, 'write', 'Creates one Item Attribute definition and, for type Option, the listed option values. No Item is changed.', false, 'BIFROST Full ori');
                    Preconditions.Add('The Attributes domain is turned on in Inventory Setup.');
                    Preconditions.Add('No attribute definition with the same name exists.');
                end;
            'Inventory.TransferOrder.Create':
                begin
                    SetEffect(Effect, 'write', 'Creates a Transfer Header with a new number from the number series and, when lines are sent, the Transfer Lines. Nothing is posted.', false, 'BIFROST Full ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The locations and items sent exist.');
                end;
            'Inventory.TransferOrder.Release':
                begin
                    SetEffect(Effect, 'write', 'Changes the status of the Transfer Header from Open to Released. An order that is already Released is returned unchanged.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists and passes the release checks of Business Central.');
                end;
            'Inventory.TransferOrder.Reopen':
                begin
                    SetEffect(Effect, 'write', 'Changes the status of the Transfer Header from Released to Open. An order that is already Open is returned unchanged.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists.');
                end;
            'Inventory.TransferOrder.Post':
                begin
                    SetEffect(Effect, 'irreversible', 'Posts the Transfer Order as a shipment, a receipt or a direct transfer: creates the posted transfer shipment, receipt or direct transfer document with its item ledger and value entries, and updates or deletes the order. The call commits and ignores Omit Commit; the posting cannot be rolled back afterwards.', false, 'BIFROST Full ori and BIFROST InvPost ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The caller holds BIFROST InvPost ori in addition to BIFROST Full ori.');
                    Preconditions.Add('The order has lines and is ready to be shipped or received.');
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    SetEffect(Effect, 'read', 'Simulates posting inside a transaction that is always rolled back. Nothing is written, including posted document numbers.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order has at least one line.');
                end;
            'Inventory.TransferOrder.Statistics':
                begin
                    SetEffect(Effect, 'read', 'Reads the lines of the Transfer Order and sums quantity, parcels, weights and volume. Nothing is changed.', true, 'BIFROST Read ori');
                    Preconditions.Add('The Transfer Orders domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists.');
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    SetEffect(Effect, 'write', 'Creates an Assembly Header with a new number from the number series and its component lines from the BOM of the parent item. Nothing is posted.', false, 'BIFROST Full ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The parent item exists and has an assembly BOM.');
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                begin
                    SetEffect(Effect, 'write', 'Re-validates the Item No. of the Assembly Header so Business Central rebuilds the component lines from the BOM of the parent item.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists.');
                end;
            'Inventory.AssemblyOrder.Release':
                begin
                    SetEffect(Effect, 'write', 'Changes the status of the Assembly Header from Open to Released. An order that is already Released is returned unchanged.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists and passes the release checks of Business Central.');
                end;
            'Inventory.AssemblyOrder.Reopen':
                begin
                    SetEffect(Effect, 'write', 'Changes the status of the Assembly Header from Released to Open. An order that is already Open is returned unchanged.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists.');
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    SetEffect(Effect, 'irreversible', 'Posts the Assembly Order: creates the posted assembly order with the item ledger and value entries for consumption and output. When quantityToAssemble is sent it is first written to the order. The call commits before posting starts and ignores Omit Commit; the posting cannot be rolled back afterwards.', false, 'BIFROST Full ori and BIFROST InvPost ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The caller holds BIFROST InvPost ori in addition to BIFROST Full ori.');
                    Preconditions.Add('The components are available and the order has a quantity to assemble.');
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    SetEffect(Effect, 'read', 'Simulates posting inside a transaction that is always rolled back. Nothing is written, including posted document numbers.', true, 'BIFROST Full ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order has at least one component line.');
                end;
            'Inventory.AssemblyOrder.Statistics':
                begin
                    SetEffect(Effect, 'read', 'Reads the Assembly Header, counts the component lines and sums the expected and actual cost. Nothing is changed.', true, 'BIFROST Read ori');
                    Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
                    Preconditions.Add('The order exists.');
                end;
        end;
        Effect.Add('preconditions', Preconditions);
    end;

    local procedure SetEffect(var Effect: JsonObject; EffectKind: Text; Changes: Text; Idempotent: Boolean; PermissionSetName: Text)
    begin
        Effect.Add('effect', EffectKind);
        Effect.Add('changes', Changes);
        Effect.Add('idempotent', Idempotent);
        Effect.Add('permissionSet', PermissionSetName);
    end;

    /// <summary>Builds the related chapter for matching Inventory and legacy Item helper selectors.</summary>
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
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Create', 'Create a new assembly order.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Statistics', 'Inspect the line counts and costs after the refresh.'));
                end;
            'Inventory.AssemblyOrder.Release':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Reopen', 'Reopen the order for editing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Post the released order.'));
                end;
            'Inventory.AssemblyOrder.Reopen':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Release', 'Release the order again after editing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.RefreshLines', 'Rebuild the component lines after changing the order.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting without committing.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Release', 'Release the order first when your process posts only released orders.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Actually post after the preview is correct.'));
            'Inventory.AssemblyOrder.Statistics':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.PreviewPost', 'Preview predicted entries.'));
                    Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Post', 'Post the order.'));
                end;
        end;
    end;

    /// <summary>Builds the workflow chapter for matching Inventory and legacy Item helper selectors.</summary>
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
            'Inventory.TransferOrder.Release':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Create', 'Create the order and its lines.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Release', 'Release the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship or receive the released order.'));
                end;
            'Inventory.TransferOrder.Reopen':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Reopen', 'Reopen the released order so it can be edited.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Release', 'Release the order again when the edits are done.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Ship or receive the order.'));
                end;
            'Inventory.TransferOrder.Post':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Statistics', 'Check quantities and totals.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Post with postingType Ship, then again with Receive.'));
                end;
            'Inventory.TransferOrder.PreviewPost':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Statistics', 'Check quantities and totals.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Post after the preview is acceptable.'));
                end;
            'Inventory.TransferOrder.Statistics':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Statistics', 'Read the totals of the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.TransferOrder.Post', 'Post after the preview is acceptable.'));
                end;
            'Inventory.AssemblyOrder.Create':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Create', 'Create the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Release', 'Release the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post the assembly order.'));
                end;
            'Inventory.AssemblyOrder.RefreshLines':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Create', 'Create the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.RefreshLines', 'Rebuild the component lines after the BOM changed.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Release', 'Release the order.'));
                end;
            'Inventory.AssemblyOrder.Release':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Create', 'Create the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Release', 'Release the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post the released order.'));
                end;
            'Inventory.AssemblyOrder.Reopen':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Reopen', 'Reopen the released order so it can be edited.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.RefreshLines', 'Rebuild the component lines.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Release', 'Release the order again.'));
                end;
            'Inventory.AssemblyOrder.Post':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Statistics', 'Inspect the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post the assembly order.'));
                end;
            'Inventory.AssemblyOrder.PreviewPost':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Statistics', 'Inspect the assembly order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post after the preview is acceptable.'));
                end;
            'Inventory.AssemblyOrder.Statistics':
                begin
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Statistics', 'Read the line counts and costs of the order.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.PreviewPost', 'Preview the posting.'));
                    Steps.Add(ContractMgt.WorkflowStep('Inventory.AssemblyOrder.Post', 'Post after the preview is acceptable.'));
                end;
            else
                exit;
        end;
        Workflow.Add('steps', Steps);
    end;

    /// <summary>Builds the examples chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetExamples(MessageType: Text) Examples: JsonArray
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        case MessageType of
            'Item.Attribute.Get', 'Inventory.Attribute.Get':
                Examples.Add(ContractMgt.Example('Read item attributes', '{"type":"Inventory.Attribute.Get","subject":"1000","data":{"includeUnassigned":true}}', '{"status":"Success","items":[]}'));
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                Examples.Add(ContractMgt.Example('Create an option definition', '{"type":"Inventory.AttributeDefinition.Create","data":{"name":"Finish","type":"Option","optionValues":["Matte","Gloss"]}}', '{"status":"Success","attributeId":2,"attributeName":"Finish","type":"Option","createdValues":[]}'));
            'Inventory.TransferOrder.Create':
                Examples.Add(ContractMgt.Example('Create a transfer order', '{"type":"Inventory.TransferOrder.Create","data":{"transferFromCode":"BLUE","transferToCode":"RED","directTransfer":true}}', '{"status":"Success","documentNo":"TO000456","statusAfter":"Open"}'));
            'Inventory.TransferOrder.Release':
                Examples.Add(ContractMgt.Example('Release a transfer order', '{"type":"Inventory.TransferOrder.Release","data":{"documentNo":"TO000456"}}', '{"status":"Success","documentNo":"TO000456","transferFromCode":"BLUE","transferToCode":"RED","directTransfer":true,"statusBefore":"Open","statusAfter":"Released"}'));
            'Inventory.TransferOrder.Reopen':
                Examples.Add(ContractMgt.Example('Reopen a transfer order', '{"type":"Inventory.TransferOrder.Reopen","data":{"documentNo":"TO000456"}}', '{"status":"Success","documentNo":"TO000456","transferFromCode":"BLUE","transferToCode":"RED","directTransfer":true,"statusBefore":"Released","statusAfter":"Open"}'));
            'Inventory.TransferOrder.Post':
                Examples.Add(ContractMgt.Example('Ship a released transfer order', '{"type":"Inventory.TransferOrder.Post","data":{"documentNo":"TO000456","postingType":"Ship"}}', '{"status":"Success","documentNo":"TO000456","postingType":"Ship","directTransfer":false,"postedShipmentNo":"109001","postedReceiptNo":"","orderDeleted":false,"postingDate":"2026-10-22"}'));
            'Inventory.TransferOrder.PreviewPost':
                Examples.Add(ContractMgt.Example('Preview shipping a transfer order', '{"type":"Inventory.TransferOrder.PreviewPost","data":{"documentNo":"TO000456","postingType":"Ship"}}', '{"status":"Success","entryCount":2,"glEntryCount":0,"rollback":true,"documentNo":"TO000456","postingType":"Ship","predictedNumbers":{"postedShipmentNo":"109001"}}'));
            'Inventory.TransferOrder.Statistics':
                Examples.Add(ContractMgt.Example('Read transfer order totals', '{"type":"Inventory.TransferOrder.Statistics","data":{"documentNo":"TO000456"}}', '{"status":"Success","documentNo":"TO000456","directTransfer":false,"statusValue":"Released","totals":{"lineCount":1,"quantity":10,"parcels":0,"netWeight":0,"grossWeight":0,"volume":0}}'));
            'Inventory.AssemblyOrder.Create':
                Examples.Add(ContractMgt.Example('Create an assembly order', '{"type":"Inventory.AssemblyOrder.Create","data":{"itemNo":"1000","quantity":1}}', '{"status":"Success","documentNo":"AO000456","statusAfter":"Open"}'));
            'Inventory.AssemblyOrder.RefreshLines':
                Examples.Add(ContractMgt.Example('Refresh the component lines', '{"type":"Inventory.AssemblyOrder.RefreshLines","data":{"documentNo":"AO000456"}}', '{"status":"Success","documentNo":"AO000456","itemNo":"1000","quantity":1,"linesBefore":3,"linesAfter":3}'));
            'Inventory.AssemblyOrder.Release':
                Examples.Add(ContractMgt.Example('Release an assembly order', '{"type":"Inventory.AssemblyOrder.Release","data":{"documentNo":"AO000456"}}', '{"status":"Success","documentNo":"AO000456","itemNo":"1000","statusBefore":"Open","statusAfter":"Released"}'));
            'Inventory.AssemblyOrder.Reopen':
                Examples.Add(ContractMgt.Example('Reopen an assembly order', '{"type":"Inventory.AssemblyOrder.Reopen","data":{"documentNo":"AO000456"}}', '{"status":"Success","documentNo":"AO000456","itemNo":"1000","statusBefore":"Released","statusAfter":"Open"}'));
            'Inventory.AssemblyOrder.Post':
                Examples.Add(ContractMgt.Example('Post an assembly order', '{"type":"Inventory.AssemblyOrder.Post","data":{"documentNo":"AO000456","postingDate":"2026-10-22"}}', '{"status":"Success","documentNo":"AO000456","postedDocumentNo":"32000001","itemNo":"1000","postingDate":"2026-10-22","assembleToOrder":false}'));
            'Inventory.AssemblyOrder.PreviewPost':
                Examples.Add(ContractMgt.Example('Preview posting an assembly order', '{"type":"Inventory.AssemblyOrder.PreviewPost","data":{"documentNo":"AO000456"}}', '{"status":"Success","entryCount":4,"glEntryCount":0,"rollback":true,"documentNo":"AO000456","itemNo":"1000","predictedNumbers":{"postedAssemblyNo":"32000001"}}'));
            'Inventory.AssemblyOrder.Statistics':
                Examples.Add(ContractMgt.Example('Read assembly order statistics', '{"type":"Inventory.AssemblyOrder.Statistics","data":{"documentNo":"AO000456"}}', '{"status":"Success","documentNo":"AO000456","itemNo":"1000","quantity":1,"status_":"Open","lines":{"total":3,"item":3,"resource":0,"text":0}}'));
        end;
    end;

    /// <summary>Builds the overview chapter for matching Inventory and legacy Item helper selectors.</summary>
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

    /// <summary>Builds the notes chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetNotes(MessageType: Text) Notes: Text
    begin
        case MessageType of
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                Notes := AttributeCreateNotesLbl;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                Notes := AttributeUpdateNotesLbl;
            'Inventory.TransferOrder.Create':
                Notes := TransferCreateNotesLbl;
            'Inventory.TransferOrder.Release':
                Notes := 'Releases an Open transfer order. An order that is already Released is answered with Success and no change, with statusBefore and statusAfter both Released. Business Central''s own release checks apply and a failure is returned as its error text. The order is not posted; use Inventory.TransferOrder.Post to ship or receive it.';
            'Inventory.TransferOrder.Reopen':
                Notes := 'Reopens a Released transfer order. An order that is already Open is answered with Success and no change, with statusBefore and statusAfter both Open. Business Central''s own checks apply and a failure is returned as its error text. Use Inventory.TransferOrder.Release to release the order again.';
            'Inventory.TransferOrder.Post':
                Notes := TransferPostNotesLbl;
            'Inventory.TransferOrder.PreviewPost':
                Notes := TransferPreviewNotesLbl;
            'Inventory.TransferOrder.Statistics':
                Notes := 'Reads only, in any status. The totals cover the top-level lines of the order; lines derived from another line are not counted. parcels is each line''s quantity divided by its units per parcel, rounded up per line. netWeight, grossWeight and volume are the line quantity times the item''s net weight, gross weight and unit volume. The order status is returned in statusValue.';
            'Inventory.AssemblyOrder.Create':
                Notes := AssemblyCreateNotesLbl;
            'Inventory.AssemblyOrder.RefreshLines':
                Notes := 'The call takes no data key besides the order identifier. It re-validates the parent Item No. on the order so Business Central rebuilds the component lines from the BOM; linesBefore and linesAfter show the result. Repeating the call gives the same result.';
            'Inventory.AssemblyOrder.Release':
                Notes := 'Releases an Open assembly order. An order that is already Released is answered with Success and no change, with statusBefore and statusAfter both Released. Business Central''s own release checks apply and a failure is returned as its error text. The order is not posted; use Inventory.AssemblyOrder.Post.';
            'Inventory.AssemblyOrder.Reopen':
                Notes := 'Reopens a Released assembly order. An order that is already Open is answered with Success and no change, with statusBefore and statusAfter both Open. Business Central''s own checks apply and a failure is returned as its error text. Use Inventory.AssemblyOrder.Release to release the order again.';
            'Inventory.AssemblyOrder.Post':
                Notes := AssemblyPostNotesLbl;
            'Inventory.AssemblyOrder.PreviewPost':
                Notes := AssemblyPreviewNotesLbl;
            'Inventory.AssemblyOrder.Statistics':
                Notes := 'Reads only, in any status. lines counts the component lines by type. costs.totalExpectedCost sums the expected cost of the component lines and costs.totalActualCost the actual costs posted so far. The order status is returned in status_, because status holds the call result.';
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
    /// <summary>Reads a bounded JSON string and collects every invalid value before the caller writes.</summary>
    procedure ReadRequestText(Request: JsonObject; Name: Text; var Argument: Record "Message Argument ori"; Required: Boolean; MaximumLength: Integer): Text
    var
        Token: JsonToken;
        Serialized: Text;
        Value: Text;
        MissingErr: Label '%1 is required.', Comment = '%1 = parameter name; is-IS=%1 er nauðsynlegt.';
        FormatErr: Label '%1 must be text of at most %2 characters.', Comment = '%1 = parameter name, %2 = maximum length; is-IS=%1 verður að vera texti með að hámarki %2 stöfum.';
        ExpectedTxt: Label 'A JSON string of at most %1 characters.', Comment = '%1 = maximum length; is-IS=JSON-strengur með að hámarki %1 stöfum.';
        NextStepTxt: Label 'Send %1 as text in the documented format.', Comment = '%1 = parameter name; is-IS=Sendu %1 sem texta á skjalfestu sniði.';
    begin
        if not Request.Get(Name, Token) then begin
            if Required then
                Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, Name), Name, '<missing>', StrSubstNo(ExpectedTxt, MaximumLength), StrSubstNo(NextStepTxt, Name));
            exit('');
        end;
        Token.WriteTo(Serialized);
        if not Token.IsValue() or not Serialized.StartsWith('"') then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatErr, Name, MaximumLength), Name, Serialized, StrSubstNo(ExpectedTxt, MaximumLength), StrSubstNo(NextStepTxt, Name));
            exit('');
        end;
        Value := Token.AsValue().AsText();
        if StrLen(Value) > MaximumLength then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(FormatErr, Name, MaximumLength), Name, Value, StrSubstNo(ExpectedTxt, MaximumLength), StrSubstNo(NextStepTxt, Name));
            exit('');
        end;
        if Required and (Value = '') then
            Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, Name), Name, Serialized, StrSubstNo(ExpectedTxt, MaximumLength), StrSubstNo(NextStepTxt, Name));
        exit(Value);
    end;

    /// <summary>Responds once with every collected request problem; single errors retain their specific code.</summary>
    procedure RespondToProblems(var Argument: Record "Message Argument ori"): Boolean
    var
        ProblemsErr: Label 'Correct the reported request values before retrying.', Comment = 'is-IS=Leiðréttu tilgreind gildi beiðninnar áður en þú reynir aftur.';
    begin
        if not Argument.HasCollectedErrors() then
            exit(false);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, ProblemsErr);
        exit(true);
    end;

    /// <summary>Preserves a collected refusal and adds caller context only to an otherwise context-free native failure.</summary>
    procedure RespondWithNativeContext(var Argument: Record "Message Argument ori"; Parameter: Text; Received: Text; Expected: Text; NextStep: Text)
    var
        Response: JsonObject;
        Token: JsonToken;
    begin
        Argument.RespondWithLastError();
        Response := Argument.GetResponseJson();
        if not Response.Get('code', Token) then
            exit;
        if Token.AsValue().AsText() <> 'BusinessCentralError' then
            exit;
        AddMissingContext(Response, 'parameter', Parameter);
        AddMissingContext(Response, 'received', Received);
        AddMissingContext(Response, 'expected', Expected);
        AddMissingContext(Response, 'nextStep', NextStep);
        Argument.SetResponseJson(Response);
    end;

    local procedure AddMissingContext(var Response: JsonObject; Name: Text; Value: Text)
    var
        Token: JsonToken;
    begin
        if not Response.Get(Name, Token) then
            Response.Add(Name, Value)
        else
            if Token.AsValue().AsText() = '' then
                Response.Replace(Name, Value);
    end;

}
