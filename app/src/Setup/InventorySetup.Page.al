namespace Origo.Bifrost.Inventory;

/// <summary>
/// Company page for turning Bifrost Inventory domains on or off.
/// </summary>
page 70013452 "Inventory Setup ori"
{
    ApplicationArea = All;
    Caption = 'Inventory Setup', Comment = 'is-IS=Uppsetning birgða';
    PageType = Card;
    SourceTable = "Inventory Setup ori";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Domains)
            {
                Caption = 'Domains', Comment = 'is-IS=Svið';
                field(Attributes; Rec.Attributes)
                {
                    ToolTip = 'Specifies whether attribute message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort eiginleikaskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(TransferOrders; Rec."Transfer Orders")
                {
                    ToolTip = 'Specifies whether transfer order message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort flutningspantanaskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(Assembly; Rec.Assembly)
                {
                    ToolTip = 'Specifies whether assembly message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort samsetningarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(Reservations; Rec.Reservations)
                {
                    ToolTip = 'Specifies whether reservation message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort frátektarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(ItemTracking; Rec."Item Tracking")
                {
                    ToolTip = 'Specifies whether item tracking message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort vörurakningarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(PhysInventory; Rec."Phys. Inventory")
                {
                    ToolTip = 'Specifies whether physical inventory message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort birgðatalningarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(Costing; Rec.Costing)
                {
                    ToolTip = 'Specifies whether costing message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort kostnaðarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(Reclassification; Rec.Reclassification)
                {
                    ToolTip = 'Specifies whether reclassification message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort endurflokkunarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(ItemApplication; Rec."Item Application")
                {
                    ToolTip = 'Specifies whether item application message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort vörujöfnunarskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(InventoryPeriod; Rec."Inventory Period")
                {
                    ToolTip = 'Specifies whether inventory period message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort birgðatímabilsskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(ItemPrice; Rec."Item Price")
                {
                    ToolTip = 'Specifies whether item price update message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort vöruverðsskilaboð séu virk fyrir þetta fyrirtæki.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
