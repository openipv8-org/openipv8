%%%
title = "IPv8 Support Protocols: ARP8, ICMPv8, Route8, ACL8, and DNS8"
abbrev = "support8"
docName = "draft-thain-support8-00"
ipr = "trust200902"
category = "std"
area = "Internet"
workgroup = "Internet Area Working Group"
keyword = ["IPv8", "ARP8", "ICMPv8", "Route8", "ACL8", "DNS8", "ARP", "ICMP"]

[seriesInfo]
name = "Internet-Draft"
value = "draft-thain-support8-00"
stream = "IETF"
status = "standard"
date = 2026-10-24T00:00:00Z

[[author]]
initials = "J."
surname = "Thain"
fullname = "Jamie Thain"
organization = "One Limited"
  [author.address]
  email = "jamie@one.bm"
  [author.address.postal]
  city = "Hamilton"
  country = "Bermuda"

[[author]]
initials = "A."
surname = "Aleinikov"
fullname = "Aleksei Aleinikov"
organization = "Open-IPv8-Lab"
  [author.address]
  email = "contact@alekseialeinikov.com"

%%%

.# Abstract

This document specifies five support protocols for Internet
Protocol Version 8 (IPv8) [@IPv8] networks.

ARP8 extends ARP [@RFC826] with a three-step resolution (ARP8 for
the Route Number asked, ARP8 to any Route Number, then ARP),
first-answer mode permanence for the life of a cache entry,
gratuitous ARP8 on boot, a duplicate-address probe and alarm,
defence against spoofed answers, and the ARP8 subnet query by
which a segment's Route Numbers are learned where DHCP does not
give them. IPv4-only devices coexist on IPv8 segments
indefinitely without modification.

ICMPv8 is ICMP [@RFC792] carried inside an IPv8 packet. Because
an IPv8 packet is an 8-octet shim in front of an unmodified
IPv4 packet, ICMPv8 needs no new message formats; this document
specifies how Route Numbers are reported in Time Exceeded,
Destination Unreachable and Redirect, and the path-MTU rules for
the shim and for 8-over-4 transport.

Route8 is the IPv8 routing function: a map from Route Number to
forwarding target (the IPv4 main table, the global IPv8 table,
a per-RN table, or an IPv4 VRF), with IPv4 longest-prefix
forwarding inside the selected target. It specifies the three
forwarding modes, per-RN tables for the scoped and interconnect
route spaces, the
resolution of a Route Number with no route through
DNS, pseudowires, 8-over-4 transport, the carriage of IPv8
routes across BGP4, transit source-RN preservation, and the
even/odd dual default gateway model.

ACL8 is the per-device per-interface policy layer that compiles
identity-based policy (JWT claims) to native platform firewalls,
and the interface DNS policy (normal or strict).

DNS8 carries the A8 and ZS resource records, serves the handle
mechanism by which IPv4-only clients reach other Route Numbers,
and answers the Route8 lookup of a Route Number's ingress: the
ZS record, which spreads a Route Number's traffic across many
Zone Servers, and the anycast record as fallback.

{mainmatter}

# Introduction

IPv8 [@IPv8] prepends a 32-bit Route Number (RN) to each IPv4
address. On the wire an IPv8 packet is an 8-octet shim (source
RN, destination RN) in front of a complete, unmodified IPv4
packet, carried in a frame of EtherType 0x8080 or, across
IPv4-only spans, inside an outer IPv4 packet (8-over-4). The
core document specifies the address format, the wire rule, the
route spaces and the forwarding modes. This document specifies
the support protocols that make a segment and a router work:
how neighbours are discovered and classified (ARP8), how errors
are reported (ICMPv8), how forwarding decisions are made
(Route8), how policy is enforced (ACL8), and how names are
resolved (DNS8).

All five are designed around one principle: extend what exists
rather than replace it. ARP, ICMP, the IPv4 FIB, platform
firewalls and DNS are all used as they are, with the Route
Number carried alongside. IPv4-only devices continue to operate
on IPv8 segments indefinitely; the mechanisms here detect what
each neighbour can do and send it only what it understands.

This document forms part of a companion specification suite:

- draft-thain-ipv8-04               Core protocol
- draft-thain-support8-00           ARP8, ICMPv8, Route8, ACL8, DNS8 (this document)
- draft-thain-routing-protocols-00  BGP8, BGP8x, IBGP8, OSPF8, IS-IS8, CF
- draft-thain-zoneserver-00         Zone Server Architecture
- draft-thain-rine-00               Regional Inter-Network Exchange
- draft-thain-netlog8-00            NetLog8 Protocol
- draft-thain-ipv8-mib-00           IPv8 MIB and SNMPv8
- draft-thain-wifi8-00              WiFi8 Protocol
- draft-thain-update8-00            Update8 and NIC Certification

## Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL
NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as
described in BCP 14 [@RFC2119] [@RFC8174] when, and only when,
they appear in all capitals, as shown here.

Command syntax shown in this document is illustrative. Vendors
are free to implement any command nomenclature consistent with
their platform conventions; the requirement is that the
functionality exists and the underlying behaviour conforms to
this document.

## Terminology

Terms defined in [@IPv8] are used here with the same meaning:
Route Number, Local Address, shim, Primary and Secondary RN,
the per-segment RN invariant, the route spaces (public, private
`127.r.r.r`, scoped `222.r.r.r`, interconnect `99.r.r.r`, and
system), IPv4-Compatible Form, and the
three forwarding modes. Examples use the public Route Number
1115169, private Route Numbers in `127.r.r.r` and scoped Route
Numbers in `222.r.r.r`, with documentation Local Addresses from
[@RFC5737] and RFC 1918 space.

The system route space of [@IPv8] is never configured, routed,
or used as a sender's Route Number:

- `224.r.r.r` is reserved for internal Route Number masking.
- `255.r.r.r` is reserved for future system use, assigned by the
  IETF. Its one claimed value, `255.255.255.255`, is the
  **broadcast RN**: "any Route Number". It appears only as the
  target Route Number of an ARP8 request (Part I).

A packet whose source or destination Route Number is in either
block is dropped on receipt (Part III, Dispatch).

# Part I: ARP8

## ARP8 Overview

The compatibility rule of IPv8, stated in [@IPv8] as the wire
rule, is enforced on each segment by ARP8:

   An IPv8 speaker sends every packet with the shim, except to
   a neighbour that has proved itself IPv4-only. An IPv4-only
   device never receives a frame of EtherType 0x8080.

ARP8 is how a neighbour proves what it is. ARP8 extends ARP
[@RFC826] with a three-step resolution: an ARP8 request for the
Route Number asked, then an ARP8 request to any Route Number,
then an ordinary ARP request where that is permitted. The first
answer fixes the neighbour's mode for the life of the cache
entry. An IPv8 neighbour is thereafter sent shimmed frames; an
IPv4-only neighbour is sent bare IPv4 and is recorded in the
Route Number of its subnet (Segment Route Numbers, below).

## ARP8 Packet Format

ARP8 is ARP with an 8-octet protocol address:

| Field                   | ARP      | ARP8     |
|-------------------------|----------|----------|
| Hardware type           | 2 octets | 2 octets |
| Protocol type           | 0x0800   | 0x8080   |
| Hardware address length | 1 octet  | 1 octet  |
| Protocol address length | 4        | 8        |
| Operation               | 2 octets | 2 octets |
| Sender hardware address | 6 octets | 6 octets |
| Sender protocol address | 4 octets | 8 octets |
| Target hardware address | 6 octets | 6 octets |
| Target protocol address | 4 octets | 8 octets |

The protocol type of an ARP8 packet is the IPv8 EtherType,
0x8080, exactly as the protocol type of an ARP packet is the
IPv4 EtherType. The protocol address is the 64-bit IPv8 address
in network byte order: Route Number then Local Address. ARP8
packets are carried in frames of EtherType 0x0806 (ARP) like
any ARP packet; an IPv4-only device that receives one ignores
it because the protocol type is unknown to it, per [@RFC826].
An earlier working revision gave the protocol type as 0x86DD8,
which does not fit the 16-bit field; that value is withdrawn.

ARP8 operations: 1 request, 2 reply, 26 subnet request, 27
subnet reply (Segment Route Numbers, below). Operations 3 and 4
are RARP's [@RFC903] and are not used.

## Resolution

A Local Address is unique within one broadcast domain whatever
its Route Number ([@IPv8]). When an IPv8 device needs to resolve
`(<RN>, <LA>)` for the first time:

    t = 0 ms:    ARP8 request
                 sender: own <RN>-<LA>, own MAC
                 target: <RN>-<LA> being resolved

    t = 50 ms:   if no ARP8 reply: ARP8 request to any RN
                 target: 255.255.255.255-<LA>

    t = 100 ms:  if no ARP8 reply: ARP request for <LA>,
                 only when <RN> is the Route Number of the
                 interface or of the subnet holding <LA>, and
                 only when no IPv8 device of another Route
                 Number has answered step 2 for <LA>

    on ARP8 reply for <RN>:
                 record neighbour mode = ipv8
                 store the full <RN>-<LA> and MAC
                 start the activity timer
                 send this neighbour shimmed frames only

    on ARP8 reply for another RN only:
                 <LA> is that RN's; the entry for <RN> fails
                 and packets for it are dropped, never sent
                 as bare IPv4

    on ARP reply with no ARP8 reply:
                 record neighbour mode = ipv4
                 store <subnet RN>-<LA> and MAC
                 start the activity timer
                 send this neighbour bare IPv4 only

    no answer:   the entry fails; packets for it are dropped

The second step and the conditions on the third close a leak:
with two steps only, a request for a Route Number not on the
segment fell through to ARP, the device holding that Local
Address in another Route Number answered, and packets crossed
Route Numbers. A device answers an ARP8 request as ARP does:
only for an address configured on the interface the request
arrived on. A request to any Route Number is answered with the
Route Number of that interface's address holding the Local
Address asked for; an interface holds a Local Address once, so
a device answers it at most once.

An IPv8 neighbour MUST answer ARP8 requests for all of its
identities (Primary and Secondary) and MUST also answer ARP
requests for its Local Address, because IPv4-only neighbours
can only ask that way. Answering ARP does not make it an
IPv4-only device; its mode is fixed by whether it answered
ARP8.

## Cache Modes and Permanence

The ARP8 cache records a mode for every entry:

~~~
1115169-10.20.30.10   ipv4   00:11:22:33:44:55
   IPv4-only device. Send bare IPv4. Expect bare IPv4.
   The RN is its subnet's Route Number, recorded, not learned.

1115169-10.20.30.14   ipv8   11:22:33:44:55:66
   IPv8 device, Primary identity. Send shimmed frames.

127.2.3.4-10.20.30.14 ipv8   11:22:33:44:55:66
   The same device's Secondary identity in another RN,
   learned by ARP8. Same MAC, different RN: reachable only
   by shimmed frames carrying that RN.
~~~

Once recorded, the mode is permanent for the life of the entry.
An IPv8 device MUST NOT send ARP8 to a neighbour recorded as
ipv4, and MUST NOT send ARP to a neighbour recorded as ipv8
except where a protocol requires it (duplicate-address probing);
the re-confirmation of an entry in use (Timer Model) asks in the
recorded mode. A neighbour's mode changes only by the entry
expiring or failing re-confirmation and a fresh resolution, or
by a gratuitous ARP8 from that MAC.

## Timer Model

ARP8 uses the ARP timer model. An entry in use does not expire:
while traffic is sent to the neighbour, the entry is re-confirmed
every 30 seconds by a unicast request to the recorded MAC in the
recorded mode, and three unanswered re-confirmations in a row
return it to full resolution, so an answer that won a race is not
trusted for ever. An entry not used for 300 seconds is removed,
and its mode with it, so that a device upgraded from IPv4 to IPv8
without rebooting is rediscovered as IPv8 within 300 seconds of
going idle; a device that reboots announces itself immediately
with gratuitous ARP8.

## Segment Route Numbers

### Purpose

IPv4 carries no Route Number. An IPv8 device that finds a plain
IPv4 neighbour by ARP must know which Route Number that
neighbour is in before it can record it as `<RN>-<LA>`.

A Route Number belongs to an interface, never to a device. One
device may have interfaces in many Route Numbers, and one Route
Number may be on many interfaces across many devices.
Everything below is per interface.

### DHCP Is the Arbitrator

The segment's DHCP server decides its Primary RN:

- A device that takes a DHCP lease receives the Primary RN in
  option 222 [@IPv8].
- A device with a statically configured address asks for
  option 222 with DHCPINFORM [@RFC2131]; the server answers it
  as it answers every client.

No other device can name the Primary RN. A gratuitous ARP8 does
not state it: an unauthenticated broadcast can be forged, and a
forged Primary RN would move a segment's IPv4 devices into
another Route Number. A rogue DHCP answer is the rogue DHCP
server problem, with its existing remedy: DHCP snooping on the
switch, which a Zone Server acting as the switch SHOULD enable.

### Without DHCP: the ARP8 Subnet Query

On a segment with no DHCP server, a device learns which subnets,
in which Route Numbers, are on the segment with the ARP8 subnet
query.

**Subnet request (operation 26).** Broadcast. It asks for any
Route Number and any Local Address.

| Field                   | Value                                      |
|-------------------------|--------------------------------------------|
| Operation               | 26                                         |
| Sender HW / RN / LA     | the asker's MAC, RN (0 if none) and LA     |
| Target hardware address | zero                                       |
| Target RN               | 255.255.255.255 (the broadcast RN)         |
| Target LA               | 255.255.255.255 (any LA)                   |

**Subnet reply (operation 27).** Returns Route Number, Local
Address and subnet mask.

| Field                   | Value                                      |
|-------------------------|--------------------------------------------|
| Operation               | 27                                         |
| Sender HW / RN / LA     | the answerer's MAC, RN and LA              |
| Target hardware address | the asker's MAC                            |
| Target RN               | 0                                          |
| Target LA               | the answerer's subnet mask                 |

Every IPv8 device that receives a subnet request sends one subnet
reply for each IPv8 address (primary and secondary) on that
interface. To keep one question from drawing one answer from
every device, a device SHOULD wait a random 0 to 100 ms, send the
reply to the Ethernet broadcast address, and stay silent for a
subnet whose reply it has already heard from another device in
that time. A segment then answers with one reply per subnet.

Neither message is a claim on an address. A subnet reply MUST NOT
be used for duplicate address detection; it MAY refresh an
existing ARP8 cache entry for the sender's (RN, LA).

A device sends a subnet request when its interface comes up with
no DHCP lease and no answer to DHCPINFORM, and SHOULD repeat it
twice at one-second intervals.

### A Neighbour's Route Number

From the replies and its own configured addresses the device
builds the segment's subnet table, for example:

    RN 1115172     10.10.10.0/24
    RN 127.1.1.1   10.10.20.0/24

- **One subnet, the device's own:** IPv4 neighbours are in its
  Route Number.
- **More than one:** an IPv4 neighbour's Route Number is that of
  the longest subnet in the table containing its address.
- **An address in no subnet:** its Route Number is unknown; the
  neighbour is reached as IPv4 only and never over IPv8.
- **An address in subnets of two different Route Numbers** (two
  Route Numbers reusing one IPv4 subnet): ambiguous. The device
  MUST NOT guess; it raises the NetLog8 event
  ARP8-SUBNET-AMBIGUOUS and reaches the neighbour as IPv4 only.
- **Nothing heard on the segment:** the interface's own Route
  Number.

The table is kept until the interface loses link.

### Subnets on a Segment

A router's interface carries the segment's subnets as a primary
address and secondary addresses, on the model of IPv4 secondary
addresses; each secondary address carries its own Route Number
and defines a subnet in that Route Number on the segment:

    interface GigabitEthernet1/1
     ip address 1115172-10.10.10.254/24
     ip address 127.1.1.1-10.10.20.254/24 secondary

The interface's Primary RN is the Route Number of its primary
address. A host's Primary RN is the Route Number of the subnet
holding its primary address; the segment's Primary RN is the one
DHCP hands out (option 222).

A segment may carry up to 255 subnets: the primary and up to 254
secondaries. A device MUST refuse configuration of more than 254
secondary IPv8 addresses on one interface, and MUST size its
subnet table for 255. Production networks rarely use more than
three, so more than a few is abnormal: a misconfiguration, or
forged subnet replies. Each level below is raised once when a
device's subnet table first passes it, and again only after the
table is cleared (link loss):

| More than | Severity            | Message                                        | NetLog8 event        |
|-----------|---------------------|------------------------------------------------|----------------------|
| 8         | 6 (Informational)   | subnet networks abnormally high                | P2 ARP8-SUBNET-HIGH  |
| 16        | 4 (Warning)         | ALERT: subnet networks abnormally high         | E2 ARP8-SUBNET-ALERT |
| 32        | 2 (Critical)        | ALARM: subnet networks abnormally high         | E2 ARP8-SUBNET-ALARM |

The ARP8-SUBNET-ALARM event is the NetLog8 collector's alarm, on
which it notifies the operator.

**Whatever the count, the segment keeps running.** A device MUST
NOT stop IPv8 on an interface, refuse to answer the subnet
query, or drop traffic because of the number of subnets: subnet
replies are not authenticated, and a limit that stopped the
segment would let one device stop it with forged replies. A
device whose table is full keeps the subnets it has.

The thresholds and the table size are protocol parameters.
Nothing on the wire depends on them: a subnet request has no
count field and each subnet is its own reply.

## Gratuitous ARP8 and Duplicate Address Detection

An IPv8 device MUST send gratuitous ARP8 on boot, on interface
up, and on address assignment, preceded by a duplicate-address
probe:

    t = 0 ms:    ARP8 probe: sender protocol address all-zero,
                 target = own <RN>-<LA>
    t = 50 ms:   ARP probe per [@RFC5227]: sender 0.0.0.0,
                 target = own LA
    t = 100 ms:  no answer to either: send gratuitous ARP8
                 (sender and target = own <RN>-<LA>) and
                 gratuitous ARP (own LA)
    on answer:   duplicate. NetLog8 SEC-ALERT ARP8-DUPLICATE;
                 the address MUST NOT be used; DHCP8 is told
                 and offers another.

The ARP probe is required even on an all-IPv8 segment because
Local Addresses MUST be unique within one broadcast domain
irrespective of Route Number ([@IPv8]): ARP resolves on the
Local Address alone, so two devices sharing a Local Address on
one segment collide at ARP whatever their Route Numbers. A
Zone Server MUST probe a candidate Local Address before
assigning it, and a DHCP8 client that observes a conflict MUST
decline the offered address. Any device that sees two distinct
MACs answering for one Local Address on one segment, in any
Route Numbers, MUST treat the address as duplicated, MUST NOT
forward to the new claimant, and MUST raise the duplicate-address
alarm (logged, counted, and signalled to the Zone Server). An
established entry is defended: it is kept and re-checked, and the
claimant's entry is marked duplicate, so a forged answer cannot
take a working host off the segment.

An IPv8 device MUST listen for gratuitous ARP8 and gratuitous
ARP. On gratuitous ARP8 from a MAC it updates or creates the
entry with mode ipv8. A gratuitous ARP from a MAC recorded as
ipv8 does not change its mode. A gratuitous ARP8 is never a
statement of the segment's Primary RN.

~~~
{
  "class": "SEC-ALERT",
  "event": "ARP8-DUPLICATE",
  "severity": 2,
  "proposed_address": "127.1.0.0-10.10.8.44",
  "existing_mac": "<responding-mac>",
  "our_mac": "<our-mac>",
  "interface": "<interface>",
  "timestamp_us": "<timestamp>"
}
~~~

## Defence Against Spoofed Answers

An IPv8 device MUST apply [@RFC5227] address-conflict defence
to its own identities: on receiving an ARP8 or ARP packet that
claims one of its own addresses from a different MAC, it sends
one defending announcement and raises ARP8-DUPLICATE; repeated
conflicts within the defence interval are logged, not fought,
to avoid an announcement storm. An implementation SHOULD
rate-limit the ARP8 requests it answers per source MAC and
MUST NOT allocate unbounded state for unanswered requests.

## Route Number Validation on Receipt

Every ARP8 packet carries the sender's Route Number. A segment
may legitimately carry several Route Numbers (Segment Route
Numbers, above), so no fixed rule about which public Route
Numbers may appear is possible. Validation is:

- **Reserved Route Numbers.** An ARP8 packet whose sender Route
  Number is in `224.r.r.r` or `255.r.r.r` is dropped.
- **Per-link trust list.** An operator MAY configure, per
  interface, the list of source Route Numbers that may appear on
  that link (Part III, Transit Source-RN Preservation). When a
  list is configured, an ARP8 packet whose sender Route Number is
  not on it is dropped and counted. With no list, every other
  Route Number is accepted.
- **Unexpected Route Number.** An ARP8 packet whose sender Route
  Number is in no subnet heard on the segment and is not the
  interface's own is accepted, and the NetLog8 event
  ARP8-UNEXPECTED-RN is raised as E2 at severity 4 (Warning). It
  is usually a misconfigured static Route Number, which would
  otherwise raise the event on every ARP8 it sends, so a
  repeating event is
  rate-limited: for one sender, once every 5 minutes for the
  first hour, then once a day. Repeat rates for events of other
  severities are set per severity and are not specified here.

~~~
{
  "class": "E2",
  "event": "ARP8-UNEXPECTED-RN",
  "severity": 4,
  "sender_ipv8": "64500-10.10.8.44",
  "sender_mac": "<mac>",
  "received_rn": "64500",
  "interface": "<interface>",
  "action": "accepted",
  "timestamp_us": "<timestamp>"
}
~~~

## Boot Sequence

    t = 0 ms:     DHCP8 Discover
    t = ~10 ms:   DHCP8 Offer (options 222 and 223)
    t = ~10 ms:   ARP8 probe (duplicate detection)
    t = ~60 ms:   ARP probe (duplicate detection)
    t = ~110 ms:  no duplicate: DHCP8 Request
    t = ~120 ms:  DHCP8 Acknowledge; DHCP8 registers the host
                  in DNS8 (A8 record and CNAME)
    t = ~120 ms:  gratuitous ARP8 and gratuitous ARP
    t = ~170 ms:  persistent connection to the Zone Server;
                  NetLog8 stream begins
    t = ~180 ms:  DNS8 lookup for NTP8; time sync
    t = ~200 ms:  fully operational

A device with a static address sends DHCPINFORM for option 222
in place of the Discover; on a segment with no DHCP server it
sends the ARP8 subnet query.

## ARP8 MIB Objects and NetLog8 Events

The ipv8ARP8 group of [@MIB] records cache size, entries by
mode, probes by outcome, duplicates detected, isolation
violations, subnet requests and replies, ambiguous subnets, and
gratuitous ARP8 sent. NetLog8 [@NETLOG8] events are
ARP8-DUPLICATE (SEC-ALERT, E2), ARP8-UNEXPECTED-RN (E2,
severity 4, rate-limited), ARP8-SUBNET-AMBIGUOUS,
ARP8-SUBNET-HIGH, ARP8-SUBNET-ALERT and ARP8-SUBNET-ALARM,
DEVICE-UP on persistent-connection establishment and
DEVICE-DOWN on heartbeat timeout.

# Part II: ICMPv8

## ICMPv8 Overview

An IPv8 packet is an unmodified IPv4 packet behind a shim, so
ICMP inside it is ordinary ICMP [@RFC792]. ICMPv8 is the name
for ICMP as used by IPv8 devices; it defines no new message
types and no new header. What it specifies is which Route
Numbers go in the shim of an ICMP message, how a router
reports its own identity, and how path MTU is handled for the
shim and for 8-over-4. An earlier working revision described a
distinct 36-octet ICMPv8 header; that description is withdrawn.

ICMPv8 version selection follows the ARP8 rule: an ICMP message
to a neighbour recorded as ipv4 is sent as bare IPv4; to an
IPv8 speaker it is sent with the shim. An IPv4-only device
never receives a shimmed frame.

## Addressing of ICMP Messages

An ICMP error message generated by an IPv8 device in response
to a packet is sent to the packet's Source Route Number and
Source Local Address: the shim of the error carries the
responder's own Route Number as source and the original
packet's Source Route Number as destination. The IPv4 header of
the error carries the responder's Local Address and the original
Source Local Address, as ICMP always has. The quoted original
header inside an ICMP error is the original IPv4 header and
first 8 octets of its payload, per [@RFC792]; the original shim
is not quoted, because the receiver already knows its own
Route Number and the responder's is in the error's shim.

A router that generates Time Exceeded (Type 11) or Destination
Unreachable (Type 3) therefore identifies itself by a full
`<RN>-<LA>`, which is what `traceroute8` displays per hop. A
router SHOULD use its Primary RN as the source Route Number of
errors it generates on a transit interface, and MUST NOT use a
Route Number it does not hold.

## Echo

ICMP Echo Request and Reply (Types 8 and 0) are unchanged.
`ping8` sends an Echo Request with the shim set to its own RN
and the target's RN, and displays the responder's `<RN>-<LA>`,
round-trip time, TTL and loss. A `ping8` of an IPv4 address
sends bare ICMP. An IPv8 device MUST answer Echo Requests
addressed to any of its identities.

## Redirect

ICMP Redirect (Type 5) carries the recommended gateway's Local
Address in its IPv4 body as always. The gateway's Route Number
is the Route Number of the host's subnet; it equals both Route
Numbers of the redirect's shim, since Redirect is valid only
within one segment. A router MUST NOT send Redirect across a Route
Number boundary and MUST drop Redirect received on an external
interface, generating a NetLog8 E3 event.

## Path MTU

A native IPv8 frame is 8 octets longer than the IPv4 frame
inside it; an 8-over-4 packet is 28 octets longer. IPv8
devices MUST implement path MTU discovery [@RFC1191] and MUST
NOT fragment packets with the DF bit set; they MUST return
ICMP Type 3 Code 4 with the MTU of the constraining link
expressed as the IPv4 payload the link can carry, i.e. net of
the shim.

IPv8 runs jumbo frames by default. The 1500-octet Ethernet MTU
dates from 10 Mb/s half-duplex CSMA/CD and has no place on
gigabit links; an IPv8 interface defaults to an MTU of 9000 and
scales back to 1500 where the link or path cannot carry more.
Where an interface runs at 1500, the stack limits inner packets
to 1492 so that the shim fits. For 8-over-4 the encapsulating
Zone Server performs path MTU handling on the outer path and
relays Fragmentation Needed to the inner source with the inner
MTU reduced by 28. DHCP8 SHOULD advertise a reduced MTU on
segments whose Zone Server is known to use 8-over-4 for most
traffic. A reported MTU below 576 octets MUST be ignored, and
repeated MTU reductions from one source MUST generate a NetLog8
E3 event.

## traceroute8

`traceroute8` uses Time Exceeded as traceroute does and
displays per hop the responder's `<RN>-<LA>`, round-trip time,
a marker when the Route Number changes between hops, a RINE
marker on a `100.r.r.r` hop, an XLATE8 marker where the
IPv4/IPv8 boundary is crossed, and a scoped-link marker on a
`222.r.r.r` hop:

    traceroute8 64500-192.0.2.8

    1   1115169-10.10.8.254    0.3 ms   [Zone Server]
    2   1115169-10.1.1.1       1.1 ms   [edge]
    3   222.1.1.1-10.255.0.1   1.4 ms   [scoped link]
    4   100.12.1.22-10.0.0.1   1.6 ms   [RINE]
    5   64500-192.0.2.8       71.8 ms   [destination]

# Part III: Route8

## Route8 Overview

Route8 is the IPv8 routing function. It is a map from Route
Number to forwarding target, followed by IPv4 longest-prefix
forwarding inside the target. The Route Number is matched
exactly; aggregation across Route Numbers is not defined.
`1115169-192.0.2.0/24`, `64500-192.0.2.0/24` and `0-192.0.2.0/24`
are three different routes with different targets, distinguished
by Route Number alone. Route8 is mandatory on every IPv8
device; the routing-protocol requirements vary by device role
and are specified in [@ROUTING-PROTOCOLS].

## Dispatch {#dispatch}

One kernel holds one Route Number map. Every bound Route Number
has exactly one forwarding target, and the type of that target
is the mode. A received shim is handled in this order:

    0. src or dst RN in 224.x
       or 255.x               -> drop
    1. dst RN == 0            -> shim removed, plain IPv4: main
                                 FIB, the unchanged IPv4 path
    2. dst RN bound here      -> its target: a VRF's IPv4 FIB
                                 (Provider Edge) or a table
    3. the RN's routes        -> exact RN, then longest match
                                 on the Local Address; a 222.x
                                 or 99.x RN is its own table
    4. no route               -> resolution through DNS
                                 (RN Resolution, below)
    5. still no route         -> the default route that
                                 matches the RN: a 222.x table
                                 its own or one by wildcard,
                                 a 99.x table its own,
                                 any other RN the master's
                                 (never with the DNS policy
                                 strict); otherwise drop

A frame that arrives with no shim is plain IPv4 and goes to the
IPv4 stack unchanged; no Route Number is attached to it. An IPv4
neighbour's Route Number is used only when the device sends to
it (Part I, A Neighbour's Route Number). The shim is the same in
every mode, and binding one Route Number to two targets is
rejected at configuration time.

The inner IPv4 TTL is decremented at each Route Number hop, so
a misconfigured Route Number loop dies like any IPv4 loop.
Traffic crosses between tables only by a route: static, or one
that BGP8, OSPF8 or IS-IS8 installed, exactly as routes are
leaked between VRFs on existing routers. A route MAY join two
tables of the same space (two scoped tables); a route MUST NOT
join tables of different spaces. Traffic leaves the scoped space
only through NAT (XLATE8) at an outside interface, and the
private space leaves the site only through NAT at the border
([@IPv8], Route Space Protection). A scoped table's default MAY
point at an outside interface, where NAT translates; that is the
NAT exit, not a leak. No forwarding step rewrites a Route Number
or a Local Address.

## Forwarding Modes

**Native** (`ip routing v8`). One global IPv8 table keyed on
Route Number and Local Address. Route Number 0 goes to the
ordinary main table and nothing in the IPv4 path is touched. No
VRF device, no route distinguisher, no label. This is the mode
for hosts, Zone Servers and standalone IPv8 edges, and normally
all routes live here. An interface with an IPv8 address and no
VRF has its Route Number in the main table.

**Provider Edge.** A Route Number is bound to a VRF through the
interface that carries it: the interface is placed in the VRF
and given an IPv8 address, and the address's Route Number is
bound to that VRF.

    vrf definition ipv8-1115169
     address-family ipv4
    interface Vlan10
     vrf forwarding ipv8-1115169
     ip address 1115169-10.1.1.1/24

Packets arriving for that Route Number are delivered into the
VRF; inside it the traffic is ordinary IPv4, and the routing
daemon runs VPNv4 [@RFC4364] in it with route distinguisher and
route target `<RN>:65535`, always RD type 2 (4-octet AS :
2-octet number), so the Route Number is recoverable from the RD.
65535 is the highest value not reserved; the number after the
colon belongs to the Route Number's holder. One Route Number may
be on many interfaces; its binding is removed only when no
interface still carries it. The kernel's job in this mode is
the binding, with its MPLS label and connection-tracking zone,
and XLATE8 on egress; distribution is the
carrier's existing RFC 4364 machinery. The Route Number is given
to the kernel as an explicit argument and never parsed from a
VRF name.

**Per-RN table.** A separate IPv8 table for one Route Number,
keyed on Route Number and Local Address, with no route
distinguisher or route target: the Route Number is the
separation. It is a named VRF with the IPv8 address family:

    vrf definition ipv8-64500
     address-family ipv8

(`ip vrf v8 <RN>` is accepted as a legacy short form; it is
converted to the form above, with the typed line kept as a
comment). Every scoped
(`222.r.r.r`) and interconnect (`99.r.r.r`) Route Number has a
per-RN table automatically,
created by its first route and freed with its last, up to 2^24
per node; nothing in it crosses to the global table, so the
global default route never applies there, and its own default
is `<RN>-0.0.0.0/0`. Private (`127.r.r.r`) Route Numbers have no
table of their own: they share the master table and are kept in
by the border ([@IPv8], Route Space Protection). Any other Route Number
MAY be given a per-RN table, and a Zone Server SHOULD warn when
it is, because that Route Number keeps its normal propagation
unless the operator fences it.

## VRF Names

A VRF is known to the operator by the name typed in `vrf
definition`; that name is what every configuration and display
shows. A VRF named after a Route Number is typed `ipv8-<RN>`,
the Route Number in either of its written forms:

    vrf definition ipv8-127.1.1.1
    vrf definition ipv8-1115169

Internally, and as the name of the platform's VRF device, the
VRF is `ipv8-xxxx-xxxx`: the Route Number as eight lowercase
hexadecimal digits split by a dash (`ipv8-7f01-0101`,
`ipv8-0011-0421`), always fourteen characters, within the
fifteen-character device-name limit of common platforms. Two
spellings of one Route Number are one VRF. Other VRFs keep
whatever name the operator gives them; IPv4-only VRFs are
`vrf definition <name>` with `address-family ipv4`.

## RN Resolution {#resolution}

When a packet's destination Route Number has no route, Route8
resolves it in this order:

1. **The routing table.** Routes learned by BGP8, OSPF8, IS-IS8
   or configured statically, and routes already learned by step 2.
2. **DNS.** A separate step. The Route Number's ZS records
   (`<RN>.asn.arpa`, or `<RN>.asn.openipv8.org`) are looked up
   first (Part V); if there are none, the anycast A record
   `anycast.<RN>.asn.arpa` (or `anycast.<RN>.asn.openipv8.org`).
   The answer is installed as a route for the Route Number, `<RN>`
   carried 8-over-4 to the Zone Servers the ZS records name, or
   to the anycast address, for the DNS TTL. Equal-preference ZS
   targets become equal-cost next hops, so a Route Number's
   traffic is spread across them per flow. While the lookup runs,
   up to 3 packets per Route Number are held for up to 3 seconds;
   at most 1024 Route Numbers wait at once (tunable).
3. **No answer.** The Route Number is marked failed for 60
   seconds and its traffic goes to the default route, the route
   of last resort; DNS is asked again every 5 seconds. With no
   default route, or in strict mode, the packet is dropped.

Routes learned through DNS have administrative distance 230
(configurable): after every routing protocol, including iBGP8 at
200, so any learned route replaces them. Route displays MUST mark
them distinctly (code `8D` below), so that an operator debugging
a route can see it came from DNS and not from BGP, OSPF or IS-IS.
As IPv8 is deployed and Route Numbers are carried by the routing
protocols, DNS resolution is expected to fade to a fallback.

A Zone Server SHOULD install the route at the moment it answers
the DNS query (as XLATE8 is primed from an A8 answer), so the
first packet finds it. A kernel Route Number miss means traffic
that bypassed the Zone Server's DNS, and raises a NetLog8 warning.

**Private and scoped Route Numbers.** Whether a `127.r.r.r` or
`222.r.r.r` Route Number with no route is resolved through DNS
is configurable, by a global command and a per-interface command
(the interface command wins); it is never configured per Route
Number. Two internal domains that share no routing peers are the
case for it: an internal DNS can join them. Such an answer MUST
come from the operator's own DNS, never the public `asn.arpa`
tree. The default setting is not yet specified. The master's
default route applies to private Route Numbers, which live in
the master table; it never applies to a scoped Route Number,
whose table has its own default.

**Strict mode.** With the DNS policy strict (Part IV), there is
no route of last resort: traffic goes only to destinations DNS
has answered for, and step 3 drops.

## Pseudowires

The Cisco `xconnect` forms are carried unchanged, on physical
interfaces, 802.1Q subinterfaces and SVIs, so that an engineer
who has configured EoMPLS on a router or switch types the same
thing on a Zone Server. A cross-connect is a Layer 2 pseudowire
between two devices; an interface in one carries no Layer 3
address. Both the classic one-line form and the IOS-XE form are
accepted, as IPv4 addressing accepts both the mask and the prefix
length:

    interface Vlan100
     ! the VC-ID must match
     xconnect 1115169-10.1.1.2 100 encapsulation ipv8

    interface pseudowire0100
     encapsulation ipv8
     ! the VC-ID must match
     neighbor 1115169-10.1.1.2 100
    l2vpn xconnect context vc0100
     member Vlan100
     member pseudowire0100

    interface GigabitEthernet1/2
     ! the VC-ID must match
     xconnect 203.0.113.9 200 encapsulation mpls

The running configuration keeps the IOS-XE form; a classic line
is converted to it, with the pseudowire and context numbered
after the VC ID, and marked as converted. The peer is an IPv8
address `<RN>-<LA>` or an IPv4 address. A pseudowire MAY use an
interconnect Route Number (`99.r.r.r`, [@IPv8]) for its peer.
Carried across several carriers, a pseudowire is visible hop by
hop in their interconnect Route Numbers; the two ends need not
be in directly connected carriers, and the path may cross any
number of them. The configuration shows
a comment above the VC ID, as above, because a mismatch is the
commonest fault.

**VC ID.** The VC ID identifies the pseudowire and MUST be the
same at both ends. The attachment circuits need not match: VLAN
103 at one end may meet VLAN 203 at the other.

**Encryption.** An `ipv8` pseudowire is encrypted by default: it
is carried inside the WireGuard tunnel between the two Zone
Servers, the one made by `ip remote zoneserver <peer> tunnel N
encrypt` ([@ZONESERVER]). With no such tunnel to the peer, the
pseudowire stays down and reports the reason. `no encrypt`
carries it bare; the classic line takes an optional `encrypt`.
An `mpls` pseudowire is not encrypted, because the equipment it
meets cannot be assumed to.

**EoIPv8 (`encapsulation ipv8`)** is the IPv8-native pseudowire,
on the model of L2TPv3 [@RFC3931]: the attachment circuit's
Ethernet frame is carried behind an L2TPv3 data header (session
ID and an optional cookie) in an IPv4 packet behind the shim,
native or 8-over-4, to the far device. The session ID is the VC
ID; the cookie guards against blind insertion of frames. At the
far end the packet is delivered locally, the session ID selects
the pseudowire, and the frame is emitted on the bound interface
or SVI without any Layer 3 lookup. No pseudowire state is placed
in the Route Number map.

**EoMPLS (`encapsulation mpls`)** is the interoperability
pseudowire: the Zone Server terminates an Ethernet pseudowire
[@RFC4448] against a router or switch running `xconnect ...
encapsulation mpls`. The installed base this serves is equipment
that does EoMPLS and MPLS L3VPN and nothing else, so it is
REQUIRED on a Zone Server rather than optional. Signalling is in
two steps: static labels first (`encapsulation mpls manual` with
a local and remote label at each end, no LDP), then targeted
LDP. The control word is off at both ends in the first
implementation; a control-word mismatch is the classic
pseudowire-up-no-traffic fault and implementations SHOULD detect
and report it.

**MTU.** A pseudowire's MTU defaults to 9000 and is shown in the
configuration (range 64 to 9216), scaling back where the path
cannot carry it. As on existing pseudowire equipment, a
pseudowire stays down until both ends agree on VC ID and MTU,
and a mismatch is reported with its reason; an explicit operator
override MAY bring it up despite an MTU mismatch. A device SHOULD
warn when the path is too small for the configured MTU.

**Stitching.** Two pseudowires that are members of one `l2vpn
xconnect context` are stitched into a multi-segment pseudowire,
as on existing equipment; the two segments MAY use different
encapsulations, so EoMPLS from a provider edge can continue as an
EoIPv8 pseudowire to a remote Zone Server.

## 8-over-4 Transport {#eight-over-four}

Where the next span toward a destination cannot carry EtherType
0x8080, the IPv8 packet is carried inside an outer IPv4 packet
whose Protocol field is the IPv8-in-IPv4 protocol number (253
from the experimental range [@RFC3692] pending assignment). The
outer source is the sending device's IPv4 address; the outer
destination is chosen by the Route8 entry:

- **Intra-AS**: the BGP next-hop loopback of the Route8 entry,
  exactly as BGP next-hop semantics dictate, for routes learned
  by iBGP8, OSPF8 or IS-IS8.

- **Inter-AS**: the destination Route Number's Zone Servers from
  its ZS records, or its anycast address where it publishes no ZS
  record, learned through RN Resolution (above) and installed as
  an `8D` route for the DNS TTL.

- **Inter-site within one operator**: the far Zone Server over
  the inter-site session of [@IPv8].

8-over-4 is not a tunnel. It is IPv8 carried over IPv4 until it
reaches the proper far end, which recognises the protocol
number, strips the outer header and resumes native dispatch.
There is nothing to configure: carriage over IPv4 follows from
the Route8 lookup, and every IPv4 router in between forwards an
ordinary IPv4 packet. Loop prevention and unreachability are
inherited from BGP next-hop semantics and IGP convergence; no new
state is required.

A Zone Server MUST accept an 8-over-4 packet whose Destination
Route Number is in the private or scoped route space only from
a peer with which that Route Number has been agreed (the
inter-site session, or the bilateral peering session), even
when it owns that Route Number itself. Otherwise any IPv4 host
could address a private Route Number by constructing the outer
header.

## Tunnels

Tunnels are a separate subject from 8-over-4. A Zone Server
offers WireGuard tunnels made when they are needed: between two
Zone Servers, one command stands up an encrypted path to a
remote enterprise site in seconds rather than the days an
IKE/IPsec deployment takes, and a client may hold a WireGuard
tunnel to its Zone Server for privacy, inside the network or
from outside it. The tunnels and their configuration are
specified in [@ZONESERVER].

## Scoped Route Numbers and Per-RN Tables

A scoped Route Number's table is populated three ways, all the
same kernel object: statically by the operator; by iBGP8
between BGP8 routers, each installing into table(RN) and never
into the global table; and bilaterally on one eBGP8 session
agreed for it. What is fenced is
installation: a scoped route installs only into the target its
Route Number is bound to, never into main and never into the
global IPv8 table, and is not re-advertised on any session other
than the one it was agreed for ([@IPv8] route spaces). By
default that target is the Route Number's own per-RN table. An
operator MAY instead bind a scoped Route Number in Provider Edge
mode (`vrf definition ipv8-222.x.x.x`, with the interface in that
VRF), in which case its routes land in the IPv4 VRF named for it
and are reachable from the operator's existing L3VPN VRFs through
ordinary VPNv4 route-target policy; the scope rule is unchanged,
since the VRF is the agreed target. A scoped Route Number never
leaves through an outside interface toward the Internet, and it
does not cross scopes. A route leak joins scoped tables to
each other; traffic leaves the scoped space only up through NAT
at an outside interface ([@IPv8], Route Space Protection).
Clients kept apart, each in a scoped Route Number of its own,
reach a shared layer only through NAT, and there is nothing to
leak between them even by mistake: for example
`222.<building>.<client type>.<purpose>` up to a NAT whose
policy admits only the datacentre's `127.10.10.*`.

**Wildcard Route Numbers.** In a route, a private, scoped or
RINE Route Number (127.x, 222.x, or 100.x, the RINE peering
fabric) MAY be wildcarded octet by octet, so that an operator's
own structure summarises. With Route Numbers laid out as
127.city.building.floor, a building's floors are static routes
such as `127.10.10.10-10.10.10.254/24`, and its uplink is one
route, `127.10.*.*-0.0.0.0/0`. A master Route Number is never
wildcarded: an AS number has no structure, and AS 11757 has
nothing to do with AS 11758. For the same reason an interconnect
Route Number (99.x), which carries an AS number, is never
wildcarded. The most specific match wins: the
exact Route Number, then the longest pattern, with the Local
Address by longest prefix. A private or RINE wildcard route is a
route in the master table; a scoped wildcard route is installed
in every matching scoped table and carries nothing between
them. Specific routes from BGP8 or OSPF
remain the preferred method; a wildcard suits a site kept static.

## IPv8 Routes Across BGP4

The default carriage of IPv8 routes is VPNv4, with the Zone
Server as Provider Edge ([@IPv8], Interoperation with BGP4):
existing routers carry it as they stand, and the Route Number
returns from the route distinguisher at the far BGP8 router. The
large-community path described here is off by default. It is
for public Route Numbers with globally unique Local Addresses
crossing a BGP4 fabric with no Provider Edge at either end.

A router learns a new BGP address family only from its software:
which AFI/SAFI pairs a router speaks is built into its BGP
implementation and negotiated per session [@RFC4760]; it cannot
be added by configuration, and a router that does not know an
address family neither negotiates nor carries it. IPv8 routes
therefore cross existing BGP4 routers as ordinary IPv4 routes
tagged with a BGP Large Community [@RFC8092] that names the
Route Number, named `asn-ibgp-path` [@ROUTING-PROTOCOLS]
(`<GA>:8:<RN>`; until IANA assigns the Global Administrator,
implementations use the private ASN 4288888888), an optional
transitive attribute that unmodified BGP4 routers pass on. It is
iBGP-scoped: a BGP8 speaker strips it on eBGP unless that
neighbour is configured to receive it.

An existing BGP4 router needs no new code to use them: it
matches the large community in its import policy (a route-map
used as a VRF import map, or a VRF import policy) and installs
the Local Address prefixes into the VRF for that Route Number,
with the IPv8 neighbour as next hop. It forwards plain IPv4 to
that neighbour, which applies the Route Number. A router with the
BGP8 code decodes the routes fully.

Overlapping Local Addresses in different Route Numbers are the
one case to provide for: on one BGP session a prefix is carried
once, so `1115169-10.1.0.0/16` and `64500-10.1.0.0/16` sent to
one neighbour on one session would replace each other. Two
remedies are specified; one or the other is needed:

- **One session per VRF** (VRF-lite): each Route Number's VRF has
  its own BGP session to the IPv8 neighbour.
- **ADD-PATH** [@RFC7911]: one session carries every path for a
  prefix, each with its own path identifier, and the import
  policy sorts them into VRFs by large community.

## Transit Source-RN Preservation

A router that forwards an IPv8 packet, whether natively, over
8-over-4, or through a pseudowire's carriage, MUST preserve the
packet's Source Route Number end to end. It MUST NOT substitute
its own Route Number. The only device that changes a Source
Route Number is XLATE8 performing 8-to-8 translation at a Route
Number boundary, which keeps per-flow state so that the reply is
mapped back. A per-flow source-RN cache on transit devices
records the originator's Route Number against the flow so that
replies and ICMP errors are addressed to it. An operator MAY
configure a per-link source-RN trust list on an interface,
recording which Route Numbers may legitimately appear as sources
on that link; when one is configured, a packet whose Source
Route Number is not on the list for its ingress interface is
dropped and logged.

A Zone Server MUST 8-to-8 translate a Source Route Number in
the private route space to its own public Route Number before
sending the packet over a session on which that private Route
Number has not been agreed; otherwise the reply carries a
private Destination Route Number that cannot cross back.

## Local Address Uniqueness Across Sites

Independently of the per-segment rule of Part I, a Local
Address MUST be unique within one Route Number across every
site that carries that Route Number: one Route Number is one
address space. The conflict surfaces as two routes for one
`<RN>-<LA>` on the iBGP8 session joining the sites, and an
implementation MUST treat it as a duplicate-address condition,
installing neither and raising the alarm, rather than letting
best-path selection pick one.

## Route Display

Route display commands are vendor-defined. A display of the
routing table shows IPv4 and IPv8 together, with the Route
Number on every line:

    Gateway of last resort:
       1115169-10.10.8.254 even
       1115169-10.10.8.253 odd

    C    1115169-10.10.8.0/24 connected, Gi1/1
    O8   1115169-10.10.9.0/24 [110/2] via 1115169-10.10.8.254
    B8   64500-192.0.2.0/24 [20/0] via 203.0.113.1 (8-over-4)
    8D   64501 [230/0] via 198.51.100.7 (8-over-4, from DNS)
    S    0-0.0.0.0/0 [1/0] via 1115169-10.10.8.254 even
                            via 1115169-10.10.8.253 odd

Administrative distances are those of the underlying protocols:
connected 0, static 1, eBGP8 20, OSPF8 110, IS-IS8 115, iBGP8
200, and routes learned through DNS (`8D`) 230. IPv8 routes
learned by the routing protocols are marked with the protocol's
letter and 8: `B8` BGP8, `O8` OSPF8 (`O8-1` and `O8-2` its type 1
and type 2 externals), `I8` IS-IS8.

## Routing Protocols

Routing protocols carry IPv8 reachability as specified in
[@ROUTING-PROTOCOLS]: by default as VPNv4 with the Zone Server
as Provider Edge, between BGP8 speakers too; as native BGP8 NLRI
(the experimental IPv8 AFI) only where both ends negotiate it; as
the `asn-ibgp-path` large community across a BGP4 fabric with no
Provider Edge (above); OSPF8 as opaque LSAs; IS-IS8 as TLVs. These
are the existing protocols with IPv8 reachability added, not new
protocols, and their native metrics and path selection are
unchanged. Cost Factor and Sun Tzu belong to BGP8x and are not
required by anything in this document. On a Zone Server the
routing daemons are configured from the Zone Server's running
configuration and started and stopped through the routing
suite's own reload mechanism; their configuration appears within
the Zone Server's running configuration. Static routes are REQUIRED on every
device including end devices. RIP and EIGRP are not specified
for IPv8. Anyone who builds EIGRP for IPv8 should follow the same
process as OSPF8, IS-IS8 and IBGP8: the protocol unchanged,
carrying IPv8 reachability, its native metric kept for intra-AS
path selection, and Cost Factor and other metrics handled through
the IGP CF Export Interface of [@ROUTING-PROTOCOLS].

## Even/Odd Dual Default Gateway

Every IPv8 segment has two default gateways, the Zone Server
pair at `.254` (even) and `.253` (odd). Devices with an
even-numbered Local Address use `.254` as active and `.253` as
failover; odd-numbered devices the reverse. TCP connections
follow their even or odd path for the life of the connection,
chosen at establishment; UDP follows the source device's parity
per datagram. Where the two Zone Servers have different
upstreams, the even path and the odd path are two ISPs, and on
failure of one all traffic moves to the other without operator
action. The pair is active-active; if one is lost the survivor
takes both parities, and on a partition both deliberately take
both and compete rather than running as two independent
gateways. Maximum packets lost on failover: two.

## Management Plane

Management of an IPv8 device is reached only through its
management port or a management tunnel. The management port is
a dedicated routed port, never a switch port, in its own
management table (`Mgmt-vrf` by convention): a switch port would
send spanning-tree BPDUs, and an upstream port with BPDU guard
would shut it down. The management port and management
tunnels are the only interfaces in that table; no VLAN interface
is ever placed in it. A management tunnel is an encrypted Layer 3
tunnel (Tunnels, above) that carries management traffic to a
remote management system; the device dials out, so the site needs
no inbound port. It is never a Layer 2 pseudowire, which would
extend the management segment itself. The management port's
address is DHCP-assigned by default. A separate out-of-band emergency
VRF MAY exist where the platform has one. The management table
has no routes to production segments and production segments
have no routes to it; it uses static routes only.

## Route8 MIB Objects

The ipv8Route8 group of [@MIB] records table sizes by mode and
protocol, per-RN table count, default gateway addresses, Route
Numbers waiting for and failed in DNS resolution, `8D` routes
installed, and counters for reserved-RN drops, no-route drops,
scope violations (a route refused installation outside its
space), source-RN trust drops, and duplicate-address conflicts
across sites.

# Part IV: ACL8

## ACL8 Overview

ACL8 is enforced on every interface of every IPv8 device. The
Zone Server is the policy authority that builds and distributes
ACL8 policy; every device enforces it locally. ACL8 is a
configuration layer: it does not replace platform-native
firewalls, it configures them.

## Three-Layer Policy Model

~~~
Layer 1  Network-manager manual ACL (highest authority)
         Operator configured, explicit, absolute.
Layer 2  Auto-ACL from the device's JWT declaration
         The device announces its legitimate ports and
         destinations in ipv8: claims of its OAuth8 token;
         the Zone Server adds them automatically. Only
         authenticated devices generate auto-ACL. Subject
         to Layer 1.
Layer 3  Default deny
         Anything not permitted by Layer 1 or 2 is dropped,
         with a NetLog8 SEC-ALERT.
~~~

~~~
{
  "ipv8:accept-ports":          ["443", "80"],
  "ipv8:initiate-ports":        ["5432"],
  "ipv8:initiate-destinations": ["db.internal"],
  "ipv8:program":               "com.company.webserver",
  "ipv8:service":               "WebServerService",
  "ipv8:acl-mode":              "declared-only"
}
~~~

An unauthenticated device is confined to the holding Route
Number of [@IPv8] and receives no auto-ACL; it cannot declare
its way out without a valid token.

## Platform Translation

Each platform translates ACL8 policy into its native
mechanism: the Windows Filtering Platform directly, with
program and service identity as first-class rules; nftables on
Linux with cgroup, SELinux or unit binding for program identity;
pf plus the application firewall on macOS; and a port and
address subset in NIC and switch hardware. Program and service
identity claims are stronger than port rules: a compromised
process masquerading on port 443 is blocked where the executable
does not match the declared program identity.

## Rule Syntax

ACL8 rules use the canonical `<RN>-<LA>` form. The Route Number
is matched exactly, wildcarded as a whole, or, in the private,
scoped and RINE spaces, wildcarded octet by octet as in routes
(`127.10.10.*`); a master or interconnect Route Number is never
wildcarded by octet. Wildcard masks apply to the Local Address. IPv4 rules continue to function and
are treated as Route Number 0.

~~~
access-list <n> <permit|deny> <protocol>
   <source-ipv8> <source-wildcard>
   <destination-ipv8> <destination-wildcard>
   [eq <port>] [program <id>] [service <name>] [log]

deny ip 64500-0.0.0.0/0 any        ! everything from RN 64500
deny ip 0-0.0.0.0/0 any            ! all plain IPv4 (RN 0) traffic
permit ip 222.*.*.*-0.0.0.0/0 127.10.10.*-0.0.0.0/0
                                   ! clients to the datacentre only
~~~

The last rule of every list is an implicit deny. Rules MAY
reference DNS names, resolved at application and refreshed on
TTL expiry; on resolution failure the last result is kept, a
NetLog8 error is raised, and resolution is retried every 60
seconds.

## DNS Policy

Each interface has a DNS policy, set globally with a per-interface
override:

- **normal** (the default): traffic flows as it does today, peer
  to peer; DNS is used where it is used.
- **strict**: a flow is permitted only if a DNS8 lookup produced
  it. A destination given as a bare IP address that no DNS answer
  produced is not forwarded, and there is no route of last
  resort (Part III, RN Resolution). Strict mode ends north-south
  malware traffic that calls out to bare addresses. It is the
  mechanism behind the strict interface mode of [@IPv8] and
  behind the handle mechanism of Part V.

Strict's two drops, traffic with no DNS answer and routes that
RPKI marks invalid ([@IPv8], Route origin validation), are the
rules of the access list `Policy_Strict`. They are a default
setting, not a requirement: the operator can change them.

Other interface modes of [@IPv8] (plug-and-play, and guest for
devices not yet logged in) are unchanged by the DNS policy. A
stricter posture, such as denying destinations with a poor
reputation, is an ordinary access list (for example one filled
from DNS response policy zone feeds), not a further DNS policy.
WHOIS8. Deprecated in favour of RPKI and ASPA. The keyword
`whois` on the strict policy
(`dns-lookup mode strict whois`) is reserved for future use: an
implementation accepts it, reports that it is reserved, and
changes nothing.

## Distribution and Logging

Zone rules are distributed to end devices via DHCP8
(`dhcp8 option acl8-zone <name>`), so that both the device's
own enforcement and the Zone Server's must be defeated for
lateral movement. ACL8 denies with the `log` keyword generate
NetLog8 E3 events; a surge of denies from one source SHOULD
raise a SEC-ALERT; Layer 1 overriding Layer 2 is logged as a
POLICY event with the conflicting declaration. When ACL8 policy
is configured, a device passes no packets until the policy has
loaded; if it fails to load, the drop stays in place and the
failure is reported through NetLog8. Rules protecting
the management port MUST NOT be modifiable through the
management interface.

# Part V: DNS8

## DNS8 Overview

DNS8 is DNS [@RFC1035] carrying two additional resource record
types and one additional behaviour. It runs over the same
transports as DNS (UDP and TCP port 53, DNS over HTTPS
[@RFC8484], DNS over TLS [@RFC7858]) and validates with DNSSEC.
Existing DNS servers serve the new records through the generic
RR-type notation of [@RFC3597] without modification.

DNS8 serves three purposes: destination resolution for IPv8
clients (the A8 record); Route Number resolution for Route8 (the
anycast A record, and the ZS record); and the handle mechanism
by which IPv4-only clients reach other Route Numbers.

## A8 Record

| Field    | Value                                       |
|----------|---------------------------------------------|
| TYPE     | A8 (IANA assignment requested in [@IPv8])   |
| CLASS    | IN                                          |
| RDLENGTH | 8                                           |
| RDATA    | Route Number, Local Address; network order  |

A name MAY have A records and A8 records together; a name MAY
have several A8 records. An IPv8 client that receives an A8
record opens an AF_INET8 socket to it, and the Route Number is
thereby attached to the connection before any packet is sent.

To an IPv8 client, a name with A records and no A8 record is in
Route Number 0: the address `n.n.n.n` is `0-n.n.n.n`. An IPv4
client receives `n.n.n.n` as always.

## ZS Record and the Anycast Record

The ZS record lists a Route Number's Zone Server ingress
endpoints with MX-style preference semantics: a preference
value and a target name, resolved by ordinary A and A8 records.
The primary hierarchy is `<RN>.asn.arpa`; a parallel hierarchy
`<RN>.asn.openipv8.org` serves hosted DNS, private Route
Numbers, experimental deployments and deployments not under
formal delegation, and is used until `asn.arpa` is delegated.

| Field    | Value                                       |
|----------|---------------------------------------------|
| TYPE     | ZS (IANA assignment requested in [@IPv8])   |
| CLASS    | IN                                          |
| RDATA    | Preference (16 bits), target domain name    |

The ZS record is how a Route Number's ingress is load-balanced:
an operator with forty Zone Servers across the globe publishes
forty ZS records. Targets of equal preference share the traffic,
each sender spreading its flows across them; a higher preference
value is used only when every target of a lower value is
unreachable. A sender MAY prefer the nearest of equal targets
where it can measure distance.

The anycast A record `anycast.<RN>.asn.arpa` resolves to one IPv4
address the operator announces from several locations as an
anycast prefix (a `/24`, or within one the operator already
announces; longer prefixes are filtered on the Internet), so the
internet's routing delivers each sender to
the nearest Zone Server, as a public anycast resolver does. Every
Zone Server is an anycast server for its Route Number by default:
it announces the Route Number's anycast prefix unless the
operator turns that off, so each Zone Server put up brings the
Route Number's anycast closer to the world.

Anycast alone has no failover a sender can act on: it gives one
address, and if the nearest Zone Server fails while its
announcement stays up, the sender has nowhere else to go until
that is fixed. The ZS list supplies the failover. A Route Number
SHOULD therefore list its own anycast name first and its
individual Zone Servers after it:

    1115169.asn.arpa.  ZS  10 anycast.1115169.asn.arpa.
    1115169.asn.arpa.  ZS  20 zs-lon.example.net.
    1115169.asn.arpa.  ZS  20 zs-nyc.example.net.
    1115169.asn.arpa.  ZS  20 zs-sin.example.net.

Normally preference 10 wins and anycast delivers the sender to
the closest Zone Server; if it fails, the sender moves at once to
the preference-20 servers, which share the load, without waiting
for the record's TTL. A Route Number that publishes no ZS record
is resolved through `anycast.<RN>` directly (Part III, RN
Resolution). How a sender detects that a target has failed is an
implementation matter. Records in both
hierarchies SHOULD be DNSSEC-signed; a forged ZS or anycast
record redirects an entire Route Number's ingress, and clients
SHOULD refuse unsigned answers where the zone is known to be
signed.

## Registration at Lease Time

The DHCP8 server registers each host in DNS8 at lease time: a
designated name with the host's A8 record, and a CNAME from the
machine's own hostname to it. Service names are further CNAMEs
to the machine name, so CNAME chains are normal. The zone apex
is the Zone Server itself. The registration records the client
as the Zone Server saw it, which is what the handle mechanism
and the self-lookup rule below depend on.

## Handles for IPv4-only Clients {#handles}

An IPv4-only client addresses everything by a 32-bit IPv4
address and sends bare IPv4. For a destination in another
Route Number the Zone Server must add the shim on its behalf,
and the only moment the client expressed which Route Number it
meant is the DNS lookup before the packet. The Route Number
therefore attaches at DNS time, and XLATE8's 4-to-8 state is
created by the DNS8 answer, keyed on the client as the Zone
Server sees it and the address returned. It is never keyed on
the bare destination Local Address.

DNS8 answers an IPv4-only client as follows:

- A name in the client's own Route Number, any subnet: the real
  Local Address. No state.
- A name in Route Number 0 (the Internet): the real public
  address. The default route carries it to the Zone Server.
- A name in any other Route Number: a **handle** from
  `198.18.0.0/15` [@RFC2544], every time, first lookup included.
  The handle is sticky: the same client asking for the same
  `<RN>-<LA>` gets the same handle while the binding lives, and
  one client never has two bindings on one handle. The binding
  expires with its last use and the handle returns to the pool.

Returning the real Local Address on the first cross-RN lookup
and a handle only on a later conflicting one is NOT permitted.
The Zone Server cannot know what a Local Address means from the
client's side: the same address may sit behind other addresses
on the client's side of the network, and when it is on the
client's own subnet the client resolves it locally and the
packet never reaches the Zone Server. A handle cannot collide.

The pool is per Zone Server interface: each segment has 131,072
handles, and one handle may be in use on two interfaces for two
clients. The client sees only three kinds of address, its own
Route Number's, the Internet's, and handles, which cannot
collide.

A client behind a legacy NAT in front of the Zone Server needs
nothing special: its queries and its packets traverse the same
NAT, so the client as the Zone Server sees it is the same for
both, and the client is never told its own real address. A
lookup of the client's own registered name, recognised because
the query source matches the registration, returns the client's
own address as the client knows it. DNS8 MUST NOT resolve a
name in a scoped Route Number for a client whose Zone Server has
no agreed session for that Route Number; no handle is minted
for an unreachable target.

## Availability and Failover

DNS8 availability tracking uses a lightweight counter stream on
each client's persistent connection to the Zone Server:
clients pre-aggregate connection outcomes and send compact
updates every 60 seconds. An A8 address with no successes for
five continuous minutes is withdrawn from answers and restored
when successes resume; transitions generate NetLog8 events. The
default A8 TTL is 30 minutes. On loss of its Zone Server a
client connects to the other of the pair; lease state is
shared between them and no re-authentication is required.

## DNS8 MIB Objects

The ipv8DNS8 group of [@MIB] records queries by type (A8, ZS,
anycast), DNSSEC validations and failures, cache statistics,
handles in use and pool high-water mark per interface, and
availability-state transitions.

# Implementation Status

This section records the status of known implementations per
[@RFC7942] and will be removed before publication as an RFC.

The ip8native Linux kernel module (alpha 10) implements the
dispatch of Part III with the drop of the system space (224.x and
255.x); the native, Provider Edge and per-RN table modes, with a
table of its own for each scoped Route Number and private Route
Numbers in the master table under its default; wildcard Route
Numbers in routes (private, scoped and RINE, octet by octet,
never a master Route Number); the outside-interface flag, at
which a private Route Number never leaves; RN resolution through
DNS with packet hold, failure marking, retry and fallback to the
default route (private and scoped Route Numbers do not yet ask
DNS); the strict ingress with no default; recursive next hops
with a loop guard; 8-over-4 for routes configured over IPv4;
transit source-RN preservation with the per-flow source-RN cache
and per-link trust list; ARP8 with the three-step resolution and
the broadcast RN, answers per interface as ARP does,
re-confirmation of an entry in use every 30 seconds, and the
ARP4 fallback restricted to the Route Number of the subnet
holding the Local Address (the interface's own when no subnet is
known); detection of one Local Address on two MACs in any Route
Numbers, with the established entry defended; the [@RFC5227] ARP
probe on address assignment and interface up; the ARP8 subnet
query (operations 26 and 27) with its subnet levels; ICMP echo
within the shim (`ping8`); and the AF_INET8 socket family. Its
functional suite passed in full (181 tests) on a patched Linux
6.12.111 kernel on 2026-10-30. Not yet in the kernel: the ARP8
probe and gratuitous ARP8, ARP8-UNEXPECTED-RN, ICMP Time
Exceeded at Route Number hops (an expired packet is dropped
silently), the 8-over-4 path-MTU relay, jumbo frames by default,
per-RN tables for interconnect Route Numbers, and equal-cost next
hops for a Route Number. The kernel modules are published under
the GPL-2.0.

zoneCore (alpha 4, Go, MIT licence), built on a general console
platform with the IPv8 functions as an add-on, implements DHCP8
with options 222 and 223, DHCPINFORM and lease-time registration
of an A8 record (a private-use type until one is assigned); DNS8
with A8 and the anycast record under `asn.arpa` and
`asn.openipv8.org`; the interface-based VRF binding with VRFs
typed `ipv8-<RN>` and held as `ipv8-xxxx-xxxx`, RD/RT
`<RN>:65535`, and `ip vrf v8` converted; the interface modes; the
pseudowire configuration in both forms; ACL8 `<RN>-<LA>`
addresses, with octet wildcards, in IOS access lists (the Route
Number is not yet matched by the packet filter: rules match the
Local Address only); the outside-interface border; one routing
table display of IPv4 and IPv8; and NetLog8 over a provisional
TCP transport.

Routing is FRR8 (alpha 3, GPL-2.0), a fork of FRR 10.3.4 with
IPv8 in zebra, bgpd, ospfd and isisd: native BGP8 NLRI
(experimental AFI 8888) where both ends negotiate it, the
`asn-ibgp-path` large community, OSPF8 opaque LSAs and IS-IS8
TLVs, shown as `B8`, `O8` (`O8-1`, `O8-2`) and `I8`. Cost Factor
and Sun Tzu are left to version 1.1.

The pseudowire data plane, the handle mechanism, the ZS record,
DNS resolution for private and scoped Route Numbers, `8D` route
marking, the JWT-derived auto-ACL and `Policy_Strict` are
specified here ahead of implementation. Aleksei Aleinikov
independently tested the kernel implementation in virtual
machines including KASAN, KCSAN and lockdep kernels; findings
from that testing are reflected in Parts I and III. Source is
published at https://www.openipv8.org.

# Security Considerations

ARP8 spoofing is mitigated by the three-step resolution, which
never hands a Route Number's traffic to a device of another
Route Number; by [@RFC5227]-style defence of a device's own
identities and of established entries; by rate limiting of
answers; by the per-link trust list where configured; by
switch-port binding where available; by Zone Server MAC-to-port
tracking via LLDP; and by the NetLog8 audit trail. The segment's
Primary RN is taken from DHCP, not from any ARP8 message, so it
cannot be set by a forged broadcast; the subnet query's levels
cost a forger's victims log lines, never service.

Route injection into the management plane is prevented by
static-only routing in the management table. Scoped and private
routes cannot be injected into the public space because a
route installs only into the table of its own space; a Zone
Server accepts 8-over-4 for a private or scoped Route Number
only from an agreed peer; and a private Source Route Number is
translated before it crosses an unagreed session. No forwarding
step rewrites a Route Number or a Local Address; traffic crosses
between tables only by a route.

A DNS-learned route can redirect a Route Number's traffic, so
DNS answers SHOULD be DNSSEC-validated, a private or scoped
Route Number is resolved only through the operator's own DNS,
and DNS-learned routes rank below every routing protocol.

ICMP Redirect MUST NOT cross a Route Number boundary and MUST
be dropped on external interfaces. Path MTU messages are
validated as in Part II. Per-RN table isolation is a routing
property and cannot be bypassed by ACL misconfiguration. Even
and odd paths are fixed for a connection's life, so a path
change requires a new connection. EoIPv8 pseudowires are
carried in WireGuard by default.

The handle mechanism exposes nothing: handles are not globally
reachable, exist only in the Zone Server's state for one
interface, and expire with the binding. A client that can run a
tool using `198.18.0.0/15` for its own purposes (some proxy
clients do) will conflict with handles on that client only;
implementations SHOULD detect such a client by its failure to
use handles and log it.

# IANA Considerations

The ARP8 protocol type is the IPv8 EtherType 0x8080 requested
in [@IPv8]; no separate assignment is needed. This document
requests two values from the ARP Operation Codes registry
[@RFC5494]: 26, ARP8 Subnet Request, and 27, ARP8 Subnet Reply.
Values 3 and 4 belong to RARP [@RFC903] and are not used. The IPv8-in-IPv4 protocol number,
the A8 and ZS resource record types, the `asn.arpa` delegation
and the 198.18.0.0/15 registry note are requested in [@IPv8].
This document requests a DHCP8 option code for `acl8-zone`, and
NetLog8 event
registrations for the ARP8, ICMPv8, Route8 and ACL8 events named
above per [@NETLOG8].

# References

## Normative References

<reference anchor="RFC826">
  <front>
    <title>Ethernet Address Resolution Protocol</title>
    <author initials="D." surname="Plummer"/>
    <date year="1982" month="November"/>
  </front>
  <seriesInfo name="RFC" value="826"/>
</reference>

<reference anchor="RFC903">
  <front>
    <title>A Reverse Address Resolution Protocol</title>
    <author initials="R." surname="Finlayson"/>
    <author initials="T." surname="Mann"/>
    <author initials="J." surname="Mogul"/>
    <author initials="M." surname="Theimer"/>
    <date year="1984" month="June"/>
  </front>
  <seriesInfo name="RFC" value="903"/>
</reference>

<reference anchor="RFC5494">
  <front>
    <title>IANA Allocation Guidelines for the Address Resolution Protocol (ARP)</title>
    <author initials="J." surname="Arkko"/>
    <author initials="C." surname="Pignataro"/>
    <date year="2009" month="April"/>
  </front>
  <seriesInfo name="RFC" value="5494"/>
</reference>

<reference anchor="RFC792">
  <front>
    <title>Internet Control Message Protocol</title>
    <author initials="J." surname="Postel"/>
    <date year="1981" month="September"/>
  </front>
  <seriesInfo name="RFC" value="792"/>
</reference>

<reference anchor="RFC1035">
  <front>
    <title>Domain names - implementation and specification</title>
    <author initials="P." surname="Mockapetris"/>
    <date year="1987" month="November"/>
  </front>
  <seriesInfo name="RFC" value="1035"/>
</reference>

<reference anchor="RFC1191">
  <front>
    <title>Path MTU Discovery</title>
    <author initials="J." surname="Mogul"/>
    <author initials="S." surname="Deering"/>
    <date year="1990" month="November"/>
  </front>
  <seriesInfo name="RFC" value="1191"/>
</reference>

<reference anchor="RFC2119">
  <front>
    <title>Key words for use in RFCs to Indicate Requirement Levels</title>
    <author initials="S." surname="Bradner"/>
    <date year="1997" month="March"/>
  </front>
  <seriesInfo name="RFC" value="2119"/>
</reference>

<reference anchor="RFC2131">
  <front>
    <title>Dynamic Host Configuration Protocol</title>
    <author initials="R." surname="Droms"/>
    <date year="1997" month="March"/>
  </front>
  <seriesInfo name="RFC" value="2131"/>
</reference>

<reference anchor="RFC3597">
  <front>
    <title>Handling of Unknown DNS Resource Record (RR) Types</title>
    <author initials="A." surname="Gustafsson"/>
    <date year="2003" month="September"/>
  </front>
  <seriesInfo name="RFC" value="3597"/>
</reference>

<reference anchor="RFC3931">
  <front>
    <title>Layer Two Tunneling Protocol - Version 3 (L2TPv3)</title>
    <author initials="J." surname="Lau"/>
    <author initials="M." surname="Townsley"/>
    <author initials="I." surname="Goyret"/>
    <date year="2005" month="March"/>
  </front>
  <seriesInfo name="RFC" value="3931"/>
</reference>

<reference anchor="RFC4364">
  <front>
    <title>BGP/MPLS IP Virtual Private Networks (VPNs)</title>
    <author initials="E." surname="Rosen"/>
    <author initials="Y." surname="Rekhter"/>
    <date year="2006" month="February"/>
  </front>
  <seriesInfo name="RFC" value="4364"/>
</reference>

<reference anchor="RFC4448">
  <front>
    <title>Encapsulation Methods for Transport of Ethernet over MPLS Networks</title>
    <author initials="L." surname="Martini"/>
    <author initials="E." surname="Rosen"/>
    <author initials="N." surname="El-Aawar"/>
    <author initials="G." surname="Heron"/>
    <date year="2006" month="April"/>
  </front>
  <seriesInfo name="RFC" value="4448"/>
</reference>

<reference anchor="RFC4760">
  <front>
    <title>Multiprotocol Extensions for BGP-4</title>
    <author initials="T." surname="Bates"/>
    <author initials="R." surname="Chandra"/>
    <author initials="D." surname="Katz"/>
    <author initials="Y." surname="Rekhter"/>
    <date year="2007" month="January"/>
  </front>
  <seriesInfo name="RFC" value="4760"/>
</reference>

<reference anchor="RFC5227">
  <front>
    <title>IPv4 Address Conflict Detection</title>
    <author initials="S." surname="Cheshire"/>
    <date year="2008" month="July"/>
  </front>
  <seriesInfo name="RFC" value="5227"/>
</reference>

<reference anchor="RFC5737">
  <front>
    <title>IPv4 Address Blocks Reserved for Documentation</title>
    <author initials="J." surname="Arkko"/>
    <author initials="M." surname="Cotton"/>
    <author initials="L." surname="Vegoda"/>
    <date year="2010" month="January"/>
  </front>
  <seriesInfo name="RFC" value="5737"/>
</reference>

<reference anchor="RFC7911">
  <front>
    <title>Advertisement of Multiple Paths in BGP</title>
    <author initials="D." surname="Walton"/>
    <author initials="A." surname="Retana"/>
    <author initials="E." surname="Chen"/>
    <author initials="J." surname="Scudder"/>
    <date year="2016" month="July"/>
  </front>
  <seriesInfo name="RFC" value="7911"/>
</reference>

<reference anchor="RFC8092">
  <front>
    <title>BGP Large Communities Attribute</title>
    <author initials="J." surname="Heitz"/>
    <author initials="J." surname="Snijders"/>
    <author initials="K." surname="Patel"/>
    <author initials="I." surname="Bagdonas"/>
    <author initials="N." surname="Hilliard"/>
    <date year="2017" month="February"/>
  </front>
  <seriesInfo name="RFC" value="8092"/>
</reference>

<reference anchor="RFC8174">
  <front>
    <title>Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words</title>
    <author initials="B." surname="Leiba"/>
    <date year="2017" month="May"/>
  </front>
  <seriesInfo name="RFC" value="8174"/>
</reference>

<reference anchor="IPv8">
  <front>
    <title>Internet Protocol Version 8 (IPv8)</title>
    <author initials="J." surname="Thain" fullname="Jamie Thain"/>
    <author initials="A." surname="Aleinikov" fullname="Aleksei Aleinikov"/>
    <date year="2026" month="October"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-thain-ipv8-04"/>
</reference>

<reference anchor="ZONESERVER">
  <front>
    <title>IPv8 Zone Server Architecture</title>
    <author initials="J." surname="Thain" fullname="Jamie Thain"/>
    <date year="2026" month="May"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-thain-zoneserver-00"/>
</reference>

## Informative References



<reference anchor="RFC2544">
  <front>
    <title>Benchmarking Methodology for Network Interconnect Devices</title>
    <author initials="S." surname="Bradner"/>
    <author initials="J." surname="McQuaid"/>
    <date year="1999" month="March"/>
  </front>
  <seriesInfo name="RFC" value="2544"/>
</reference>

<reference anchor="RFC3692">
  <front>
    <title>Assigning Experimental and Testing Numbers Considered Useful</title>
    <author initials="T." surname="Narten"/>
    <date year="2004" month="January"/>
  </front>
  <seriesInfo name="RFC" value="3692"/>
</reference>

<reference anchor="RFC7858">
  <front>
    <title>Specification for DNS over Transport Layer Security (TLS)</title>
    <author initials="Z." surname="Hu"/>
    <author initials="L." surname="Zhu"/>
    <author initials="J." surname="Heidemann"/>
    <author initials="A." surname="Mankin"/>
    <author initials="D." surname="Wessels"/>
    <author initials="P." surname="Hoffman"/>
    <date year="2016" month="May"/>
  </front>
  <seriesInfo name="RFC" value="7858"/>
</reference>

<reference anchor="RFC7942">
  <front>
    <title>Improving Awareness of Running Code: The Implementation Status Section</title>
    <author initials="Y." surname="Sheffer"/>
    <author initials="A." surname="Farrel"/>
    <date year="2016" month="July"/>
  </front>
  <seriesInfo name="RFC" value="7942"/>
</reference>

<reference anchor="RFC8484">
  <front>
    <title>DNS Queries over HTTPS (DoH)</title>
    <author initials="P." surname="Hoffman"/>
    <author initials="P." surname="McManus"/>
    <date year="2018" month="October"/>
  </front>
  <seriesInfo name="RFC" value="8484"/>
</reference>

<reference anchor="ROUTING-PROTOCOLS">
  <front>
    <title>IPv8 Routing Protocols: BGP8, IBGP8, OSPF8, IS-IS8</title>
    <author initials="J." surname="Thain" fullname="Jamie Thain"/>
    <date year="2026" month="May"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-thain-routing-protocols-00"/>
</reference>

<reference anchor="NETLOG8">
  <front>
    <title>NetLog8 Protocol</title>
    <author initials="J." surname="Thain" fullname="Jamie Thain"/>
    <date year="2026" month="May"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-thain-netlog8-00"/>
</reference>

<reference anchor="MIB">
  <front>
    <title>IPv8 Management Information Base and SNMPv8 Protocol</title>
    <author initials="J." surname="Thain" fullname="Jamie Thain"/>
    <date year="2026" month="April"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-thain-ipv8-mib-00"/>
</reference>

{backmatter}

# Appendix A: Relationship to Earlier Working Text

This is the first submitted revision. Earlier unsubmitted working
text differed as follows.

- **Wire format.** All text is aligned to the shim: an 8-octet
  Route Number pair in front of an unmodified IPv4 packet. The
  36-octet ICMPv8 header, the IPv8 header version field, the
  Parameter Problem offsets for a widened header, and the
  9000-octet fixed MTU are withdrawn; jumbo frames are now the
  default with fallback to 1500.

- **ARP8.** Protocol type corrected to the IPv8 EtherType 0x8080
  (0x86DD8 does not fit the field). The two-step dual probe is
  replaced by three-step resolution with the broadcast RN
  255.255.255.255, closing a cross-RN leak through ARP. The
  segment's Primary RN comes from DHCP (option 222, DHCPINFORM),
  not from gratuitous ARP8, with the ARP8 subnet query
  (operations 26 and 27) where there is no DHCP; an IPv4-only
  neighbour is in its subnet's Route Number. The rule dropping a
  public Route Number other than the Primary is withdrawn; the
  per-link trust list drops, and ARP8-UNEXPECTED-RN is a
  rate-limited low-severity event. The hybrid "ipv8h" mode is
  removed.

- **Route8.** Dispatch begins with the reserved-RN drop; a frame
  with no shim stays plain IPv4. Provider Edge binding is by
  interface (`vrf definition`, `vrf forwarding`, `ip address
  <RN>-<LA>/<len>`); `ip vrf v4 ... rn` is withdrawn; `ip vrf v8 <RN>` is
  accepted and converted to `vrf definition` with
  `address-family ipv8`. VRFs named after a
  Route Number are typed `ipv8-<RN>` and held as
  `ipv8-xxxx-xxxx`. RD/RT `<RN>:65535`, type 2. Per-RN tables
  are automatic for scoped Route Numbers; private Route Numbers
  share the master table and are kept in by the border. The
  Route-Number-rewriting `ip rn connect` and the address-rewriting
  target of the Route Number map are withdrawn: tables are joined only
  by routes. RN resolution: routing table, then DNS (ZS records,
  anycast record as fallback, `8D` routes at distance 230), then
  the default route;
  configurable for private and scoped Route Numbers; none in
  strict mode. Pseudowires follow the Cisco forms (classic and
  IOS-XE), the L2TPv3 model for EoIPv8, encryption by default,
  MTU agreement and stitching. 8-over-4 is not a tunnel; tunnels
  (WireGuard) are a separate subject in [@ZONESERVER]. IPv8
  routes cross BGP4 as large communities, with VRF-lite and
  ADD-PATH for overlapping Local Addresses. The management port
  is a dedicated routed port in its own table. The VLAN-numbered
  VRF auto-generation, the "unified table" presentation and the
  `<asn>.222` null-route convention are withdrawn. Routing
  protocols: IPv8 reachability in BGP8, OSPF8 and IS-IS8; Cost
  Factor to BGP8x; RIP and EIGRP not specified.

- **DNS8.** ZS record added; registration at lease time; the
  handle mechanism for IPv4-only clients from 198.18.0.0/15,
  per-interface pools, stickiness, legacy-NAT and self-lookup
  behaviour, and refusal to resolve into unagreed scoped Route
  Numbers. Route8 resolves a Route Number through its ZS records,
  which load-balance its ingress across many Zone Servers, with
  the anycast A record as fallback.
  WHOIS8. Deprecated in favour of RPKI and ASPA.

- **ACL8** condensed. The DNS-only connection policy and its
  `dns-and-direct` and `dns-only-strict` variants are replaced by
  the DNS policy normal (default) or strict; reputation filtering
  is an access list; holding Route Number referenced for
  unauthenticated devices.

- **Co-author.** Aleksei Aleinikov added; Implementation Status
  section added per [@RFC7942].

# Acknowledgements

The authors thank the IETF community for the protocols this
document extends rather than replaces: ARP, ICMP, BGP/MPLS VPNs,
Ethernet pseudowires, L2TPv3 and DNS.
