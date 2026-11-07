%%%
title = "IPv8 Routing Protocols: BGP8, IBGP8, OSPF8, IS-IS8"
abbrev = "routing-protocols"
docName = "draft-thain-routing-protocols-00"
ipr = "trust200902"
category = "std"
area = "Internet"
workgroup = "Internet Area Working Group"
keyword = ["IPv8", "BGP8", "OSPF8", "IS-IS8", "Cost Factor", "CF"]

[seriesInfo]
name = "Internet-Draft"
value = "draft-thain-routing-protocols-00"
stream = "IETF"
status = "standard"

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

%%%

# Abstract

This document specifies the routing protocol suite for Internet
Protocol Version 8 (IPv8) [@IPV8]. It defines Border Gateway
Protocol Version 8 (BGP8), Interior BGP Version 8 (IBGP8), OSPF8
intra-zone routing extensions, IS-IS8 optional interior gateway
protocol extensions, the encapsulation mechanism for IPv8
traffic across IPv4-only transit networks, and the Cost Factor
(CF) metric that provides end-to-end measured path quality
across all routing protocol boundaries.

BGP8 extends BGP4 [@RFC4271] with a versioned Cost Factor (CF)
metric derived from TCP session telemetry, proportional load
distribution across multiple paths, WHOIS8 route validation,
and a structurally bounded global routing table. BGP8 capability
is negotiated per-session per [@RFC5492]; sessions where
capability negotiation does not succeed use BGP4 semantics with
the `asn-ibgp-path` BGP Large Community [@RFC8092] for IPv8
path preservation.

OSPF8 extends OSPFv2 [@RFC2328] and IS-IS8 extends IS-IS
[@ISO10589] with the same CF export TLV/LSA interface and with
IPv8 reachability distribution via opaque LSAs and unknown TLVs
respectively. IBGP8 distributes WHOIS8-validated external
routes with full CF awareness throughout an autonomous system.

This document is one of the companion specifications listed in
[@IPV8] §1. The Regional Inter-Network Exchange (RINE) peering
fabric addressing convention is specified in [@RINE]. This
document references RINE for peering fabric context.

{mainmatter}

# Introduction

## Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL
NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as
described in BCP 14 [@RFC2119] [@RFC8174] when, and only when,
they appear in all capitals, as shown here.

## Document Scope

This document specifies the routing-protocol behaviour of IPv8
networks. The IPv8 address format, terminology, architectural
principles, and security model are specified in [@IPV8]. The
encapsulation mechanism for IPv8 traffic across IPv4-only spans
is specified in [@SUPPORT8]. The trust mechanisms (WHOIS8
records, AnycastROA, RPKI integration) are specified in
[@WHOIS8]. This document references those specifications and
specifies the routing-protocol-specific behaviour that builds
on them.

# Terminology

In addition to terms defined in [@IPV8] §2, this document uses
the following terms.

**BGP8.** The IPv8 extension of BGP4 [@RFC4271] specified in
this document.

**IBGP8.** Interior BGP version 8, the IPv8 extension of iBGP
specified in this document.

**OSPF8.** The IPv8 extension of OSPFv2 [@RFC2328] specified
in this document.

**IS-IS8.** The IPv8 extension of IS-IS [@ISO10589] specified
in this document.

**Native NLRI8.** The encoding of an IPv8 prefix in BGP8 multi-
protocol NLRI form, used between BGP8-capable peers that have
successfully negotiated BGP8 capability per [@RFC5492].

**Community-Encoded NLRI.** The encoding of an IPv8 prefix in
BGP4 form using the `asn-ibgp-path` BGP Large Community
[@RFC8092] to preserve the Route Number through BGP4-only
transit. Used between iBGP peers when BGP8 capability is not
negotiated on the session.

**Cost Factor (CF).** The IPv8 path-quality metric defined in
§[@cf]. CF combines round-trip time, loss, congestion, stability,
capacity, economic policy, and geographic distance into a
single scalar.

**Sun Tzu.** The Neighbor Trust Verification mechanism defined
in §[@sun-tzu]. Sun Tzu accumulates per-peer trust scores and
governs route acceptance through trust-state transitions.

**8to4.** The IPv8-in-IPv4 encapsulation mechanism specified in
[@SUPPORT8] §III. Referenced in this document where routing-
protocol behaviour interacts with encapsulation.

# Background

## The ASN Organisational Problem

Border Gateway Protocol version 4 [@RFC4271] was designed when
Autonomous System Numbers mapped roughly to geographical and
organisational boundaries. This assumption no longer holds. Major
Tier 1 carriers operate globally under organisational ASN
portfolios. A single carrier may operate under one ASN that spans
datacentres on multiple continents. BGP4 sees one ASN entry with
no visibility into where inside that ASN traffic will be delivered.

The result is that AS-level routing decisions are made with no
information about actual experienced path quality. Operators work
around this with complex LOCAL_PREF configurations, route maps,
and community strings — all requiring manual maintenance and all
approximating what measured telemetry could provide automatically.

Most carriers today use a combination of OSPF, IBGP, static routes,
and MPLS label switching to solve the same path quality problems
that the Cost Factor metric is designed to solve. CF provides a
single measured end-to-end metric that threads across all routing
protocol boundaries — something no individual protocol achieves
alone.

### The Cost Factor Solution

The Cost Factor (CF) metric addresses the ASN organisational
problem by replacing topology-based path selection with
measurement-based path selection. CF is a 32-bit accumulated
metric derived from seven components measured directly from TCP
session telemetry. CF accumulates across every BGP8 hop from
source to destination. Every router independently selects the
path with the lowest accumulated CF without coordination.

CF combines properties of three historically separate routing
approaches:

- **EIGRP's dynamic composite metric** — real measured path
  quality combining latency, loss, and congestion rather than
  theoretical topology approximation.
- **OSPF's accumulated cost model** — a number that grows
  hop by hop so every router independently calculates the
  optimal path without centralised coordination.
- **Load balancing** — proportional traffic distribution
  across multiple paths weighted by relative CF values.

CF extends all three because it operates end-to-end across AS
boundaries. OSPF stops at the zone boundary. EIGRP stops at the
AS boundary. BGP4 path attributes exist but none measure actual
experienced quality. CF threads through all of them via the IGP
CF export interface (Section 10) and the IBGP8 distribution
mechanism (Section 9).

The goal of CF is short links and small numbers. A well-connected
regional network will have CF values in the low millions. Paths
to remote locations with limited fibre infrastructure may require
manual CF adjustment via the Economic Component to reflect routing
topology that exceeds the geographic floor. See Section 3.3
(Economic Component) and [@RINE] Section 6.3.

### The Carrier Regional ASN Model and Summarisation

Major carriers have independently converged on maintaining separate
regional ASNs for each major economic region of the world —
commonly 6 to 8 regional ASNs. IPv8 formalises this existing
operational practice as a recommended convention.

Each regional ASN advertises a single /8 summary route into the
global BGP8 table. The /16 minimum injectable prefix rule creates
an economic forcing function: carriers that do not summarise
regionally inject more routes into peers' tables, creating
commercial incentive for summarisation.

The result is a global BGP8 routing table structurally bounded
by ASN count. Most providers will have no more than approximately
10 routes per ASN in the global table — typically one /8 summary
per regional ASN. Even providers with complex multi-regional
presence rarely need more than a handful of summary routes. This
compares favourably to BGP4's 900,000+ prefixes growing without
architectural bound.

### eBGP8 as Mandatory EGP

eBGP8 is the mandatory exterior gateway protocol for the IPv8
internet. All autonomous systems participating in global IPv8
routing MUST implement eBGP8. eBGP8 is 100% backward compatible
with BGP4 [@RFC4271]. BGP8 and BGP4 sessions MAY coexist on the
same router without restriction.

### IGP Selection - Operator Decision

IPv8 requires that all L3 devices implement OSPF8 and that IS-IS8
be available in all L3 routing stacks. The choice of which IGP to
run — OSPF8, IS-IS8, or both — is entirely the operator's
decision. IPv8 makes no recommendation regarding IGP selection,
topology design, area structure, or operational deployment. That
is the operator's domain.

Both OSPF8 and IS-IS8 are fully specified in Section 10. Both
MUST implement the CF export interface if running. The CF export
interface is the mandatory requirement — not which IGP implements
it.

### CF as Open Versioned Algorithm

The Cost Factor metric is an open versioned algorithm. CFv1 is
the mandatory baseline. Future CF versions MAY be negotiated
between peers via the BGP8 capability advertisement mechanism.

---

## BGP8 Routing Table

### Table Structure

The global BGP8 routing table is bounded by the number of
/16 prefixes held across all active ASNs -- a structurally
finite set. An ASN may advertise multiple /16 prefixes but
never more specific. Most ASNs advertise a small number of
/16 summary routes. This compares favourably to BGP4's
900,000+ prefixes growing without architectural bound.

The BGP8 table carries ASN-level reachability including the
IPv4 anycast address for each ASN used for encapsulated
IPv4 transit (Section 11). Internal prefix management
within an ASN is never advertised to the global table.

### Routing Table Tiers

| Tier | Scope  | Index    | Description                              |
|------|--------|----------|------------------------------------------|
| 1    | Global | r.r.r.r  | Routes to correct AS border router       |
| 2    | Local  | n.n.n.n  | Identical to existing IPv4 routing table |

When r.r.r.r = 0.0.0.0 the Tier 1 lookup is bypassed.

### Internal Zone Prefix Routing

The 127.x.x.x internal zone prefix space is routed via IBGP8
within an organisation's AS. Internal zone prefixes MUST NOT
appear in eBGP8 advertisements.

### Minimum Injectable Prefix - /16 at Inter-AS

Prefixes more specific than /16 MUST NOT be advertised across
AS boundaries. Received advertisements more specific than /16
from external peers MUST be rejected and logged via NetLog8 as
SEC-ALERT.

Peers MAY implement route filters accepting only /16 or shorter
prefixes from any single external ASN. Such filtering is
RECOMMENDED as default policy on all BGP8 border routers.

### Regional Summarisation Convention

Major carriers operating multiple regional ASNs SHOULD advertise
a single /8 summary route per regional ASN into the global BGP8
table. This is a recommended operational convention, not a
protocol requirement. The enforcement mechanism is economic:
carriers that do not summarise inject additional routes into
every peer's routing table.

The seven standard regional ASN groupings align with RINE regions:

| Region | Scope | RINE Regions |
|--------|-------|--------------|
| North America | | 1-5 |
| Europe | | 12-17 |
| Asia Pacific | | 38-46 |
| Middle East and UAE | | 21-24 |
| Africa | | 25-28 |
| South America | | 6-11 |
| Southeast Asia | | 34-37 |

---

## Cost Factor (CF) {#cf}

### CF Field Definition

| Property      | Value                                      |
|---------------|--------------------------------------------|
| Size          | 32-bit unsigned integer                    |
| Default value | 2,147,483,648 (2^31, neutral midpoint)     |
| Minimum       | 0 (absolute preferred path)                |
| Maximum       | 4,294,967,295 (effectively unreachable)    |
| Stability band| +2,000 to -5,000                           |

Lower CF = preferred path. CF is carried in the BGP8 data region.
BGP4 speakers that do not recognise CF MUST ignore it.

A path does not change unless the CF delta of a competing path
exceeds the stability band (+2,000 worse or -5,000 better than
the current path). This prevents oscillation on marginal
differences and rewards path stability.

### CFv1 Algorithm

    CF = 2,147,483,648
       + RTT_COMPONENT
       + LOSS_COMPONENT
       + CONGESTION_COMPONENT
       + STABILITY_COMPONENT
       + CAPACITY_COMPONENT
       + ECONOMIC_COMPONENT
       + GEOGRAPHIC_COMPONENT

    Clamped to: 0 to 4,294,967,295

### CFv1 Component Definitions

**RTT Component** (most significant signal):

    RTT_COMPONENT = RTT_us × 100

    RTT_us = round trip time in microseconds
             60-second exponential moving average
             from TCP session telemetry

    Examples:
       1ms RTT   (1,000us)    → +100,000
       10ms RTT  (10,000us)   → +1,000,000
       50ms RTT  (50,000us)   → +5,000,000
       150ms RTT (150,000us)  → +15,000,000
       300ms RTT (300,000us)  → +30,000,000

RTT dominates CF because it measures actual experienced latency
of real traffic rather than theoretical capacity.

**Loss Component** (exponentially penalised):

    LOSS_COMPONENT = (LOSS_PCT ^ 2) × 10,000,000

    Examples:
       0.0% loss → 0
       0.1% loss → +100,000
       0.5% loss → +2,500,000
       1.0% loss → +10,000,000
       5.0% loss → +250,000,000

Loss is squared because 1% loss has approximately 100x the
impact on TCP throughput of 0.1% loss.

**Congestion Component** (window-based):

    CONGESTION_COMPONENT = CWND_RATIO × 5,000,000

    CWND_RATIO = (MAX_CWND - CURRENT_CWND) / MAX_CWND
                 MAX_CWND = maximum observed over 300 seconds

    Examples:
       CWND at 100% → +0
       CWND at 50%  → +2,500,000
       CWND at 10%  → +4,500,000

**Stability Component** (rewards consistent paths):

    STABILITY_COMPONENT = -(MIN(SESSION_DAYS, 30) × 10,000)

    Examples:
       Session up 1 day    → -10,000
       Session up 7 days   → -70,000
       Session up 30 days  → -300,000 (maximum)

Stability is negative — it reduces CF. A long-running stable
session is preferred over a new session with identical other
metrics.

**Capacity Component** (rewards high bandwidth):

    CAPACITY_COMPONENT = -(LOG10(LINK_GBPS) × 100,000)

    Examples:
       1 Gbps   → 0
       10 Gbps  → -100,000
       100 Gbps → -200,000
       400 Gbps → -260,000
       1 Tbps   → -300,000

**Economic Component** (operator policy):

    ECONOMIC_COMPONENT = OPERATOR_CONFIGURED_VALUE

    Range: -500,000,000 to +500,000,000

    Configuration:
       peer <asn> cf-contribution <value>

    Examples:
       -50,000,000  Preferred or subsidised peering
       0            Settlement-free IXP peer
       100,000      Normal transit peer
       500,000      Expensive transit peer
       2,000,000,000 Last resort only

The economic component expresses commercial relationships within
the CF framework. Operators familiar with BGP4 will recognise
this as LOCAL_PREF expressed numerically and accumulated rather
than reset at each AS boundary.

Manual CF adjustment via the economic component is RECOMMENDED
for paths where routing topology causes measured RTT to
significantly exceed the geographic floor — for example paths
to Pacific island locations or polar regions where submarine
cable routes add significant latency beyond the physical distance.

**Geographic Component** (physics floor):

    GEOGRAPHIC_COMPONENT = GREAT_CIRCLE_KM × 333

    GEO_WEIGHT = 333
                 (speed of light in fibre ≈ 200,000 km/s)

    Examples:
       London → Frankfurt  (600km)     → +199,800
       London → New York   (5,500km)   → +1,831,500
       London → Singapore  (10,800km)  → +3,596,400
       London → Sydney     (16,900km)  → +5,627,700

Geographic component sets the physics floor. If RTT_COMPONENT
is less than GEOGRAPHIC_COMPONENT the path is physically
implausible and a CF-ANOMALY NetLog8 alert MUST be generated.

### CFv1 Real World Examples

London to Frankfurt direct (excellent path):

    RTT: 8ms              → +800,000
    Loss: 0.01%           → +1,000
    CWND: 95% of max      → +250,000
    Session: 180d (cap 30)→ -300,000
    Capacity: 100G        → -200,000
    Economic: IXP peer    → -50,000
    Geographic: 600km     → +199,800
    CF = 2,148,184,448

London to New York via good peer:

    RTT: 75ms             → +7,500,000
    Loss: 0.02%           → +4,000
    CWND: 90% of max      → +500,000
    Session: 365d (cap 30)→ -300,000
    Capacity: 400G        → -260,000
    Economic: good peer   → 0
    Geographic: 5,500km   → +1,831,500
    CF = 2,156,759,148

London to Sydney via satellite (poor path):

    RTT: 600ms            → +60,000,000
    Loss: 0.5%            → +2,500,000
    CWND: 40% of max      → +3,000,000
    Session: 2 days       → -20,000
    Capacity: 1G          → 0
    Economic: last resort → +2,000,000,000
    Geographic: 16,900km  → +5,627,700
    CF = 4,294,967,295 (clamped)

### CF Accumulation

    CF_out = CF_in + CF_configured + CF_measured_delta

Each BGP8 peer contributes its measured cost to the accumulated
CF. CF_measured_delta is computed from TCP session telemetry
per CFv1.

### BGP4 Traversal and IPv4 Hop CF

BGP8 --> BGP8: CF accumulates normally.
BGP8 --> BGP4 --> BGP8: IPv4-only hops contribute zero CF.
CF accumulation resumes when the packet re-enters a BGP8
path. The IPv4 segment is invisible to CF optimisation.
BGP4 --> BGP8: CF initialises at 2,147,483,648 (neutral).

An IPv4-only hop MUST NOT be assigned a negative CF
contribution. The minimum CF contribution for an IPv4 hop
is zero. Operators MAY assign a positive economic component
to IPv4 hops to explicitly penalise them in path selection.
By default the economic component for IPv4 hops is zero.

The natural preference for BGP8 paths with real CF data over
BGP4 paths with reset CF creates gentle economic incentive for
BGP8 adoption without any forced migration.

### CF Algorithm Versioning

CFv1 is the mandatory baseline. Future CF versions MAY add:

- QUIC session telemetry
- Application layer latency signals
- Carbon cost component (green routing)
- Time of day component (peak/off-peak)
- Measured jitter (video/voice quality)
- ML-derived congestion prediction

CF version is negotiated in the BGP8 OPEN message. Peers
negotiate the highest mutually supported CF version. A CFv1
peer talking to a CFv2 peer downgrades to CFv1 for that
session automatically.

### IGP CF Export Interface

All running IGP instances MUST export intra-zone cost as CF
contribution to IBGP8. The CF export interface is common to
both OSPF8 and IS-IS8:

    <igp> export cf
       cf-range +2000 -5000

The cf-range parameter defines the stability band for CF
contributions exported from the IGP into IBGP8. Changes within
this band do not trigger IBGP8 route updates.

IBGP8 adds intra-zone CF to external CF:

    CF_total = CF_external + CF_intrazone

Every internal router automatically prefers the edge router
with the best combined external plus internal CF.

---

## TCP Session Telemetry

BGP8 runs over TCP port 179. Mandatory telemetry fields:

| Field               | Description                                   |
|---------------------|-----------------------------------------------|
| TCP_RTT             | Round trip time in microseconds               |
| TCP_retransmit_rate | Retransmission rate % over 60s window         |
| TCP_cwnd            | Current congestion window in bytes            |
| TCP_rwnd            | Current receive window in bytes               |
| TCP_session_uptime  | Session uptime in seconds                     |

A BGP8 optional attribute carries peer geolocation:
- Attribute type: BGP8-GEO
- Format: latitude (float32), longitude (float32)

---

## Load Distribution

### Proportional Distribution

    Path percentage = (Total_CF - Path_CF) / Total_CF × 100

Lower CF paths receive proportionally more traffic.

### Example - Four Active Paths to ASN 15169

| Path | CF            | Traffic |
|------|---------------|---------|
| 1    | 1,000,000,000 | 45%     |
| 2    | 1,500,000,000 | 30%     |
| 3    | 2,000,000,000 | 20%     |
| 4    | 3,000,000,000 | 5%      |

### Even/Odd Path Selection

Route8 [@SUPPORT8] implements per-connection even/odd path
selection. Even-numbered client IPs use the even border gateway.
Odd-numbered client IPs use the odd border gateway. TCP
connections follow their assigned path for the lifetime of the
connection.

### Configuration

    router bgp8 <asn>
       load-balance
       max-peers auto <1-65000>

---

## Path Selection

BGP8 retains the top N paths per destination ASN ranked by CF
ascending. Default N = 4. On failure of all retained paths the
BGP8 speaker queries upstream peers for next best paths.

---

## Route Validation (WHOIS8)

All BGP8 route advertisements MUST be validated against WHOIS8
[@WHOIS8] before installation in the routing table.

| Rule | Action                                            |
|------|---------------------------------------------------|
| R1   | ASN not in RIR registry — reject                  |
| R2   | Address not in provisioned WHOIS8 block — reject  |
| R3   | Invalid record signature — reject                 |
| R4   | WHOIS8 server unreachable — grace period applies  |

## Anycast Route Authorisation

WHOIS8 anycast advertisements (the `/32` prefixes specified in
[@WHOIS8]) are subject to additional verification based on the
AnycastROA mechanism. The verification is layered:

**`/24` covering prefix verification.** A BGP router receiving
an advertisement for a `/24` prefix that contains a registered
WHOIS8 anycast `/32` SHOULD verify the originating AS in the BGP
path against the WHOIS8-published origin AS for that `/24`. On
mismatch, the router SHOULD emit a console warning of the form
"source address not signed, route unable to be inserted" and
hold the route from insertion pending operator review. NetLog8
SHOULD record the held-route event.

**`/32` anycast prefix verification.** A BGP8 router receiving
an advertisement for a `/32` matching a registered WHOIS8
anycast SHOULD additionally verify the originating AS against
the AnycastROA's authorised origins list, with the same
console-warning-and-hold behaviour on mismatch.

**RINE peering enforcement.** RINE peering routers MUST perform
both verifications and MUST reject advertisements failing either
check. RINE rejection events MUST emit NetLog8 records and MUST
contribute to Sun Tzu trust evaluation of the offending peer.

The verification policy guards against misconfiguration as well
as deliberate hijack. Operator visibility into held routes is
the primary recovery path for both cases. Implementations SHOULD
NOT silently reject routes that fail AnycastROA verification;
the operator-visible warning is load-bearing for misconfiguration
detection.

### Anycast Redundancy Recommendation

WHOIS8-participating ASes SHOULD publish at least three anycast
`/24` prefixes per [@WHOIS8], geographically separated and
ideally on diverse upstream providers. Each anycast SHOULD have
its own AnycastROA listing the authorised originators. This
redundancy provides:

- **Availability:** failure of any single anycast does not break
  inter-AS IPv8 reachability for the AS.
- **Topological diversity:** different anycasts can be reached
  via different paths, allowing BGP4 anycast routing to select
  the best path per source.
- **Traffic engineering:** different anycasts MAY serve
  different LA ranges per the WHOIS8 `ipv4-anycast-detail`
  mechanism.

### Filter List Operational Pattern

Per [@IPV8] §4.6, AnycastROA filter lists are updated via
explicit operator command rather than automatic background
refresh. Implementations SHOULD provide separate operations for
verification (showing the diff between current upstream state
and locally-installed state without modification) and update
(installing the upstream state). See [@WHOIS8] for the full
filter list availability specification.

---

## Minimum Prefix Length

### Inter-AS Minimum - /16 {#inter-as-min-prefix}

Prefixes more specific than /16 MUST NOT be advertised beyond
an AS boundary. Received advertisements more specific than /16
from external peers MUST be rejected and logged via NetLog8 as
SEC-ALERT.

### Intra-AS - Any Length Permitted

Internal routing via IBGP8 and IGPs MAY use any prefix length.

---

## IBGP8 (Interior BGP8)

### Validated Route Distribution

IBGP8 distributes only WHOIS8-validated routes within the AS.
Invalid routes never enter IBGP8.

### Internal Zone Prefix Distribution

IBGP8 distributes 127.x.x.x internal zone prefix routes between
Zone Server pairs across zone boundaries.

### End-to-End CF Metrics

    CF_total = CF_external + CF_intrazone

Every internal router receives validated external routes with
combined total CF per path.

### Configuration

    router ibgp8 <asn>
       redistribute whois8-validated
       cf-internal measure
       redistribute <igp> cf-export

IBGP8 sessions automatically negotiate IPv8 capability with peers.
Sessions where capability negotiation succeeds use Native NLRI8.
Sessions with BGP4-only iBGP peers use the `asn-ibgp-path`
community-encoded form per the NLRI Encoding section below. Both
forms produce equivalent RIB entries.

---

## NLRI Encoding and BGP4 Compatibility {#nlri}

BGP8 supports two NLRI formats for IPv8 prefix distribution.
Selection is determined per session via capability negotiation
[@RFC5492].

### Native NLRI8

Between BGP8 routers that have negotiated IPv8 capability, IPv8
prefixes are exchanged using Multiprotocol BGP [@RFC4760] with
an IPv8-specific AFI/SAFI pair.

    AFI:  TBD-IPV8 (IANA assignment requested)
    SAFI: 1 (Unicast)

NLRI entries carry full 64-bit r.r.r.r.n.n.n.n prefixes encoded
as `<prefix_length, prefix>` tuples per the standard MP-BGP
encoding extended to 64-bit length. NEXT_HOP is carried in the
standard BGP NEXT_HOP attribute.

Native NLRI8 is the efficient form. BGP8 implementations MUST
use Native NLRI8 on sessions where IPv8 capability has been
negotiated.

### Community-Encoded NLRI (asn-ibgp-path)

For sessions where IPv8 capability has not been negotiated —
including iBGP sessions traversing BGP4-only routers within an
AS — IPv8 prefixes are exchanged using standard 32-bit IPv4
NLRI [@RFC4271] with the r.r.r.r ASN prefix carried in a BGP
large community [@RFC8092].

The community is named `asn-ibgp-path`. Its format:

    Global Administrator: <IETF-AS>  (IANA-assigned)
    Local Data 1:         8           (IPv8 path semantic)
    Local Data 2:         r.r.r.r     (32-bit ASN prefix)

A BGP UPDATE message carrying an IPv8 route in community-encoded
form contains:

- Standard IPv4 NLRI: `n.n.n.n/length` (the n.n.n.n portion
  of the IPv8 prefix)
- BGP large community: `<IETF-AS>:8:<r.r.r.r>` (the r.r.r.r
  portion)
- Standard NEXT_HOP: the originating BGP8 router's loopback
  address (RFC 1918 acceptable for intra-AS use)
- Standard AS_PATH and other path attributes per BGP4

BGP4-only routers receiving such routes propagate them
transparently per [@RFC1997] / [@RFC8092] community propagation
rules. They install the standard 32-bit IPv4 route in their
RIB and forward the community attribute unchanged in further
iBGP advertisements. They do not interpret the community
semantically.

BGP8 routers receiving community-encoded routes reconstruct
the full 64-bit prefix as `<r.r.r.r from community>.<n.n.n.n
from NLRI>` and install the route in their unified Route8
table with the originating loopback as NEXT_HOP.

### BGP-in-VRF via VPNv4

For sessions where the AS's iBGP fabric supports L3VPN
distribution via Multiprotocol BGP with the VPNv4 address
family [@RFC4364], an additional mechanism is available: the
IPv8 prefix is carried in an `ipv8-asn-<RN>` VRF using VPNv4
NLRI with route distinguisher `<RN>:65535`. The L3VPN
distribution machinery propagates the route through the
existing iBGP fabric without requiring IPv8 awareness in any
intermediate router; routers that participate in VPNv4
distribution propagate VPNv4 advertisements as standard
L3VPN PE/P behaviour.

BGP-in-VRF is the natural mechanism for operators with
existing L3VPN deployments — major carriers, large enterprises
with MPLS backbones — because it rides the same VPNv4
distribution they already operate for customer L3VPN service.
The `ipv8-asn-<RN>` VRF is structurally indistinguishable from
any other customer L3VPN VRF from the iBGP fabric's
perspective.

Routes received via BGP-in-VRF are installed in the receiving
BGP8 router's Route8 table with the route distinguisher's
ASN portion (<RN>) supplying the IPv8 prefix's R.R.R.R, and
the inner IPv4 NLRI within the VRF supplying the n.n.n.n.
NEXT_HOP is the originating PE's loopback per standard L3VPN
mechanics.

### Format Selection

BGP8 implementations MUST select the NLRI format per session
based on capability negotiation [@RFC5492] and on
locally-available infrastructure. Three NLRI mechanisms exist:

- **Native NLRI8** — used when the session has IPv8 capability
  negotiated successfully. Most efficient form; full
  R.R.R.R.n.n.n.n prefix carried in MP-BGP NLRI directly.

- **BGP-in-VRF via VPNv4** — used when the iBGP fabric
  supports VPNv4 distribution but the session does not
  negotiate IPv8 capability. The `ipv8-asn-<RN>` VRF rides
  existing L3VPN distribution machinery.

- **Community-encoded NLRI (`asn-ibgp-path`)** — used when
  neither IPv8 capability nor VPNv4 distribution is available
  on the session. Standard 32-bit IPv4 NLRI with the R.R.R.R
  prefix carried in a BGP large community [@RFC8092]. The
  community propagates transparently through any BGP4 router
  per [@RFC1997] community-propagation rules.

The mechanisms compose. A single AS may use different
mechanisms on different segments depending on what each
region of infrastructure supports; the choice is determined
per session by capability negotiation, not by operator
configuration in advance. Routes installed in receiving BGP8
routers' Route8 RIBs are functionally identical regardless
of which mechanism delivered them. Path selection, forwarding
decisions, and CF processing operate on the unified RIB
without distinguishing how routes were encoded on the wire.

### iBGP Through BGP4 Transit

A BGP8 router peering with iBGP neighbours that are BGP4-only
uses the community-encoded form for all IPv8 route
advertisements. The BGP4-only iBGP routers propagate the routes
transparently. Other BGP8 routers elsewhere in the AS receive
the advertisements (potentially via multiple BGP4 hops) and
reconstruct the full IPv8 RIB.

This permits incremental BGP8 deployment within an AS — a small
number of BGP8 routers can exchange complete IPv8 routing
information through an existing BGP4 iBGP fabric without
requiring all iBGP routers to be upgraded simultaneously.

### eBGP Strip-by-Default

The `asn-ibgp-path` community is iBGP-scoped by name and design.
BGP8 implementations MUST strip the `asn-ibgp-path` community
on all eBGP outbound advertisements by default.

Operators MAY configure explicit override on specific eBGP
sessions for bilateral arrangements where coordinating ASNs
choose to share IPv8 path information. Override requires
deliberate per-peer configuration; the default is strip.

External IPv8 reachability is conveyed through per-ASN anycast
advertisements per the IPv8 Across IPv4 Networks section using
standard BGP4 NLRI. The `asn-ibgp-path` community has no defined
eBGP semantics and propagating it externally would communicate
internal infrastructure information for which external peers
have no context.

BGP8 implementations receiving the community on eBGP sessions
propagate it per standard [@RFC1997]/[@RFC8092] rules but MUST NOT use
it to influence routing decisions in eBGP context.

### CF Initialisation for BGP4 Routes

Routes received via standard BGP4 (no IPv8 community, no IPv8
NLRI) are installed in the unified Route8 table with r.r.r.r =
0.0.0.0 (IPv4-form) and CF initialised to 2,147,483,648 (neutral
midpoint). This ensures BGP4 routes participate in path selection
without being either preferred or penalised relative to
measured-CF IPv8 paths.

---

## Interior Gateway Protocol Extensions

### Overview - Operator IGP Choice

IPv8 requires that all L3 devices implement OSPF8 and that IS-IS8
be available in all L3 routing stacks. The operator decides which
IGP to run. IPv8 makes no recommendation regarding this choice.

The CF export interface defined in Section 10.2 is mandatory for
any running IGP instance. An IGP that is installed but not running
does not need to export CF. An IGP that is running MUST export CF.

### CF Export Interface (IGP-Agnostic)

The CF export interface is common to both OSPF8 and IS-IS8. Both
implementations use the same cost-to-CF mapping:

| IGP Cost | CF Contribution | Description               |
|----------|-----------------|---------------------------|
| 1        | -50,000         | Excellent intra-zone link |
| 5        | -25,000         | Good intra-zone link      |
| 10       | 0               | Neutral (reference cost)  |
| 50       | +200,000        | Degraded link             |
| 100      | +500,000        | Poor intra-zone link      |
| 65535    | +2,000,000,000  | Link effectively down     |

The mapping formula:

    CF_contribution = (IGP_cost - 10) × 5,000

Clamped to the configured cf-range values.

### OSPF8 Implementation

#### Overview

OSPF8 is OSPFv2 [@RFC2328] extended with a CF export interface.
All other OSPF behaviour — LSA flooding, SPF calculation, area
design, neighbour adjacency, authentication — is unchanged.
OSPF8 is not a new protocol. It is OSPFv2 with one additional
export mechanism.

#### OSPF8 Area Design for IPv8

    Area 0 (backbone):
       Connects Zone Server pairs at AS boundary routers
       Carries CF export data to IBGP8 redistributors
       MUST be present on all multi-area deployments

    Non-zero areas:
       One area per network zone (per VLAN typically)
       Matches Zone Server segment boundaries
       Area ID SHOULD match zone VLAN number for clarity

    Stub areas:
       RECOMMENDED for end-device zones with single exit

#### OSPF8 IPv8 Reachability Distribution

OSPF8 distributes IPv8 reachability through the same flood-and-
ignore extension mechanism that BGP8 uses with the `asn-ibgp-path`
community: a new LSA type carries the R.R.R.R portion of an IPv8
prefix, OSPF8 routers parse and install it, and OSPF-only routers
in the same area flood the LSA per [@RFC5250] opaque-LSA rules
without interpreting its contents.

**IPv8 Reachability Opaque LSA (area-scope):**

    LSA Type:           10 (area-scope opaque, [@RFC5250])
    Opaque Type:        [IANA assignment pending]
    Content:
       R.R.R.R:               32-bit route number prefix
       n.n.n.n/length:        standard IPv4 reachability tuple
       Originator Router ID:  Router ID of OSPF8 originator
       Originator Loopback:   IPv4 loopback address of originator,
                              used as BGP next-hop / encapsulation
                              target for this prefix
       Flags:                 IPv8_reachability_valid (bit 0)

OSPF-only routers receiving this LSA MUST flood it within the
area per standard opaque-LSA flooding rules and store it in the
LSDB. OSPF-only routers MUST NOT attempt to install the carried
prefix in their forwarding table — the LSA is opaque to them by
definition. SPF calculations on OSPF-only routers are unaffected.

OSPF8 routers extract the R.R.R.R prefix and the n.n.n.n/length
tuple from the LSA, combine them into the full 64-bit IPv8
prefix, and install the route in the unified Route8 table with
the Originator Loopback as next-hop. The Originator Loopback is
the IPv4 destination that an encapsulating router places in the
outer IPv4 header when forwarding a packet for this prefix
across an IPv4-only span; see [@SUPPORT8] Part III for the
encapsulation rule.

This permits incremental OSPF8 deployment within an area: a small
number of OSPF8 routers can exchange complete IPv8 reachability
through an existing OSPF area populated mostly by unupgraded
OSPF routers, without requiring all routers in the area to be
upgraded simultaneously.

#### Reachability LSA Origination

The IPv8 Reachability Opaque LSA MUST be originated only at the
point of injection of an IPv8 prefix into the OSPF8 area. This
occurs when an OSPF8 router:

- has a directly-connected IPv8 interface in the area;
- redistributes an IPv8 prefix into OSPF8 from another routing
  source (BGP8, IBGP8, IS-IS8, static, or whois8-validated);
- originates an IPv8 prefix via local configuration.

OSPF8 routers receiving an existing IPv8 Reachability Opaque
LSA from another OSPF8 router MUST NOT re-originate the LSA
under their own Router ID. They install the carried prefix in
the unified Route8 table and rely on standard OSPF flooding to
propagate the LSA further. Re-origination would cause LSA
duplication and confuse the SPF calculation on OSPF8 routers
that consume the LSA.

#### OSPF8 Type 11 LSA for CF Export

OSPF8 adds one new LSA type for CF export:

**Type 11 — CF Export LSA (AS-scope):**

    LSA Type:     11 (AS-scope opaque, [@RFC5250])
    Content:
       Link ID:         Interface IPv8 address
       CF_contribution: int32
       Link_Gbps:       uint16
       Session_uptime:  uint32
       Flags:           CF_export_valid (bit 0)

#### Configuration

    router ospf8 <process-id>
       area <n> range <prefix>
       cf-export enable
       cf-range +2000 -5000
       redistribute ibgp8 cf-import

### IS-IS8 Implementation

#### Overview and Operational Context

IS-IS [@ISO10589] is extensively deployed in Tier 1 carrier and
large enterprise networks. It offers a two-level hierarchy that
simplifies large-scale IGP design compared to OSPF8 multi-area
configurations. IPv8 fully supports IS-IS8 as an equal alternative
to OSPF8.

IS-IS8 MUST be available in all IPv8 L3 routing stacks. Carriers
and operators MAY deploy IS-IS8 at their discretion. IS-IS8 with
CF export achieves equivalent path optimisation to OSPF8.

The IS-IS community is encouraged to develop extended IS-IS8
specifications building on this foundation through the IETF
process.

#### Two-Level Hierarchy in IPv8

IS-IS8 two-level hierarchy maps naturally to IPv8 network structure:

    Level 1 (intra-area):
       Equivalent to OSPF8 non-backbone area
       Intra-zone routing within a network zone
       CF export applies at L1 boundaries

    Level 2 (backbone):
       Equivalent to OSPF8 Area 0
       Inter-zone routing within the AS
       CF exported to IBGP8 at L2/IBGP8 boundary

#### IS-IS8 IPv8 Reachability Distribution

IS-IS8 distributes IPv8 reachability through the same flood-and-
ignore extension mechanism that BGP8 uses with the `asn-ibgp-path`
community: a new TLV carries the R.R.R.R portion of an IPv8
prefix in IS-IS LSPs, IS-IS8 routers parse and install it, and
IS-IS-only routers in the same level flood the LSP per
[@RFC5305] unknown-TLV handling without interpreting the new TLV.

**IS-IS8 IPv8 Reachability TLV:**

    TLV type:    [IANA assignment pending]
    TLV name:    IS-IS8 IPv8 Reachability
    Content:
       R.R.R.R:               32-bit route number prefix
       n.n.n.n/length:        standard IPv4 reachability tuple
       Originator System ID:  System ID of IS-IS8 originator
       Originator Loopback:   IPv4 loopback address of originator,
                              used as BGP next-hop / encapsulation
                              target for this prefix
       Flags:                 IPv8_reachability_valid (bit 0)

IS-IS-only routers receiving an LSP carrying this TLV MUST flood
the LSP per standard IS-IS flooding rules and store it in the
LSDB. IS-IS-only routers MUST NOT attempt to install the carried
prefix in their forwarding table — the TLV is opaque to them by
definition of IS-IS unknown-TLV handling. SPF calculations on
IS-IS-only routers are unaffected.

IS-IS8 routers extract the R.R.R.R prefix and the n.n.n.n/length
tuple from the TLV, combine them into the full 64-bit IPv8
prefix, and install the route in the unified Route8 table with
the Originator Loopback as next-hop. The Originator Loopback is
the IPv4 destination that an encapsulating router places in the
outer IPv4 header when forwarding a packet for this prefix
across an IPv4-only span; see [@SUPPORT8] Part III for the
encapsulation rule.

This permits incremental IS-IS8 deployment within a level: a
small number of IS-IS8 routers can exchange complete IPv8
reachability through an existing IS-IS level populated mostly by
unupgraded IS-IS routers, without requiring all routers in the
level to be upgraded simultaneously.

#### Reachability TLV Origination

The IS-IS8 IPv8 Reachability TLV MUST be originated only at the
point of injection of an IPv8 prefix into the IS-IS8 level. This
occurs when an IS-IS8 router:

- has a directly-connected IPv8 interface in the level;
- redistributes an IPv8 prefix into IS-IS8 from another routing
  source (BGP8, IBGP8, OSPF8, static, or whois8-validated);
- originates an IPv8 prefix via local configuration.

IS-IS8 routers receiving an LSP that already carries an IPv8
Reachability TLV from another IS-IS8 router MUST NOT add a
duplicate TLV under their own System ID. They install the carried
prefix in the unified Route8 table and rely on standard IS-IS
flooding to propagate the LSP further.

#### IS-IS8 CF Export TLV

IS-IS8 adds one new TLV for CF export (IANA type assignment
requested):

    TLV type:    [IANA assignment pending]
    TLV name:    IS-IS8 CF Export
    Content:
       Interface IPv8 address: 64-bit
       CF_contribution:        int32
       Link_Gbps:              uint16
       Session_uptime:         uint32
       Flags:                  CF_export_valid (bit 0)

The TLV carries identical semantic content to the OSPF8 Type 11
LSA defined in Section 10.3.3. Both implementations export to
IBGP8 using the same cf-range parameter and the same cost-to-CF
mapping defined in Section 10.2.

#### IS-IS8 Without CF Export

IS-IS8 instances that do not implement CF export receive the
neutral CF value of 2,147,483,648 at AS boundaries — the same
treatment as BGP4 paths. IS-IS8 without CF export is not
penalised. It simply does not contribute intra-zone measured
cost to the end-to-end CF accumulation.

IS-IS8 implementations SHOULD implement CF export. IS-IS8
implementations that do not implement CF export MUST declare
this via the IS-IS8 capability TLV so that IBGP8 redistributors
can apply the neutral CF value correctly.

#### Configuration

    router isis8
       cf-export enable
       cf-range +2000 -5000
       redistribute ibgp8 cf-import
       
    interface <n>
       isis8 metric <1-65535>
       isis8 cf-export enable

### Vendor IGP Extensions

Vendors MAY implement additional IGPs beyond OSPF8 and IS-IS8.
Vendor IGP implementations MUST implement the CF export interface
defined in Section 10.2 if running on an IPv8 network. Vendor
IGPs that do not implement CF export receive neutral CF treatment
per Section 10.4.4.

The address space reservations ff.ff.00.03 (EIGRP) and ff.ff.00.04
(RIP) are retained for vendor extensibility. These protocols are
deprecated in IPv8 but vendors MAY extend them with CF export
TLVs for environments where migration is not immediately possible.

---

## IPv8 Across IPv4 Networks

### Overview -- No Tunnels Required

IPv8 traverses IPv4-only networks without pre-configured tunnels.
The internet has operated for 40 years without an authoritative
real-time registry of active routes. WHOIS8 fixes this. The
anycast encapsulation model described in this section depends
on WHOIS8 as its reachability source of truth.

The canonical IPv8-in-IPv4 encapsulation rule -- including the
intra-AS case where the outer IPv4 destination is the BGP
next-hop loopback recorded in the Route8 table -- is specified
in [@SUPPORT8] Part III. This section addresses the inter-AS
case in detail: how a BGP8 router crosses an IPv4-only span to
reach a BGP8 router in a different ASN using the destination
ASN's WHOIS8 IPv4 anycast address as the outer IPv4 destination.

The key insight: a large service provider MAY leave their entire
IPv4 core unchanged for 20 years. IPv8 traffic traverses it
automatically. The only routers that need upgrading are the
BGP8 edge routers -- the ones that peer with other ASNs. Every
router in the IPv4 core between two BGP8 edge routers forwards
IPv8 traffic without any modification, without any configuration
change, and without any knowledge that IPv8 exists.

The per-hop anycast model requires no pre-configured tunnel
endpoints, no fixed paths, and no coordination between
operators. A large provider operating 100,000 BGP8-capable
peering points requires zero tunnel configuration on any
device.

### WHOIS8 IPv4 Anycast Reachability

Every ASN registered in WHOIS8 MUST include an IPv4 anycast
address. This address is advertised into the global BGP4 table
by every BGP8-capable edge router in that ASN. The BGP4 core
carries it as a normal IPv4 route with zero modification.

    WHOIS8 record for ASN 1100 includes:
       ipv4-anycast: 192.0.2.1

    All BGP8 edge routers in ASN 1100 advertise:
       192.0.2.1/32 into the surrounding BGP4 fabric

    BGP4 anycast routing delivers packets to the nearest
    BGP8 edge router in ASN 1100 automatically.

Large ASNs MAY advertise from many locations simultaneously.
BGP4 anycast naturally routes each packet to the nearest
decapsulation point. As more BGP8 edge routers come online
the anycast coverage improves automatically with no
coordination required.

    ASN 32934 (example) anycast 192.0.2.1 advertised from:
       New York, Los Angeles, London, Frankfurt,
       Tokyo, Singapore, Sao Paulo, Sydney ...

BGP4 routes each packet to the nearest instance. No
configuration required beyond the single WHOIS8 anycast field.

Large ASNs MAY additionally specify per-/16 anycast addresses
in their WHOIS8 record for traffic engineering to specific
address blocks:

    ipv4-anycast:        192.0.2.1     (default, whole ASN)
    ipv4-anycast-detail: 1100.31.0.0/16  192.0.2.5  (US East)
    ipv4-anycast-detail: 1100.157.0.0/16 192.0.2.6  (EU)

A BGP8 router sending to a specific /16 destination SHOULD
use the specific anycast address if present in WHOIS8. It
MUST fall back to the default ASN anycast if not.

### Per-Hop Encapsulation

When a BGP8 router must forward an IPv8 packet and the next
hop toward the destination ASN is an IPv4-only router, it
encapsulates the IPv8 packet in a standard IPv4 envelope:

    Outer IPv4 header:
       Source:      BGP8 router's IPv4 address
       Destination: destination ASN's WHOIS8 anycast address
       Protocol:    IPv8-in-IPv4 (IANA assignment requested)

    Inner payload: original IPv8 packet, unchanged

The IPv4-only routers in the core forward the outer IPv4
packet using normal BGP4/IS-IS/OSPF path selection toward
the anycast destination. They have no awareness of the IPv8
payload. When the packet reaches the nearest BGP8 edge router
for the destination ASN, that router decapsulates the IPv8
packet and forwards it natively.

Example with mixed IPv8/IPv4 path:

    R1[BGP8,ASN5060] --> R2[BGP4] --> R3[BGP4] --> R4[BGP8] --> R5[BGP8,ASN1100]
                      --> R2.A[BGP4] --> R3.A[BGP4] --> R4.A[BGP8] -^

    R1 wants to reach ASN 1100.
    R1 looks up ASN 1100 in WHOIS8 cache.
    Gets anycast address 192.0.2.1.
    Encapsulates IPv8 packet: outer dst = 192.0.2.1.
    Forwards to R2.

    R2 sees IPv4 dst 192.0.2.1.
    Looks up 192.0.2.1 in BGP4 table.
    Two equal paths: via R3, via R3.A.
    Picks best path -- say R3.A.
    Forwards normally. Zero IPv8 awareness.

    R3.A same. Pure IPv4 forwarding.

    R4.A is BGP8-capable. Receives packet.
    Sees IPv8-in-IPv4 protocol field.
    Decapsulates. Has original IPv8 packet.
    Destination is ASN 1100 -- local ASN.
    Forwards to R5 natively.

    R5 delivers to 1100.20.30.40.50.

All 8 available paths through the IPv4 core are available
to BGP4 path selection. The packet takes the best path
automatically. No tunnel state anywhere.

### BGP Routing Table and ASN Lookup

BGP stores next-hop information, not full paths. A BGP4
router forwarding toward the anycast address performs a
standard next-hop lookup:

    BGP4 table: 192.0.2.1/32 --> next-hop 203.0.113.5

That is the complete forwarding decision. The router sends
the encapsulated packet to 203.0.113.5. It does not know
or care what ASN is inside the envelope.

Full-table BGP4 routers in SP cores carry routes to every
announced prefix including the anycast addresses of all
BGP8-capable ASNs. Default-route routers forward toward
their upstream which eventually reaches a full-table router.
This is identical to how BGP4 operates today for any IPv4
destination.

IS-IS and OSPF cores forward the outer IPv4 packet using
their normal link-state path computation. Neither protocol
needs any modification. The anycast address is just another
IPv4 destination as far as any IGP is concerned.

### CF Behaviour on IPv4 Paths

An IPv4-only hop contributes a CF value of zero -- neither
a positive nor a negative weight -- unless an operator
explicitly assigns a CF policy weight via the economic
component. IPv4 hops are invisible to CF path optimisation
by default.

Native IPv8 paths with measured CF values are naturally
preferred by CF path selection over IPv4 paths which carry
no CF signal. This creates a gentle automatic incentive
for IPv8 adoption without any mandate or penalty:

    Native IPv8 path:   CF accumulates, measured, optimised
    IPv4 anycast path:  CF = 0 contribution from IPv4 hops

As IPv8 deployment grows, measured CF paths outperform
zero-CF paths naturally. No operator needs to configure
a penalty for IPv4 paths.

### WHOIS8 Bootstrap and Router Startup

A BGP8 router MUST connect to its WHOIS8 server and cache
the full ASN route table before accepting any BGP8 sessions.
No BGP8 route is installed without WHOIS8 validation.

    Router startup sequence:
       1. Connect to WHOIS8 server
       2. Pull full ASN table (all ASNs, prefixes,
          anycast addresses, change-grace timers)
       3. Cache locally in persistent memory
       4. Begin advertising anycast address into BGP4
       5. Accept BGP8 peer sessions
       6. Validate all received routes against cache
          before installation

The WHOIS8 cache persists across restarts. On restart the
router validates cached entries against the WHOIS8 server
and refreshes any that have changed before coming online.

Routes remain cached indefinitely while stable. When WHOIS8
detects a route change for an ASN it signals connected
BGP8 routers. The router holds the previous route for the
change-grace period (operator configured, default 12 hours)
before flushing it. This prevents a WHOIS8 update from
instantly dropping live traffic on a route in the middle
of a legitimate handoff or renumbering.

    Cache management:
       clear whois8 cache
       clear whois8 cache asn <asn>
       clear whois8 cache prefix <prefix>

On cache clear the router immediately reconnects to WHOIS8,
pulls a fresh table, revalidates all installed BGP8 routes,
and removes any that no longer validate. BGP8 sessions
remain up during the refresh. Only routes that fail
revalidation are withdrawn.

### WHOIS8 Push Invalidation

WHOIS8 servers maintain a persistent connection to all
connected BGP8 routers. When an RIR or ASN holder makes
a correction to a route record, the WHOIS8 server pushes
an invalidation message to all connected routers immediately:

    WHOIS8 --> BGP8 router:
       INVALIDATE ASN 1100 prefix 1100.31.0.0/16

    BGP8 router:
       Withdraws route immediately
       Generates NetLog8 SEC-ALERT
       Notifies BGP8 peers via normal BGP8 withdrawal

This real-time push invalidation is the mechanism that
makes route hijacking response practical. Under BGP4 a
hijacked route could persist for hours or days while
operators manually coordinated filter updates. Under BGP8
the RIR corrects the WHOIS8 record and every BGP8 router
in the world withdraws the hijacked route within seconds.

### Transition Incentive

The CF model creates automatic incentive for IPv8 adoption
without any mandate. IPv4 paths carry zero CF signal.
Native IPv8 paths accumulate measured CF and optimise
automatically. As BGP8 deployment grows, CF-optimised
paths naturally outperform zero-CF IPv4 paths. An IPv4
transit AS whose customers see traffic routed around them
via better-measured IPv8 paths experiences direct commercial
pressure to upgrade. No policy enforcement. Pure economic
signal.

---

## BGP4 Compatibility

BGP8 is incrementally deployable over existing BGP4
infrastructure. BGP8 capability is negotiated via Capabilities
Advertisement [@RFC5492]; sessions where BGP8 capability is not
successfully negotiated continue to operate as BGP4 sessions
with `asn-ibgp-path` Large Community [@RFC8092] preserving the
Route Number across the path. The two-format NLRI mechanism
specified in §[@nlri] permits BGP4-only iBGP transit to carry
IPv8 route information transparently.

## Relationship to IPv6

This document specifies routing-protocol behaviour for IPv8 over
IPv4 transport. IPv6 is out of scope.

---

## CF Anomaly Detection

NetLog8 CF-ANOMALY SEC-ALERT events MUST be generated when:

1. CF_measured < GEOGRAPHIC_COMPONENT
   (path faster than speed of light — physically impossible)

2. CF drops more than 50,000,000 in less than 60 seconds
   (sudden implausible improvement — possible CF injection)

3. Advertised CF differs from computed CF by more than
   100,000,000
   (peer advertising false CF)

~~~
{
  "class": "SEC-ALERT",
  "event": "CF-ANOMALY",
  "severity": 2,
  "peer_asn": "<asn>",
  "cf_advertised": 1000000000,
  "cf_computed": 2156759148,
  "cf_geographic_floor": 1831500,
  "delta": 1156759148,
  "reason": "implausible|injection|manipulation",
  "timestamp_us": "<timestamp>"
}
~~~

CF-ANOMALY events MUST trigger immediate trust state transition
per the CF Trust Verification section below. The combination of
single-event anomaly detection (this section) and longitudinal
trust assessment (next section) provides defence against both
single-advertisement gaming attempts and sustained low-grade
variance.

---

## CF Trust Verification (Sun Tzu) {#sun-tzu}

### Overview

CF advertisements from peers represent a peer's claimed
measurement of a path. A receiving BGP8 speaker MUST
independently verify these advertisements against its own TCP
session telemetry before accepting them into path selection.

The verification mechanism is named "Sun Tzu" after the principle
that adversarial behaviour MUST be assumed when designing
protocols at internet scale. Honest peers produce small variance
between advertised and computed CF; gaming peers produce large
variance. Trust accumulates through measured agreement over time
and degrades through observed dishonesty.

### Operating Modes {#sun-tzu-modes}

Sun Tzu MUST support three operating modes, selected per BGP8
speaker by configuration. The default mode is `warn`.

| Mode    | Scoring | Logging | Route Acceptance Effect          |
|---------|---------|---------|----------------------------------|
| off     | No      | No      | None — feature inactive          |
| warn    | Yes     | Yes     | None — state is informational    |
| enforce | Yes     | Yes     | Per Routing Behaviour by State   |

**`warn` (default).** Trust scoring runs and state transitions
are tracked exactly as specified in §Trust Score Calculation
and §State Transitions. NetLog8 events are emitted on every
transition per §NetLog8 Events. However, the routing behaviour
described in §Routing Behaviour by State is suppressed:
advertised CF is accepted for all neighbours regardless of
trust state, and routes are not rejected from BLOCKED
neighbours. The operator sees what Sun Tzu would do without
Sun Tzu actually doing it, building familiarity with the
mechanism and a baseline for their peer set before enforcement
is enabled.

**`enforce`.** Full mechanism active. State governs route
acceptance per §Routing Behaviour by State. This is the
adversarial-internet-scale posture and is the operationally
correct setting for any BGP8 speaker with public peering, but
operators MUST be familiar with the mechanism before enabling
it because PENALIZED and BLOCKED transitions cause routing
shifts that look like neighbour instability to operators who
do not know the feature exists.

**`off`.** Sun Tzu is fully disabled. No scoring, no state
tracking, no NetLog8 events from this mechanism. Advertised
CF is accepted from all neighbours as-is.

The default mode is `warn` rather than `enforce` to protect
operators who install BGP8 without reading the specification.
An operator who deploys a BGP8 speaker and observes peers
silently flapping between trust states (with traffic shifting
between paths as a consequence) is a known operational failure
mode for unattended security features; BFD aggressive mode and
UDLD aggressive mode have produced this exact pattern in the
field. Defaulting to `warn` ensures that the visible side of
Sun Tzu is operator-facing logging that prompts investigation,
not silent routing changes that prompt confusion.

The intended deployment trajectory is: install in `warn`,
review the trust scores and transition events over a baseline
period (typically 30 to 90 days, covering normal peer behaviour
and maintenance windows), and promote to `enforce` once the
operator has confidence that the peer set behaves within
expected variance bounds. Operators MAY choose to remain in
`warn` indefinitely if they prefer trust evaluation as
observability rather than as automatic policy.

### Trust States

Each BGP8 neighbour MUST maintain a trust state in one of four
values. The CF Acceptance column describes behaviour in
`enforce` mode; in `warn` mode advertised CF is accepted
regardless of state per §Operating Modes.

| State | Description | CF Acceptance (enforce mode) |
|-------|-------------|------------------------------|
| PROBATIONARY | New neighbour, insufficient history | Local CF only |
| VERIFIED | Established history, advertisements within bounds | Advertised CF accepted |
| PENALIZED | Detected gaming or persistent variance | Local CF only |
| BLOCKED | Repeated gaming or operator-applied | Routes rejected |

Default state on session establishment is PROBATIONARY. State
transitions are driven by ongoing variance measurement and
sliding-window trust score computation. Operators MAY override
state via configuration.

### Trust Score Calculation

For each CF advertisement received from a peer, the BGP8 speaker
computes:

1. **Advertised CF** — value from peer UPDATE message
2. **Local Calculated CF** — value computed from local TCP
   session telemetry per the TCP Session Telemetry section
3. **Variance** — absolute difference between advertised and
   local
4. **Variance ratio** — variance / local_calculated_CF

The trust score is computed as a sliding window over the previous
N measurements (default N = 100):

    trust_score = 100 - (mean(variance_ratio[last_N]) × 100)

A peer whose advertisements consistently match local computation
within small variance scores 95-100. A peer whose advertisements
diverge consistently scores progressively lower.

### State Transitions

PROBATIONARY → VERIFIED: After 50 advertisements (configurable)
with trust score above 80. The probationary period ensures
sufficient measurement history before granting trust.

VERIFIED → PENALIZED: Trust score drops below 60, OR a single
advertisement triggers CF-ANOMALY with delta exceeding
500,000,000.

PENALIZED → VERIFIED: Trust score recovers above 75 sustained
over the full window. Recovery is deliberately slower than
penalisation to discourage gaming-then-honest cycles.

PENALIZED → BLOCKED: Trust score drops below 30, OR three
CF-ANOMALY events within 24 hours, OR operator action.

BLOCKED → any state: Operator action only. BLOCKED state
persists across session resets and router reboots until
explicitly cleared.

### Routing Behaviour by State

The routing behaviour specified in this section applies when
the effective trust-mode for the neighbour is `enforce`. In
`warn` mode, advertised CF is accepted from all neighbours
regardless of trust state, and routes from BLOCKED neighbours
are not rejected; state is informational only. In `off` mode,
trust state is not maintained.

**PROBATIONARY**: Local Calculated CF is used for path selection.
The peer's advertised CF is logged for trust score calculation
but does not influence routing.

**VERIFIED**: Advertised CF is accepted into path selection.
Local computation continues for ongoing variance measurement.

**PENALIZED**: Local Calculated CF is used for path selection.
Advertised CF is recorded but not honoured. The peer's session
remains active and traffic continues to flow; only their
influence on routing decisions is suspended.

**BLOCKED**: Routes from this peer are rejected entirely. The
session is maintained for protocol hygiene but route
advertisements are not installed.

### Operational Visibility

BGP8 implementations MUST provide operational commands exposing
the trust state per neighbour. Reference command syntax (vendors
MAY adopt platform-appropriate variants):

    show bgp8 neighbor <addr> cf detail

Reference output:

```
Neighbor Address...... 203.0.113.1
Remote ASN............ 13335
Session State......... Established
Uptime................ 18d 04h 22m

Trust Mode............ warn (global: warn)
Advertised CF......... 2,081,440,000
Local Calculated CF... 2,094,180,000
Variance.............. +12,740,000

Trust Status.......... VERIFIED
Sun Tzu Score......... 94%

CF Components
---------------------------------
RTT Component......... +1,420,000
Loss Component........ +100,000
Congestion............ +2,000,000
Stability............. -180,000
Capacity.............. -200,000
Economic.............. +0
Geographic............ +5,040,000

Decision
---------------------------------
Accepted CF........... 2,094,180,000
Installed Paths....... Yes (1 of 4)
Rank.................. #2 Best Path
```

The Trust Mode line shows the effective mode for this
neighbour followed by the global mode in parentheses. When
the per-neighbour mode is `inherit`, both values match. The
Decision block reports what the speaker actually did with the
advertised CF; in `warn` mode this matches Advertised CF
regardless of trust state, in `enforce` mode it follows the
table in §Routing Behaviour by State.

Summary view across all neighbours:

    show bgp8 cf summary

```
Global trust-mode: warn

Neighbor          ASN     Mode      State          Score   Uptime
203.0.113.1       13335   inherit   VERIFIED       94%     18d
198.51.100.5      6695    inherit   VERIFIED       97%     142d
192.0.2.10        174     inherit   PROBATIONARY   --      0d 04h
192.0.2.20        7018    enforce   PENALIZED      52%     31d
192.0.2.30        9009    inherit   BLOCKED        18%     7d
```

### NetLog8 Events

Trust state transitions MUST generate NetLog8 events:

~~~
{
  "class": "SEC-ALERT",
  "event": "CF-TRUST-CHANGE",
  "severity": 2,
  "peer_asn": "<asn>",
  "peer_address": "<ip>",
  "previous_state": "VERIFIED",
  "new_state": "PENALIZED",
  "trust_score": 58,
  "trigger": "score_drop|anomaly|operator|timeout",
  "effective_mode": "warn|enforce",
  "would_affect_routing": true,
  "timestamp_us": "<timestamp>"
}
~~~

The `effective_mode` field records the trust-mode in effect for
the neighbour at the time of the transition. The
`would_affect_routing` field is `true` if the transition causes
a routing change under the §Routing Behaviour by State table.
In `warn` mode, `would_affect_routing` is `true` whenever the
transition would cause a change in `enforce` mode, allowing
operators to see in the log exactly what enforcement would do
without enforcement being active.

Transitions to PENALIZED or BLOCKED are severity 2 (Error).
Transitions to VERIFIED from PROBATIONARY or PENALIZED are
severity 4 (Warning). PROBATIONARY entry on session
establishment is severity 6 (Info) and MAY be filtered.

NetLog8 events for trust transitions MUST be emitted in both
`warn` and `enforce` modes. The operator-visible side of Sun
Tzu is identical in the two modes; only the routing-decision
side differs.

### Configuration

The operating mode is set globally per BGP8 speaker:

    bgp8 cf trust-mode { off | warn | enforce }   # default warn

Operators MAY override the mode for individual neighbours,
useful for piloting `enforce` against a single peer before
applying it globally:

    bgp8 cf neighbor <addr> trust-mode { off | warn | enforce | inherit }

The `inherit` value (default) means the neighbour follows the
global trust-mode setting. Explicit per-neighbour modes
override the global setting for that neighbour only.

Operators MAY adjust trust verification parameters. These
parameters affect score calculation and state transitions in
both `warn` and `enforce` modes; they have no effect in `off`
mode:

    bgp8 cf trust-window <count>             # default 100
    bgp8 cf probationary-threshold <count>   # default 50
    bgp8 cf verified-threshold <score>       # default 80
    bgp8 cf penalize-threshold <score>       # default 60
    bgp8 cf block-threshold <score>          # default 30
    bgp8 cf recovery-threshold <score>       # default 75
    bgp8 cf recovery-window <count>          # default 100

Operators MAY apply state directly. Forced states are applied
regardless of operating mode but only affect route acceptance
when the effective mode for the neighbour is `enforce`:

    bgp8 cf neighbor <addr> trust force-verified
    bgp8 cf neighbor <addr> trust force-penalized
    bgp8 cf neighbor <addr> trust force-blocked
    bgp8 cf neighbor <addr> trust clear

Forced states persist until cleared, returning the neighbour
to algorithmic state determination.

### Design Rationale

Trust verification is structural rather than optional in the
architectural sense: CF without verification reduces to BGP4
LOCAL_PREF with worse incentives, so the mechanism is
mandatory in the specification. CF MUST be verifiable to be
useful; verification MUST be ongoing because gaming behaviour
can emerge after honest periods; the response to detected
gaming MUST NOT break connectivity because peers may be
misconfigured rather than malicious.

The default operating mode is `warn` rather than `enforce`
because the failure mode of unattended security features
defaulting to active is well-attested in BGP operational
practice. BFD aggressive mode and UDLD aggressive mode have
both produced incidents in which operators installed software
containing the feature, did not read the release notes, and
subsequently spent significant time debugging "neighbour
flapping" that was in fact the safety mechanism working as
designed against marginal inputs. The lesson is that the
*specification* should mandate the mechanism but the
*default* should be observational, giving operators a chance
to learn the mechanism's behaviour against their actual peer
set before granting it authority over routing decisions.
Operators who understand Sun Tzu and want the protection
enable `enforce` deliberately; operators who do not yet
understand it see informative log events that prompt
investigation rather than silent routing changes that prompt
confusion.

The four-state model balances responsiveness against stability.
PROBATIONARY prevents new peers from immediately influencing
routing. VERIFIED is the steady state for honest operators.
PENALIZED protects the routing table while preserving
connectivity. BLOCKED is the rare measure for sustained or
operator-flagged abuse.

The Sun Tzu naming reflects the design principle: assume peers
may attempt deception, structure measurement to detect it,
respond proportionally. This is consistent with how BGP4 handles
route filtering, RPKI validation, and other security mechanisms
that assume adversarial behaviour at scale rather than relying
on universal good faith.

---

## Security Considerations

### Route Hijacking Prevention

WHOIS8 validation makes route hijacking architecturally difficult.
An attacker must compromise an RIR registry entry and produce a
validly signed WHOIS8 record. Combined with the grace period model
this represents a substantially higher attack surface than BGP4
hijacking which requires only announcing a prefix.

### BGP8 Session Security

BGP8 sessions MUST use TCP-AO [@RFC5925]. TCP MD5 [@RFC2385] MAY
be used for compatibility with legacy equipment during the
transition period but is NOT RECOMMENDED for new deployments.

### CF Manipulation

CF manipulation is detected and responded to through two
complementary mechanisms: the CF Anomaly Detection section
identifies single advertisements that are physically implausible
or grossly divergent from local measurement; the CF Trust
Verification (Sun Tzu) section assesses peer behaviour over time
through sliding-window variance measurement, transitioning peers
between PROBATIONARY, VERIFIED, PENALIZED, and BLOCKED states.

Together these mechanisms make sustained CF gaming detectable
and operationally costly. The geographic floor in CFv1 provides
a physics-based lower bound that cannot be spoofed without also
producing a physically impossible RTT measurement simultaneously.
The trust state machine ensures that even sub-anomaly variance
accumulates into trust score reduction over time, eventually
triggering PENALIZED state regardless of whether any individual
advertisement crossed the anomaly threshold.

### RINE Prefix Security

The 100.x.x.x RINE prefix MUST NOT appear in eBGP8
advertisements. Border routers MUST filter 100.x.x.x source
and destination addresses on non-peering interfaces. Packets
with 100.x.x.x r.r.r.r arriving on non-peering interfaces
MUST be dropped and logged via NetLog8 as SEC-ALERT.

### Interior Link Security

The n.n.n.n range 222.0.0.0/8 MUST NOT be advertised in eBGP8.
Border routers MUST filter received BGP8 advertisements containing
n.n.n.n addresses in 222.0.0.0/8. NetLog8 E3 trap MUST be
generated for each violation.

### Internal Zone Prefix Security

The 127.x.x.x internal zone prefix MUST NOT appear in eBGP8
advertisements. Border routers MUST filter 127.x.x.x on external
interfaces.

### /16 Minimum Prefix Enforcement {#min-prefix-enforcement-rp}

Received advertisements more specific than /16 from external
peers MUST be rejected and logged as SEC-ALERT. This prevents
deaggregation attacks and enforces the regional summarisation
model.

---

## IANA Considerations

- BGP capability code for BGP8 capability advertisement.
- BGP8 optional attribute type for BGP8-GEO geolocation.
- BGP8 optional transitive attribute type for 8TO4-ENDPOINT.
- BGP8 optional attribute type for CF version negotiation.
- CF version number registry.
- OSPF8 IPv8 Reachability Opaque LSA type assignment
  (Opaque Type within LSA Type 10 area-scope, per [@RFC5250]).
- OSPF8 Type 11 LSA opaque type assignment (per [@RFC5250]).
- IS-IS8 IPv8 Reachability TLV type assignment.
- IS-IS8 CF Export TLV type assignment.
- ff.ff.00.02 retained as BGP8 reserved multicast prefix.
- ff.ff.00.05 retained as IS-IS8 reserved multicast prefix.

### IPv8 AFI/SAFI for BGP

IANA is requested to allocate an Address Family Identifier
value for IPv8 in the registry "Address Family Numbers"
maintained per [@RFC4760]. The AFI value is referenced as
TBD-IPV8 throughout this document.

### asn-ibgp-path Large Community

IANA is requested to allocate a Global Administrator value
in the BGP Large Communities registry per [@RFC8092] for
the IPv8 working group. The community structure is:

    Global Administrator: TBD-IETF-IPV8
    Local Data 1:         8 (IPv8 path)
    Local Data 2:         32-bit ASN prefix value

Community name: `asn-ibgp-path`

Scope: iBGP only by protocol specification. BGP8
implementations MUST strip this community on eBGP
advertisements by default.

### OSPF8 IPv8 Reachability Opaque LSA

IANA is requested to allocate an Opaque Type value within the
OSPF Opaque LSA Type registry per [@RFC5250] for the IPv8
Reachability Opaque LSA (area-scope, LSA Type 10). The Opaque
Type value is referenced as TBD-IPV8-REACH-OSPF throughout this
document.

Scope: area-local. OSPF-only routers within the area MUST
flood the LSA per standard opaque-LSA flooding rules and MUST
NOT install the carried prefix in their forwarding table.

### IS-IS8 IPv8 Reachability TLV

IANA is requested to allocate a TLV type value within the
IS-IS TLV registry for the IS-IS8 IPv8 Reachability TLV. The
TLV type value is referenced as TBD-IPV8-REACH-ISIS
throughout this document.

Scope: per-level. IS-IS-only routers within the level MUST
flood LSPs carrying this TLV per standard IS-IS unknown-TLV
handling and MUST NOT install the carried prefix in their
forwarding table.

---


{backmatter}

<reference anchor="RFC2119" target="https://www.rfc-editor.org/info/rfc2119">
  <front><title>Key words for use in RFCs to Indicate Requirement Levels</title>
  <author initials="S." surname="Bradner" fullname="S. Bradner"/>
  <date year="1997" month="March"/></front>
  <seriesInfo name="BCP" value="14"/><seriesInfo name="RFC" value="2119"/>
</reference>
<reference anchor="RFC8174" target="https://www.rfc-editor.org/info/rfc8174">
  <front><title>Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words</title>
  <author initials="B." surname="Leiba" fullname="B. Leiba"/>
  <date year="2017" month="May"/></front>
  <seriesInfo name="BCP" value="14"/><seriesInfo name="RFC" value="8174"/>
</reference>
<reference anchor="RFC8092" target="https://www.rfc-editor.org/info/rfc8092">
  <front><title>BGP Large Communities Attribute</title>
  <author initials="J." surname="Heitz" fullname="J. Heitz"/>
  <date year="2017" month="February"/></front>
  <seriesInfo name="RFC" value="8092"/>
</reference>
<reference anchor="RFC2328" target="https://www.rfc-editor.org/info/rfc2328">
  <front><title>OSPF Version 2</title>
  <author initials="J." surname="Moy" fullname="J. Moy"/>
  <date year="1998" month="April"/></front>
  <seriesInfo name="STD" value="54"/><seriesInfo name="RFC" value="2328"/>
</reference>
<reference anchor="RFC1997" target="https://www.rfc-editor.org/info/rfc1997">
  <front><title>BGP Communities Attribute</title>
  <author initials="R." surname="Chandra" fullname="R. Chandra"/>
  <date year="1996" month="August"/></front>
  <seriesInfo name="RFC" value="1997"/>
</reference>
<reference anchor="RFC4271" target="https://www.rfc-editor.org/info/rfc4271">
  <front><title>A Border Gateway Protocol 4 (BGP-4)</title>
  <author initials="Y." surname="Rekhter" fullname="Y. Rekhter"/>
  <date year="2006" month="January"/></front>
  <seriesInfo name="RFC" value="4271"/>
</reference>
<reference anchor="RFC4364" target="https://www.rfc-editor.org/info/rfc4364">
  <front><title>BGP/MPLS IP Virtual Private Networks (VPNs)</title>
  <author initials="E." surname="Rosen"/>
  <date year="2006" month="February"/></front>
  <seriesInfo name="RFC" value="4364"/>
</reference>
<reference anchor="RFC2385" target="https://www.rfc-editor.org/info/rfc2385">
  <front><title>Protection of BGP Sessions via the TCP MD5 Signature Option</title>
  <author initials="A." surname="Heffernan"/>
  <date year="1998" month="August"/></front>
  <seriesInfo name="RFC" value="2385"/>
</reference>
<reference anchor="RFC5305" target="https://www.rfc-editor.org/info/rfc5305">
  <front><title>IS-IS Extensions for Traffic Engineering</title>
  <author initials="T." surname="Li"/>
  <date year="2008" month="October"/></front>
  <seriesInfo name="RFC" value="5305"/>
</reference>
<reference anchor="RFC4456" target="https://www.rfc-editor.org/info/rfc4456">
  <front><title>BGP Route Reflection</title>
  <author initials="T." surname="Bates" fullname="T. Bates"/>
  <date year="2006" month="April"/></front>
  <seriesInfo name="RFC" value="4456"/>
</reference>
<reference anchor="RFC4760" target="https://www.rfc-editor.org/info/rfc4760">
  <front><title>Multiprotocol Extensions for BGP-4</title>
  <author initials="T." surname="Bates" fullname="T. Bates"/>
  <date year="2007" month="January"/></front>
  <seriesInfo name="RFC" value="4760"/>
</reference>
<reference anchor="RFC5250" target="https://www.rfc-editor.org/info/rfc5250">
  <front><title>The OSPF Opaque LSA Option</title>
  <author initials="L." surname="Berger" fullname="L. Berger"/>
  <date year="2008" month="July"/></front>
  <seriesInfo name="RFC" value="5250"/>
</reference>
<reference anchor="RFC5492" target="https://www.rfc-editor.org/info/rfc5492">
  <front><title>Capabilities Advertisement with BGP-4</title>
  <author initials="J." surname="Scudder" fullname="J. Scudder"/>
  <date year="2009" month="February"/></front>
  <seriesInfo name="RFC" value="5492"/>
</reference>
<reference anchor="RFC5925" target="https://www.rfc-editor.org/info/rfc5925">
  <front><title>The TCP Authentication Option</title>
  <author initials="J." surname="Touch" fullname="J. Touch"/>
  <date year="2010" month="June"/></front>
  <seriesInfo name="RFC" value="5925"/>
</reference>
<reference anchor="RFC6793" target="https://www.rfc-editor.org/info/rfc6793">
  <front><title>BGP Support for Four-Octet AS Number Space</title>
  <author initials="Q." surname="Vohra" fullname="Q. Vohra"/>
  <date year="2012" month="December"/></front>
  <seriesInfo name="RFC" value="6793"/>
</reference>
<reference anchor="ISO10589">
  <front><title>Intermediate System to Intermediate System Intra-Domain Routing Protocol</title>
  <author><organization>ISO</organization></author>
  <date year="2002"/></front>
  <seriesInfo name="ISO/IEC" value="10589:2002"/>
</reference>
<reference anchor="IPv8">
  <front><title>Internet Protocol Version 8</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-ipv8-04"/>
</reference>
<reference anchor="IPV8">
  <front><title>Internet Protocol Version 8 (IPv8)</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-ipv8-04"/>
</reference>
<reference anchor="RINE">
  <front><title>Regional Inter-Network Exchange</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-rine-00"/>
</reference>
<reference anchor="WHOIS8">
  <front><title>WHOIS8 Protocol and Trust Bootstrap</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-whois8-00"/>
</reference>
<reference anchor="SUPPORT8">
  <front><title>IPv8 Support Protocols: ARP8, ICMPv8, Route8, and ACL8</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-support8-00"/>
</reference>
<reference anchor="NETLOG8">
  <front><title>NetLog8 Protocol</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-netlog8-00"/>
</reference>
<reference anchor="ZONESERVER">
  <front><title>IPv8 Zone Server Architecture</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-zoneserver-00"/>
</reference>
<reference anchor="MIB">
  <front><title>IPv8 Management Information Base and SNMPv8 Protocol</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-ipv8-mib-00"/>
</reference>
<reference anchor="UPDATE8">
  <front><title>Update8 Protocol</title>
  <author initials="J." surname="Thain" fullname="Jamie Thain"/>
  <date year="2026" month="April"/></front>
  <seriesInfo name="Internet-Draft" value="draft-thain-update8-00"/>
</reference>
