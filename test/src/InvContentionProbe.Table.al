namespace Origo.Bifrost.Inventory.Test;

/// <summary>Owned test-only inputs and actual independent-session outcomes; never customer or licence data.</summary>
table 96990 "Inv Contention Probe"
{
    DataClassification = SystemMetadata;
    fields
    {
        field(1; Id; Guid) { }
        field(2; "Run Id"; Guid) { }
        field(3; Scenario; Option) { OptionMembers = Reservation,Application; }
        field(4; "Item No."; Code[20]) { }
        field(5; "Source Id"; Guid) { }
        field(6; "Inbound Entry No."; Integer) { }
        field(7; "Outbound Entry No."; Integer) { }
        field(8; Quantity; Decimal) { }
        field(9; "Release At"; DateTime) { }
        field(10; State; Option) { OptionMembers = Ready,Running,Succeeded,Refused; }
        field(11; "Session Id"; Integer) { }
        field(12; "Started At"; DateTime) { }
        field(13; "Finished At"; DateTime) { }
        field(14; "Hold Started At"; DateTime) { }
        field(15; "Hold Finished At"; DateTime) { }
        field(16; "Error Text"; Text[2048]) { }
        field(17; "Response Text"; Text[2048]) { }
        field(18; "Assertion Passed"; Boolean) { }
    }
    keys
    {
        key(PK; Id) { Clustered = true; }
        key(Run; "Run Id") { }
    }
}
