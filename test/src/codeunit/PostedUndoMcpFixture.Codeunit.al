namespace Origo.Bifrost.Inventory.Test;

using Microsoft.CRM.BusinessRelation;
using Microsoft.CRM.Contact;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;

/// <summary>Explicit owned-tenant MCP fixtures for issue 134. Never invoked on installation or through product dispatch.</summary>
codeunit 96997 "Posted Undo MCP Fixture ori"
{
    /// <summary>Posts independent sales and purchase fixtures for both LCIDs and returns their identifiers.</summary>
    procedure Seed(): Text
    var
        Item: Record Item;
        Setup: Record "Inventory Setup";
        Result: JsonObject;
        Scenario: JsonObject;
        Scenarios: JsonArray;
        Output: Text;
        Sales: Boolean;
        LanguageId: Integer;
        Index: Integer;
        DocumentNo: Code[20];
    begin
        AssertCompany();
        Item.SetFilter("No.", 'W4I134-*');
        if not Item.IsEmpty() then
            Error('Owned undo fixtures exist. Inspect them before retrying.');
        Setup.Get();
        if Setup."Automatic Cost Posting" or (Setup."Automatic Cost Adjustment" <> Setup."Automatic Cost Adjustment"::Never) then
            Error('Inspect the owned test setup first: automatic cost posting and adjustment must be off.');
        for Index := 1 to 4 do begin
            Sales := Index <= 2;
            if Index mod 2 = 1 then
                LanguageId := 1033
            else
                LanguageId := 1039;
            DocumentNo := CreateDocument(Sales, LanguageId);
            Clear(Scenario);
            Scenario.Add('sales', Sales);
            Scenario.Add('lcid', LanguageId);
            Scenario.Add('documentNo', DocumentNo);
            Scenarios.Add(Scenario);
        end;
        Result.Add('scenarios', Scenarios);
        Result.WriteTo(Output);
        exit(Output);
    end;

    /// <summary>Removes only documents and ledger rows tied to the explicit owned fixture parties and items after MCP verification.</summary>
    procedure Cleanup()
    var
        Item: Record Item;
        Entry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostValueEntry: Record "Post Value Entry to G/L";
        AverageCostEntry: Record "Avg. Cost Adjmt. Entry Point";
        AdjustmentOrder: Record "Inventory Adjmt. Entry (Order)";
        Register: Record "Item Register";
        RangeEntry: Record "Item Ledger Entry";
        OwnedEntry: Record "Item Ledger Entry";
        Application: Record "Item Application Entry";
        Relation: Record "Item Entry Relation";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Shipment: Record "Sales Shipment Header";
        ShipmentLine: Record "Sales Shipment Line";
        Receipt: Record "Purch. Rcpt. Header";
        ReceiptLine: Record "Purch. Rcpt. Line";
        Customer: Record Customer;
        Vendor: Record Vendor;
        ContactBusinessRelation: Record "Contact Business Relation";
        Contact: Record Contact;
        ContactNos: List of [Code[20]];
        ContactNo: Code[20];
    begin
        AssertCompany();
        // Native party creation also creates CRM contacts; retain their exact keys before removing the parties.
        ContactBusinessRelation.SetRange("No.", 'W4I134');
        ContactBusinessRelation.SetFilter("Link to Table", '%1|%2', ContactBusinessRelation."Link to Table"::Customer, ContactBusinessRelation."Link to Table"::Vendor);
        if ContactBusinessRelation.FindSet() then
            repeat
                if not ContactNos.Contains(ContactBusinessRelation."Contact No.") then
                    ContactNos.Add(ContactBusinessRelation."Contact No.");
            until ContactBusinessRelation.Next() = 0;
        // Delete a register only when every entry in its full range belongs to this explicit fixture.
        if Register.FindSet() then
            repeat
                RangeEntry.SetRange("Entry No.", Register."From Entry No.", Register."To Entry No.");
                OwnedEntry.CopyFilters(RangeEntry);
                OwnedEntry.SetFilter("Item No.", 'W4I134-*');
                if (not RangeEntry.IsEmpty()) and (RangeEntry.Count() = OwnedEntry.Count()) then
                    Register.Delete();
            until Register.Next() = 0;
        Item.SetFilter("No.", 'W4I134-*');
        if Item.FindSet() then
            repeat
                Entry.SetRange("Item No.", Item."No.");
                if Entry.FindSet() then
                    repeat
                        Application.SetRange("Inbound Item Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.SetRange("Inbound Item Entry No.");
                        Application.SetRange("Outbound Item Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.SetRange("Outbound Item Entry No.");
                        Application.SetRange("Item Ledger Entry No.", Entry."Entry No.");
                        Application.DeleteAll();
                        Application.Reset();
                        Relation.SetRange("Item Entry No.", Entry."Entry No.");
                        Relation.DeleteAll();
                    until Entry.Next() = 0;
                ValueEntry.SetRange("Item No.", Item."No.");
                PostValueEntry.SetRange("Item No.", Item."No.");
                PostValueEntry.DeleteAll();
                AverageCostEntry.SetRange("Item No.", Item."No.");
                AverageCostEntry.DeleteAll();
                AdjustmentOrder.SetRange("Item No.", Item."No.");
                AdjustmentOrder.DeleteAll();
                ValueEntry.DeleteAll();
                Entry.DeleteAll();
                Item.UpdateCostIsAdjusted();
            until Item.Next() = 0;
        Shipment.SetRange("Sell-to Customer No.", 'W4I134');
        if Shipment.FindSet() then
            repeat
                ShipmentLine.SetRange("Document No.", Shipment."No.");
                ShipmentLine.DeleteAll();
            until Shipment.Next() = 0;
        Shipment.DeleteAll();
        Receipt.SetRange("Buy-from Vendor No.", 'W4I134');
        if Receipt.FindSet() then
            repeat
                ReceiptLine.SetRange("Document No.", Receipt."No.");
                ReceiptLine.DeleteAll();
            until Receipt.Next() = 0;
        Receipt.DeleteAll();
        SalesHeader.SetRange("Sell-to Customer No.", 'W4I134');
        if SalesHeader.FindSet() then
            repeat
                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                SalesLine.DeleteAll();
            until SalesHeader.Next() = 0;
        SalesHeader.DeleteAll();
        PurchaseHeader.SetRange("Buy-from Vendor No.", 'W4I134');
        if PurchaseHeader.FindSet() then
            repeat
                PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchaseLine.DeleteAll();
            until PurchaseHeader.Next() = 0;
        PurchaseHeader.DeleteAll();
        Item.DeleteAll(true);
        Customer.SetRange("No.", 'W4I134');
        Customer.DeleteAll(true);
        Vendor.SetRange("No.", 'W4I134');
        Vendor.DeleteAll(true);
        foreach ContactNo in ContactNos do
            if Contact.Get(ContactNo) then
                Contact.Delete(true);
    end;

    local procedure AssertCompany()
    begin
        if CompanyName() <> 'CRONUS International Ltd.' then
            Error('This fixture is limited to the owned CRONUS verification company.');
    end;

    local procedure CreateDocument(Sales: Boolean; LanguageId: Integer): Code[20]
    var
        Item: Record Item;
        Customer: Record Customer;
        Vendor: Record Vendor;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        Shipment: Record "Sales Shipment Header";
        Receipt: Record "Purch. Rcpt. Header";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        KeyCode: Code[20];
        OrderNo: Code[20];
    begin
        KeyCode := 'W4I134-P-' + Format(LanguageId, 0, 9);
        if Sales then
            KeyCode := 'W4I134-S-' + Format(LanguageId, 0, 9);
        LibraryInventory.CreateItem(Item);
        Item.Rename(KeyCode);
        if not Vendor.Get('W4I134') then begin
            LibraryPurchase.CreateVendor(Vendor);
            Vendor.Rename('W4I134');
        end;
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        OrderNo := PurchaseHeader."No.";
        if Sales then
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10)
        else begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        end;
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);
        if not Sales then begin
            Receipt.SetRange("Order No.", OrderNo);
            Receipt.FindFirst();
            exit(Receipt."No.");
        end;
        if not Customer.Get('W4I134') then begin
            LibrarySales.CreateCustomer(Customer);
            Customer.Rename('W4I134');
        end;
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        OrderNo := SalesHeader."No.";
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 2);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 2);
        LibrarySales.PostSalesDocument(SalesHeader, true, false);
        Shipment.SetRange("Order No.", OrderNo);
        Shipment.FindFirst();
        exit(Shipment."No.");
    end;
}
