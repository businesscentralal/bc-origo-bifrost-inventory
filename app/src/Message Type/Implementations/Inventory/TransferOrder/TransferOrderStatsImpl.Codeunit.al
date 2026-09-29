namespace Origo.Bifrost.Inventory;

/// <summary>
/// Implementation of the Inventory.TransferOrder.Statistics message type.
/// Returns transfer order line totals (Quantity, Parcels, Net Weight, Gross Weight, Volume)
/// and the reservation state. Calculation mirrors Page 5755 "Transfer Statistics".
/// </summary>

using Microsoft.Inventory.Transfer;
using Origo.Bifrost;

codeunit 70013419 "Transfer Order Stats Impl ori" implements "Msg Interface ori", "Msg Discovery ori"
{
    Access = Internal;
    procedure IsEnabled(): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetFilterTableNo());
        exit(RecRef.ReadPermission());
    end;
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Transfer Header");
    end;

    procedure GetDescription() Description: Text[250]
    begin
        exit('Returns transfer order statistics: line quantity, parcels, net/gross weight, volume and reservation state.');
    end;

    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'transfer statistics, transfer weight, parcels, transfer volume, transfer quantities', Comment = 'is-IS=tölfræði millifærslu, þyngd millifærslu, pakkar, rúmmál millifærslu, magn millifærslu';
    begin
        exit(KeywordsLbl);
    end;

    procedure GetSelectionDescription(): Text
    begin
        exit(GetDescription());
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Transfer Order Stats Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ResponseJson: JsonObject;
        TotalsJson: JsonObject;
        LineQty: Decimal;
        TotalParcels: Decimal;
        TotalNetWeight: Decimal;
        TotalGrossWeight: Decimal;
        TotalVolume: Decimal;
        LineCount: Integer;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Argument.FindTransferHeader(TransferHeader) then
            exit;

        // Replicates Page 5755 "Transfer Statistics".CalculateTotals
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        if TransferLine.FindSet() then
            repeat
                LineCount += 1;
                LineQty += TransferLine.Quantity;
                TotalNetWeight += TransferLine.Quantity * TransferLine."Net Weight";
                TotalGrossWeight += TransferLine.Quantity * TransferLine."Gross Weight";
                TotalVolume += TransferLine.Quantity * TransferLine."Unit Volume";
                if TransferLine."Units per Parcel" > 0 then
                    TotalParcels += Round(TransferLine.Quantity / TransferLine."Units per Parcel", 1, '>');
            until TransferLine.Next() = 0;

        TotalsJson.Add('lineCount', LineCount);
        TotalsJson.Add('quantity', LineQty);
        TotalsJson.Add('parcels', TotalParcels);
        TotalsJson.Add('netWeight', TotalNetWeight);
        TotalsJson.Add('grossWeight', TotalGrossWeight);
        TotalsJson.Add('volume', TotalVolume);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('documentNo', TransferHeader."No.");
        ResponseJson.Add('transferFromCode', TransferHeader."Transfer-from Code");
        ResponseJson.Add('transferToCode', TransferHeader."Transfer-to Code");
        ResponseJson.Add('directTransfer', TransferHeader."Direct Transfer");
        ResponseJson.Add('statusValue', StatusToText(TransferHeader.Status));
        ResponseJson.Add('postingDate', Format(TransferHeader."Posting Date", 0, 9));
        ResponseJson.Add('shipmentDate', Format(TransferHeader."Shipment Date", 0, 9));
        ResponseJson.Add('receiptDate', Format(TransferHeader."Receipt Date", 0, 9));
        ResponseJson.Add('totals', TotalsJson);

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure StatusToText(StatusValue: Option Open,Released): Text
    begin
        case StatusValue of
            StatusValue::Open:
                exit('Open');
            StatusValue::Released:
                exit('Released');
        end;
        exit('');
    end;
}
