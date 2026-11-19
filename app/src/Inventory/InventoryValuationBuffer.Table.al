namespace Origo.Bifrost.Inventory;

/// <summary>Temporary, sorted item/location/variant totals for historical valuation; never persists data.</summary>
table 10077020 "Inventory Valuation Buffer ori"
{
    Access = Internal;
    TableType = Temporary;
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.', Comment = 'is-IS=Vörunúmer';
        }
        field(2; "Location Code"; Code[10])
        {
            Caption = 'Location Code', Comment = 'is-IS=Birgðageymslukóði';
        }
        field(3; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code', Comment = 'is-IS=Afbrigðiskóði';
        }
        field(4; Quantity; Decimal)
        {
            Caption = 'Quantity', Comment = 'is-IS=Magn';
        }
        field(5; "Actual Cost"; Decimal)
        {
            Caption = 'Actual Cost', Comment = 'is-IS=Raunverulegur kostnaður';
        }
        field(6; "Expected Cost"; Decimal)
        {
            Caption = 'Expected Cost', Comment = 'is-IS=Áætlaður kostnaður';
        }
    }
    keys
    {
        key(PK; "Item No.", "Location Code", "Variant Code")
        {
            Clustered = true;
        }
    }
}
