This chapter describes this document, includes summaries of changes from previous releases and precautionary messages, and lists command conventions.

## 1.1. About this document
This document describes basic configuration for EVPN Layer 2 (L2) and Layer 3 (L3) functionality on the Nokia Service Router Linux (SR Linux). It presents examples to configure and implement various protocols and services.

This document is intended for network technicians, administrators, operators, service providers, and others who need to understand how the router is configured.

!!!note
    This manual covers the current release and may also contain some content that will be released in later maintenance loads. Refer to the SR Linux Release Notes for information on features supported in each load.

## 1.2. What’s new
This is the first release of this document. In future releases, a table will define new or change information for the release.

## 1.3. Precautionary messages
Observe all dangers, warnings, and cautions in this document to avoid injury or equipment damage during installation and maintenance. Follow the safety procedures and guidelines when working with and near electrical equipment.

Table 1 describes information symbols contained in this document.

<small>Table 1: Information symbols</small>

|  Symbol   | Meaning | Description                                                                                                                                                                                                                                                                                              |
| :-------: | :------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ![p1][p1] | Danger  | Warns that incorrect handling and installation could result in bodily injury. An electric shock hazard could exist. Before you begin work on this equipment, be aware of hazards involving electrical circuitry, be familiar with networking environments, and implement accident prevention procedures. |
| ![p2][p2] | Warning | Warns that incorrect handling and installation could result in equipment damage or loss of data.                                                                                                                                                                                                         |
| ![p3][p3] | Caution | Warns that incorrect handling may reduce your component or system performance.                                                                                                                                                                                                                           |
| ![p4][p4] | Note    | Notes contain suggestions or additional operational information.                                                                                                                                                                                                                                         |


## 1.4. Conventions
Nokia SR Linux documentation uses the following command conventions.

* **Bold** type indicates a command that the user must enter.
* Input and output examples are displayed in `Courier` text.
* An open right-angle bracket indicates a progression of menu choices or simple command sequence (often selected from a user interface). Example: **start > connect to**.
* Angle brackets (< >) indicate an item that is not used verbatim. For example, for the command **show ethernet <name>**, name should be replaced with the name of the interface.
* A vertical bar (|) indicates a mutually exclusive argument.
* Square brackets ([ ]) indicate optional elements.
* Braces ({ }) indicate a required choice. When braces are contained within square brackets, they indicate a required choice within an optional element.
* *Italic* type indicates a variable.
* Generic IP addresses are used in examples. Replace these with the appropriate IP addresses used in the system.



[p1]: https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/nn021188.gif
[p2]: https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/nn021189.gif
[p3]: https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/nn021190.gif
[p4]: https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/nn021191.gif