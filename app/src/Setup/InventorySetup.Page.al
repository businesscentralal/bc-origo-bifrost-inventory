namespace Origo.Bifrost.Inventory;

/// <summary>
/// Company page for turning Bifrost Inventory domains on or off.
/// </summary>
page 10076835 "Inventory Setup ori"
{
    ApplicationArea = All;
    Caption = 'Inventory Setup', Comment = 'is-IS=Uppsetning birgða';
    PageType = Card;
    SourceTable = "Inventory Setup ori";
    UsageCategory = Administration;
    ContextSensitiveHelpPage = 'inventory-setup';

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
                field(ItemReference; Rec."Item Reference")
                {
                    ToolTip = 'Specifies whether item reference message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort vörutilvísanaskilaboð séu virk fyrir þetta fyrirtæki.';
                }
                field(Availability; Rec.Availability)
                {
                    ToolTip = 'Specifies whether availability by period message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð framboðs eftir tímabilum séu virk fyrir þetta fyrirtæki.';
                }
                field(ItemCharge; Rec."Item Charge")
                {
                    ToolTip = 'Specifies whether item charge assignment message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð úthlutunar kostnaðarauka séu virk fyrir þetta fyrirtæki.';
                }
                field(ItemSubstitution; Rec."Item Substitution")
                {
                    ApplicationArea = All;
                }
                field(ItemCategory; Rec."Item Category")
                {
                    ToolTip = 'Specifies whether item category message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð vöruflokka séu virk fyrir þetta fyrirtæki.';
                }
                field(PurchaseReturns; Rec."Purchase Returns")
                {
                    ToolTip = 'Specifies whether purchase return message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð innkaupaskila séu virk fyrir þetta fyrirtæki.';
                }
                field(CatalogItems; Rec."Catalog Items")
                {
                    ToolTip = 'Specifies whether catalog item message types, such as creating an item from a catalog item, are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð vörulistavara, svo sem að stofna vöru úr vörulistavöru, séu virk fyrir þetta fyrirtæki.';
                }
                field(Planning; Rec.Planning)
                {
                    ToolTip = 'Specifies whether planning worksheet message types are enabled for this company.', Comment = 'is-IS=Tilgreinir hvort skilaboð áætlunarkeyrslu séu virk fyrir þetta fyrirtæki.';
                }
            }
            group(SetupModeHelp)
            {
                Caption = 'Setup mode', Comment = 'is-IS=Uppsetningarhamur';
                InstructionalText = 'While Bifrost setup mode is active for a session source, Data.Records.Set can write Inventory Setup, the only table Bifrost Inventory opens. Items, item cost and price fields, item categories, attributes, variants, stockkeeping units, price lists, reservation and tracking entries and item charge assignments stay refused; use the Inventory message types for them. Setup mode does not change permissions, the domain gate or what is protected when it is off.', Comment = 'is-IS=Meðan uppsetningarhamur Bifröst er virkur fyrir uppruna setu getur Data.Records.Set skrifað í Uppsetningu birgða, einu töfluna sem Bifröst birgðir opna. Vörur, kostnaðar- og verðreitir vara, vöruflokkar, eiginleikar, afbrigði, birgðageymsluvörur, verðlistar, frátektar- og rakningarfærslur og úthlutun kostnaðarauka eru áfram lokuð; notaðu skilaboðategundir Birgða fyrir þau. Uppsetningarhamur breytir ekki heimildum, svæðahliðinu né því sem er varið þegar hann er óvirkur.';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetupWizard)
            {
                Caption = 'Setup Wizard', Comment = 'is-IS=Uppsetningarhjálp';
                ToolTip = 'Opens the guided setup for Bifrost Inventory.', Comment = 'is-IS=Opnar leiðsagða uppsetningu Bifröst birgða.';
                Image = Setup;
                RunObject = page "Inventory Setup Wizard ori";
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InsertIfNotExists();
    end;
}
