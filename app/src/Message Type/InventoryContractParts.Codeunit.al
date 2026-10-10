namespace Origo.Bifrost.Inventory;

using Origo.Bifrost;

/// <summary>Builds shared contract chapters for the Inventory message types.</summary>
codeunit 70013445 "Inventory Contract Parts ori"
{
    Access = Internal;

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
            AddLookupErrors(Errors, 'Transfer Header');
        if MessageType in ['Inventory.AssemblyOrder.RefreshLines', 'Inventory.AssemblyOrder.Release', 'Inventory.AssemblyOrder.Reopen', 'Inventory.AssemblyOrder.Post', 'Inventory.AssemblyOrder.PreviewPost', 'Inventory.AssemblyOrder.Statistics'] then
            AddLookupErrors(Errors, 'Assembly Header');
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
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Create', 'Assign a missing attribute value.'));
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Update', 'Replace an existing attribute mapping.'));
                    Related.Add(ContractMgt.RelatedEntry('Item.AttributeDefinition.Create', 'Create a new attribute definition.'));
                end;
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Update', 'Change an existing mapping instead of creating it.'));
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Get', 'Read assigned and unassigned values.'));
                end;
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Create', 'Create a mapping that does not exist.'));
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Get', 'Read the current mapping first.'));
                end;
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                begin
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Get', 'Read definitions and values.'));
                    Related.Add(ContractMgt.RelatedEntry('Item.Attribute.Create', 'Assign the new definition to an item.'));
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
                Overview := 'Reads attribute definitions and assigned values for one or more Items without changing Business Central data.';
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                Overview := 'Assigns one or more attribute values to an Item. Existing equal mappings are idempotent; conflicts require overwrite or the update message.';
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                Overview := 'Changes existing Item attribute mappings and returns the resulting values. Use Item.Attribute.Create when a mapping does not exist.';
            'Item.AttributeDefinition.Create', 'Inventory.AttributeDefinition.Create':
                Overview := 'Creates an Item Attribute definition and optional Option values independently of an Item.';
            'Inventory.TransferOrder.Create':
                Overview := 'Creates a Transfer Order header and optional lines. The call allocates a new document number and is not idempotent.';
            'Inventory.TransferOrder.Release':
                Overview := 'Releases an open Transfer Order so it can be posted.';
            'Inventory.TransferOrder.Reopen':
                Overview := 'Reopens a released Transfer Order so it can be edited again.';
            'Inventory.TransferOrder.Post':
                Overview := 'Posts a Transfer Order as Ship, Receive or direct transfer and writes the corresponding inventory documents and ledger entries.';
            'Inventory.TransferOrder.PreviewPost':
                Overview := 'Simulates Transfer Order posting, returns predicted entries and always rolls back the transaction.';
            'Inventory.TransferOrder.Statistics':
                Overview := 'Reads Transfer Order line counts, quantities, parcels, weights and volume without writing data.';
            'Inventory.AssemblyOrder.Create':
                Overview := 'Creates an Assembly Order for a parent Item and optionally refreshes its component lines from the BOM.';
            'Inventory.AssemblyOrder.RefreshLines':
                Overview := 'Refreshes Assembly Order component lines from the parent Item BOM.';
            'Inventory.AssemblyOrder.Release':
                Overview := 'Releases an open Assembly Order so it can be posted.';
            'Inventory.AssemblyOrder.Reopen':
                Overview := 'Reopens a released Assembly Order so it can be edited again.';
            'Inventory.AssemblyOrder.Post':
                Overview := 'Posts an Assembly Order and returns the posted document number.';
            'Inventory.AssemblyOrder.PreviewPost':
                Overview := 'Simulates Assembly Order posting and returns predicted entries without committing changes.';
            'Inventory.AssemblyOrder.Statistics':
                Overview := 'Reads Assembly Order header, line-count and cost statistics without writing data.';
        end;
    end;

    /// <summary>Builds the existing notes chapter for matching Inventory and legacy Item helper selectors.</summary>
    procedure GetNotes(MessageType: Text) Notes: Text
    begin
        case MessageType of
            'Item.Attribute.Create', 'Inventory.Attribute.Create':
                Notes := 'Attribute values are typed according to the definition. Set createValueIfMissing on an attribute object when an Option value may need to be created. Blocked items require allowBlocked.';
            'Item.Attribute.Update', 'Inventory.Attribute.Update':
                Notes := 'Update is intentionally limited to mappings that already exist. The operation is isolated through its write process.';
            'Inventory.TransferOrder.Create':
                Notes := 'The request is all-or-nothing. When lines are supplied, field names are camelCase and the line limit is 200. Dates use YYYY-MM-DD.';
            'Inventory.TransferOrder.Post':
                Notes := 'Non-direct orders require postingType Ship or Receive. Direct transfers use Inventory Setup direct-transfer posting configuration.';
            'Inventory.TransferOrder.PreviewPost':
                Notes := 'A successful preview includes rollback true. Nothing is persisted, including posted document numbers.';
            'Inventory.AssemblyOrder.Create':
                Notes := 'refreshLines defaults to true. PostingDate defaults to WorkDate when omitted. Quantity must be positive.';
            'Inventory.AssemblyOrder.Post':
                Notes := 'The posting gate requires BIFROST InvPost ori. Optional postingDate and quantityToAssemble are applied before posting.';
            'Inventory.AssemblyOrder.PreviewPost':
                Notes := 'The preview is rolled back and does not create posted documents or ledger entries.';
        end;
    end;
}