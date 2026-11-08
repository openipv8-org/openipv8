%%%
title = "Internet Protocol Version 8 (IPv8)"
abbrev = "IPv8"
docName = "draft-thain-ipv8-04"
ipr = "trust200902"
category = "std"
area = "Internet"
workgroup = "Internet Area Working Group"
keyword = ["IPv8", "internet protocol", "network management", "BGP8", "Zone Server"]

[seriesInfo]
name = "Internet-Draft"
value = "draft-thain-ipv8-04"
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

This document specifies Internet Protocol Version 8 (IPv8), an
extension of IPv4 [@RFC791] that prepends a 32-bit Route Number
(RN) to each IPv4 address to produce a 64-bit address space.
IPv4 is a proper subset of IPv8: an IPv8 address whose RN is
zero is bit-identical to an IPv4 address, and an IPv4 packet is
plain IPv4 to an IPv8 device, delivered through the main IPv4
table.

IPv8 is incrementally deployable over existing IPv4 infrastructure.
Forwarding silicon, BGP4 routing, and operator administrative
boundaries continue to operate without modification. IPv8-aware
behaviour is implemented in software at the edges of forwarding
paths and signalled through extension mechanisms (BGP large
communities, IS-IS TLVs, OSPF opaque LSAs) that unupgraded
transit elements flood transparently and ignore.

This document defines the IPv8 address format, the textual
representation conventions including the canonical hyphenated
locator form, the relationship to IPv4, the architectural
principles governing the suite, and the security and operational
considerations applicable to all companion specifications.
Routing-protocol behaviour, encapsulation rules, trust mechanisms,
and management interfaces are specified in companion documents
listed in §1.

{mainmatter}

# Introduction

This document specifies the core elements of Internet Protocol
Version 8 (IPv8). IPv8 extends IPv4 [@RFC791] by prepending a
32-bit Route Number (RN) to each IPv4 address, producing a 64-bit
address space written as `<RN>-<LA>` where `<RN>` is the Route
Number and `<LA>` is the IPv4 address within that Route Number's
space. The Route Number is rendered as either a decimal integer
(for RN values whose leading octet is zero) or as four dotted
octets (for reserved-block RN values whose leading octet is
non-zero). The hyphen between RN and LA is a fixed visual
separator distinguishing the two fields.

IPv4 is a proper subset of IPv8. The address `0-n.n.n.n` in IPv8
is bit-identical to the IPv4 address `n.n.n.n`, and a packet from
a device with no IPv8 awareness is plain IPv4, which an IPv8
device delivers through its main IPv4 table. No reformatting,
conversion, or translation is required for IPv4-only devices to
interoperate with IPv8.

This document forms part of a companion specification suite:

- draft-thain-ipv8-04               Core protocol (this document)
- draft-thain-routing-protocols-00  BGP8, BGP8x, IBGP8, OSPF8, IS-IS8, CF
- draft-thain-support8-00           ARP8, ICMPv8, Route8, ACL8, DNS8
- draft-thain-rine-00               Regional Inter-Network Exchange
- draft-thain-zoneserver-00         Zone Server Architecture
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

Configuration examples in this suite write masks as prefix
lengths (`/24`); implementations accept the slash form wherever a
mask is taken, alongside the dotted form.

# Terminology

This section defines terms used throughout the IPv8 specification
suite. Companion documents inherit these definitions and define
additional terms specific to their scope.

**Route Number (RN).** The 32-bit field forming the upper half
of an IPv8 address. The Route Number identifies the Autonomous
System (AS) within which the lower 32 bits of the address are
significant. The Route Number is structurally analogous to a
postal-code or telephone area-code: it routes to an
administrative domain and is not itself an IP address. RN
values are 32-bit identifiers compared by exact match; RNs do
not have prefix-length semantics.

**Local Address (LA).** The 32-bit field forming the lower half
of an IPv8 address. The Local Address is an IPv4 address within
the Route Number's space. Written as `n.n.n.n` in placeholder
form. Prefix lengths in IPv8 apply to the Local Address field
only and have the range 0 to 32, identical to IPv4 prefix
length semantics.

**Locator.** An IPv8 address rendered in its canonical
hyphenated textual form `<RN>-<LA>`. See [@rendering] for the
rendering rules.

**Autonomous System Number (ASN).** Per [@RFC4271]. The Route
Number field MAY carry an ASN value, in which case `<RN>`
represents the 32-bit ASN. The terms Route Number and ASN are
used interchangeably throughout this suite when context permits;
RN is preferred when describing the addressing field as an
abstract identifier, ASN is preferred when describing its
binding to BGP allocation.

**IPv4-Compatible Form.** An IPv8 address with `<RN> = 0`,
rendered `0-n.n.n.n`. A packet whose Destination Route Number
is 0 is plain IPv4: the shim is removed and the packet goes to
the main IPv4 table, which holds the local subnets and the
default route (usually toward the Internet) ([@wire-format]). A
frame with no shim is plain IPv4 and carries no Route Number.
When an IPv8 device sends to an IPv4-only neighbour, the
neighbour's Route Number is that of the subnet holding its
address ([@SUPPORT8]).

**Cost Factor (CF).** The IPv8 inter-AS path-quality metric
specified in [@ROUTING-PROTOCOLS] and carried by BGP8x, not by
BGP8 (see the BGP8 and BGP8x entries below). CF combines observed
round-trip time, loss, congestion, stability, capacity,
economic policy, and geographic distance into a single scalar
carried in BGP8x path attributes between PEs and across AS
boundaries, where it is used for inter-AS path selection. CF
input observations are collected by implementations within the
AS and propagate via a slow-slew adjustment mechanism analogous
to NTP clock-slew, providing damping against rapid oscillation
in inter-AS path selection. Operator policy adjustments to CF
inputs (such as economic-cost weights) are made by explicit
operator action; the slew governs how observed inputs and
operator adjustments together propagate through the network.

CF does not replace the interior routing protocols' native
metrics. OSPF cost, IS-IS metric, IBGP local-preference, and
MED continue to govern intra-AS
path selection, and operators' existing tuning of those
metrics is preserved unchanged by IPv8 adoption. The IGP CF
Export Interface specified in [@ROUTING-PROTOCOLS] contributes
intra-zone cost as a CF input to IBGP8, where it is combined
with external CF to choose the best edge router for inter-AS
destinations; this contribution does not alter intra-AS
shortest-path computation, which continues to use the IGP's
native metric.

CF is designed to accumulate measurement history over time.
As the measurement substrate matures and operators gain
confidence in CF's accuracy across a range of operational
conditions, CF might eventually become sufficient to drive
interior path selection as well, retiring some of the human
metric-tuning effort that currently goes into intra-AS
configuration. Such a transition is not specified by the
current suite and is not required for IPv8 adoption; it is
noted here as a possible future direction contingent on
operational experience with CF in the inter-AS role. Detailed
CF semantics, measurement collection, the IGP CF Export
Interface, and the slewing behaviour are specified in
[@ROUTING-PROTOCOLS].

**RINE.** Regional Inter-Network Exchange, specified in [@RINE].
RINE defines fifty geographic regions with bounded round-trip
time and provides the inter-AS peering substrate for IPv8 with
stricter admission policy than a typical internet exchange.

**Sun Tzu.** The Neighbor Trust Verification mechanism specified
in [@ROUTING-PROTOCOLS] as part of BGP8x. Sun Tzu accumulates
per-peer trust scores based on observed behaviour and triggers
state transitions governing route acceptance.

**BGP8.** BGP-4 [@RFC4271] carrying IPv8 reachability and
nothing else: VPNv4 [@RFC4364] by default, a Route Number
carried as a VRF with route distinguisher `<RN>:65535`; the IPv8
address family as multiprotocol NLRI [@RFC4760] only where both
peers negotiate it; and the `asn-ibgp-path` BGP large community
[@RFC8092] for public Route Numbers with unique Local Addresses
where the fabric is plain BGP4 with no Provider Edge. A BGP4
router carries the large community unchanged and can import the
routes it tags into VRFs by ordinary policy; it never negotiates
the IPv8 address family. Specified in [@ROUTING-PROTOCOLS].

**BGP8x.** BGP8 with the Sun Tzu neighbour-trust and Cost
Factor path-selection extensions. BGP8x is a separately
negotiated capability released after BGP8; nothing in BGP8 or
in this document depends on it. Specified in
[@ROUTING-PROTOCOLS].

**Zone Server.** The unified network-services platform specified
in [@ZONESERVER]. Each Zone Server pair (`.254` active even,
`.253` active odd) provides DHCP8, DNS8, NTP8, NetLog8, OAuth8,
ACL8, XLATE8, and Route8 management for the local zone.

**WHOIS8.** Deprecated in favour of RPKI [@RFC6480] and ASPA
[@ASPA].

**XLATE8.** The IPv8 forwarding-plane engine at administrative
boundaries, specified in [@ZONESERVER]. XLATE8 operates five
modes over a unified state-table substrate: native IPv8
forwarding, 4-to-8 translation (IPv4-only host origination
through an IPv8-aware boundary), 8-to-4 translation (IPv8
egress to RN 0 or other IPv4-only destinations), 8-to-8 NAPT
(many-to-fewer translation between RN namespaces, typically at
security boundaries), and 8-over-IPv4 carriage across
IPv4-only transit. Each Zone Server, edge router, firewall, and
end-host stack participates in XLATE8 as required by its
position in the topology; the modes are selected per-flow by
the configured policy.

**ACL8.** The IPv8 policy expression and enforcement mechanism
specified in [@SUPPORT8] and [@ZONESERVER]. ACL8 supports
first-class matching on the RN field, enabling AS-aware policy
expression at line rate.

**Route8.** The IPv8 routing function, specified in
[@SUPPORT8]. Route8 is a map from Route Number to forwarding
target: the main IPv4 FIB for Route Number 0, the global IPv8
table, a per-RN table, or an IPv4 VRF ([@forwarding-modes]).
The Route Number selects the context; IPv4 longest-prefix
forwarding does delivery inside it.

**An RN is a remote VRF.** To IPv4 equipment, a Route Number
reached over the Internet is a standard remote VRF. See
[@rn-vrf]; naming and route distinguisher are in [@SUPPORT8].

# Locator Rendering {#rendering}

An IPv8 address rendered for human consumption uses the
canonical hyphenated form `<RN>-<LA>`. The hyphen is a fixed
visual separator that distinguishes the Route Number portion of
the address from the Local Address portion. Implementations
MUST accept this canonical form on input and MUST emit it on
output.

## RN Portion Rendering

The Route Number portion of the locator is rendered as follows:

- If the leading octet of the Route Number is zero, the RN is
  rendered as the decimal integer value of the 32-bit Route
  Number. Examples: `64501-192.0.2.1`, `64502-10.20.30.40`,
  `64500-192.0.2.1`.

- If the leading octet of the Route Number is non-zero, the RN
  is rendered as four dotted octets. Examples:
  `127.10.60.10-10.0.0.1` (private internal),
  `222.0.0.1-10.1.1.1` (scoped),
  `100.5.3.7-203.0.113.20` (RINE peering).

This rendering is automatic, reversible, and self-managing.
ASN allocations are concentrated in the lower 24 bits of the
32-bit ASN space (approximately 128,000 ASNs allocated globally
as of 2026, all within the lower 24 bits). For these
allocations the leading octet is always zero, and rendering
them as decimal integers matches operator expectations from the
BGP ecosystem. Reserved ranges within the upper octets (such as
`127.r.r.r` for private internal use, `100.r.r.r` for RINE
peering, `222.r.r.r` for scoped Route Numbers) have
non-zero leading octets and naturally render in dotted form. As
ASN allocation eventually crosses 2^24, dotted rendering takes
over for those allocations without specification change.

## LA Portion Rendering

The Local Address portion is always rendered as a dotted IPv4
quad. Standard IPv4 rendering rules apply. The LA portion is
always four dotted decimal octets; the LA is never compressed,
abbreviated, or rendered in any form other than the four-octet
IPv4 representation.

## Prefix Length Notation

Prefix lengths apply to the Local Address portion only. The
notation `<RN>-<LA>/N` denotes the IPv8 prefix consisting of
the specified Route Number `<RN>` combined with the LA `/N`
IPv4 prefix. Examples: `64500-10.0.0.0/8` (the 10.0.0.0/8
prefix within RN 64500), `127.10.60.10-10.20.30.0/24` (the
10.20.30.0/24 prefix within RN 127.10.60.10).

Prefix lengths greater than 32 are not defined. Prefix lengths
that would notionally extend across the RN boundary have no
semantic meaning and MUST be rejected by implementations. The
Route Number itself is not subnettable; RN values are
identifiers compared by exact match, not prefix-matched.

## Storage and Wire Format Are Independent

The hyphenated rendering is a display-layer convention.
Implementations MAY store IPv8 addresses internally in any
format (8-byte binary, packed structure, struct-of-fields, etc.)
and MAY accept additional input formats for backward
compatibility with earlier draft notation. The wire format
specified in [@header] is always the full 64-bit pair
regardless of how the address is rendered.

## ASN Simplification Configuration

Implementations MUST provide a configuration option named
`asn-simplification` (or vendor-equivalent), default enabled.
When enabled, the rendering rule above applies (integer form
for leading-zero RNs, dotted form for non-zero-leading RNs).
When disabled, all RNs render in full dotted form regardless of
the leading-octet value, suppressing RN integer compression for
diagnostic purposes such as packet capture analysis or
wire-format debugging.

The `asn-simplification` setting affects display only; it does
not alter the encoding of addresses on the wire, in routing
tables, in JSON representations, or in protocol exchanges. Two
implementations with different `asn-simplification` settings
interoperate correctly; they differ only in how they present
addresses to operators.

# Architecture Overview

## The Postal-Code Framing

The Route Number is the postal code of the internet. It is a
32-bit identifier that routes to an administrative domain (an
Autonomous System) and disambiguates Local Addresses that would
otherwise collide. Approximately 128,000 ASNs are currently
allocated globally; under IPv4, every one of those ASes can have
a host at `192.0.2.1` or `10.0.0.1`, and operators rely on Network
Address Translation at administrative boundaries to hide the
duplication. Under IPv8, `64500-192.0.2.1` and
`64501-192.0.2.1` are distinct addresses in Route8 and never collide. The Route
Number resolves at routing time what NAT resolves at boundary
translation time.

The postal-code framing extends to operational behaviour.
Prefix lengths apply only to the Local Address field --- there
is no concept of subnetting across the RN boundary, just as
there is no concept of subnetting across a postal code in
mailing-address syntax. The RN is a different kind of identifier
than the LA, and the spec preserves that distinction throughout.

## Route Spaces {#route-spaces}

Every Route Number belongs to exactly one of five route spaces,
determined by its leading octet:

- **Public route space.** Every Route Number whose leading
  octet is not 99, 127, 222, 224 or 255. Public Route Numbers are
  allocated (the RIR ASN pool, RINE, the reserved pools of
  [@reserved]) and are what the global IPv8 routing system
  carries. Route Number 0 is plain IPv4: the main IPv4 table,
  holding the local subnets and the default route toward the
  Internet. It is public because this suite declares it so, not
  because of anything in the packet.

- **Private route space.** `127.r.r.r`. Allocated by nobody,
  meaningful only inside the administrative domain that uses
  it, the analogue of RFC 1918 address space one level up. Its
  Route Numbers share the master table with Route Number 0 and
  the public Route Numbers; what keeps them private is the
  border ([@route-space-protection]).

- **Scoped route space.** `222.r.r.r`. Each Route Number is its
  own forwarding table, meaningful only on the interfaces and
  sessions where it was configured or agreed. A scoped Route
  Number never leaves through an outside interface toward the
  Internet ([@route-space-protection]), and it does not cross
  scopes.

- **Interconnect route space.** `99.r.r.r`. Each Route Number is
  its own forwarding table, as in the scoped space. The intent
  is peering, carrier to carrier, and private CGNAT for devices,
  carrier to self, in the way `100.64.0.0/10` [@RFC6598] is used:
  16,777,216 Route Numbers of 2^32 addresses each. An
  interconnect Route Number MAY be used publicly, on
  public-facing interfaces and sessions, or behind NAT, and
  pseudowires MAY use it; it is never redistributed on the
  public Internet.

- **System route space.** `224.r.r.r` and `255.r.r.r`, never
  routed. `224.r.r.r` is internal router space management (the
  Route Number masking of [@reserved]). `255.r.r.r` is reserved
  for future system use, assigned only by the IETF through IANA;
  this document claims one value from it, `255.255.255.255`, the
  broadcast RN, used only as the ARP8 "any Route Number" target.
  A packet whose source or destination Route Number is in the
  system space MUST be dropped on receipt.

The spaces do not blend. A router MUST NOT advertise a route out
of its space: a private route is never advertised on an
inter-AS session or out of an outside interface, a scoped route
is never re-advertised from the session or interface on which it
was learned, and a public route is never installed into a scoped
table or an interconnect table. Private Route Numbers share the
master table with Route Number 0 and the public space and are
kept in by the border; each scoped or interconnect Route Number
is its own table. The per-block rules
in the Security Considerations are instances of this one rule.

Routes never cross the wall between spaces. Traffic crosses it
only through XLATE8 at a Zone Server, as a translation with
per-flow state ([@ZONESERVER]). Private and public Route Numbers
share the master table inside the AS; the wall between them is
the border ([@route-space-protection]). The only difference between a
public edge and a private edge is therefore reachability: which
spaces the interface can reach, and through which Zone Server.

The recommended practice is RFC 1918 Local Addresses inside.
The private route space provides 16,777,216 Route Numbers, each
with the whole of `10.0.0.0/8`, before `172.16.0.0/12` or
`192.168.0.0/16` are touched; no internal host ever needs a
public Local Address.

## An RN is a Remote VRF {#rn-vrf}

**An RN is a remote VRF.** To IPv4 equipment, a Route Number
reached over the Internet is a standard remote VRF: a VRF that
happens to be somewhere else. On a native IPv8 device the Route
Number selects a table ([@forwarding-modes]); where a Route
Number is carried through an existing L3VPN core it is a VRF,
with the Zone Server as its Provider Edge. Naming and route
distinguisher are in [@SUPPORT8]. Routes inside an RN are IPv4
routes, carried by whatever interior protocol the operator
already runs.

This is why IPv8 needs no new silicon and no new mental model.
The L3VPN pipeline already does a per-VRF lookup at line rate,
and every carrier and multi-tenant enterprise already runs VRFs.
The VRFs an operator uses today for internal compartments
(hospital, phones, payroll) are untouched; IPv8 specifies only
routing between Route Numbers.

Networks run hybrid: native IPv8 between IPv8 speakers, bare
IPv4 to and from IPv4-only devices, and 8-over-4 where a span is
not yet IPv8-aware. That is the normal condition, not a
transition to hurry through. A router keeps a forwarding context
only for the RNs it originates or terminates; RNs it merely
carries by BGP8 need none, so per-router state is bounded by
what the operator hosts, not by the size of the IPv8 routing
system.

## Adding an RN to an Interface {#adding-rn}

Giving an interface an IPv8 address (`ip address [v8]
<RN>-<LA>/<len>`, where `v8` is optional because the `<RN>-<LA>`
form already says it is IPv8, or a DHCP8 lease carrying option
222) is the whole configuration. The interface's Route Number is
then in the main table; the operator places it in a VRF only by
putting the interface in one. The first RN on an interface is
its Primary; further RNs are Secondaries, reachable only by IPv8
speakers. Traffic with no explicit Route Number follows the
Primary RN's default gateway; an application reaches a Secondary
RN's gateway only by binding to that RN (an `AF_INET8` socket,
or a namespace bound to it).

## Ride Existing Infrastructure, Signal at the Edges

IPv8 is designed so that existing IPv4 infrastructure carries
IPv8 traffic without modification. The principle:

- Forwarding silicon (commodity ASICs in deployed routers) does
  not change. IPv8 traffic crosses these chips inside IPv4, and
  the chips forward the IPv4 envelope using their existing IPv4
  lookup logic. The IPv4 protocol field carries an IPv8-in-IPv4
  indication that is irrelevant to the forwarding decision.

- BGP4 routing does not change. ASes that have not deployed
  BGP8 still carry IPv8 reachability by running an ordinary
  BGP instance inside each `ipv8-<RN>` VRF (the standard
  L3VPN pattern per [@RFC4364]). Routes within the VRF are
  IPv4 routes within the RN's address space; the RN identity
  is supplied by the VRF context, not by an attribute on the
  routes themselves. Unupgraded transit routers see ordinary
  IPv4 routes inside a VRF and forward them with existing
  L3VPN machinery.

- DNS, RPKI, and DNSSEC do not change. IPv8 publishes records
  using new resource record types that ride within existing DNS
  publication infrastructure, and signs with the existing RPKI.

- Operator administrative procedures do not change. RIR
  delegation, AS allocation, and RPKI signing operate exactly
  as they do for IPv4 today.

The IPv8-specific behaviour is implemented in software at the
edges of forwarding paths: at endpoints originating or
terminating IPv8 packets, at boundaries between IPv8-aware and
IPv4-only forwarding spans, and at trust-validation points
consuming RPKI and DNSSEC outputs. The core of the internet ---
the millions of routers and switches in transit and access
networks worldwide --- carries IPv8 traffic without any
modification or awareness that IPv8 exists.

This is the property that makes incremental adoption tractable.
An AS can begin participating in IPv8 with software changes at
one BGP edge router and one RPKI signing operation, with no
expectation that any peer or transit provider has done anything
at all.

## Minimum Deployment Unit {#minimum-deployment-unit}

The minimum deployment unit for IPv8 participation is **one
BGP8-capable edge router per AS**, advertising that AS's anycast
ingress prefix into the surrounding BGP4 fabric. With this
single upgrade:

- The AS becomes reachable as an IPv8 destination from any IPv8
  source on the internet.
- All other routers within the AS continue to operate as IPv4
  routers without modification.
- All hosts within the AS continue to operate as IPv4 hosts
  without modification, communicating as plain IPv4.
- The IPv4 internet between the AS and any IPv8 source is
  unchanged and unaware.

Edge routers participating in the public IPv8 routing system
MUST maintain IPv4 connectivity sufficient to serve as 8-over-4
endpoints and to be reachable from IPv4-only peers. This
requirement applies during the IPv8 transition period and may be
relaxed in future revisions when global IPv8 adoption renders
IPv4 transit unnecessary.

Hosts MAY independently opt into IPv8 capability by deploying
an IPv8-aware network stack (a software upgrade), at which point
they originate native IPv8 packets and participate in IPv8
addressing. Host opt-in is independent of any network operator's
decision to deploy IPv8; an IPv8-capable host on a purely IPv4
network can reach any IPv8-participating AS through the
8-over-4 rules specified in [@SUPPORT8].

## Per-Segment RN Invariant {#segment-invariant}

A segment's **Primary RN** is the Route Number its DHCP server
hands out (option 222, or DHCPINFORM for a statically configured
device). A segment MAY also carry subnets in other Route
Numbers, configured on the model of IPv4 secondary addresses:

    interface GigabitEthernet1/1
     ip address 1115172-10.10.10.254/24
     ip address 127.1.1.1-10.10.20.254/24 secondary

An interface's Primary RN is the Route Number of its primary
address; each secondary address carries its own Route Number
and defines a subnet in that Route Number on the same segment.
On a segment with no DHCP server, the ARP8 subnet query returns
the Route Numbers and subnets present ([@SUPPORT8] §Segment Route
Numbers). No ARP8 message states the Primary RN.

**IPv8 Local Addresses MUST be unique within one broadcast
domain**, irrespective of RN. Every IPv8 host also runs an IPv4
stack that answers ARP for its Local Address, and ARP resolves
on the LA alone; two hosts sharing one LA on one segment
therefore collide at ARP no matter which RNs they are bound to.
Local Addresses are reused freely *across* broadcast domains
(the same 10.0.0.0/8 space appears on every floor and in every
site) but never *within* one. An implementation that detects
two distinct link-layer addresses answering for one LA on one
segment --- whether via ARP or ARP8, and whatever their RNs ---
MUST treat the Local Address as duplicated: it MUST NOT forward
to the new claimant, it keeps and re-checks an established entry
so that a forged answer cannot take a working host off the
segment, and it MUST raise a duplicate-address alarm (logged,
counted, and signalled to the Zone Server). A Zone Server MUST
probe a candidate Local Address (ARP, sender 0.0.0.0, per
[@RFC5227]) before assigning it, and a DHCP8 client that
observes a conflict MUST decline the offered address. This
makes LA uniqueness a detected-and-reported configuration
constraint rather than a silent failure mode.

**One Route Number is one address space.** Independently of
the broadcast-domain rule, a Local Address MUST be unique
within a Route Number across every site that carries that
Route Number: a host at one site holding a Secondary identity
in Route Number X with the same Local Address as a host in
Route Number X at another site is a duplicate even though the
two are on different broadcast domains. The conflict surfaces
as two routes for one `<RN>-<LA>` in the iBGP8 session that
joins the sites, and implementations MUST treat it as the
duplicate-address condition above rather than install either.

- **Every IPv4 address on the segment is in the Route Number of
  its subnet.** IPv4 has no Route Number awareness. A segment
  may carry several subnets, in several Route Numbers; an IPv4
  neighbour's Route Number is that of the longest subnet holding
  its address, and an address in subnets of two Route Numbers is
  ambiguous and reached as IPv4 only ([@SUPPORT8]).

- **Every IPv8-aware interface attached to the segment MUST have
  its Primary IPv8 address in the Route Number of the subnet
  holding that address.** A host's Primary RN is the Route Number
  of the subnet holding its primary address; that is the
  interface's identity-of-record.

- **An IPv8 interface MAY hold any number of Secondary IPv8
  addresses in other RNs.** Secondary addresses are IPv8-only:
  they are reachable only via ETH_P_IPV8 frames carrying the
  explicit RN, and only from IPv8-aware peers that have
  discovered the secondary identities via ARP8. IPv4-only
  neighbours have no knowledge of secondary RN identities and
  cannot address them; traffic from IPv4-only endpoints to a
  peer's secondary RN identity is delivered via the Zone Server,
  which performs XLATE8 translation between the IPv4
  representation and the secondary IPv8 identity.

- **A device participating in multiple Primary RNs MUST use
  multiple distinct interfaces (or VLAN-tagged sub-interfaces),
  one per segment, with each segment carrying exactly one
  Primary RN.** Multiple RNs MAY share physical infrastructure
  through Layer 2 isolation mechanisms (VLAN tagging, MPLS,
  etc.); the one-Primary-RN-per-segment invariant is preserved because
  each L2-isolated logical segment is its own segment for
  purposes of the invariant.

Implementations MUST validate this invariant at configuration
commit time. A conflict seen at run time raises an alarm via
NetLog8 and never stops forwarding: the replies that would reveal
it are not authenticated, and a rule that stopped the segment
would let one forged reply stop it.

## Forwarding Silicon Compatibility

IPv8-in-IPv4 carriage is designed to traverse existing
forwarding silicon transparently. The packet presents to
forwarding ASICs as a standard IPv4 packet to a standard IPv4
destination, with an IPv4 protocol field value indicating the
IPv8 payload. Because forwarding decisions in IPv4 silicon are
based on the destination IPv4 address, not on the protocol
field, IPv8 traffic is forwarded at line rate by silicon that
has no awareness of IPv8.

The MPLS L3VPN forwarding pipeline provides the matching
per-VRF lookup behaviour for native IPv8 traffic within an AS.
A router with native IPv8 awareness performs forwarding by
selecting the VRF corresponding to the destination RN and
performing an IPv4 longest-prefix-match lookup on the
destination LA within that VRF. This is the same operation that
existing L3VPN-aware silicon already performs for MPLS-labelled
traffic; the only difference is the source of the VRF identity
(an IPv8 packet's RN field rather than an MPLS label).

This property is structural rather than incidental. The design
is constrained to preserve it: any mechanism that required new
silicon support to operate would introduce a deployment
dependency on hardware refresh cycles, which are measured in
capital-expenditure timescales. By constraining the
IPv8-specific behaviour to the endpoints at each end of an
IPv4-only span --- both software --- existing silicon carries
IPv8 traffic without modification indefinitely.

Future hardware MAY accelerate native IPv8 forwarding
(processing 64-bit `<RN>-<LA>` lookups directly). Such hardware
is not a precondition for IPv8 deployment and is expected to
emerge through normal vendor product cycles in response to
deployed IPv8 traffic volumes.

## Trust-State Operational Pattern {#trust-state-pattern}

Trust-state data in the IPv8 suite --- including RIR trust
anchors, RINE region membership, and Sun Tzu peer trust
baselines --- is updated via explicit operator command rather
than automatic background refresh.

This pattern is selected over automatic refresh for three
reasons:

- Operator agency: explicit update is a deliberate action with
  a known timestamp, allowing the operator to investigate
  changes before installing them and to correlate router
  behaviour changes with specific update events.

- Auditability: explicit updates produce discrete events in
  NetLog8, syslog, and operator change-management records;
  automatic refresh produces a continuous stream of state
  changes that is harder to audit after the fact.

- Blast-radius limitation: a compromised upstream data source
  affects only operators who happen to refresh during the
  compromise window; with automatic refresh, every operator's
  router accepts the compromise simultaneously.

Implementations SHOULD provide separate operations for
verification (showing the diff between current upstream state
and locally-installed state without modification) and update
(installing the upstream state). Implementations SHOULD emit a
console warning when locally-installed trust state has not been
refreshed for a configurable interval (default: 7 days). The
operation names are not normative; the separation of verify-
from-update and the operator-initiated nature of update are
the normative properties.

## Identity-Driven Access Control

IPv8 anchors access control on signed identity claims rather
than on physical network position. Each authenticated client
holds a JSON Web Token (JWT) issued by OAuth8 [@ZONESERVER]
containing claims for user identity, device identity, session
context, and authorised access scopes. ACL8 enforcement points
validate the JWT at each access decision and apply policy based
on the token's claims, independently of which physical network
the client is connected to.

OAuth8/JWT in IPv8 occupies the role that RADIUS [@RFC2865]
occupies in classical enterprise network AAA: it is the
authentication, authorisation, and accounting substrate for
network access. OAuth8/JWT is the modern equivalent, using
the same identity infrastructure (OAuth2 [@RFC6749], OpenID
Connect, JWT [@RFC7519]) that already underpins web and API
access control in contemporary deployments. Operators familiar
with RADIUS-based 802.1X port authentication will recognise
the role; the difference is that the identity assertion is a
signed JWT rather than a RADIUS attribute exchange, and the
enforcement point is ACL8 at the IPv8 layer rather than a
port-state machine at the switch.

### Pre-Authentication Holding State and the Displacement of 802.1X {#preauth}

IPv8 displaces 802.1X [@IEEE8021X] as the enterprise network
admission mechanism. 802.1X is a Layer 2 port-state machine: it
requires a supplicant on the endpoint (absent on much equipment),
a RADIUS back end, and switch-side support, and even when all
three are present it gates only the switch port. IPv8 moves
admission to Layer 3 and makes it a property of a signed
identity rather than of a physical port.

A device that has not yet authenticated is placed by DHCP8 in a
**holding RN** --- a guest Route Number in `127.255.r.r`
([@per-interface-mode]) --- and
issued a host route (a /32 Local Address) whose only reachable
next hop is the Zone Server. From this confined address the
device can reach the Zone Server's authentication endpoint and
its resolver, and nothing else: there is no route out of the
holding RN, no path to peers on the segment (the /32 has no
on-link neighbours), and no default route. Confinement is thus
the *absence of a route*, not a firewall rule that can be
misconfigured to fail open.

The device authenticates over Layer 3 by presenting an OAuth8
JWT to the Zone Server (for example over EAP-TTLS where 802.1X
port control is also present, or directly over HTTPS where it is
not). The Zone Server validates the token exactly as it
validates any JWT at the management interface --- signature
against the OAuth8 issuer, expiry, and scopes --- and reads the
authorised Route Number from a token claim. On success it
rebinds the device from the holding RN into the RN its identity
is entitled to, and normal forwarding begins. Because the RN
derives from the validated claim and not from a port lookup, the
assignment travels with the token and is revoked by revoking the
token.

Because authentication is an ordinary Layer 3 exchange to a
confined address, it works on any device with a web client and
requires no supplicant, no RADIUS server, and no switch
cooperation; it is the mechanism a captive portal already proves
works universally, extended so that the outcome is Route Number
assignment rather than mere internet unlock. The Zone Server MAY
federate the authentication to any external OpenID Connect
provider, so an enterprise uses its existing identity provider
and a visitor signs in with a consumer account (e.g. Google),
each mapped to the Route Number its verified identity warrants.

A device that cannot present a token --- a printer, camera, or
other appliance --- remains in the holding /32, or is placed by
MAC Authentication Bypass into a Route Number chosen by operator
policy, with plug-and-play enabled on its interface where it
needs service discovery. This is the
honest security boundary of the model: token-bearing devices are
*authenticated into* their RN, while tokenless devices are
*placed into* one by operator policy and never promoted by
self-assertion.

This same mechanism operates without IPv8: a plain IPv4 DHCP
server can issue the confined /32, redirect the device to the
Layer 3 authentication flow, and on success renumber it into the
appropriate VLAN. IPv8 deployments substitute Route Number
assignment for VLAN assignment as the admission outcome; the
holding-state-and-Layer-3-auth flow is identical. An operator
MAY therefore adopt the admission mechanism in an IPv4 network
and gain the Route Number behaviour later without changing the
authentication path.

Detailed mechanism, including JWT claim format, ACL8 rule
grammar and worked examples, vNIC and profile abstractions for
user-facing identity selection, per-profile egress routing,
DHCP8 lease behaviour for JWT-driven VLAN assignment where
operators choose to deploy VLANs, Zone Server federation across
deployment sites, session lifecycle, and revocation propagation,
is specified in [@ZONESERVER]. ACL8 rule evaluation,
default-deny posture, and audit logging are specified in
[@SUPPORT8] §ACL8.

### Per-Interface Mode {#per-interface-mode}

Each IPv8-aware interface has a mode, normal or strict, and two
policy settings, plug-and-play and guest; the mode reaches hosts
in DHCP8 option 223 or is set by operator configuration:

- **normal** --- standard peer-to-peer operation, ARP8 active,
  LLDP fires, firewall does policy enforcement, full IPv8
  capability exposed. Suitable for typical end-user workstations
  and business application servers.

- **strict** --- concealed-host operation, only gateways
  visible on L2, no LLDP, gateway-mediated peer traffic, DNS-
  driven destination authorisation. Strict-mode interfaces
  refuse to forward to destinations that do not have a DNS
  resolution backing them, and have no route of last resort,
  closing off direct-to-IP exfiltration and malware call-out
  paths. Suitable for production servers, finance/healthcare
  endpoints, and anything where the policy is well-defined and
  deviations are anomalies. A Zone Server serving a strict
  interface hands out /32 leases with DHCP option 121, so that
  hosts reach one another only through the gateway.

- **pnp** (plug-and-play) --- an on/off setting on the
  interface, not a mode: it lets multicast service discovery
  (mDNS, SSDP, WS-Discovery, LLMNR) and ARP through for printers,
  IoT devices and appliances. It is called "printer" in earlier
  drafts.

- **guest** --- what a host has before it logs in: it is placed
  in a guest Route Number in `127.255.r.r` and reaches only a
  walled garden (the login page and the DHCP and DNS it needs).
  It reaches the Internet only where an operator access list
  lets it out through NAT.

Logging in (OAuth8, or RADIUS) moves a host from guest to its
authenticated mode. Its tokens decide, per user and per server,
whether it is normal, strict, or governed by an operator access
list. The interface's configured default applies only when the
login carries no token for it. Detailed mode semantics,
the strict-mode DNS-authorisation rule, and the pnp-mode
multicast registration mechanism are specified in [@SUPPORT8]
§ACL8 and [@ZONESERVER].

## Performance and Error Telemetry

The IPv8 suite's operational telemetry substrate is NetLog8
[@NETLOG8], which records performance metrics (link utilisation,
CPU and memory load, throughput, latency, queue depth, heartbeat
round-trip times sampled at configured intervals), error events
(link drops, packet errors, route holds, ROA rejections, ACL8
denies, configuration application failures, hardware faults),
security alerts (failed authentications, rejected routes, ROA
mismatches, certificate validation failures, peer trust-score
decrements), routing changes, configuration changes, and
session-level accounting (5-minute byte-counter intervals per
active session for billing and capacity planning).

NetLog8 does not log traffic content, per-flow data, or routine
successful authentications. A user's already-valid JWT presenting
to ACL8 on each access decision produces no NetLog8 event; only
the rare moments of JWT issuance at session start and
authentication failures are recorded. This deliberate exclusion
of routine successful events distinguishes NetLog8 from
authentication logging in operating systems such as Windows NT,
where thousands of routine authentication entries per hour bury
the small number of events that operators actually need to
investigate. NetLog8's volume is bounded by what an operator
acts on, not by what the network is doing. The signal-to-noise
ratio is high by design.

The volume scoping permits cryptographic integrity guarantees on
the audit stream that would not be feasible at line rate for
traffic data. Traffic-content logging is the responsibility of
the operator's chosen traffic-inspection infrastructure
(corporate firewalls, IDS/IPS, scrubbing services, NetFlow
collectors), which operates independently of NetLog8. Operators
integrate NetLog8 with their existing observability stack (SIEM,
SOC tooling, performance monitoring, alerting) via the standard
NetLog8 export mechanisms specified in [@NETLOG8].

# Address Format

## Structure

An IPv8 address is a 64-bit identifier formed of two 32-bit
fields:

       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                       Route Number (RN)                      |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                       Local Address (LA)                     |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

The Route Number occupies the upper 32 bits. The Local Address
occupies the lower 32 bits. The two fields are independent
identifiers serving different functions: the RN identifies an
administrative domain (an AS), and the LA identifies an address
within that AS's space.

The canonical textual rendering is the hyphenated locator form
`<RN>-<LA>` specified in [@rendering].

## Prefix Length Semantics

Prefix lengths in IPv8 apply to the Local Address field only,
with range 0 to 32. The notation `<RN>-<LA>/N` denotes the IPv8
prefix consisting of the specified Route Number `<RN>` combined
with the LA `/N` IPv4 prefix. Prefix lengths greater than 32 are
not defined; prefix lengths that would notionally extend across
the RN boundary have no semantic meaning and MUST be rejected by
implementations.

The Route Number is not subnettable. There is no concept of an
"RN prefix" that subdivides the RN field across IPv8 prefixes,
because the RN is an administrative-domain identifier rather
than an address-space coordinate. RN values are allocated by
the IANA registry process specified in [@iana], not by prefix
delegation. References to "RN block" in this document and in
the IPv8 suite (such as the `127.r.r.r` block reserved for
private internal use) refer to categorical filters on the
leading octet of the RN field, not to prefix-matched ranges.

## IPv4 Representation in IPv8 {#ipv4-compat}

An IPv8 address with `<RN> = 0` is the IPv4-Compatible Form.
The address is bit-identical to its lower 32 bits interpreted
as an IPv4 address.

In rendered form, an IPv4-Compatible IPv8 address renders as
`0-n.n.n.n` (the integer-RN form with RN value 0). For
consistency with established IPv4 notation, implementations MAY
render IPv4-Compatible addresses in the equivalent `n.n.n.n`
form (omitting the explicit RN). Both renderings are
interchangeable; on the wire they encode identically.

A device with no IPv8 awareness sends plain IPv4. No
conversion is performed at the originating device, and an IPv8
device receiving the frame treats it as plain IPv4: it goes to
the IPv4 stack unchanged, through the main IPv4 table, and no
Route Number is attached to it ([@wire-format]).

The Route Number namespace as a whole is partitioned into the
reserved blocks specified in [@reserved]. RN 0 is reserved
within the IPv4-Compatible Form block (the lower 24 bits of
which constitute the RIR-allocated conventional ASN pool); the
other reserved blocks are described below.

## Reserved Route Number Blocks {#reserved}

The Route Number namespace is partitioned by the leading octet
of the 32-bit RN value into reserved blocks with distinct
operational semantics. The partitioning is categorical (a
match on the leading octet), not prefix-based; RN values within
a block share an operational policy but are not aggregated by
prefix matching.

The complete reservation table is as follows. Blocks marked
"Active" are defined by the current IPv8 suite. Blocks marked
"Reserved, policy TBD" are held by IANA pending future
allocation policy.

| Leading Octet | Designation | Status |
|---|---|---|
| 0 | RIR-allocated conventional ASN pool (lower 24 bits of `0.r.r.r`) | Active |
| 1--32 | Super-scalar allocation (1M+ customer base, $25M/year) | Reserved, policy TBD |
| 33--98 | IANA-reserved | TBD |
| 99 | Interconnect | Active |
| 100 | RINE peering | Active |
| 101--109 | IANA-reserved | TBD |
| 110--111 | ARIN sub-RN pool | Reserved, policy TBD |
| 112--113 | RIPE sub-RN pool | Reserved, policy TBD |
| 114--115 | APNIC sub-RN pool | Reserved, policy TBD |
| 116--117 | LACNIC sub-RN pool | Reserved, policy TBD |
| 118--119 | AFRINIC sub-RN pool | Reserved, policy TBD |
| 120--126 | IANA-reserved | TBD |
| 127 | Private internal | Active |
| 128--130 | Cellular carrier (1M+ subscribers, $1M/year) | Reserved, policy TBD |
| 131--221 | IANA-reserved | TBD |
| 222 | Scoped Route Numbers | Active |
| 223 | Experimental | Active |
| 224 | Internal Route Number masking (never configured, dropped on receipt) | Active |
| 225--239 | Future use (operates normally) | Reserved, policy TBD |
| 240--254 | IANA-reserved | TBD |
| 255 | System use: `255.255.255.255` the broadcast RN; the rest by IETF Review | Active |

Leading octets 224 and 255 form the system route space
([@route-spaces]). `255.r.r.r` is reserved for future system
use, assigned only by the IETF through IANA. This document
claims one value from it, `255.255.255.255`, the **broadcast
RN**: "any Route Number". It appears only as the target Route
Number of an ARP8 request ([@SUPPORT8]); it is never configured,
routed, or used as a source Route Number. A packet whose source
or destination Route Number is anywhere in `224.r.r.r` or
`255.r.r.r` is dropped on receipt.

The active blocks are specified as follows.

**`0.r.r.r` (the IPv4-Compatible Form block).** The lower 24
bits of this block (values 0 through 16,777,215) constitute the
conventional RIR-allocated ASN pool. RN 0 itself is reserved as
the IPv4-Compatible Form: the IPv8 address `0-n.n.n.n` is the
IPv4 address `n.n.n.n`. RN values 1 through 16,777,215 are
allocated by the RIR system to AS holders under the existing
ASN allocation procedures, unchanged from current IPv4 practice.

**`99.r.r.r` (interconnect).** RN values whose leading octet is
99 are the interconnect route space ([@route-spaces]). Every
such Route Number has its own per-RN forwarding table, created
on first bind or first route, as in the scoped space. The intent
is peering, carrier to carrier, and private CGNAT for devices,
carrier to self, as `100.64.0.0/10` [@RFC6598] is used in IPv4.
An interconnect Route Number MAY be public, on public-facing
interfaces and sessions, or behind NAT, and pseudowires MAY use
it ([@SUPPORT8]). It MUST NOT be redistributed on the public
Internet. The suggested convention is `99.<ASN>`, the
carrier's ASN in dotted decimal (AS 64500 is `99.0.251.244`).
Carriers peer in pairs: each assigns the other a link out of its
own interconnect Route Number, a /31 or /30, so every peering is
two links, odd and even, one in each carrier's Route Number.
Each carrier sees its link to the other and the other's link to
it, and the two-gateway arrangement always holds. A pseudowire
carried across several carriers is visible hop by hop in their
interconnect Route Numbers; the carriers need not be directly
connected, and the path may cross any number of them. This is a
convention, not the only use.

**`100.r.r.r` (RINE peering).** RN values whose leading octet
is 100 are reserved for Regional Inter-Network Exchange peering
prefixes, allocated per [@RINE]. RINE-block RNs have a
structured assignment `100.<region>.<ix>.<operator>` administered
by the RINE peering authority. Routers SHOULD filter eBGP8
advertisements carrying RNs in this block from peers other than
authorised RINE peering points; RINE delivers reachability by
topology rather than by advertised RN.

**`127.r.r.r` (private internal).** RN values whose leading
octet is 127 are reserved for private internal allocations.
Operators MAY use any RN value within this block for internal
addressing within their own administrative domain without
external coordination. These Route Numbers share the master
table with Route Number 0 and the public Route Numbers, keyed
by Route Number and Local Address; the border keeps them in
([@route-space-protection]). RNs in this block MUST NOT be
advertised beyond the originating AS. Routers
receiving an inter-AS advertisement carrying an RN with leading
octet 127 MUST reject the advertisement and SHOULD log the event
via [@NETLOG8]. Private internal RNs are the IPv8 analog of RFC
1918 private IPv4 address ranges; they are operationally
appropriate for home networks, lab environments, internal
corporate zones, and any context where global addressability is
not required. By convention `127.255.r.r` holds guest Route
Numbers ([@per-interface-mode]).

**`222.r.r.r` (scoped Route Numbers).** RN values whose leading
octet is 222 are the scoped route space ([@route-spaces]).
Every such Route Number automatically has its own per-RN
forwarding table ([@forwarding-modes]), created on first bind
or first route; no configuration declares it. The block
provides 2^24 Route Numbers natively, 2^20 where they are
label-carried through an MPLS core. Scoped Route Numbers are
used for interior links, customer separation, and bilateral
peering. A scoped Route Number's routes are carried through
BGP8 like any other reachability, the whole table at once; what
is fenced is installation, which is only ever into the target
the Route Number is bound to, and re-advertisement, which does
not happen. By default that target is the Route Number's own
per-RN table; an operator MAY instead bind a scoped Route
Number in Provider Edge mode ([@forwarding-modes]) so that its
routes land in the IPv4 VRF named for it and are reachable from
existing L3VPN VRFs through ordinary route-target policy.
Tables are joined only by routes, as VRFs are joined by route
leaking. A scoped Route Number never leaves through an outside
interface toward the Internet; peering between operators uses
the interconnect space (`99.r.r.r`). Detailed
per-RN table behaviour is specified in [@SUPPORT8].

**`223.r.r.r` (experimental).** Operates normally; for
experimental deployments.

**`224.r.r.r` (internal masking).** Reserved for internal Route
Number masking by implementations. It is never configured, and a
packet whose source or destination Route Number is in this block
is dropped on receipt.

**Documentation address blocks.** The IPv4 documentation
ranges `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24`
from [@RFC5737] retain their IPv4 documentation-example
semantics within IPv8 in any RN context. They MUST NOT be used
in production networks.

# Address Classes

## Unicast

A unicast IPv8 address identifies a single interface on a
single device. Packets sent to a unicast address are delivered
to that interface only. Unicast is the default address class.

## Anycast

An anycast IPv8 address identifies a service published from
multiple network locations. Packets sent to an anycast address
are delivered to the nearest of the published locations as
determined by routing-protocol path selection.

The IPv8 suite uses anycast for a Route Number's ingress. Each
Route Number publishes an anycast ingress prefix, and DNS
lookups under `anycast.<RN>.asn.arpa` and
`anycast.<RN>.asn.openipv8.org` return its IPv4 anycast address.
Every Zone Server is an anycast server for its Route Number by
default, so each Zone Server added brings the Route Number's
anycast closer to the world. Anycast gives the nearest Zone
Server but no failover a sender can act on; the Route Number's ZS
records list its anycast name first and its individual Zone
Servers after it, so a sender that loses the anycast moves at
once to the others ([@SUPPORT8] §DNS8). The anycast ingress
prefix MUST be covered by a ROA [@RFC6482].

## Multicast {#multicast}

Multicast addressing in IPv8 follows the conventions specified
in [@multicast].

## Broadcast

Broadcast addressing in IPv8 is restricted to within the local
subnet (LA portion) of an AS. Cross-AS broadcast is not
defined; a packet whose LA is `255.255.255.255` MUST NOT be
forwarded across any RN boundary.

# IPv8 Packet Format {#header}

## The Shim

An IPv8 packet is an 8-octet **shim** followed by a complete,
unmodified IPv4 packet:

       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                       Source Route Number                    |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                    Destination Route Number                  |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                               |
      |                  IPv4 packet, unmodified [@RFC791]            |
      |                                                               |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

The Source Route Number and Destination Route Number are the
upper 32 bits of the source and destination IPv8 addresses. The
Source Local Address and Destination Local Address are the
source and destination fields of the IPv4 header that follows,
exactly where IPv4 puts them. Nothing in the IPv4 header
changes: Version remains 4, and IHL, Total Length, the Header
Checksum, Fragment Offset, TTL, Protocol and Options keep their
IPv4 values and semantics. An IPv8 packet is therefore an IPv4
packet with eight octets of Route Number context in front of it.

Forming an IPv8 packet from an IPv4 packet is a prepend of the
shim; recovering the IPv4 packet is a strip of the shim. Neither
operation touches the IPv4 header or recomputes its checksum.
This is the property that lets existing IPv4 forwarding code,
and existing IPv4 forwarding silicon, carry the packet once the
Route Number has selected the forwarding context
([@forwarding-modes]).

## Native IPv8 Frames

On a link, an IPv8 packet is carried in a frame whose EtherType
is **0x8080** (ETH_P_IPV8). The EtherType is what identifies the
payload as shim-plus-IPv4 rather than bare IPv4 (EtherType
0x0800, ETH_P_IP). There is no version field, flag or marker
inside the packet; the frame type is the whole signal.

## 8-over-4 Transport {#eight-over-four}

Where the next span cannot carry EtherType 0x8080 --- an
IPv4-only router, an IPv4-only link, the public IPv4 Internet
--- the IPv8 packet is carried as the payload of an outer IPv4
packet whose Protocol field is the IPv8-in-IPv4 protocol number
([@iana]; 253 from the experimental range pending assignment):

      +----------------+------+-------------------------------+
      | outer IPv4 hdr | shim | inner IPv4 packet, unmodified |
      |  protocol 253  | 8 B  |                               |
      +----------------+------+-------------------------------+

This is the same IPv8 packet one level down. 8-over-4 is not a
tunnel: there is nothing to configure, and it carries the packet
over IPv4 until it reaches the proper far end, which strips the
outer header and resumes native dispatch. The outer header is
added by a Zone Server or other IPv8 boundary device; host
stacks do not produce it. The outer source and destination are
the IPv4 addresses of the two boundary devices, so every IPv4
forwarder in between sees an ordinary IPv4 packet between two
ordinary IPv4 addresses. Mechanism, endpoint discovery and the
per-flow state at each end are specified in [@SUPPORT8].

## Wire Rule {#wire-format}

The rule for when a frame carries the shim is: send the most
information available.

- An IPv8 speaker sends every packet with the shim, as an
  ETH_P_IPV8 frame. This includes packets to a neighbour in the
  speaker's own Primary RN, and packets to the public IPv4
  Internet, which carry Destination Route Number 0 (for example
  source `1115169-10.1.1.10`, destination `0-203.0.113.7`).

- The only frames an IPv8 speaker sends without the shim are to
  a neighbour that has proved itself IPv4-only: ARP8 resolution
  ([@SUPPORT8]) received no IPv8 answer and the ARP fallback
  did. Such frames are bare IPv4, ETH_P_IP, and are possible only
  in the Route Number of the neighbour's subnet, since an
  IPv4-only device cannot be anywhere else.

- An IPv4-only device sends bare IPv4 frames because it has no
  Route Number concept.

- A received frame with no shim is plain IPv4 and goes to the
  IPv4 stack unchanged; no Route Number is attached to it.

The consequence is that every packet between two IPv8 speakers,
on any link anywhere, carries both Route Numbers explicitly.

**IPv4-Compatible Form.** An IPv8 packet whose Destination Route
Number is 0 is in IPv4-Compatible Form: it is plain IPv4, the
shim is removed, and it is delivered through the main IPv4
table, which holds the local subnets and the default route
toward the Internet ([@route-spaces]). A Zone Server forwarding
such a packet onto an IPv4-only path strips the shim and the
packet continues as the IPv4 packet it always was. Replies from
the Internet arrive as bare IPv4 and are re-associated with the
originating Route Number by XLATE8 state ([@ZONESERVER]). The
rendering `0-n.n.n.n` and an AF_INET8 socket address with Route
Number 0 denote the same thing: a plain IPv4 destination.

## Maximum Transmission Unit

A native IPv8 frame is 8 octets longer than the IPv4 frame it
carries; an 8-over-4 packet is 28 octets longer (20 for the
outer IPv4 header, 8 for the shim). IPv8 runs jumbo frames by
default: an IPv8 interface defaults to an MTU of 9000 and scales
back to 1500 where the link or path cannot carry more, the
1500-octet Ethernet MTU being a leftover of 10 Mb/s half-duplex
CSMA/CD. On a link held at 1500 the IPv8 stack limits the inner
packet to 1492, or the link runs an L2 MTU of 1508. For 8-over-4
the boundary device is responsible for path MTU handling on the
outer path; the inner IPv4 packet's Don't Fragment bit and
fragmentation semantics are those of [@RFC791] and are
unchanged. Implementations SHOULD advertise the 8-octet shim
overhead to the IPv4 path-MTU logic so that IPv4-only peers
behind an IPv8 segment receive correct ICMP Fragmentation Needed
values.

## Socket API Compatibility

Existing IPv4 socket APIs (BSD sockets, Winsock, equivalents)
operate without modification on IPv4-Compatible IPv8 traffic
because the IPv4 packet inside an IPv8 packet is a complete
IPv4 packet. IPv8-aware socket APIs MAY expose the full 64-bit
address through a new address family (the Linux reference
implementation uses AF_INET8 = 46); such APIs are out of scope
for this document and are specified in the IPv8 implementation
guidance.

L4 transport protocols (TCP, UDP, QUIC, SCTP) are address-
family-agnostic at the protocol level and operate unchanged
over either IPv4 or IPv8. There is no "TCP/IPv8" or "UDP/IPv8"
as a distinct protocol; the transport state machines consume
socket addresses without inspecting the address family. The
same applies to ICMP and ARP: ICMP is one protocol with IPv8-
extension behaviour for 64-bit addresses (see [@SUPPORT8]),
and ARP is one protocol with IPv8-extension behaviour for
64-bit address resolution (see [@SUPPORT8] §ARP8). The suite
does not specify "TCP8", "UDP8", "ICMP8", or "ARP8" as separate
protocols; these names refer to extensions of the existing
protocols.

## Forwarding Modes {#forwarding-modes}

One kernel holds one Route Number map. Every bound Route Number
has exactly one forwarding target, and the type of that target
is the mode. A received shim is handled in this order:

    0. src or dst RN in 224.x
       or 255.x               -> drop
    1. dst RN == 0            -> plain IPv4: main FIB, unchanged
    2. dst RN bound here      -> its target: a VRF (Provider
                                 Edge) or a table
    3. the RN's routes        -> exact RN, then longest match on
                                 the LA; a 222.x or 99.x RN
                                 is its own table
    4. no route               -> resolution through DNS
                                 ([@SUPPORT8] §RN Resolution)
    5. still no route         -> the default route that matches
                                 the RN: a 222.x or 99.x table
                                 its own,
                                 any other RN the master's
                                 (never with the DNS policy
                                 strict); otherwise drop

Route Number lookup is exact match, or a wildcard pattern for
the private, scoped and RINE spaces ([@SUPPORT8]). Local Address
lookup is
longest-prefix match inside whichever table the Route Number
resolved to. The shim is the same in every mode. Binding one
Route Number to two targets is rejected at configuration time,
never resolved at run time. Tables are joined only by routes;
no forwarding step rewrites a Route Number or a Local Address.

**Native** (`ip routing v8`). One global IPv8 table keyed on
Route Number and Local Address. Route Number 0 is the
IPv4-Compatible Form and goes to the ordinary main table;
nothing in the IPv4 path is touched. No VRF device, no route
distinguisher, no label. This is the mode for hosts, Zone
Servers and standalone IPv8 edges, and normally all routes live
here.

**Provider Edge.** An interface placed in a VRF binds its Route
Number to that VRF:

    vrf definition ipv8-1115169
     address-family ipv4
    interface Vlan10
     vrf forwarding ipv8-1115169
     ip address 1115169-10.1.1.1/24

Packets for the Route Number are delivered into the VRF as
ordinary IPv4, and the routing daemon carries it as VPNv4
[@RFC4364]. A carrier carries a whole Route Number the way it
carries a customer VPN today: one label per Route Number across
the core, no IPv8 awareness in P routers, with the Zone Server
as the PE. Naming and route distinguisher are in [@SUPPORT8].

**Per-RN table.** A separate IPv8 table for one Route Number,
keyed on Route Number and Local Address, with no route
distinguisher and no route target: the Route Number is the
separation. Every Route Number in the scoped and interconnect
route spaces ([@route-spaces]) gets a per-RN table
automatically on first bind or first route unless the
operator has bound it in Provider Edge mode instead; private Route Numbers live in the
master table. Any other Route Number MAY be given one by
configuration (`vrf definition ipv8-<RN>` with
`address-family ipv8`). Per-RN tables are the native lookup with
a different root and share the native code path; the Provider
Edge mode is the only one that hands off to an IPv4 FIB.

Detailed Route8 behaviour, table population, RN resolution and
the pseudowire forms are specified in [@SUPPORT8].

# Coexistence and Deployment

## Single-Stack Operation

IPv8 deployment does not require dual-stack operation. An IPv8-
aware device runs a single network stack. There is no parallel
IPv4 stack, no separate IPv4 routing table, and no mode-
selection logic, because the three wire forms of [@header] are
one packet with different amounts of carriage:

     applications: AF_INET (RN implied) / AF_INET8 (RN explicit)
                             |
                     one IP layer: builds an ordinary IPv4
                     packet; the RN rides as metadata
                             |
                     Route8: dst RN selects the context
                     (main FIB / IPv8 table / per-RN / VRF)
                             |
                     IPv4 FIB in that context: LPM on the LA
                             |
                     egress: shim or not? (wire rule)
          +------------------+------------------+
          |                  |                  |
     neighbour proved    IPv8 speaker,     IPv4-only span
     IPv4-only           any RN            ahead
          |                  |                  |
     bare IPv4           shim + IPv4       shim + IPv4, and
     0x0800              0x8080            the Zone Server adds
                                           outer IPv4 proto 253

     ingress (reverse): 0x0800 -> plain IPv4, no RN
                        0x8080 -> read shim, strip it
                        proto 253 -> strip outer, then as 0x8080

The IPv4 input path never sees the shim, so nothing in existing
IPv4 code changes and there is no second stack to keep in step.
The invariant is: the Route Number selects the context, IPv4
forwarding does delivery, and the shim exists only on the wire
between two IPv8 speakers; inside the stack it is metadata.

## IPv4-only Clients: DNS8 Handles {#handles}

An IPv4-only device sends bare IPv4 and can only ever address
things by a 32-bit IPv4 address. For a destination in another
Route Number, the Zone Server has to add the shim on the
device's behalf, and the only moment at which the device
expressed which Route Number it meant is the DNS lookup that
preceded the packet. The Route Number therefore attaches to a
connection at DNS time, and XLATE8's 4-to-8 state is created by
the DNS8 answer that produced the flow, keyed on the client as
the Zone Server sees it together with the address returned in
that answer. It is never keyed on the bare destination Local
Address, which may belong to many Route Numbers.

DNS8 answers an IPv4-only client as follows:

- For a name in the client's own Route Number, any subnet: the
  real Local Address. The client's own routing carries it
  there and no state is created.

- For a name in Route Number 0, the public Internet: the real
  public address. Public addresses are unique and the client's
  default route already leads to the Zone Server.

- For a name in any other Route Number: a **handle**, an
  address from the DNS8 handle range `198.18.0.0/15`
  [@RFC2544], every time, first lookup included. The handle is
  sticky: the same client asking for the same `<RN>-<LA>`
  receives the same handle for as long as the binding lives,
  and one client never holds two bindings on one handle. The
  binding expires with its last use and the handle returns to
  the pool.

The handle pool is per Zone Server interface, so each segment
has 131,072 handles, and the same handle may be in use on two
interfaces for two different clients. An IPv4-only client thus
sees only three kinds of address --- its own Route Number's,
the public Internet's, and handles --- which cannot collide. It
never sees another Route Number's `10.0.0.0/8`, and it is never
given a real Local Address that is also in use in its own Route
Number or on its own link. (Returning the real Local Address on
the first cross-RN lookup, and a handle only on a later
conflicting one, does not work: it makes that address
unreachable in the client's own Route Number thereafter, and
when the address is on the client's own subnet the client
resolves it locally and the packet never reaches the Zone
Server.)

Two consequences. A client behind a legacy NAT in front of the
Zone Server needs nothing special: its DNS query and its data
packets traverse the same NAT, so the client as the Zone Server
sees it is the same in both, and the client is never told its
own real address by anything. In an IPv8 network, address
translation is XLATE8 at a Route Number boundary; a legacy NAT
with a network behind it is, from the Zone Server's view, one
IPv4-only host in its subnet's Route Number, and if the network
behind it has its own Route Number the NAT is the device that
should become a Zone Server. Second, DNS8 does not resolve a
name in a scoped Route Number for a client whose Zone Server
has no agreed session for that Route Number
([@route-spaces]); no handle is minted for an unreachable
target. A lookup of the client's own registered name returns
the client's own address as the client knows it. The
mechanism is specified in [@ZONESERVER] and [@SUPPORT8].

## Relationship to IPv6

IPv8 specifies an extension of IPv4. This document defines IPv8
behaviour over IPv4 transport only. IPv6 is out of scope for
this specification.

IPv6 networks operate independently of IPv8 and require no
modification to support IPv8 deployment elsewhere on the
internet. IPv8 implementations have no IPv6-specific code
paths, no dual-stack-with-IPv6 deployment mode, and no IPv6
capability negotiation.

Where an operator's IPv4 infrastructure is internally
implemented using IPv4-over-IPv6 transport (for example 4in6
[@RFC2473], DS-Lite [@RFC6333], 6rd [@RFC5969], or carrier-
internal IPv4-over-IPv6 backhaul), 8-over-4 traverses such
transport as opaque IPv4 payload, identical to any other IPv4
traffic. IPv8 has no awareness of the underlying IPv6 transport
and behaves identically whether the IPv4 hop is delivered
natively or via IPv6 tunnel.

Carriage of IPv8 directly within IPv6 transport is not
specified by this document. Such a specification, if pursued in
the future, would be the subject of a separate Internet-Draft
and is not contemplated by the current IPv8 work.

## Typical Deployment Pattern {#typical-deployment}

A typical IPv8 deployment introduces Zone Servers as Provider
Edge (PE) routers alongside the operator's existing IPv4
infrastructure. The Zone Server is a commodity Linux-based
appliance running the kernel-level IPv8 forwarding stack
([@SUPPORT8]) and the Zone Server userspace platform
([@ZONESERVER]). The operator's existing IPv4 network is
unchanged --- no overlay, no IPv6 dependency, no flag day ---
and IPv4 traffic continues to flow natively while IPv8
capability is added at the edges.

### Four-Step Deployment Recipe

An ISP, enterprise, or other AS operator deploys IPv8 in four
steps. The steps are independent of any other AS's deployment
state; each AS deploys on its own schedule.

**Step 1: Create the IPv8 VRF.** To an IPv4 network, a Route
Number is simply a VRF: a separate routing table holding one
Autonomous System's addresses ([@rn-vrf]). On the operator's
existing routers, create an ordinary IPv4 VRF named
`ipv8-<RN>`, where `<RN>` is the operator's ASN, exactly as for
a customer VPN today:

    vrf definition ipv8-64500
     address-family ipv4

In Provider Edge mode the Zone Server holds the VRF under an
internal name: the Route Number as eight hexadecimal digits
split by a dash, `ipv8-xxxx-xxxx`. RN 64500 (hexadecimal
`0000FBF4`) is `ipv8-0000-fbf4`; RN 1115169 (`00110421`) is
`ipv8-0011-0421`; a dotted RN converts the same way, 127.1.1.1
being `ipv8-7f01-0101`. The name is typed in either form and
shown as typed; a calculator is to be published at
TBD, and on the Zone Server `show ip vrf
detail` shows each VRF's internal name and its route
distinguisher. The name, route distinguisher and
route target are in [@SUPPORT8] (VRF Names). Existing VRF-aware
routers (Cisco, Juniper, Arista and others) need no new
hardware and no IPv8 software: inside the VRF they carry
ordinary IPv4, and the Zone Server, as the VRF's Provider Edge,
turns it into IPv8.

**Step 2: Stand up two Zone Servers.** Deploy two Linux
machines on commodity hardware as Zone Servers, configured as
the active-active even/odd pair (`.254` even, `.253` odd) per
[@ZONESERVER]. Each Zone Server connects to the IPv8 VRF
created in Step 1.

**Step 3: Enable the minimum services and set the RN.** Via the
Zone Server CLI or web services interface, enable the minimum
service set:

- **ACL8** --- perimeter defense of the Zone Server itself.
  The Zone Server's anycast leg faces the public IPv4 internet
  by definition (it terminates the anycast ingress prefix and
  8-over-4); ACL8 is the policy layer that controls what reaches
  the Zone Server's management plane, restricts inbound traffic
  to the services the Zone Server is intentionally publishing,
  and enforces the operator's security posture against signed
  identity claims (§Identity-Driven Access Control). A Zone
  Server deployed without ACL8 is an unprotected Linux host on
  the public internet; ACL8 is non-optional.

- **XLATE8** --- translation between IPv4-Compatible and
  native IPv8 traffic and between RNs (§Terminology).

- **DNS** (DNS8 with A8 record support per [@SUPPORT8]) ---
  destination resolution and the ZS and anycast records.

OAuth8/JWT is implicit in this set: ACL8 evaluates JWT claims
issued by OAuth8, and the two services operate as a pair.
Additional services (NetLog8 logging, NTP8, LLDP coordination,
multicast querier roles, etc.) layer onto this minimum and are
enabled as the operator's deployment matures.

Set the RN on the Zone Server interface connected to the IPv8
VRF (`ipv8-<RN>`) per the per-segment-one-RN invariant in
[@segment-invariant]. This single line --- `ip address
<RN>-<LA>/<len>` on the IPv8-facing interface --- is the only
IPv8-specific configuration the operator needs to provide for
the common single-zone deployment.

**Step 4: Scale and publish.** If the operator is deploying more
than a single Zone Server pair (e.g., one ZS pair per PE site
across a multi-site network), enable iBGP between the Zone
Server pairs (they share the operator's Route Number; sites in
different Route Numbers peer by eBGP, [@inter-site]), carried as
VPNv4 by default, so they exchange IPv8 reachability across the
operator's network. Publish the AS's ZS records and anycast
record in DNS so external IPv8-aware peers can find the AS's
ingress ([@SUPPORT8] §DNS8). For the default IPv8 gateway, the
operator chooses one of two options: either designate the first
PE's Zone Server pair as the IPv8 default gateway, or run an
ordinary BGP instance inside the `ipv8-<RN>` VRF so the
existing L3VPN-aware routing fabric distributes IPv8 routes (per
[@RFC4364]) without requiring native IPv8 awareness on
intermediate routers.

After these four steps, the AS is IPv8-capable. The operator
can reach IPv8 destinations elsewhere on the internet, accept
inbound IPv8 connections from IPv8-aware sources, and originate
or terminate IPv8 traffic within its own network. No other AS's
deployment progress is required; an AS that completes these
four steps in the absence of any other deployed AS interoperates
via the IPv4-Compatible Form with unupgraded peers.

### Physical Layout

The reference deployment uses each Zone Server with two 10 GbE
interfaces connected to the AS's IPv8 edge router:

- **Anycast leg.** One interface terminates the AS's anycast
  ingress prefix and the 8-over-4 endpoint ([@SUPPORT8]). This
  leg receives inbound IPv8 traffic from the public IPv4
  internet, carried 8-over-4, and removes the outer header for
  delivery into the AS's IPv8 RNs.

- **Native IPv8 leg.** One interface carries the AS's native
  IPv8 VRF (`ipv8-<RN>`) created in Step 1 and connects to the
  AS's internal IPv8 routing fabric. Traffic flowing in this VRF
  is native IPv8 on the wire.

The two-leg layout maps cleanly onto the five XLATE8 modes:
inbound traffic arrives on the anycast leg 8-over-4, has its
outer header removed, and exits on the native leg as native
IPv8; outbound traffic flows in reverse with 4-to-8 or 8-to-4
translation applied at the boundary as needed; intra-RN traffic
on the native leg never traverses the anycast leg. Operators
deploying at larger scale MAY use additional interfaces
(bonded for capacity, separated for management, or both); the
two-leg pattern is the operational minimum.

### Forwarding Behaviour

Once configured, packet forwarding through the Zone Server is
automatic. The Route8 table ([@SUPPORT8]) maps each packet's
destination Route Number to its forwarding target: Route Number
0, the public Route Numbers and the private (127) Route Numbers
share the master table, Route Number 0 on the plain IPv4 path; an
RN bound in Provider Edge mode goes to its VRF; each scoped (222)
and interconnect (99) Route Number stays in its own per-RN table. A route leak (BGP,
OSPF or static) joins scoped tables to each other, as between
VRFs; traffic leaves the scoped space only up through NAT at an
outside interface, and private traffic leaves the site only
through NAT at the border ([@route-space-protection]). XLATE8 modes (specified in [@ZONESERVER])
handle translation between IPv4-only hosts and IPv8 destinations
transparently; operators do not configure per-flow translation
rules. The appliance presents a single coherent configuration
surface to the operator while running its own DHCP and DNS
servers and orchestrating open-source daemons (FRR, nftables,
lldpd, chrony, mstpd), as specified in [@ZONESERVER].

### Corporate Deployment Variant

In a corporate deployment, the Zone Server occupies the same
two-leg position but the inside leg connects to the corporate
firewall rather than directly to the AS edge. The anycast leg
faces outward (toward the corporate edge and the public IPv4
internet beyond it), terminating the anycast ingress and
8-over-4; the native IPv8 leg faces inward, connecting to the
corporate firewall's inside zone. The firewall mediates between
the IPv8 native VRF and the corporate internal IPv4 network,
applying the operator's existing security policy. This variant
preserves the corporate security architecture (the firewall
remains the trust boundary) while adding IPv8 reach at the AS
edge.

### Deployment Trajectory

The deployment story for IPv8 is **every ASN that wants to use
IPv8 puts a Zone Server at every PE router on commodity
hardware.** This is the macro-level deployment unit: not a
network-wide IPv8 turn-up requiring synchronous upgrade of
every router and host, but an incremental deployment in which
each AS independently installs commodity-hardware Zone Servers
at its existing PE-router locations and gains IPv8
participation. Other ASes' deployment progress is not a
precondition; an AS can complete its IPv8 deployment in the
absence of any other AS doing the same, and interoperate via
plain IPv4 with non-deployed peers and via native
IPv8 (natively or 8-over-4 depending on intermediate transit's
deployment state) with deployed peers.

Commodity hardware is a load-bearing property: the Zone Server
is a software product running on standard x86 or ARM server
hardware with standard NICs. There is no requirement for
specialised silicon, no vendor lock-in to a particular
forwarding ASIC, and no capital-expenditure dependency on a
hardware refresh cycle. An AS already operating a fleet of
PE routers can deploy IPv8 by adding one commodity server per
PE site.

This deployment pattern satisfies the minimum-deployment-unit
requirement in [@minimum-deployment-unit]. Operators MAY scale
horizontally by deploying additional ZS appliances at the same
PE site (typically as the even/odd active-active pair
`.254`/`.253` per [@ZONESERVER]) or vertically by upgrading
edge routers to native IPv8 capability in subsequent phases as
hardware support emerges through normal vendor product cycles.

### Capacity Scaling

The number of Zone Server pairs an operator deploys is
determined by customer base, traffic profile, and operational
preference. The following figures are illustrative guidance for
sizing initial deployments; specific operators will adjust based
on their measured load characteristics.

- **Small ISP (less than 1,000 customers).** A single Zone
  Server pair (`.254`/`.253` even/odd active-active) is
  sufficient for the entire customer base. The pair provides
  the minimum redundancy required for production operation.

- **Mid-size service provider (on the order of 50,000
  customers).** Approximately four Zone Server pairs,
  distributed across the operator's PE sites for geographic
  diversity and traffic-locality benefits. The customer-to-pair
  ratio is roughly 12,000 customers per pair at this scale.

- **Hyperscaler (millions of customers).** Approximately one
  cloud-instance Zone Server per 10,000 customers activated on
  IPv8, or fewer if the operator deploys on dedicated hardware.
  At hyperscale, Zone Servers may run as cloud compute instances
  rather than as dedicated appliances; redundancy is provided by
  the cloud platform's standard multi-availability-zone
  deployment model rather than by the paired-appliance pattern.
  In this environment the marginal cost of an additional Zone
  Server is the cost of an additional compute instance, which
  for major cloud providers is small relative to the cost of
  the IPv8-activated customer base it serves.

  Operators sizing for hyperscale should note that dedicated
  hardware Zone Servers typically achieve higher per-instance
  throughput than equivalent cloud instances, owing to direct
  NIC access, absence of hypervisor overhead, NUMA-aware
  placement, and the absence of noisy-neighbour effects. The
  cloud-instance deployment pattern trades per-instance
  throughput for operational convenience (declarative
  provisioning, auto-scaling, multi-AZ redundancy provided by
  the platform). Operators with extreme per-instance throughput
  requirements, or operators for whom the cost of additional
  instances dominates the cost of additional hardware, may
  prefer dedicated bare-metal Zone Servers even at hyperscale.

The progression from small ISP through mid-size to hyperscaler
illustrates that Zone Server deployment scales linearly with
the customer base. The cost per Zone Server decreases as
deployment moves toward cloud-native compute instances, but
this cost reduction is partially offset by reduced per-instance
throughput. Operators sizing their deployments choose between
dedicated hardware (higher throughput per instance, higher
capital cost per instance) and cloud instances (lower throughput
per instance, lower marginal cost per instance, better
operational ergonomics) based on their specific traffic profile,
customer growth rate, and operational preferences. Operators
SHOULD benchmark against their own traffic profiles rather than
against the illustrative figures in this section.

## Phased Deployment

A typical IPv8 deployment proceeds in the following phases. No
phase requires coordination with peers, transit providers, or
other ASes.

**Phase 1: DNS publication (optional).** The AS publishes its
ZS records (its anycast name first, its individual Zone Servers
after it) and its anycast record, and its hosts as A8 records,
under `<RN>.asn.arpa` (or `<RN>.asn.openipv8.org` where no
delegation exists). This phase is optional for an AS that only
needs to reach outward: outbound IPv8 works from the moment
Route8 and XLATE8 are up. It becomes necessary when the AS
wants to be found as an IPv8 destination. The zone SHOULD be
signed with DNSSEC. The risk is different in kind from
ordinary DNS spoofing: a forged A record redirects one host,
but a forged ZS or anycast record redirects the ingress for an
entire Route Number to a rogue Zone Server, and on a plain
8-over-4 path across the Internet that is interception rather
than denial. Where the inter-site path is the encrypted one of
[@inter-site], a forged record can only cause a failed tunnel,
which is why signing the zone is RECOMMENDED rather than
REQUIRED. The anycast ingress prefix itself MUST be covered by a
ROA [@RFC6482].

**Phase 2: One BGP8 edge router.** The AS upgrades one BGP-
speaking edge router to BGP8 capability. This router advertises
the AS's anycast ingress prefix into the surrounding BGP4 fabric,
maintains IPv4 connectivity as required by [@minimum-deployment-unit],
and removes the outer header from 8-over-4 traffic arriving at
the anycast.

**Phase 3: Additional BGP8 edges.** The AS upgrades additional
edge routers as operational confidence grows. The ROA is
updated to reflect the expanded set of authorised origins.

**Phase 4: Interior IPv8 awareness.** The AS deploys IPv8
awareness in interior routers as needed for native IPv8
forwarding within the AS. This is typically done in stages and
does not affect inter-AS connectivity.

**Phase 5: Host opt-in.** Hosts within the AS deploy IPv8-aware
network stacks as appropriate to their use cases. Pure-IPv4
hosts continue to operate in their subnet's Route Number. For
IPv4-only hosts reaching other Route Numbers, the segment's
Zone Server provides XLATE8 4-to-8 and 8-to-4 translation
driven by DNS8 handles ([@handles]), as specified in
[@ZONESERVER] §XLATE8; the IPv4 hosts are oblivious to the
translation.

At every phase, the AS interoperates fully with both IPv8-
participating and IPv4-only counterparts. There is no flag day
and no forcing function.

## Interoperation with BGP4

BGP8 is released in two phases. **BGP8** is BGP-4 [@RFC4271]
carrying IPv8 reachability and nothing else. **BGP8x** adds the
Sun Tzu neighbour-trust and Cost Factor path-selection
extensions as a separately negotiated capability; nothing in
BGP8 depends on it, and nothing in this document requires it.
Both are specified in [@ROUTING-PROTOCOLS]. This section
describes BGP8.

A router speaks a BGP address family only if its software has
it: address families are built into a BGP implementation and
negotiated per session [@RFC4760], and cannot be added by
configuration. ASes that have not deployed BGP8 therefore
continue as BGP4 peers, and IPv8 reachability reaches them by
the mechanisms below, which an implementation selects among per
session in the order given:

- **Native BGP8 between BGP8-capable peers.** When two peers
  negotiate BGP8 capability per [@RFC5492] on a session, IPv8
  reachability is exchanged using Multiprotocol BGP [@RFC4760]
  NLRI with the IPv8 AFI specified in [@ROUTING-PROTOCOLS]. The
  full 64-bit `<RN>-<LA>` prefix is carried directly in the
  NLRI. It is used only where both peers implement it and have
  it enabled; a BGP4 router, which is most deployed equipment,
  never negotiates the IPv8 AFI and never carries it, so this
  form is not the default.

- **VPNv4, the Zone Server as Provider Edge.** This is the
  default, including on the inter-site session between Zone
  Servers ([@inter-site]). A BGP4 router beside the Zone Server
  carries the routes as ordinary VPNv4 into existing
  infrastructure, as IPv4 in a VRF, and the Route Number is
  recovered from the route distinguisher at the far BGP8 router.
  For every
  Route Number a Zone Server manages it exports a VPNv4
  [@RFC4364] route with route distinguisher and route target
  `<RN>:65535` and a label, and the inter-site session carries
  the VPNv4 address family. The label is pushed onto whatever
  underlay the session runs over, so this works identically
  across a carrier L3VPN core and across the inter-site tunnel
  over the public Internet. No router between the two Zone
  Servers ever sees a bare Local Address prefix; it sees
  `<RD>:prefix`, so overlapping Local Address space across Route
  Numbers cannot collide anywhere in the path. Unupgraded
  transit routers participate as standard L3VPN PEs and Ps
  without IPv8 awareness.

- **`asn-ibgp-path` BGP large community.** Where the fabric is
  plain BGP4 with no VPNv4 and no Provider Edge, IPv8
  reachability is exchanged as standard IPv4 NLRI with the
  Route Number carried in a BGP large community [@RFC8092]
  named `asn-ibgp-path`, used only for public Route Numbers whose
  Local Addresses are unique and off until configured per
  neighbour, an optional transitive attribute that
  BGP4 routers propagate per [@RFC1997] and [@RFC8092]. An
  existing BGP4 router needs no new code to use these routes: it
  matches the community in its import policy (a route-map used
  as a VRF import map, or a VRF import policy) and installs the
  Local Address prefixes into the VRF for that Route Number,
  with the IPv8 neighbour as next hop, which applies the Route
  Number. Receiving BGP8 routers reconstruct the `<RN>-<LA>`
  prefix from the community and the IPv4 NLRI. On one session a
  prefix is carried once, so Local Addresses that overlap across
  Route Numbers need one of two remedies: one BGP session per VRF
  (VRF-lite), or ADD-PATH [@RFC7911], which carries every path
  for a prefix on one session for the import policy to sort by
  community. A transit router that imports none of these routes
  SHOULD keep them out of its RIB (`table-map <route-map>
  filter` on IOS, `table-policy` on IOS-XR, `table-map` under
  the address family in FRR, the route-map denying on the
  community) so that a Route Number's prefix never shadows the
  transit router's own view of the same IPv4 prefix.

- **Interior routing protocols (IS-IS, OSPF, IBGP)**
  operate inside the `ipv8-<RN>` VRF using their standard
  mechanisms where L3VPN is available, or carry their own
  IPv8-extension behaviour (IS-IS8 unknown TLVs, OSPF8 opaque
  LSAs) where it is not. Detailed mechanisms in
  [@ROUTING-PROTOCOLS].

The mechanisms compose without operator intervention: an
implementation uses native BGP8 where both peers negotiate it,
VPNv4 otherwise, and the large community where the fabric is
plain BGP4. A single AS may use different mechanisms on
different segments. Routes installed in receiving BGP8 routers'
Route8 tables are identical regardless of which mechanism
delivered them.

The suite names BGP8, IBGP8, OSPF8, and IS-IS8 in companion
specifications; these are not separate protocols. They are the
existing protocols (BGP-4 [@RFC4271], OSPF, IS-IS)
carrying IPv8 reachability via the multiprotocol NLRI or an
address-family-equivalent encoding. Packet formats, adjacency
mechanisms, link-state database structures, flooding rules,
convergence procedures, and the protocols' native
path-selection metrics (OSPF cost, IS-IS metric, IBGP
local-preference and MED) are all
unchanged. Cost Factor measurement and carriage belong to BGP8x
and do not alter any interior protocol's path selection; the
IGP CF Export Interface of [@ROUTING-PROTOCOLS] is a BGP8x
feature.

The combined effect is that an AS can deploy IPv8 incrementally
without coordinating BGP8 deployment across the AS's interior
infrastructure. Operators with existing L3VPN deployments add
one VRF (`ipv8-<RN>`) to their PE configuration; operators
deploying Zone Servers get VPNv4 between them by default over
whatever underlay joins them; operators with plain BGP4 use the
large-community mechanism with their routers as they stand.
Mixed deployments are supported by capability negotiation
without operator coordination.

## Inter-Site Interconnection {#inter-site}

An enterprise or operator running IPv8 at more than one site
hooks its offices together over the Internet with a tunnel
interface and one statement per remote site:

    interface tunnel 11
     ip address 1115169-10.255.0.1/30
    interface tunnel 12
     ip address 1115169-10.255.0.5/30
    ip remote zoneserver ipv4 203.0.113.9 tunnel 11 encrypt
    ip remote zoneserver ipv8 64501-10.9.0.1 tunnel 12 encrypt

The `ipv4` form designates a remote reached across the public
Internet; the `ipv8` form a remote reachable over native IPv8
between the sites. In both cases the inner forwarding is Route
Number forwarding; the two forms differ only in the underlay.
The tunnel is an interface like any other: any routing protocol
(BGP, OSPF, IS-IS, static) MAY run over it.

**Mutual key acceptance.** When `encrypt` is specified, each
Zone Server generates a WireGuard [@WIREGUARD] key pair at first
boot and the two sites must each accept the other's public key
before any traffic passes, in the manner of first-contact SSH
host-key acceptance. On the first `ip remote zoneserver`
statement each console displays the peer's key fingerprint and
awaits confirmation; a packet can be neither encrypted nor
decrypted until both operators have accepted, so the established
tunnel is itself the proof that both sides consented. The
accepted fingerprint is recorded in the configuration so that a
rebuilt Zone Server re-pairs without prompting, and a peer that
subsequently presents a different key is refused with an alarm,
exactly as SSH refuses a changed host key. A remote site is thus
up in seconds, not the days an IKE/IPsec deployment takes.

**Reachability exchange via BGP.** Once the tunnel is
established the two Zone Servers exchange routes over it using
BGP [@RFC4271] automatically, not the intra-site synchronisation
channel (which is reserved for the local active-active pair).
The session type is derived from the two Route Numbers: two
sites in the **same** RN peer by iBGP (they are one Autonomous
System in two locations and share interior reachability), while
sites in **different** RNs peer by eBGP over VPNv4, the default
(Interoperation with BGP4, above), with ordinary eBGP path
semantics applied. The Route Number being the Autonomous System number
makes this determination automatic; the operator types one
statement and the session type follows.

**All Zone Servers are route reflectors.** Each Zone Server sets
a cluster identity and treats every same-RN peer as a
route-reflector client, so a route learned from any site is
reflected to every other site that server peers with, with the
standard ORIGINATOR_ID and CLUSTER_LIST attributes preventing
loops. There is no elected reflector and no hub to lose; the
arrangement is flooding-with-suppression over the site peering
graph, bounded by each server's own small number of peers rather
than by the total site count. Enterprise inter-site route tables
are stable for long periods, so the modest redundancy of
universal reflection costs little and removes the single point
of failure that an elected reflector would introduce.

**Relationship to the VRF-backed profile.** The intra-AS
VRF-backed profile of [@typical-deployment] (an `ipv8-<RN>`
VRF on an MPLS PE) and this inter-site tunnel profile are the
same Route Number forwarding model over two different underlays:
a provider MPLS core in the first case, an encrypted point-to-
point tunnel in the second. An operator uses the VRF-backed
profile where it already runs an L3VPN core and the tunnel
profile to join sites across the ordinary Internet or across
provider boundaries; the two compose, and a site may use one
toward its carrier and the other toward a partner.

# Implementation Status {#implementation}

This section records the status of known implementations at the
time of writing, per the guidance of [@RFC7942]. It will be
removed before publication as an RFC.

**Linux kernel reference implementation (ip8native, alpha 10).**
Two loadable Linux kernel modules with a small UAPI patch
implement the IPv8 forwarding plane as specified in this
document and in [@SUPPORT8]: the shim in front of an unmodified
IPv4 packet ([@header]); the Route Number map with the drop of
the system space (all of `224.r.r.r` and `255.r.r.r`); the
native, Provider Edge and per-RN table modes, with a table of its
own for each scoped Route Number and private Route Numbers in the
master table ([@forwarding-modes]); wildcard Route Numbers in the
private, scoped and RINE spaces; the outside-interface border, at
which a private Route Number never leaves; the kernel side of RN
resolution (packet hold, failure marking, retry and fallback to
the default route); the per-flow source-RN cache and per-link
source-RN trust list; ARP8 with three-step resolution, the
broadcast RN, answers only for addresses on the receiving
interface, re-confirmation of an entry in use every 30 seconds,
and the ARP4 fallback restricted to the Route Number of the
subnet holding the Local Address (the interface's own when no
subnet is known); the ARP8 subnet query (operations 26 and 27);
detection of one Local Address on two MACs in any Route Numbers,
with an [@RFC5227] ARP probe on address assignment; XLATE8
forwarding; the AF_INET8 socket family (`ping8`); and 8-over-4.
It modifies nothing in the existing IPv4 code paths. A Linux
6.12 kernel patched with the UAPI builds and packages cleanly
with it, and its functional suite (181 checks in network
namespaces) passed in full on 2026-10-30. Not yet in the kernel:
the ARP8 probe and gratuitous ARP8, ICMP Time Exceeded at Route
Number hops (an expired packet is dropped silently), and the
8-over-4 path-MTU relay. Source is published under the GPL-2.0
at https://www.openipv8.org.

**Zone Server (zoneCore, alpha 4).** The Zone Server userspace
platform is written in Go (MIT licence) on a general console
platform, with the IPv8 functions as one add-on and routing as
another: DHCP8 (options 222 and 223, DHCPINFORM, lease-time
registration of each host in DNS8 as an A8 record with CNAME;
A8 uses a private-use type pending assignment), DNS8 (A8 and the
anycast record), the interface-based VRF binding with
`ipv8-<RN>` VRF names, the interface-mode configuration, ACL8
addresses in IOS access lists, route origin validation over RTR,
NetLog8 to `<RN>-<LA>` destinations over a provisional TCP
transport with heartbeats, and the pseudowire configuration. It
has a Cisco IOS command grammar (`running-config`, `configure
terminal`, `show ip route`, output filters) that also fronts the
routing daemons' configuration.

**FRR8.** Routing is FRR8: FRR 10.3.4 with IPv8 added to lib,
zebra, bgpd, ospfd and isisd (GPL-2.0, packaged for Debian). BGP8
native NLRI uses the experimental AFI 8888 and is used only where
both peers negotiate it; VPNv4 with route distinguisher and
route target `<RN>:65535` is the default. The `asn-ibgp-path`
large community is `4288888888:8:<RN>`, a private ASN standing in
for the Global Administrator until IANA assigns one; it is off
until configured and stripped on eBGP. OSPF8 is an area-scope
opaque LSA (opaque type 248) and IS-IS8 is TLV 248, each pending
assignment. Cost Factor and Sun Tzu (BGP8x) are not implemented.
Native IPv8 routing between FRR8 instances has been tested in
network namespaces. On four test machines, BGP ran over seven
sessions with routes both ways, and a failed link was detected in
under 2.4 seconds with BFD (about 170 seconds without). A full
Internet table from RIPE RIS rrc00 (1,176,277 routes) loaded into
one machine, with zebra holding it in about 640 MB and the
console paging it. On a machine with 1 GB of RAM the same table
exhausted memory: the routing daemons were restarted, zebra was
killed, and 666,992 stale routes stayed in the kernel. The
fail-safe behaviour for that case is designed but not yet
implemented.

**Not yet implemented:** BGP8x (Cost Factor and Sun Tzu), RINE,
the DNS8 handle mechanism of [@handles], the ZS record, the DNS
lookup that answers the kernel's RN-miss request, DNS resolution
for private and scoped Route Numbers, `8D` marking of routes
learned through DNS, per-RN tables for the interconnect space,
the outside-interface drop of scoped Route Numbers, router 8-to-8
translation (the NAT exit from a scoped table and the
private-source rule of [@route-space-protection]), ACL8 matching
on the Route Number (rules match the Local Address only),
`ip address <RN>-<LA>/<len>` without `v8`, the 9000-octet default
MTU, `asn-simplification`, OAuth8 and the guest login, the
pseudowire data plane, the inter-site tunnel of [@inter-site],
and the delegation of `asn.openipv8.org`. The forwarding rules of this revision, including the
route-space wall, the DNS8 handle mechanism and the
double-XLATE8 cases, were additionally checked against a rule
model over the full variation grid before publication; that is a
model of the specification, not of the kernel.

**Independent testing and educational toolkit.**
Aleksei Aleinikov independently tested the kernel implementation
in his own virtual-machine environment, on running Linux kernels
including kernels built with KASAN, KCSAN and lockdep, under
functional and adversarial load. Results from that testing drove
several of the correctness requirements in this and the
previous revision, including the broadcast-domain Local Address
uniqueness rule, the duplicate-address alarm, the transit
source-RN preservation rule, and the three-step ARP8 resolution.
He also maintains Open-IPv8-Lab
(https://github.com/LF3551/Open-IPv8-Lab), an educational
userspace toolkit based on draft-thain-ipv8-02 that lets anyone
try IPv8 addressing, packet formats and routing behaviour
hands-on; it is not an implementation of this revision and does
not use the kernel modules.

# Security Considerations

## Trust Foundation

The IPv8 trust model rests on the existing RPKI [@RFC6480] trust
chain. Each Regional Internet Registry operates a RPKI trust
anchor that signs delegation certificates to ASN holders. ASN
holders sign ROAs and router certificates under their End-Entity
certificate. The IPv8 suite introduces no new PKI
infrastructure.

Compromise of the RPKI trust chain affects IPv8 identically to
how it affects ordinary BGP routing security: a compromised RIR
trust anchor permits forgery of any signed object under that
RIR's hierarchy. Mitigations are inherited from RPKI operational
practice (key ceremonies, hardware security modules, audit logs,
incident response procedures).

**Route origin validation.** An IPv8 edge router SHOULD support
RPKI route origin validation [@RFC6811], taking validated ROA
payloads from a relying-party validator over the RPKI-to-Router
protocol [@RFC8210]. By default validation only marks routes:
valid, invalid and not-found routes are all used. When strict
validation is configured, an invalid route is dropped; a
not-found route still passes, because much of the address space
has no ROA yet. To encourage registration, an implementation MAY
keep a grey list of not-found origins. How a grey-listed route is
treated beyond being listed is not yet decided and is left to a
future revision.

## Route Number Spoofing

A malicious BGP speaker MAY attempt to advertise an IPv8 prefix
with a Route Number it does not legitimately hold. The defences
against RN spoofing are:

- RPKI Route Origin Validation [@RFC6483] applied to IPv8
  prefixes, including each Route Number's anycast ingress
  prefix, rejects advertisements whose origin AS does not match
  a published ROA.

- RINE-level admission policy (per [@RINE]) MUST validate the
  origin of advertised prefixes against the RPKI. Mismatches are
  rejected and logged via NetLog8.

Because the anycast ingress prefix is announced as a `/24` (or
within a `/24` the operator already announces), covered by a
ROA with maxLength 24, no more-specific hijack validates, and an
equally specific advertisement from an unauthorised AS fails
origin validation.

## Route Space Protection {#route-space-protection}

The route spaces of [@route-spaces] MUST be kept apart. The
per-block rules are instances of that one rule:

- Routers MUST reject any inter-AS advertisement carrying an
  RN with leading octet 127 (private route space).
- A border is an interface explicitly declared outside; no
  interface is outside by its address alone. An interface with a
  public address that is not declared outside carries no traffic
  to the Internet, and an interface with a private address MAY
  be declared outside, with a warning (for example toward an ISP
  router that hands out private addresses).
- A packet MUST NOT leave an outside interface with an
  untranslated inside source: NAT (XLATE8 [@ZONESERVER]) gives it
  the outside interface's own address, or it is dropped. NAT
  zones may be layered (inside, NAT, a further zone, NAT, the
  Internet); each zone is its own private space.
- Routes MUST NOT cross between inside and outside. A routing
  protocol MAY run in both zones, on the inside interfaces and
  on the outside interfaces, normally as two routing domains
  (two processes, each with its own AS number and its own area
  0); nothing learned inside is advertised out, and nothing
  learned outside is advertised in. The inside reaches out by
  its default route through NAT. This is what keeps firewalls in
  series a defence in depth: were the layers joined by one
  routing domain, a single leaked route would carry traffic
  around every layer.
- A packet MUST NOT leave an outside interface that has a public
  address, whether configured or leased, with a source or
  destination in the private route space (`127.r.r.r`), in the
  scoped route space (`222.r.r.r`) or, in Route Number 0, in the
  [@RFC1918] address ranges. This is the rule of [@RFC1918], made
  a requirement on an IPv8 device; it is checked after NAT. Only
  an explicit operator override (`ip nat outside allow private
  addresses`) lifts it.
- Routers MUST NOT redistribute an RN with leading octet 99
  (interconnect route space) on the public Internet. It MAY be
  used on public-facing interfaces and on the sessions on which
  it is agreed, and is installed only into its own table.
- Routers MUST reject any advertisement of RN with leading
  octet 100 (RINE peering) from a non-RINE peer.
- Routers MUST accept an advertisement of an RN with leading
  octet 222 (scoped route space) only on a session on which
  that Route Number has been agreed --- an iBGP8 session within
  the operator, or the bilateral eBGP8 session set up for it
  --- MUST install it only into the target that Route Number is
  bound to (its own table by default, or its Provider Edge VRF),
  and MUST NOT re-advertise it on any other session.
- A packet whose source or destination Route Number is in the
  system route space (`224.r.r.r` or `255.r.r.r`) MUST be
  dropped.
- A Zone Server MUST accept an 8-over-4 packet whose
  Destination Route Number is in the private or scoped route
  space only over a session on which that Route Number has
  been agreed, even when the Zone Server itself owns that
  Route Number. Without this rule any Internet host could
  address a private Route Number directly by constructing the
  outer header.
- A Zone Server MUST translate (XLATE8 8-to-8) a Source Route
  Number in the private route space to its own public Route
  Number before sending the packet over a session on which
  that private Route Number has not been agreed. Otherwise the
  reply carries a private Destination Route Number that cannot
  cross back.

These rejections SHOULD be logged via NetLog8 and, where BGP8x
is deployed, SHOULD contribute to Sun Tzu trust evaluation of
the offending peer.

## Per-Segment RN Invariant Enforcement

The per-segment-one-RN invariant ([@segment-invariant]) is
security-relevant. The segment's Primary RN is taken from DHCP,
never from an ARP8 message, so it cannot be set by a forged
broadcast; a rogue DHCP answer is the rogue DHCP server problem,
with its existing remedy (DHCP snooping). A conflict observed at
run time MUST raise a NetLog8 SEC-ALERT and MUST NOT stop
forwarding on the interface: the messages that reveal it are not
authenticated, and a rule that stopped the segment would let one
forged message stop it.

## Encapsulation Boundary Trust

8-over-4 (specified in [@SUPPORT8]) places trust in the
integrity of the outer IPv4 path between the two ends. This
trust is identical to the trust placed in IPv4 by any
application or protocol traversing IPv4 today. Specifically:

- Outer-header integrity is protected by the IPv4 header
  checksum and any link-layer protections present.
- Inner-payload confidentiality and integrity are the
  responsibility of higher-layer protocols (TLS, IPsec, etc.)
  exactly as for any IPv4-transported traffic, or of the
  encrypted inter-site tunnel of [@inter-site].
- An attacker capable of intercepting and modifying IPv4
  packets in flight can intercept and modify 8-over-4 packets
  equivalently. 8-over-4 introduces no new vulnerability beyond
  those inherent to IPv4 transport.

## Cross-AS Multicast and Broadcast

Cross-AS multicast and broadcast in IPv8 carry the same
amplification and reflection risks as in IPv4. Cross-AS
multicast group assignments ([@multicast]) MUST be filtered
by ingress policy at the AS boundary; broadcast addresses MUST
NOT be forwarded across any RN boundary.

## Trust State Update Discipline

Per the operational pattern in [@trust-state-pattern],
trust-state updates are operator-initiated. The security
implications:

- A compromised upstream data source affects only operators
  who happen to update during the compromise window. The blast
  radius is limited compared to automatic refresh.

- An operator who declines to update (perhaps after observing
  anomalous diff output from `verify`) preserves their pre-
  compromise state. The verify-before-update separation is
  load-bearing for this property and SHOULD NOT be removed in
  implementations.

- An operator who updates and subsequently observes incident
  symptoms can roll back to a previous version of the trust
  state by replaying the prior update. Implementations SHOULD
  retain the previous N versions of trust state to support this
  recovery path.

# IANA Considerations {#iana}

This section enumerates IANA registry actions requested by this
document. Companion documents in the IPv8 suite request
additional codepoints in their respective IANA Considerations
sections.

No IP version number is requested. The IPv4 header carried
inside an IPv8 packet is unmodified and its Version field is 4
([@header]); IPv8 is identified on the wire by the EtherType
and, for 8-over-4, by the IPv4 protocol number below.

## EtherType for Native IPv8

IANA is requested to coordinate with the IEEE Registration
Authority to assign EtherType 0x8080 (referenced for the
Altair 8800) for native IPv8 frames carrying the shim and IPv4
packet specified in [@header].

## Route Number Reserved Block: Private Route Space

IANA is requested to record the reservation of Route Numbers
with leading octet 127 (`127.r.r.r`) as the private route
space, for private use without allocation, as specified in
[@route-spaces] and [@reserved].

## Route Number Reserved Block: RINE Peering

IANA is requested to record the reservation of Route Numbers
with leading octet 100 (`100.r.r.r`) for RINE peering as
specified in [@reserved] and detailed in [@RINE].

## Route Number Reserved Block: Scoped Route Space

IANA is requested to record the reservation of Route Numbers
with leading octet 222 (`222.r.r.r`) as the scoped route space,
each Route Number of which is a separate forwarding table
meaningful only on the sessions and interfaces where it is
agreed, as specified in [@route-spaces] and [@reserved]. A
scoped Route Number never leaves through an outside interface
toward the Internet.

## Route Number Reserved Block: Interconnect Route Space

IANA is requested to record the reservation of Route Numbers
with leading octet 99 (`99.r.r.r`) as the interconnect route
space, each Route Number of which is a separate forwarding
table, for peering and private CGNAT-style use, which MAY be
used publicly but is never redistributed on the public
Internet, as specified in [@route-spaces] and [@reserved].

## Route Number Reserved Blocks: Experimental, Masking, System Use

IANA is requested to record leading octet 223 (`223.r.r.r`) as
experimental and leading octet 224 (`224.r.r.r`) as reserved for
internal Route Number masking, as specified in [@reserved].
IANA is requested to record `255.r.r.r` as reserved for future
system use, assignment by IETF Review [@RFC8126], and to assign
`255.255.255.255` from it as the broadcast Route Number, as
specified in this document. Leading octets 240 to 254 remain
IANA-reserved.

## DNS8 Handle Range

IANA is requested to add to the entry for 198.18.0.0/15 in the
IANA IPv4 Special-Purpose Address Registry [@RFC6890] a second
documented use, "DNS8 synthetic IPv4 handles for IPv4-only
clients", as specified in [@handles], alongside the existing
benchmarking use of [@RFC2544]. No change to the entry's
properties is requested: the addresses remain not globally
reachable, not forwardable beyond the local scope, and not
advertised in the routing system. This is a registry note, not
a reallocation.

## Route Number Reserved Blocks: Future Allocation Pools

IANA is requested to record the additional RN-block reservations
specified in the table in [@reserved] (leading octets 1--32 for
super-scalar allocation, 110--119 for RIR sub-RN pools, 128--130
for cellular carrier allocation, 225--239 for future use, and
the various IANA-reserved ranges in between). Allocation policy
for these blocks is to be defined by future IETF action. Route
Numbers in 225--239 operate normally; implementations MUST NOT
filter or reject them.

## DNS Resource Record Types for A8 and ZS

IANA is requested to assign DNS Resource Record Type codes to
the A8 record type, which carries an IPv8 address as RDATA (the
64-bit IPv8 address in network byte order, 8 octets), and to the
ZS record type, which lists a Route Number's Zone Server ingress
endpoints (a 16-bit preference and a target domain name), as
specified in [@SUPPORT8]. The exact codepoints are to be
assigned by IANA.

## IPv8-in-IPv4 Protocol Number

IANA is requested to assign an IPv4 Protocol Number to "IPv8-
in-IPv4" in the Protocol Numbers registry. This codepoint
identifies an IPv4 packet whose payload is an IPv8 packet (shim
followed by an IPv4 packet), as specified in [@header] and
[@SUPPORT8]. Implementations use 253 from the experimentation
range [@RFC3692] pending assignment.

## .arpa Subdomain Registration

IANA is requested to delegate the `asn.arpa` zone for use by
the IPv8 specification suite. The zone hosts records of the
form `<RN>.asn.arpa` (the Route Number's ZS records and its
hosts' A8 records) and `anycast.<RN>.asn.arpa` (the Route
Number's anycast ingress address), as specified in [@SUPPORT8].
Until the zone is delegated, `asn.openipv8.org` serves the same
records.

## DHCP Option Codepoints

IANA is requested to assign codepoints in the BOOTP/DHCP
Parameters registry for the IPv8-specific options:

- **Option 222** --- IPv8 Default Route Number. Carries the
  Primary RN assignment for the segment scope, as specified
  in [@ZONESERVER] and [@SUPPORT8].

- **Option 223** --- IPv8 Interface Mode. Carries the
  per-interface mode value (normal, strict, pnp, guest) as
  specified in [@per-interface-mode] of this document and
  in [@ZONESERVER].

The values 222 and 223 are taken from the DHCP private-use
range pending permanent IANA assignment.

# References

## Normative References

<reference anchor="RFC791">
  <front>
    <title>Internet Protocol</title>
    <author initials="J." surname="Postel" fullname="Jon Postel"/>
    <date year="1981" month="September"/>
  </front>
  <seriesInfo name="RFC" value="791"/>
</reference>

<reference anchor="RFC2119">
  <front>
    <title>Key words for use in RFCs to Indicate Requirement Levels</title>
    <author initials="S." surname="Bradner" fullname="Scott Bradner"/>
    <date year="1997" month="March"/>
  </front>
  <seriesInfo name="RFC" value="2119"/>
</reference>

<reference anchor="RFC8174">
  <front>
    <title>Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words</title>
    <author initials="B." surname="Leiba" fullname="Barry Leiba"/>
    <date year="2017" month="May"/>
  </front>
  <seriesInfo name="RFC" value="8174"/>
</reference>

<reference anchor="RFC4271">
  <front>
    <title>A Border Gateway Protocol 4 (BGP-4)</title>
    <author initials="Y." surname="Rekhter"/>
    <date year="2006" month="January"/>
  </front>
  <seriesInfo name="RFC" value="4271"/>
</reference>

<reference anchor="RFC4364">
  <front>
    <title>BGP/MPLS IP Virtual Private Networks (VPNs)</title>
    <author initials="E." surname="Rosen"/>
    <date year="2006" month="February"/>
  </front>
  <seriesInfo name="RFC" value="4364"/>
</reference>

<reference anchor="RFC1997">
  <front>
    <title>BGP Communities Attribute</title>
    <author initials="R." surname="Chandra"/>
    <author initials="P." surname="Traina"/>
    <author initials="T." surname="Li"/>
    <date year="1996" month="August"/>
  </front>
  <seriesInfo name="RFC" value="1997"/>
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

<reference anchor="RFC5492">
  <front>
    <title>Capabilities Advertisement with BGP-4</title>
    <author initials="J." surname="Scudder"/>
    <author initials="R." surname="Chandra"/>
    <date year="2009" month="February"/>
  </front>
  <seriesInfo name="RFC" value="5492"/>
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

<reference anchor="RFC6480">
  <front>
    <title>An Infrastructure to Support Secure Internet Routing</title>
    <author initials="M." surname="Lepinski"/>
    <date year="2012" month="February"/>
  </front>
  <seriesInfo name="RFC" value="6480"/>
</reference>

<reference anchor="RFC6482">
  <front>
    <title>A Profile for Route Origin Authorizations (ROAs)</title>
    <author initials="M." surname="Lepinski"/>
    <date year="2012" month="February"/>
  </front>
  <seriesInfo name="RFC" value="6482"/>
</reference>

<reference anchor="RFC6483">
  <front>
    <title>Validation of Route Origination Using the Resource Certificate PKI and ROAs</title>
    <author initials="G." surname="Huston"/>
    <date year="2012" month="February"/>
  </front>
  <seriesInfo name="RFC" value="6483"/>
</reference>

<reference anchor="RFC5737">
  <front>
    <title>IPv4 Address Blocks Reserved for Documentation</title>
    <author initials="J." surname="Arkko"/>
    <date year="2010" month="January"/>
  </front>
  <seriesInfo name="RFC" value="5737"/>
</reference>

## Informative References

<reference anchor="RFC6598">
  <front>
    <title>IANA-Reserved IPv4 Prefix for Shared Address Space</title>
    <author initials="J." surname="Weil" fullname="J. Weil"/>
    <author initials="V." surname="Kuarsingh" fullname="V. Kuarsingh"/>
    <author initials="C." surname="Donley" fullname="C. Donley"/>
    <author initials="C." surname="Liljenstolpe" fullname="C. Liljenstolpe"/>
    <author initials="M." surname="Azinger" fullname="M. Azinger"/>
    <date year="2012" month="April"/>
  </front>
  <seriesInfo name="RFC" value="6598"/>
  <seriesInfo name="BCP" value="153"/>
</reference>

<reference anchor="RFC1918">
  <front>
    <title>Address Allocation for Private Internets</title>
    <author initials="Y." surname="Rekhter" fullname="Yakov Rekhter"/>
    <author initials="B." surname="Moskowitz" fullname="Robert G. Moskowitz"/>
    <author initials="D." surname="Karrenberg" fullname="Daniel Karrenberg"/>
    <author initials="G. J." surname="de Groot" fullname="Geert Jan de Groot"/>
    <author initials="E." surname="Lear" fullname="Eliot Lear"/>
    <date year="1996" month="February"/>
  </front>
  <seriesInfo name="RFC" value="1918"/>
  <seriesInfo name="BCP" value="5"/>
</reference>

<reference anchor="RFC8126">
  <front>
    <title>Guidelines for Writing an IANA Considerations Section in RFCs</title>
    <author initials="M." surname="Cotton" fullname="Michelle Cotton"/>
    <author initials="B." surname="Leiba" fullname="Barry Leiba"/>
    <author initials="T." surname="Narten" fullname="Thomas Narten"/>
    <date year="2017" month="June"/>
  </front>
  <seriesInfo name="RFC" value="8126"/>
  <seriesInfo name="BCP" value="26"/>
</reference>

<reference anchor="RFC6811">
  <front>
    <title>BGP Prefix Origin Validation</title>
    <author initials="P." surname="Mohapatra"/>
    <author initials="J." surname="Scudder"/>
    <author initials="D." surname="Ward"/>
    <author initials="R." surname="Bush"/>
    <author initials="R." surname="Austein"/>
    <date year="2013" month="January"/>
  </front>
  <seriesInfo name="RFC" value="6811"/>
</reference>

<reference anchor="RFC8210">
  <front>
    <title>The Resource Public Key Infrastructure (RPKI) to Router Protocol, Version 1</title>
    <author initials="R." surname="Bush"/>
    <author initials="R." surname="Austein"/>
    <date year="2017" month="September"/>
  </front>
  <seriesInfo name="RFC" value="8210"/>
</reference>

<reference anchor="ASPA">
  <front>
    <title>BGP AS_PATH Verification Based on Autonomous System Provider Authorization (ASPA) Objects</title>
    <author initials="A." surname="Azimov"/>
    <author initials="E." surname="Bogomazov"/>
    <author initials="R." surname="Bush"/>
    <author initials="K." surname="Patel"/>
    <author initials="J." surname="Snijders"/>
    <author initials="K." surname="Sriram"/>
  </front>
  <seriesInfo name="Internet-Draft" value="draft-ietf-sidrops-aspa-verification"/>
</reference>

<reference anchor="RFC2473">
  <front>
    <title>Generic Packet Tunneling in IPv6 Specification</title>
    <author initials="A." surname="Conta"/>
    <date year="1998" month="December"/>
  </front>
  <seriesInfo name="RFC" value="2473"/>
</reference>

<reference anchor="RFC2865">
  <front>
    <title>Remote Authentication Dial In User Service (RADIUS)</title>
    <author initials="C." surname="Rigney"/>
    <date year="2000" month="June"/>
  </front>
  <seriesInfo name="RFC" value="2865"/>
</reference>

<reference anchor="RFC5227">
  <front>
    <title>IPv4 Address Conflict Detection</title>
    <author initials="S." surname="Cheshire"/>
    <date year="2008" month="July"/>
  </front>
  <seriesInfo name="RFC" value="5227"/>
</reference>

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

<reference anchor="RFC6890">
  <front>
    <title>Special-Purpose IP Address Registries</title>
    <author initials="M." surname="Cotton"/>
    <author initials="L." surname="Vegoda"/>
    <author initials="R." surname="Bonica"/>
    <author initials="B." surname="Haberman"/>
    <date year="2013" month="April"/>
  </front>
  <seriesInfo name="RFC" value="6890"/>
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

<reference anchor="IEEE8021X">
  <front>
    <title>IEEE Standard for Local and Metropolitan Area Networks --- Port-Based Network Access Control</title>
    <author><organization>IEEE</organization></author>
    <date year="2020"/>
  </front>
  <seriesInfo name="IEEE" value="802.1X-2020"/>
</reference>

<reference anchor="WIREGUARD">
  <front>
    <title>WireGuard: Next Generation Kernel Network Tunnel</title>
    <author initials="J." surname="Donenfeld"/>
    <date year="2017"/>
  </front>
  <refcontent>NDSS 2017</refcontent>
</reference>

<reference anchor="RFC5969">
  <front>
    <title>IPv6 Rapid Deployment on IPv4 Infrastructures (6rd)</title>
    <author initials="W." surname="Townsley"/>
    <date year="2010" month="August"/>
  </front>
  <seriesInfo name="RFC" value="5969"/>
</reference>

<reference anchor="RFC6333">
  <front>
    <title>Dual-Stack Lite Broadband Deployments Following IPv4 Exhaustion</title>
    <author initials="A." surname="Durand"/>
    <date year="2011" month="August"/>
  </front>
  <seriesInfo name="RFC" value="6333"/>
</reference>

<reference anchor="RFC6749">
  <front>
    <title>The OAuth 2.0 Authorization Framework</title>
    <author initials="D." surname="Hardt"/>
    <date year="2012" month="October"/>
  </front>
  <seriesInfo name="RFC" value="6749"/>
</reference>

<reference anchor="RFC7519">
  <front>
    <title>JSON Web Token (JWT)</title>
    <author initials="M." surname="Jones"/>
    <date year="2015" month="May"/>
  </front>
  <seriesInfo name="RFC" value="7519"/>
</reference>

<reference anchor="ROUTING-PROTOCOLS">
  <front><title>IPv8 Routing Protocols: BGP8, IBGP8, OSPF8, IS-IS8</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <author initials="A." surname="Aleinikov" fullname="Aleksei Aleinikov"/>
  <date year="2026" month="May"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-routing-protocols-00"/>
</reference>

<reference anchor="RINE">
  <front><title>Regional Inter-Network Exchange</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="May"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-rine-00"/>
</reference>

<reference anchor="ZONESERVER">
  <front><title>Zone Server Architecture</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <author initials="A." surname="Aleinikov" fullname="Aleksei Aleinikov"/>
  <date year="2026" month="May"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-zoneserver-00"/>
</reference>

<reference anchor="NETLOG8">
  <front><title>NetLog8 Protocol</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="May"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-netlog8-00"/>
</reference>

<reference anchor="SUPPORT8">
  <front><title>IPv8 Support Protocols: ARP8, ICMPv8, Route8, ACL8, and DNS8</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <author initials="A." surname="Aleinikov" fullname="Aleksei Aleinikov"/>
  <date year="2026" month="October"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-support8-00"/>
</reference>

<reference anchor="UPDATE8">
  <front><title>Update8 and NIC Certification</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="May"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-update8-00"/>
</reference>

{backmatter}

# Appendix A: Changes since -02

This appendix summarises the substantive changes. Editorial
corrections, reference updates, and similar housekeeping are not
enumerated individually.

## Changes in -04

- **Wire format corrected.** The 28-octet widened header of -03
  is withdrawn. An IPv8 packet is an 8-octet shim (Source Route
  Number, Destination Route Number) in front of a complete,
  unmodified IPv4 packet; native frames use EtherType 0x8080;
  8-over-4 is the same packet inside an outer IPv4 header with
  the IPv8-in-IPv4 protocol number ([@header]), and is not a
  tunnel. The request for an IP version number is withdrawn. An
  MTU subsection is added, with jumbo frames by default.

- **Wire rule.** An IPv8 speaker always sends the shim, including
  within its own Primary RN and with Destination Route Number 0
  for the Internet; bare IPv4 is sent only to a neighbour that
  proved itself IPv4-only; a received unshimmed frame is plain
  IPv4 ([@wire-format]). The -03 rule that omitted the shim
  inside the Primary RN is withdrawn. IPv4-Compatible Form is
  redefined as a shim with Destination Route Number 0.

- **Segment Primary RN.** The Primary RN is given by DHCP
  (option 222, DHCPINFORM), with the ARP8 subnet query where
  there is no DHCP; ARP8 Primary RN Discovery is withdrawn. A
  segment may carry subnets in several Route Numbers, and an
  IPv4 neighbour is in its subnet's Route Number. A conflict
  raises an alarm and never stops forwarding.

- **Route spaces.** New [@route-spaces] defines the public,
  private (127), scoped (222) and interconnect (99) route spaces and the rule that
  routes never cross between them; traffic crosses only through
  XLATE8. The 222 block is redefined from "interior link
  convention" to scoped Route Numbers, each automatically its
  own forwarding table, never leaving toward the Internet,
  never crossing scopes; the
  NO_EXPORT/NO_ADVERTISE default and the "outside the
  originating AS" rejection are replaced by session-scoped
  acceptance. Private Route Numbers share the master table and
  are kept in by the border: a packet leaves an outside
  interface only translated, no route crosses between inside
  and outside, and no private, scoped or RFC 1918 address
  leaves the last border. The interconnect space `99.r.r.r` is
  new: each Route Number its own table, for peering and private
  CGNAT for devices, used publicly or behind NAT and by
  pseudowires, never redistributed on the public Internet;
  `99.<ASN>` with carriers peering in odd and even pairs is a
  suggested convention.

- **Reserved blocks.** 223 experimental, 224 internal masking
  (dropped on receipt), 225--239 future use, 240--254
  IANA-reserved; 224 and 255 form the system route space;
  `255.r.r.r` is reserved for system use by IETF Review, and
  `255.255.255.255`, the broadcast RN, is claimed from it.

- **Forwarding modes.** The two-mode description is replaced by
  the Route Number map with native, Provider Edge and per-RN
  table modes ([@forwarding-modes]), beginning with the
  reserved-RN drop and ending with RN resolution through DNS
  and the default route. A VRF named after a Route Number is
  typed `ipv8-<RN>` and held internally as `ipv8-xxxx-xxxx`;
  the VPNv4 route distinguisher and route target are
  `<RN>:65535`, RD type 2 ([@SUPPORT8]). The VRF material is
  reduced to the remote-VRF framing ([@rn-vrf]). Provider Edge
  binding is by interface; an interface's IPv8 address is
  `ip address [v8] <RN>-<LA>/<len>`. Tables are joined only by
  routes.

- **BGP8 and BGP8x.** BGP8 is defined as BGP-4 carrying IPv8
  reachability only; Sun Tzu and Cost Factor move to BGP8x, a
  later, separately negotiated capability. VPNv4 with the Zone
  Server as Provider Edge is the default everywhere, including
  between BGP8 speakers; native BGP8 only where both peers
  negotiate it; the large community, off by default, only for
  unique-LA public Route Numbers across plain BGP4, which
  existing routers import into VRFs by policy, with VRF-lite and
  ADD-PATH for overlapping Local Addresses.

- **DNS8 handles.** New [@handles]: IPv4-only clients receive a
  sticky handle from 198.18.0.0/15 for every destination in
  another Route Number; XLATE8 4-to-8 state is created by the
  DNS8 answer and keyed on the client as the Zone Server sees
  it; pool per interface; legacy-NAT and self-lookup behaviour;
  no resolution into unagreed scoped Route Numbers. IANA is
  asked to note the use in the special-purpose registry.

- **Anycast and ZS.** Every Zone Server is an anycast server for
  its Route Number by default; the ZS records list the anycast
  name first and the individual Zone Servers after it, giving
  the nearest server and failover together. The anycast ingress
  prefix MUST be covered by a ROA. IANA is asked for the ZS
  record type.

- **WHOIS8** is deprecated in favour of RPKI and ASPA; AnycastROA
  is withdrawn.

- **Inter-site interconnection** uses a tunnel interface
  (`interface tunnel N`, `ip remote zoneserver ipv4|ipv8 <peer>
  tunnel N encrypt`) with automatic BGP, and any routing
  protocol MAY run over it.

- **Rules from the forwarding model.** 8-over-4 for a private or
  scoped Destination Route Number is accepted only over an
  agreed session; a private Source Route Number is 8-to-8
  translated before crossing an unagreed session; Local Address
  uniqueness is per Route Number across sites as well as per
  broadcast domain ([@segment-invariant], §Security
  Considerations).

- **Framing.** "An RN is a remote VRF"; hybrid IPv4/IPv8
  operation stated as the normal condition rather than a
  transition; the Single-Stack section carries the stack figure.

- **Deployment.** Phase 1 is optional DNS publication with
  DNSSEC RECOMMENDED and its rationale; Phase 2 refers to the
  anycast ingress prefix. Masks are written as prefix lengths.

- **Implementation Status** updated to ip8native alpha 10,
  zoneCore alpha 4 and FRR8, with coverage, measurements (a full
  Internet table, and the failure on a 1 GB box) and gaps listed.

- **Route origin validation.** Edge routers SHOULD validate
  origins against the RPKI over RTR; by default validation only
  marks routes, and strict drops invalid routes only.

- **Wildcard Route Numbers.** Private, scoped and RINE Route
  Numbers may be wildcarded octet by octet in routes; public and
  interconnect Route Numbers never.

- **Per-interface mode.** Modes are normal and strict;
  plug-and-play is an interface setting; guest is a walled garden
  on `127.255.r.r` before login, and tokens choose the mode after
  it.

## Changes in -03

- **Co-author.** Aleksei Aleinikov (Open-IPv8-Lab) is added as
  co-author; see Contributors.

- **Broadcast-domain Local Address uniqueness.** The
  per-segment invariant ([@segment-invariant]) now states
  explicitly that IPv8 Local Addresses MUST be unique within one
  broadcast domain irrespective of RN, with a required
  duplicate-address alarm and a required pre-assignment ARP
  probe. This closes a cross-RN address-collision case
  identified in independent testing of the kernel
  implementation: because every IPv8 host also answers ARP for
  its Local Address, two hosts sharing a Local Address on one
  segment collide regardless of their Route Numbers. Local
  Addresses remain freely reusable across broadcast domains.

- **Pre-authentication holding state; displacement of 802.1X.**
  The Identity-Driven Access Control section ([@preauth]) now
  specifies that an unauthenticated device is confined to a
  holding RN on a /32 Local Address reachable only to the Zone
  Server, authenticates over Layer 3 by presenting an OAuth8
  JWT, and is rebound into its entitled RN on success. IPv8 is
  stated to displace 802.1X: admission becomes a property of a
  signed identity reached at Layer 3 rather than a Layer 2
  port-state machine, needs no supplicant, RADIUS server, or
  switch cooperation, federates to any OpenID Connect provider,
  and confines by the absence of a route rather than by a
  firewall rule. The same mechanism is noted to operate in an
  IPv4 network with VLAN assignment as the admission outcome.

- **Inter-site interconnection.** A new section ([@inter-site])
  specifies the `ip remote zoneserver ... encrypt` model:
  WireGuard tunnels with SSH-style mutual key acceptance,
  reachability exchange over BGP (iBGP for same-RN sites, eBGP
  for different-RN, derived automatically from the Route
  Numbers), and all Zone Servers acting as route reflectors.
  Its relationship to the VRF-backed MPLS profile is stated:
  the same Route Number forwarding model over two underlays.

- **Transit source-RN preservation.** Clarified that a router
  forwarding a packet that arrived 8-over-4 preserves the
  originator's source Route Number end to end rather than
  substituting its own.

- **ARP8 and ICMPv8 alignment with running code.** The ARP8
  protocol type is the IPv8 EtherType; the value 0x86DD8 in
  earlier companion text does not fit the 16-bit field and is
  corrected in [@SUPPORT8]. ICMPv8 is carried as ordinary ICMP
  within the IPv8 packet addressed to the source RN, not as a
  distinct 36-octet header; the earlier description is
  corrected in [@SUPPORT8].

- **Running code.** A mainline-kernel reference implementation
  (the two modules of [@implementation]) now exists and has been
  tested independently; correctness requirements in this
  revision reflect results from loading and attacking that code
  on running kernels.

- **Notation.** Canonical locator form changed from dotted
  eight-octet notation (`R.R.R.R.n.n.n.n`) to the hyphenated
  form `<RN>-<LA>`; the dotted-eight-octet form is accepted on
  input only. Reserved-block notation changed from `127.0.0.0/8`
  style to `127.r.r.r` style, since the Route Number is not
  subnettable.

- **Reserved RN blocks.** A complete reservation table for the
  leading-octet namespace was added in [@reserved]; the
  `127.127.0.0/16` "Inter-Company Interop Prefix" was removed,
  its use case covered by the two-XLATE8 model of [@ZONESERVER].

- **Per-segment RN invariant, per-interface mode, XLATE8, L4
  family-agnostic framing, the edge-router IPv4 requirement,
  the typical deployment pattern and capacity guidance, the
  three BGP8 propagation mechanisms, Cost Factor scope, and the
  shortened Identity-Driven Access Control section** were added
  or rewritten as described in that revision.

# Contributors

IPv8 is the joint work of the authors. Aleksei Aleinikov
(Open-IPv8-Lab) independently tested the kernel implementation
in a virtual-machine test environment; his results drove a
number of the correctness requirements in -03 and -04,
including the broadcast-domain Local Address uniqueness rule and
its duplicate-address alarm, the transit source-RN preservation
rule, and the three-step ARP8 resolution. He also maintains
Open-IPv8-Lab, an educational IPv8 toolkit for hands-on
experimentation. On the strength of that work he is named as
co-author of this and subsequent revisions and of [@SUPPORT8].

# Acknowledgements

The authors thank the IETF community for prior work on RPKI,
DNSSEC, and BGP routing security on which this specification
builds. IPv8 introduces no new cryptographic primitives, no new
PKI infrastructure, and no new DNS infrastructure; it composes
existing well-deployed mechanisms into a coherent addressing
and trust framework.
