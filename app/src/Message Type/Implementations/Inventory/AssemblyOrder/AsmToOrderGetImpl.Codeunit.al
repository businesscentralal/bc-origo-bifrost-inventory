namespace Origo.Bifrost.Inventory;

using Microsoft.Assembly.Document;
using Microsoft.Inventory.BOM;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Inventory.AssemblyToOrder.Get. Answers the assembly order linked to a sales line through the Assemble-to-Order Link
/// (table 904), with its lines. Read only.
/// </summary>
codeunit 10076965 "Asm. To Order Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        DocumentTypeKeyTok: Label 'documentType', Locked = true;
        DocumentNoKeyTok: Label 'documentNo', Locked = true;
        LineNoKeyTok: Label 'lineNo', Locked = true;
        TextExpectedTok: Label 'text', Locked = true;
        IntegerExpectedTok: Label 'integer', Locked = true;
        DocumentTypeExpectedLbl: Label 'Quote, Order or Blanket Order', Comment = 'is-IS=Quote, Order eða Blanket Order';
        PermissionSetTok: Label 'BIFROST InvRead ori', Locked = true;

    /// <summary>Reports discovery availability without reading setup for an unauthorized caller.</summary>
    procedure IsEnabled(): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not InventorySetup.ReadPermission() then
            exit(false);
        if not DomainGate.IsEnabled("Inventory Domain ori"::Assembly, Database::"Assembly Header", false, false) then
            exit(false);
        exit(CanReadSources());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Sales Line");
    end;

    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Answers the assemble-to-order assembly order linked to a sales line, with its lines.', Comment = 'is-IS=Svarar samsetningarpöntuninni sem er tengd sölulínu með samsetningu eftir pöntun, ásamt línum hennar.';
    begin
        exit(DescriptionLbl);
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'assemble to order, ATO, assembly order, sales line, kit', Comment = 'is-IS=samsetning eftir pöntun, ATO, samsetningarpöntun, sölulína, samsett vara';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Reads which assembly order belongs to a sales line and the components on it, without changing anything.', Comment = 'is-IS=Les hvaða samsetningarpöntun tilheyrir sölulínu og íhlutina á henni, án þess að breyta neinu.';
    begin
        exit(SelectionLbl);
    end;

    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Clear(Envelope);
        Envelope.ReadFrom('{"subject":{"use":"notUsed","forms":[],"description":"Subject is not read; the sales line is named in data.documentType, data.documentNo and data.lineNo."},"dataRequired":true,"version":"1.0","contentType":"text/json"}');
        exit(true);
    end;

    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TargetLbl: Label 'The sales line whose assemble-to-order link is read.', Comment = 'is-IS=Sölulínan sem tenging samsetningar eftir pöntun er lesin fyrir.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.documentNo', 'text', TargetLbl));
        exit(true);
    end;

    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        DocumentTypeLbl: Label 'The sales document type: Quote, Order or Blanket Order. Leave it out for Order.', Comment = 'is-IS=Tegund sölugagns: Quote, Order eða Blanket Order. Slepptu henni fyrir Order.';
        DocumentNoLbl: Label 'The sales document number.', Comment = 'is-IS=Númer sölugagnsins.';
        LineNoLbl: Label 'The line number of the sales line, as a whole number.', Comment = 'is-IS=Línunúmer sölulínunnar, sem heil tala.';
    begin
        Parameters.Add(ContractMgt.Parameter('documentType', 'string', false, DocumentTypeLbl));
        Parameters.Add(ContractMgt.Parameter('documentNo', 'string', true, DocumentNoLbl));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, LineNoLbl));
        exit(true);
    end;

    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Clear(Response);
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('documentType', 'string', 'The sales document type: Quote, Order or Blanket Order.'));
        Fields.Add(ContractMgt.ResponseField('documentNo', 'string', 'The sales document number.'));
        Fields.Add(ContractMgt.ResponseField('lineNo', 'integer', 'The sales line number.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The No. on the sales line.'));
        Fields.Add(ContractMgt.ResponseField('qtyToAssembleToOrder', 'decimal', 'Qty. to Assemble to Order on the sales line.'));
        Fields.Add(ContractMgt.ResponseField('linked', 'boolean', 'true when an assembly order is linked to the sales line; false when none is.'));
        Fields.Add(ContractMgt.ResponseField('assemblyOrder', 'object', 'The linked assembly header: documentType, documentNo, systemId, itemNo, variantCode, description, locationCode, unitOfMeasureCode, quantity, quantityToAssemble, assembledQuantity, remainingQuantity, orderStatus (Open or Released), dueDate, startingDate and endingDate. Empty object when linked is false.'));
        Fields.Add(ContractMgt.ResponseField('lines', 'array', 'The assembly lines: lineNo, type (Item, Resource, or empty for a text line), no, variantCode, description, locationCode, unitOfMeasureCode, quantityPer, quantity, quantityBase, remainingQuantity, consumedQuantity, dueDate, unitCost and costAmount. Empty when linked is false.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingWhenLbl: Label 'documentNo or lineNo is missing or empty.', Comment = 'is-IS=documentNo eða lineNo vantar eða er tómt.';
        MissingFixLbl: Label 'Send documentNo and lineNo.', Comment = 'is-IS=Sendu documentNo og lineNo.';
        FormatWhenLbl: Label 'A key has the wrong JSON type, lineNo is not a whole number, or documentType is not Quote, Order or Blanket Order.', Comment = 'is-IS=Lykill er á rangri JSON-gerð, lineNo er ekki heil tala, eða documentType er ekki Quote, Order eða Blanket Order.';
        FormatFixLbl: Label 'Send documentType and documentNo as text, documentType as Quote, Order or Blanket Order, and lineNo as a whole number.', Comment = 'is-IS=Sendu documentType og documentNo sem texta, documentType sem Quote, Order eða Blanket Order, og lineNo sem heila tölu.';
        UnknownWhenLbl: Label 'The request contains a key this type does not read.', Comment = 'is-IS=Beiðnin inniheldur lykil sem þessi tegund les ekki.';
        UnknownFixLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo and lineNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo og lineNo.';
        NotFoundWhenLbl: Label 'The sales line does not exist, or the linked assembly order is missing.', Comment = 'is-IS=Sölulínan er ekki til, eða tengda samsetningarpöntunin vantar.';
        NotFoundFixLbl: Label 'Check documentType, documentNo and lineNo.', Comment = 'is-IS=Athugaðu documentType, documentNo og lineNo.';
        DomainWhenLbl: Label 'The Assembly domain is turned off in Inventory Setup.', Comment = 'is-IS=Slökkt er á samsetningarsviðinu í Uppsetningu birgða.';
        DomainFixLbl: Label 'Ask an administrator to turn the Assembly domain on from the Inventory Setup page.', Comment = 'is-IS=Biddu kerfisstjóra að kveikja á samsetningarsviðinu á síðunni Uppsetning birgða.';
        PermissionWhenLbl: Label 'The caller cannot read sales lines, assemble-to-order links, assembly headers or assembly lines.', Comment = 'is-IS=Kallandinn getur ekki lesið sölulínur, tengingar samsetningar eftir pöntun, samsetningarhausa eða samsetningarlínur.';
        PermissionFixLbl: Label 'Assign the Bifrost "Read-Only" permission set (extended by Inventory read permissions) and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst (með viðbótinni lesheimildir birgða) og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingWhenLbl, MissingFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, FormatWhenLbl, FormatFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, UnknownWhenLbl, UnknownFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundWhenLbl, NotFoundFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, DomainWhenLbl, DomainFixLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionWhenLbl, PermissionFixLbl));
        exit(true);
    end;

    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Clear(Effect);
        Effect.Add('effect', 'read');
        Effect.Add('writes', false);
        Effect.Add('posts', false);
        Effect.Add('changes', 'None. The call only reads the sales line, the assemble-to-order link and the assembly order.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Preconditions.Add('The Assembly domain is turned on in Inventory Setup.');
        Preconditions.Add('The caller can read sales lines, assemble-to-order links, assembly headers and assembly lines.');
        Effect.Add('preconditions', Preconditions);
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
        Clear(Related);
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyBOM.Get', 'Use it for the assembly BOM of the item on the sales line.'));
        Related.Add(ContractMgt.RelatedEntry('Inventory.AssemblyOrder.Statistics', 'Use it for the quantities and cost breakdown of the linked assembly order.'));
        exit(true);
    end;

    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        TitleLbl: Label 'Read the assembly order of sales order line 10000', Comment = 'is-IS=Lesa samsetningarpöntun sölupöntunarlínu 10000';
    begin
        Clear(Examples);
        Examples.Add(ContractMgt.Example(TitleLbl,
            '{"type":"Inventory.AssemblyToOrder.Get","data":{"documentType":"Order","documentNo":"101005","lineNo":10000}}',
            '{"status":"Success","documentType":"Order","documentNo":"101005","lineNo":10000,"itemNo":"1925-W","qtyToAssembleToOrder":2,"linked":true,"assemblyOrder":{"documentType":"Order","documentNo":"A00012","itemNo":"1925-W","quantity":2,"orderStatus":"Open"},"lines":[{"lineNo":10000,"type":"Item","no":"1906-S","unitOfMeasureCode":"PCS","quantityPer":1,"quantity":2}]}'));
        exit(true);
    end;

    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Answers which assembly order is linked to a sales quote, order or blanket order line through assemble to order, with the assembly header and its lines. A sales line without a link answers linked false. Nothing is changed.', Comment = 'is-IS=Svarar hvaða samsetningarpöntun er tengd línu í sölutilboði, sölupöntun eða standandi pöntun með samsetningu eftir pöntun, ásamt samsetningarhausnum og línum hans. Sölulína án tengingar svarar linked false. Engu er breytt.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'documentType, type and orderStatus are fixed English names, not captions. Quantities on the lines are in their unit of measure; quantityBase is in the base unit of the component. Project (job) planning lines are not read by this type.', Comment = 'is-IS=documentType, type og orderStatus eru föst ensk heiti, ekki skjátextar. Magn á línum er í mælieiningu þeirra; quantityBase er í grunnmælieiningu íhlutarins. Áætlunarlínur verka eru ekki lesnar af þessari tegund.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        SalesLine: Record "Sales Line";
        AssembleToOrderLink: Record "Assemble-to-Order Link";
        AssemblyHeader: Record "Assembly Header";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        AssemblyOrderJson: JsonObject;
        LinesJson: JsonArray;
        DocumentType: Enum "Sales Document Type";
        DocumentTypeText: Text;
        DocumentNo: Text;
        LineNo: Integer;
        Linked: Boolean;
        LinkNotFoundErr: Label 'The assembly order linked to the sales line does not exist.', Comment = 'is-IS=Samsetningarpöntunin sem er tengd sölulínunni er ekki til.';
        LinkNextStepLbl: Label 'Open the sales line in Business Central and check its assemble-to-order link.', Comment = 'is-IS=Opnaðu sölulínuna í Business Central og athugaðu tengingu hennar við samsetningu eftir pöntun.';
    begin
        if not AssertCanRead(Argument) then
            exit;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        RequestJson := Argument.GetRequestJson();
        if not RejectUnknownKeys(Argument, RequestJson) then
            exit;
        // String literals are the keys the contract guard counts as reads.
        if RequestJson.Contains('documentType') then;
        if RequestJson.Contains('documentNo') then;
        if RequestJson.Contains('lineNo') then;
        if not ReadDocumentType(Argument, RequestJson, DocumentType, DocumentTypeText) then
            exit;
        if not ReadText(Argument, RequestJson, DocumentNoKeyTok, DocumentNo) then
            exit;
        if not ReadLineNo(Argument, RequestJson, LineNo) then
            exit;
        if not LoadSalesLine(Argument, DocumentType, DocumentNo, LineNo, SalesLine) then
            exit;

        AssembleToOrderLink.SetCurrentKey(Type, "Document Type", "Document No.", "Document Line No.");
        AssembleToOrderLink.SetRange(Type, AssembleToOrderLink.Type::Sale);
        AssembleToOrderLink.SetRange("Document Type", SalesLine."Document Type");
        AssembleToOrderLink.SetRange("Document No.", SalesLine."Document No.");
        AssembleToOrderLink.SetRange("Document Line No.", SalesLine."Line No.");
        Linked := AssembleToOrderLink.FindFirst();
        if Linked then begin
            if not AssemblyHeader.Get(AssembleToOrderLink."Assembly Document Type", AssembleToOrderLink."Assembly Document No.") then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, LinkNotFoundErr, DocumentNoKeyTok, SalesLine."Document No.", '', LinkNextStepLbl);
                exit;
            end;
            AssemblyOrderJson := HeaderToJson(AssemblyHeader);
            LinesJson := LinesToJson(AssemblyHeader);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentType', DocumentTypeText);
        ResponseJson.Add('documentNo', SalesLine."Document No.");
        ResponseJson.Add('lineNo', SalesLine."Line No.");
        ResponseJson.Add('itemNo', SalesLine."No.");
        ResponseJson.Add('qtyToAssembleToOrder', SalesLine."Qty. to Assemble to Order");
        ResponseJson.Add('linked', Linked);
        ResponseJson.Add('assemblyOrder', AssemblyOrderJson);
        ResponseJson.Add('lines', LinesJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure HeaderToJson(AssemblyHeader: Record "Assembly Header") HeaderJson: JsonObject
    begin
        HeaderJson.Add('documentType', AssemblyDocumentTypeName(AssemblyHeader."Document Type"));
        HeaderJson.Add('documentNo', AssemblyHeader."No.");
        HeaderJson.Add('systemId', Format(AssemblyHeader.SystemId, 0, 4).ToLower());
        HeaderJson.Add('itemNo', AssemblyHeader."Item No.");
        HeaderJson.Add('variantCode', AssemblyHeader."Variant Code");
        HeaderJson.Add('description', AssemblyHeader.Description);
        HeaderJson.Add('locationCode', AssemblyHeader."Location Code");
        HeaderJson.Add('unitOfMeasureCode', AssemblyHeader."Unit of Measure Code");
        HeaderJson.Add('quantity', AssemblyHeader.Quantity);
        HeaderJson.Add('quantityToAssemble', AssemblyHeader."Quantity to Assemble");
        HeaderJson.Add('assembledQuantity', AssemblyHeader."Assembled Quantity");
        HeaderJson.Add('remainingQuantity', AssemblyHeader."Remaining Quantity");
        if AssemblyHeader.Status = AssemblyHeader.Status::Released then
            HeaderJson.Add('orderStatus', 'Released')
        else
            HeaderJson.Add('orderStatus', 'Open');
        HeaderJson.Add('dueDate', DateOrEmpty(AssemblyHeader."Due Date"));
        HeaderJson.Add('startingDate', DateOrEmpty(AssemblyHeader."Starting Date"));
        HeaderJson.Add('endingDate', DateOrEmpty(AssemblyHeader."Ending Date"));
    end;

    local procedure LinesToJson(AssemblyHeader: Record "Assembly Header") LinesJson: JsonArray
    var
        AssemblyLine: Record "Assembly Line";
        LineJson: JsonObject;
    begin
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        if not AssemblyLine.FindSet() then
            exit;
        repeat
            Clear(LineJson);
            LineJson.Add('lineNo', AssemblyLine."Line No.");
            LineJson.Add('type', ComponentTypeName(AssemblyLine.Type));
            LineJson.Add('no', AssemblyLine."No.");
            LineJson.Add('variantCode', AssemblyLine."Variant Code");
            LineJson.Add('description', AssemblyLine.Description);
            LineJson.Add('locationCode', AssemblyLine."Location Code");
            LineJson.Add('unitOfMeasureCode', AssemblyLine."Unit of Measure Code");
            LineJson.Add('quantityPer', AssemblyLine."Quantity per");
            LineJson.Add('quantity', AssemblyLine.Quantity);
            LineJson.Add('quantityBase', AssemblyLine."Quantity (Base)");
            LineJson.Add('remainingQuantity', AssemblyLine."Remaining Quantity");
            LineJson.Add('consumedQuantity', AssemblyLine."Consumed Quantity");
            LineJson.Add('dueDate', DateOrEmpty(AssemblyLine."Due Date"));
            LineJson.Add('unitCost', AssemblyLine."Unit Cost");
            LineJson.Add('costAmount', AssemblyLine."Cost Amount");
            LinesJson.Add(LineJson);
        until AssemblyLine.Next() = 0;
    end;

    local procedure CanReadSources(): Boolean
    var
        SalesLine: Record "Sales Line";
        AssembleToOrderLink: Record "Assemble-to-Order Link";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
    begin
        exit(SalesLine.ReadPermission() and AssembleToOrderLink.ReadPermission() and AssemblyHeader.ReadPermission() and AssemblyLine.ReadPermission());
    end;

    local procedure AssertCanRead(var Argument: Record "Message Argument ori"): Boolean
    var
        InventorySetup: Record "Inventory Setup ori";
        DomainGate: Codeunit "Inventory Domain Gate ori";
    begin
        if not (InventorySetup.ReadPermission() and CanReadSources()) then begin
            RespondPermission(Argument);
            exit(false);
        end;
        exit(DomainGate.AssertEnabled(Argument, "Inventory Domain ori"::Assembly, Database::"Assembly Header", false, false));
    end;

    local procedure RejectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject): Boolean
    var
        KeyName: Text;
        UnknownKeyErr: Label 'The key is not part of this message type.', Comment = 'is-IS=Lykillinn er ekki hluti af þessari skilaboðategund.';
        UnknownNextStepLbl: Label 'Remove the unknown key. Allowed keys are documentType, documentNo and lineNo.', Comment = 'is-IS=Fjarlægðu óþekkta lykilinn. Leyfðir lyklar eru documentType, documentNo og lineNo.';
    begin
        foreach KeyName in RequestJson.Keys() do
            if not (KeyName in [DocumentTypeKeyTok, DocumentNoKeyTok, LineNoKeyTok]) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::UnknownParameter, UnknownKeyErr, KeyName, KeyName, '', UnknownNextStepLbl);
                exit(false);
            end;
        exit(true);
    end;

    local procedure LoadSalesLine(var Argument: Record "Message Argument ori"; DocumentType: Enum "Sales Document Type"; DocumentNo: Text; LineNo: Integer; var SalesLine: Record "Sales Line"): Boolean
    var
        NotFoundErr: Label 'The sales line does not exist.', Comment = 'is-IS=Sölulínan er ekki til.';
        NotFoundNextStepLbl: Label 'Check documentType, documentNo and lineNo.', Comment = 'is-IS=Athugaðu documentType, documentNo og lineNo.';
    begin
        if (StrLen(DocumentNo) <= MaxStrLen(SalesLine."Document No.")) then
            if SalesLine.Get(DocumentType, CopyStr(DocumentNo, 1, MaxStrLen(SalesLine."Document No.")), LineNo) then
                exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundErr, DocumentNoKeyTok, CopyStr(DocumentNo, 1, 250), '', NotFoundNextStepLbl);
        exit(false);
    end;

    local procedure ReadDocumentType(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var DocumentType: Enum "Sales Document Type"; var DocumentTypeText: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
    begin
        DocumentType := DocumentType::Order;
        DocumentTypeText := 'Order';
        if not GetPresentToken(RequestJson, DocumentTypeKeyTok, Token) then
            exit(true);
        if not Token.IsValue() then begin
            RespondFormat(Argument, DocumentTypeKeyTok, '', TextExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, DocumentTypeKeyTok, Raw, TextExpectedTok);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        case LowerCase(Value) of
            '', 'order':
                exit(true);
            'quote':
                begin
                    DocumentType := DocumentType::Quote;
                    DocumentTypeText := 'Quote';
                end;
            'blanket order':
                begin
                    DocumentType := DocumentType::"Blanket Order";
                    DocumentTypeText := 'Blanket Order';
                end;
            else begin
                RespondFormat(Argument, DocumentTypeKeyTok, Value, DocumentTypeExpectedLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; KeyName: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not GetPresentToken(RequestJson, KeyName, Token) then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, KeyName, '', TextExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            RespondFormat(Argument, KeyName, Raw, TextExpectedTok);
            exit(false);
        end;
        Value := Token.AsValue().AsText();
        if Value = '' then begin
            RespondMissing(Argument, KeyName);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadLineNo(var Argument: Record "Message Argument ori"; RequestJson: JsonObject; var LineNo: Integer): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        LineNo := 0;
        if not GetPresentToken(RequestJson, LineNoKeyTok, Token) then begin
            RespondMissing(Argument, LineNoKeyTok);
            exit(false);
        end;
        if not Token.IsValue() then begin
            RespondFormat(Argument, LineNoKeyTok, '', IntegerExpectedTok);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if Raw.StartsWith('"') or (Raw in ['true', 'false']) or (StrPos(Raw, '.') > 0) or (StrPos(LowerCase(Raw), 'e') > 0) then begin
            RespondFormat(Argument, LineNoKeyTok, Raw, IntegerExpectedTok);
            exit(false);
        end;
        if not Evaluate(LineNo, Raw) then begin
            RespondFormat(Argument, LineNoKeyTok, Raw, IntegerExpectedTok);
            exit(false);
        end;
        exit(true);
    end;

    local procedure GetPresentToken(RequestJson: JsonObject; KeyName: Text; var Token: JsonToken): Boolean
    begin
        if not RequestJson.Get(KeyName, Token) then
            exit(false);
        if Token.IsValue() then
            if Token.AsValue().IsNull() then
                exit(false);
        exit(true);
    end;

    local procedure AssemblyDocumentTypeName(DocumentType: Enum "Assembly Document Type"): Text
    begin
        case DocumentType of
            DocumentType::Quote:
                exit('Quote');
            DocumentType::Order:
                exit('Order');
            DocumentType::"Blanket Order":
                exit('Blanket Order');
        end;
        exit(DocumentType.Names().Get(DocumentType.Ordinals().IndexOf(DocumentType.AsInteger())));
    end;

    local procedure ComponentTypeName(ComponentType: Enum "BOM Component Type"): Text
    begin
        case ComponentType of
            ComponentType::Item:
                exit('Item');
            ComponentType::Resource:
                exit('Resource');
        end;
        exit('');
    end;

    local procedure DateOrEmpty(Value: Date): Text
    begin
        if Value = 0D then
            exit('');
        exit(Format(Value, 0, 9));
    end;

    local procedure RespondMissing(var Argument: Record "Message Argument ori"; KeyName: Text)
    var
        MissingErr: Label 'A required key is missing.', Comment = 'is-IS=Nauðsynlegur lykill vantar.';
        MissingNextStepLbl: Label 'Send documentNo and lineNo.', Comment = 'is-IS=Sendu documentNo og lineNo.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, KeyName, '', KeyName, MissingNextStepLbl);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; KeyName: Text; Received: Text; Expected: Text)
    var
        FormatErr: Label 'The value has the wrong format.', Comment = 'is-IS=Gildið er á röngu sniði.';
        FormatNextStepLbl: Label 'Send documentType and documentNo as text, documentType as Quote, Order or Blanket Order, and lineNo as a whole number.', Comment = 'is-IS=Sendu documentType og documentNo sem texta, documentType sem Quote, Order eða Blanket Order, og lineNo sem heila tölu.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, FormatErr, KeyName, CopyStr(Received, 1, 250), Expected, FormatNextStepLbl);
    end;

    local procedure RespondPermission(var Argument: Record "Message Argument ori")
    var
        PermissionDeniedErr: Label 'Permission denied for this inventory message type.', Comment = 'is-IS=Heimild hafnað fyrir þessa birgðaskilaboðategund.';
        PermissionNextStepLbl: Label 'Assign the Bifrost "Read-Only" permission set with Inventory read permissions and a Business Central permission set that can read these tables.', Comment = 'is-IS=Úthlutaðu heimildasafninu „Lesaðgangur“ í Bifröst með lesheimildum birgða og Business Central heimildasafni sem getur lesið þessar töflur.';
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionDeniedErr, '', '', PermissionSetTok, PermissionNextStepLbl);
    end;
}
