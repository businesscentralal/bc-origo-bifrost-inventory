namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Creates or updates an item reference through validated, atomic writes.</summary>
codeunit 10076954 "Item Ref. Set Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";

    /// <summary>Checks company and caller access.</summary>
    procedure IsEnabled(): Boolean
    var
        Setup: Record "Inventory Setup ori";
    begin
        exit(Setup.IsDomainEnabled("Inventory Domain ori"::ItemReference) and HasNativePermission());
    end;

    local procedure HasNativePermission(): Boolean
    var
        Setup: Record "Inventory Setup ori";
        Reference: Record "Item Reference";
    begin
        exit(Setup.ReadPermission() and Reference.ReadPermission() and Reference.WritePermission());
    end;

    /// <summary>Returns the reference table.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Item Reference");
    end;

    /// <summary>Returns inbound direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Provides translated description.</summary>
    procedure GetDescription(): Text[250]
    var
        TextLbl: Label 'Creates or updates an item reference.', Comment = 'is-IS=Stofnar eða uppfærir vörutilvísun. (strikamerki, viðskiptavinur, birgir).';
    begin
        exit(TextLbl);
    end;

    /// <summary>Provides translated keywords.</summary>
    procedure GetKeywords(): Text
    var
        TextLbl: Label 'item reference, barcode, customer, vendor', Comment = 'is-IS=vörutilvísun, strikamerki, viðskiptavinur, birgir';
    begin
        exit(TextLbl);
    end;

    /// <summary>Provides translated selectiondescription.</summary>
    procedure GetSelectionDescription(): Text
    var
        TextLbl: Label 'Create or change a reference for an existing item.', Comment = 'is-IS=Stofnaðu eða breyttu tilvísun fyrir vöru sem er til.';
    begin
        exit(TextLbl);
    end;

    /// <summary>Provides translated overview.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        TextLbl: Label 'Creates a reference or updates its description and dates using the full item, variant, unit, reference type, type number and reference number key. A reference assigned to another item is refused.', Comment = 'is-IS=Stofnar tilvísun eða uppfærir lýsingu hennar og dagsetningar með öllum lyklinum: vöru, afbrigði, einingu, tegund tilvísunar, tegundarnúmeri og tilvísunarnúmeri. Tilvísun á aðra vöru er hafnað.';
    begin
        Overview := TextLbl;
        exit(true);
    end;

    /// <summary>Provides translated notes.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        TextLbl: Label 'Omitted description and dates keep existing values. Empty dates clear them. An omitted or empty unit uses the item base unit. Native validation runs before saving. Vendor references may create an item vendor relation. Generic writes to item references are refused.', Comment = 'is-IS=Slepptri lýsingu og dagsetningum er haldið óbreyttum. Tómar dagsetningar hreinsa þær. Eining sem vantar eða er tóm notar grunneiningu vörunnar. Innbyggð sannprófun fer fram áður en vistað er. Birgjatilvísanir geta stofnað tengsl vöru og birgja. Almennum skrifum í vörutilvísanir er hafnað.';
    begin
        Notes := TextLbl;
        exit(true);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the target item.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        TargetLbl: Label 'Existing item number.', Comment = 'is-IS=Vörunúmer sem er til.';
    begin
        Target.Add(ContractMgt.TargetEntry('data.itemNo', 'text', TargetLbl));
        exit(true);
    end;

    /// <summary>Describes all accepted fields.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Field0Lbl: Label 'Existing item number, at most 20 characters.', Comment = 'is-IS=Vörunúmer sem er til, mest 20 stafir.';
        Field1Lbl: Label 'Existing variant of the item; empty means no variant.', Comment = 'is-IS=Afbrigði vörunnar sem er til; tómt merkir ekkert afbrigði.';
        Field2Lbl: Label 'Existing item unit; omitted or empty uses the base unit.', Comment = 'is-IS=Vörueining sem er til; grunneining er notuð ef gildið vantar eða er tómt.';
        Field3Lbl: Label 'barCode, customer, vendor or blank.', Comment = 'is-IS=barCode, customer, vendor eða blank.';
        Field4Lbl: Label 'Existing customer or vendor number. Required for customer and vendor, otherwise empty.', Comment = 'is-IS=Númer viðskiptavinar eða birgja sem er til. Áskilið fyrir customer og vendor, annars tómt.';
        Field5Lbl: Label 'Reference number, at most 50 characters. Cannot already identify another item in the same type and type number.', Comment = 'is-IS=Tilvísunarnúmer, mest 50 stafir. Má ekki auðkenna aðra vöru með sömu tegund og tegundarnúmeri.';
        Field6Lbl: Label 'Description, at most 100 characters; omitted keeps the current value.', Comment = 'is-IS=Lýsing, mest 100 stafir; óbreytt ef gildið vantar.';
        Field7Lbl: Label 'First valid day as yyyy-mm-dd; empty clears, omitted keeps the current value.', Comment = 'is-IS=Fyrsti gildisdagur á forminu yyyy-mm-dd; tómt hreinsar, óbreytt ef gildið vantar.';
        Field8Lbl: Label 'Last valid day as yyyy-mm-dd, not before startingDate; empty clears, omitted keeps the current value.', Comment = 'is-IS=Síðasti gildisdagur á forminu yyyy-mm-dd, ekki á undan startingDate; tómt hreinsar, óbreytt ef gildið vantar.';
    begin
        Parameters.Add(ContractMgt.Parameter('itemNo', 'string', true, Field0Lbl));
        Parameters.Add(ContractMgt.Parameter('variantCode', 'string', false, Field1Lbl));
        Parameters.Add(ContractMgt.Parameter('unitOfMeasure', 'string', false, Field2Lbl));
        Parameters.Add(ContractMgt.Parameter('referenceType', 'string', true, Field3Lbl));
        Parameters.Add(ContractMgt.Parameter('referenceTypeNo', 'string', false, Field4Lbl));
        Parameters.Add(ContractMgt.Parameter('referenceNo', 'string', true, Field5Lbl));
        Parameters.Add(ContractMgt.Parameter('description', 'string', false, Field6Lbl));
        Parameters.Add(ContractMgt.Parameter('startingDate', 'string', false, Field7Lbl));
        Parameters.Add(ContractMgt.Parameter('endingDate', 'string', false, Field8Lbl));
        exit(true);
    end;

    /// <summary>Describes the saved reference response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Field0Lbl: Label 'Success on a successful call.', Comment = 'is-IS=Success þegar kall tekst.';
        Field1Lbl: Label 'True when a reference was inserted.', Comment = 'is-IS=True þegar tilvísun var stofnuð.';
        Field2Lbl: Label 'Saved item number.', Comment = 'is-IS=Vistað vörunúmer.';
        Field3Lbl: Label 'Saved variant code.', Comment = 'is-IS=Vistaður afbrigðiskóði.';
        Field4Lbl: Label 'Saved unit of measure.', Comment = 'is-IS=Vistuð mælieining.';
        Field5Lbl: Label 'Saved reference type.', Comment = 'is-IS=Vistuð tegund tilvísunar.';
        Field6Lbl: Label 'Saved customer or vendor number.', Comment = 'is-IS=Vistað númer viðskiptavinar eða birgja.';
        Field7Lbl: Label 'Saved reference number.', Comment = 'is-IS=Vistað tilvísunarnúmer.';
        Field8Lbl: Label 'Saved description.', Comment = 'is-IS=Vistuð lýsing.';
        Field9Lbl: Label 'Saved starting date as yyyy-mm-dd, or empty.', Comment = 'is-IS=Vistaður upphafsdagur á forminu yyyy-mm-dd, eða tómt.';
        Field10Lbl: Label 'Saved ending date as yyyy-mm-dd, or empty.', Comment = 'is-IS=Vistaður lokadagur á forminu yyyy-mm-dd, eða tómt.';
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', Field0Lbl));
        Fields.Add(ContractMgt.ResponseField('created', 'boolean', Field1Lbl));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', Field2Lbl));
        Fields.Add(ContractMgt.ResponseField('variantCode', 'string', Field3Lbl));
        Fields.Add(ContractMgt.ResponseField('unitOfMeasure', 'string', Field4Lbl));
        Fields.Add(ContractMgt.ResponseField('referenceType', 'string', Field5Lbl));
        Fields.Add(ContractMgt.ResponseField('referenceTypeNo', 'string', Field6Lbl));
        Fields.Add(ContractMgt.ResponseField('referenceNo', 'string', Field7Lbl));
        Fields.Add(ContractMgt.ResponseField('description', 'string', Field8Lbl));
        Fields.Add(ContractMgt.ResponseField('startingDate', 'string', Field9Lbl));
        Fields.Add(ContractMgt.ResponseField('endingDate', 'string', Field10Lbl));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes structured refusals.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ReasonLbl: Label 'The request cannot be saved.', Comment = 'is-IS=Ekki er hægt að vista beiðnina.';
        NextLbl: Label 'Correct the named field using the help and retry.', Comment = 'is-IS=Leiðréttu tilgreindan reit samkvæmt hjálpinni og reyndu aftur.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, ReasonLbl, NextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, ReasonLbl, NextLbl));
        exit(true);
    end;

    /// <summary>Declares an idempotent write.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        ChangesLbl: Label 'Creates an item reference or updates its description and dates. Vendor references may create an item vendor relation. Does not post.', Comment = 'is-IS=Stofnar vörutilvísun eða uppfærir lýsingu hennar og dagsetningar. Birgjatilvísanir geta stofnað tengsl vöru og birgja. Bókar ekki.';
    begin
        Effect.Add('effect', 'write');
        Effect.Add('writes', true);
        Effect.Add('posts', false);
        Effect.Add('idempotent', true);
        Effect.Add('changes', ChangesLbl);
        Effect.Add('permissionSet', 'BIFROST Full ori');
        exit(true);
    end;

    /// <summary>No additional metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Names the matching read type.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ReadLbl: Label 'Resolve the saved reference.', Comment = 'is-IS=Finndu vistuðu tilvísunina.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Inventory.ItemReference.Resolve', ReadLbl));
        exit(true);
    end;

    /// <summary>Describes saving a reference and reading the result.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        SaveLbl: Label 'Create or update the item reference.', Comment = 'is-IS=Stofnaðu eða uppfærðu vörutilvísunina.';
        ReadLbl: Label 'Resolve the reference to verify its saved item and metadata.', Comment = 'is-IS=Finndu tilvísunina til að staðfesta vistaða vöru og lýsigögn hennar.';
    begin
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemReference.Set', SaveLbl));
        Steps.Add(ContractMgt.WorkflowStep('Inventory.ItemReference.Resolve', ReadLbl));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a request example.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        TitleLbl: Label 'Create a barcode reference', Comment = 'is-IS=Stofna strikamerkjatilvísun';
    begin
        Examples.Add(ContractMgt.Example(TitleLbl, '{"type":"Inventory.ItemReference.Set","data":{"itemNo":"1000","referenceType":"barCode","referenceNo":"5901234123457"}}', '{"status":"Success","created":true,"itemNo":"1000","referenceNo":"5901234123457"}'));
        exit(true);
    end;

    /// <summary>Checks access and input, then saves through an atomic process.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Setup: Record "Inventory Setup ori";
        TempReference: Record "Item Reference" temporary;
        Request: JsonObject;
        NativeNextLbl: Label 'Read the Business Central error, correct the related item, variant, unit, customer or vendor record and retry.', Comment = 'is-IS=Lestu Business Central villuna, leiðréttu tengda vöru, afbrigði, einingu, viðskiptavin eða birgja og reyndu aftur.';
        NativeExpectedLbl: Label 'Valid item reference and related records.', Comment = 'is-IS=Gild vörutilvísun og tengdar færslur.';
        PermissionLbl: Label 'Permission denied for item reference writes.', Comment = 'is-IS=Heimild hafnað fyrir skrif í vörutilvísanir.';
        PermissionNextLbl: Label 'Assign Bifrost Full and Business Central permissions for item references and their related records.', Comment = 'is-IS=Úthlutaðu Bifrost Full og Business Central heimildum fyrir vörutilvísanir og tengdar færslur.';
    begin
        if not Setup.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', '', '', PermissionNextLbl);
            exit;
        end;
        if not HasNativePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', '', '', PermissionNextLbl);
            exit;
        end;
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Argument.SetErrorContext('data', NativeExpectedLbl, NativeNextLbl);
        Request := Argument.GetRequestJson();
        if Request.Contains('itemNo') then;
        if Request.Contains('variantCode') then;
        if Request.Contains('unitOfMeasure') then;
        if Request.Contains('referenceType') then;
        if Request.Contains('referenceTypeNo') then;
        if Request.Contains('referenceNo') then;
        if Request.Contains('description') then;
        if Request.Contains('startingDate') then;
        if Request.Contains('endingDate') then;
        if not ValidateRequest(Argument, Request, TempReference, false) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Item Ref. Set Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Item Ref. Set Proc ori", Argument) then
                Argument.RespondWithLastError();
    end;

    /// <summary>Validates and normalizes an entire request without writing data.</summary>
    procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; var TempReference: Record "Item Reference" temporary; ForUpdate: Boolean): Boolean
    var
        Item: Record Item;
        Variant: Record "Item Variant";
        ItemUnit: Record "Item Unit of Measure";
        Customer: Record Customer;
        Vendor: Record Vendor;
        Existing: Record "Item Reference";
        Conflict: Record "Item Reference";
        KeyName: Text;
        Value: Text;
        Token: JsonToken;
        Raw: Text;
        DateValue: Date;
        TypeName: Text;
        MaxLength: Integer;
    begin
        foreach KeyName in Request.Keys() do begin
            case KeyName of
                'itemNo':
                    MaxLength := 20;
                'variantCode':
                    MaxLength := 10;
                'unitOfMeasure':
                    MaxLength := 10;
                'referenceType':
                    MaxLength := 10;
                'referenceTypeNo':
                    MaxLength := 20;
                'referenceNo':
                    MaxLength := 50;
                'description':
                    MaxLength := 100;
                'startingDate':
                    MaxLength := 10;
                'endingDate':
                    MaxLength := 10;
                else
                    exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, KeyName));
            end;
            Request.Get(KeyName, Token);
            if not Token.IsValue() then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName));
            if Token.AsValue().IsNull() then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName));
            Token.WriteTo(Raw);
            if not Raw.StartsWith('"') then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName));
            Value := Token.AsValue().AsText();
            if StrLen(Value) > MaxLength then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, KeyName));
        end;
        foreach KeyName in RequiredKeys() do
            if ReadText(Request, KeyName).Trim() = '' then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, KeyName));
        TempReference.Init();
        TempReference."Item No." := CopyStr(ReadText(Request, 'itemNo'), 1, 20);
        if not Item.Get(TempReference."Item No.") then
            exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'itemNo'));
        TempReference."Variant Code" := CopyStr(ReadText(Request, 'variantCode'), 1, 10);
        if TempReference."Variant Code" <> '' then
            if not Variant.Get(Item."No.", TempReference."Variant Code") then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'variantCode'));
        TempReference."Unit of Measure" := CopyStr(ReadText(Request, 'unitOfMeasure'), 1, 10);
        if TempReference."Unit of Measure" = '' then
            TempReference."Unit of Measure" := Item."Base Unit of Measure";
        if TempReference."Unit of Measure" <> '' then
            if not ItemUnit.Get(Item."No.", TempReference."Unit of Measure") then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'unitOfMeasure'));
        TypeName := LowerCase(ReadText(Request, 'referenceType'));
        case TypeName of
            'barcode':
                TempReference."Reference Type" := "Item Reference Type"::"Bar Code";
            'customer':
                TempReference."Reference Type" := "Item Reference Type"::Customer;
            'vendor':
                TempReference."Reference Type" := "Item Reference Type"::Vendor;
            'blank':
                TempReference."Reference Type" := "Item Reference Type"::" ";
            else
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'referenceType'));
        end;
        TempReference."Reference Type No." := CopyStr(ReadText(Request, 'referenceTypeNo'), 1, 20);
        if TypeName in ['customer', 'vendor'] then begin
            if TempReference."Reference Type No." = '' then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, 'referenceTypeNo'));
            if TypeName = 'customer' then begin
                if not Customer.Get(TempReference."Reference Type No.") then
                    exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'referenceTypeNo'));
            end else
                if not Vendor.Get(TempReference."Reference Type No.") then
                    exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'referenceTypeNo'));
        end else
            if TempReference."Reference Type No." <> '' then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'referenceTypeNo'));
        TempReference."Reference No." := CopyStr(ReadText(Request, 'referenceNo'), 1, 50);
        if ForUpdate then
            Conflict.ReadIsolation := IsolationLevel::UpdLock
        else
            Conflict.ReadIsolation := IsolationLevel::ReadCommitted;
        Conflict.SetRange("Reference Type", TempReference."Reference Type");
        Conflict.SetRange("Reference Type No.", TempReference."Reference Type No.");
        Conflict.SetRange("Reference No.", TempReference."Reference No.");
        Conflict.SetFilter("Item No.", '<>%1', TempReference."Item No.");
        if not Conflict.IsEmpty() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'referenceNo'));
        if Existing.Get(TempReference."Item No.", TempReference."Variant Code", TempReference."Unit of Measure", TempReference."Reference Type", TempReference."Reference Type No.", TempReference."Reference No.") then begin
            TempReference.Description := Existing.Description;
            TempReference."Starting Date" := Existing."Starting Date";
            TempReference."Ending Date" := Existing."Ending Date";
        end;
        if Request.Contains('description') then
            TempReference.Description := CopyStr(ReadText(Request, 'description'), 1, 100);
        foreach KeyName in DateKeys() do
            if Request.Contains(KeyName) then begin
                Value := ReadText(Request, KeyName);
                DateValue := 0D;
                if Value <> '' then begin
                    if not Evaluate(DateValue, Value, 9) then
                        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName));
                    if Format(DateValue, 0, 9) <> Value then
                        exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, KeyName));
                end;
                if KeyName = 'startingDate' then
                    TempReference."Starting Date" := DateValue
                else
                    TempReference."Ending Date" := DateValue;
            end;
        if (TempReference."Starting Date" <> 0D) and (TempReference."Ending Date" <> 0D) then
            if TempReference."Starting Date" > TempReference."Ending Date" then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'endingDate'));
        exit(true);
    end;

    local procedure RequiredKeys() Keys: List of [Text]
    begin
        Keys.Add('itemNo');
        Keys.Add('referenceType');
        Keys.Add('referenceNo');
    end;

    local procedure DateKeys() Keys: List of [Text]
    begin
        Keys.Add('startingDate');
        Keys.Add('endingDate');
    end;

    local procedure ReadText(Request: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Request.Get(KeyName, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; KeyName: Text): Boolean
    var
        ReasonLbl: Label 'The item reference request is invalid: %1.', Comment = '%1 = field, is-IS=Beiðni um vörutilvísun er ógild: %1.';
        NextLbl: Label 'Correct %1 using Inventory.ItemReference.Set help and retry. For a conflicting reference, choose another reference or the item it already identifies.', Comment = '%1 = field, is-IS=Leiðréttu %1 samkvæmt hjálp Inventory.ItemReference.Set og reyndu aftur. Fyrir tilvísun sem stangast á skaltu velja aðra tilvísun eða vöruna sem hún auðkennir þegar.';
    begin
        Argument.RespondWithError(ErrorCode, StrSubstNo(ReasonLbl, KeyName), CopyStr(KeyName, 1, 250), '', '', StrSubstNo(NextLbl, KeyName));
        exit(false);
    end;
}
