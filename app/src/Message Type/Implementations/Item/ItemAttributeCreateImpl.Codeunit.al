namespace Origo.Bifrost.Inventory;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Attribute;
using Origo.Bifrost;

/// <summary>
/// Implementation of the Item.Attribute.Create message type (Inbound).
/// Writes run through <c>Item Attr. Create Process ori</c> for error isolation.
/// </summary>
codeunit 10036898 "Item Attribute Create Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    procedure IsEnabled(): Boolean
    var
        Mapping: Record "Item Attribute Value Mapping";
    begin
        exit(Mapping.WritePermission());
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Assigns attribute values to an item. Idempotent when the same value already exists.');
    end;

    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "Item Attribute Create Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        if not Codeunit.Run(Codeunit::"Item Attr. Create Process ori", Argument) then begin
            Argument.RespondWithLastError();
            exit;
        end;
    end;
}
