# Risks & Mitigations

**Every known risk in connecting ShowUp to a lighting console, and exactly how the SDK handles each one.**

---

## Risk Severity Levels

| Level | Meaning | Example |
|-------|---------|---------|
| **Critical** | Could disrupt a live show | Fixtures flicker, wrong universe takes over, emergency lights override |
| **High** | Silent failure, hard to debug | Connection drops with no error, multicast not delivered, OSC commands ignored |
| **Medium** | Visible issue, user can recover | Wrong universe assignment, Telnet disconnect, fader feedback delayed |
| **Low** | Cosmetic or documentation issue | Universe numbering confusion, console name mismatch |

---

## Critical Risks

### RISK-01: sACN Priority Outputs Zeros — Causes Blackout on Console Fixtures

**Severity:** Critical
**What happens:** sACN priority is all-or-nothing per universe. If ShowUp outputs a full 512-channel frame at priority 50 with zeros on channels it doesn't control, those zeros beat the console's output at priority 49 on a receiver that only looks at priority. Fixtures on channels ShowUp doesn't "own" go dark.

**SDK mitigation — SOLVED IN CODE:**

```dart
/// SacnTransport only outputs channels that have patched ShowUp fixtures.
/// Channels without patched fixtures are excluded from the sACN packet
/// by setting propertyValueCount to cover only the occupied range,
/// or by using per-channel masking.
///
/// Three strategies available (configurable per universe):
///
/// 1. RangeOnly — output startChannel to lastChannel, fill gaps with
///    passthrough from DMX input (if available) or HTP merge
/// 2. SparseOutput — only output channels with patched fixtures,
///    use sACN's per-property addressing (E1.31 §6.2.6)
/// 3. FullFrame — output all 512 channels (ONLY for ShowUp-owned
///    universes where no console traffic exists)
class SacnChannelStrategy { ... }
```

Additionally:
- ShowUp-owned universes use `FullFrame` (normal behavior)
- Console-owned universes use `NoOutput` (ShowUp never sends)
- Shared universes use `RangeOnly` with passthrough — ShowUp only touches its own fixture channels
- The DmxEngine's `_tick()` loop checks `universeRoles` before calling `transport.sendUniverse()`

**Residual risk:** None if implemented correctly. Unit tests verify that console-owned channels never receive ShowUp output.

---

### RISK-04: Failover False Positives — ShowUp Takes Over During a Cable Jiggle

**Severity:** Critical
**What happens:** A brief network hiccup (WiFi dropout, cable reseated, switch reboot) causes ShowUp to think the console is offline. If failover is enabled, ShowUp takes over console universes and applies fallback looks. When the console returns 3 seconds later, there's a visible "jump" on stage. During a wedding first dance or concert climax, this could be catastrophic.

**SDK mitigation — SOLVED IN CODE:**

```dart
class FailoverConfig {
  /// Failover is OFF by default. Must be explicitly enabled.
  bool enabled = false;

  /// Number of consecutive missed heartbeats before failover triggers.
  /// At 1Hz polling, 15 = 15 seconds of silence before takeover.
  int missedHeartbeatsThreshold = 15;

  /// When true, ShowUp shows a notification asking the operator to confirm
  /// before taking over. Adds human judgment to the decision.
  bool requireConfirmation = true;

  /// Fade-in duration when ShowUp takes over (avoids hard snap).
  Duration fadeInDuration = Duration(seconds: 3);

  /// Fade-out duration when console returns (avoids hard snap back).
  Duration fadeOutDuration = Duration(seconds: 2);

  /// What ShowUp outputs on takeover. NEVER defaults to blackout.
  FailoverLook fallbackLook = FailoverLook.lastCapturedState;
}

enum FailoverLook {
  /// Replay the last DMX snapshot captured from the console.
  /// Safest option — maintains whatever was on stage.
  lastCapturedState,

  /// Fade to a warm ambient wash. Safe, non-disruptive.
  ambientWarm,

  /// Fade to a specific captured look (user-selected).
  specificLook,

  /// Blackout — WARNING shown in UI. Never the default.
  /// "Blackout during an event could be a safety risk.
  ///  People could trip or fall in darkness."
  blackout,
}
```

- **Strobe is not an option.** It is not in the `FailoverLook` enum. You cannot select strobe as a failover look.
- If the user selects `blackout`, the UI shows a persistent warning banner.
- `requireConfirmation = true` by default means the operator always has a chance to say "no, the console is fine, the cable just jiggled."
- Fade in/out prevents the visual "snap" that makes failover obvious to the audience.

**Residual risk:** If `requireConfirmation` is disabled and the timeout is set very low, false positives can still occur. The SDK defaults prevent this, but a user who changes both settings is accepting the risk.

---

### RISK-13: Emergency Lighting Interference

**Severity:** Critical
**What happens:** In professional venues, emergency lighting (exit signs, aisle lights, blue work lights) often runs on DMX universe 1. If ShowUp accidentally outputs to that universe, it could override emergency lighting — which is a fire code violation in most jurisdictions.

**SDK mitigation — SOLVED IN CODE:**

```dart
class UniverseRoleConfig {
  /// Channels that ShowUp will NEVER output to, regardless of
  /// universe role. These are absolute — no override possible.
  /// Populated during setup when ShowUp detects active traffic
  /// on channels commonly used for emergency/safety lighting.
  List<ProtectedChannel> protectedChannels = [];

  /// Universe roles default to consoleOwned for ANY universe
  /// with detected sACN/Art-Net traffic during setup.
  /// User must explicitly change a universe to "showup" or "shared."
  UniverseRole defaultForActiveUniverse = UniverseRole.consoleOwned;
}

class ProtectedChannel {
  final int universe;
  final int startChannel;
  final int endChannel;
  final String reason; // "Detected active traffic during setup"
}
```

- During the setup wizard, ShowUp sniffs sACN/Art-Net for 5 seconds to detect which universes have active traffic.
- ALL universes with detected traffic default to `consoleOwned`.
- The user must explicitly tap a universe tile to change it — no auto-assignment to ShowUp-owned for active universes.
- `protectedChannels` is a hard block enforced in `DmxEngine._tick()` — even if a bug elsewhere tries to output to these channels, the engine blocks it.

**Residual risk:** If a venue adds emergency lighting AFTER ShowUp was configured, the protection won't cover the new channels. The "Re-scan Network" button in Stage Setup re-runs detection.

---

### RISK-14: Blackout as Failover = Safety Hazard

**Severity:** Critical
**What happens:** If ShowUp's failover fires a blackout on a packed dance floor, people could trip and fall. If it fires during a concert, the audience panics.

**SDK mitigation — SOLVED IN CODE:**

- Failover fallback defaults to `lastCapturedState` (see RISK-04 above)
- Strobe is blocked as a failover option entirely (not in the enum)
- Blackout selection triggers a UI warning
- Failover fades in over 3 seconds (never a hard snap to dark)

**Residual risk:** None for default settings. User must actively override multiple safety defaults to create a dangerous configuration.

---

## High Risks

### RISK-02: MA3 OSC Stops Working After Show Load

**Severity:** High
**What happens:** After loading a show file on GrandMA3 (documented in v2.2.5.2+), OSC stops sending and receiving entirely until the network session is restarted. ShowUp's connection silently dies. Commands go into the void. No error is returned.

**SDK mitigation — SOLVED IN CODE:**

```dart
class ConsoleHeartbeat {
  /// Sends a non-destructive ping every [interval].
  /// MA3: /gma3/cmd,s,"" (empty command, no-op)
  /// Eos: /eos/get/version (returns version string)
  /// MQ: /ch/playback/1/level (returns current level)
  /// Onyx: QLActive\r\n (returns active cuelists)
  final Duration interval = Duration(seconds: 5);

  /// Number of missed pongs before declaring console offline.
  int missedThreshold = 3;

  /// Emitted states:
  /// connected → degraded (1 miss) → offline (3 misses) → reconnecting
  Stream<ConsoleConnectionState> get stateStream => ...;
}
```

- For MA3 specifically, when `offline` state is reached, the SDK surfaces: **"Console stopped responding. You may need to restart the OSC session on your GrandMA3 (Setup > Network > Protocols > restart session)."**
- The heartbeat is protocol-specific — OSC for MA3/Eos/MQ, Telnet for Onyx.
- State transitions are smooth: `connected → degraded → offline`. The UI shows a yellow dot for degraded, red for offline.

**Residual risk:** The user must restart OSC on the console manually. ShowUp cannot fix MA3's bug, but detects it within 15 seconds instead of the operator noticing minutes later when a cue doesn't fire.

---

### RISK-05: IGMP Snooping Mismatch — Multicast Silently Fails

**Severity:** High
**What happens:** sACN uses multicast. If the venue switch has IGMP snooping enabled without a proper querier, multicast packets are silently dropped. ShowUp appears connected (TCP/unicast works fine) but no sACN data reaches fixtures. This is invisible to the user and extremely hard to debug.

**SDK mitigation — PARTIALLY SOLVED IN CODE:**

```dart
class NetworkDiagnostic {
  /// Tests multicast delivery by sending a test sACN packet on a
  /// reserved universe (64000) and listening for its own multicast
  /// loopback. If the packet doesn't arrive within 2 seconds,
  /// multicast is likely blocked.
  Future<DiagnosticResult> testMulticast();

  /// Tests unicast UDP delivery to the console's IP.
  Future<DiagnosticResult> testUnicast(String consoleIp);

  /// Tests Art-Net broadcast delivery.
  Future<DiagnosticResult> testArtNetBroadcast();

  /// Tests TCP connectivity (for Eos OSC and Onyx Telnet).
  Future<DiagnosticResult> testTcpConnect(String ip, int port);

  /// Tests ArtPoll response from the console.
  Future<DiagnosticResult> testArtPollResponse(String consoleIp);

  /// Runs all relevant tests and returns a summary.
  Future<NetworkDiagnosticReport> runAll(ConsoleProfile profile);
}

class DiagnosticResult {
  final bool passed;
  final String testName;
  final String? failureReason;
  final String? suggestion; // "Enable IGMP querier on your switch"
  final Duration latency;
}
```

- The network diagnostic runs automatically between Discovery and Mode Selection in the wizard.
- If multicast fails but unicast works, ShowUp suggests: "Your switch may have IGMP snooping enabled. Try disabling it, or switch ShowUp to unicast sACN mode."
- The SDK supports unicast sACN as a fallback (direct IP targeting instead of multicast groups).

**Residual risk:** ShowUp can detect the problem and suggest fixes, but cannot configure the venue's network switch. The diagnostic gives the user clear, actionable information.

---

### RISK-07: Art-Net Broadcast Storm Above 15 Universes

**Severity:** High
**What happens:** Art-Net broadcast mode sends every packet to every device on the network. Above ~15 universes, cheap Art-Net nodes can't decode fast enough, causing frame drops, lag, and erratic fixture behavior. On WiFi, this threshold is even lower (~4 universes).

**SDK mitigation — SOLVED IN CODE:**

```dart
class ArtNetOutputConfig {
  /// Default: unicast to specific node IPs discovered via ArtPoll.
  /// Broadcast mode must be explicitly enabled.
  ArtNetMode mode = ArtNetMode.unicast;

  /// If broadcast is selected and universe count exceeds this,
  /// show a warning in the UI.
  int broadcastWarningThreshold = 8;

  /// Hard cap on broadcast universes. Above this, ShowUp refuses
  /// to broadcast and falls back to unicast automatically.
  int broadcastMaxUniverses = 16;

  /// WiFi detection: if ShowUp is on WiFi, lower the warning
  /// threshold to 4 and suggest unicast or wired connection.
  bool wifiDetected = false;
}
```

- Art-Net defaults to unicast (direct to discovered node IPs)
- If the user enables broadcast with >8 universes, a warning appears
- If on WiFi, ShowUp warns: "Art-Net broadcast over WiFi is unreliable above 4 universes. Use a wired connection or unicast mode."
- Above 16 universes in broadcast mode, ShowUp auto-switches to unicast

**Residual risk:** None for default settings. User must explicitly enable broadcast mode.

---

### RISK-17: OSC UDP Packet Loss — Cue Trigger Doesn't Fire

**Severity:** High
**What happens:** UDP doesn't guarantee delivery. On a congested network, an OSC cue trigger could be dropped. The console never fires the cue. ShowUp doesn't know it failed. The show falls out of sync.

**SDK mitigation — SOLVED IN CODE:**

```dart
class OscReliability {
  /// For critical commands (cue fires, blackout, release all),
  /// send the packet multiple times with spacing.
  /// Console-side deduplication is natural — firing an already-
  /// active cue is a no-op on all consoles.
  int criticalCommandRepeat = 3;
  Duration criticalCommandSpacing = Duration(milliseconds: 10);

  /// For non-critical commands (fader adjustments, status queries),
  /// send once. Loss is tolerable — next tick corrects it.
  int normalCommandRepeat = 1;

  /// For ETC Eos: prefer TCP over UDP. TCP eliminates packet loss.
  /// SDK auto-selects TCP when Eos is detected.
  bool preferTcp = true;
}
```

- Critical commands (cue fire, blackout, release) are sent 3x with 10ms spacing
- All consoles handle duplicate cue fires gracefully (idempotent)
- For Eos, TCP is the default — eliminates the problem entirely
- For MA3 and MQ (UDP only), the triple-send is the mitigation
- For Onyx, Telnet (TCP) is the primary protocol — no UDP loss

**Residual risk:** In extreme network congestion, even 3 UDP packets could all be lost. This is unlikely in practice — lighting networks are typically dedicated and low-traffic.

---

### RISK-08: Art-Net Universe Offset (0 vs 1 Indexing)

**Severity:** High (causes wrong-universe output)
**What happens:** Art-Net uses 0-indexed universes (Art-Net Universe 0 = DMX Universe 1). sACN uses 1-indexed. ShowUp's internal buffers use 0-indexed arrays. If any conversion is wrong, fixtures on Universe 2 get Universe 1's data or vice versa.

**SDK mitigation — SOLVED IN CODE:**

```dart
/// Single source of truth for universe addressing.
/// Stores the canonical 1-indexed DMX universe number internally.
/// All display and wire-protocol conversions go through explicit methods.
class UniverseAddress {
  /// The canonical universe number (1-indexed, DMX convention).
  /// This is what the user sees in the UI.
  final int dmxUniverse;

  const UniverseAddress(this.dmxUniverse)
      : assert(dmxUniverse >= 1 && dmxUniverse <= 63999);

  /// Convert to Art-Net wire format (0-indexed).
  /// Art-Net Universe 0 = DMX Universe 1.
  int get artNet => dmxUniverse - 1;

  /// Convert to sACN wire format (1-indexed, same as DMX).
  int get sacn => dmxUniverse;

  /// Convert to internal buffer index (0-indexed array).
  int get bufferIndex => dmxUniverse - 1;

  /// Convert to sACN multicast address.
  /// 239.255.{high}.{low} where universe is 1-indexed.
  InternetAddress get sacnMulticast {
    final high = (dmxUniverse >> 8) & 0xFF;
    final low = dmxUniverse & 0xFF;
    return InternetAddress('239.255.$high.$low');
  }
}
```

- ALL universe references in the SDK use `UniverseAddress`, never raw `int`
- The UI always shows `dmxUniverse` (1-indexed)
- Art-Net packets always use `.artNet` (0-indexed)
- sACN packets always use `.sacn` (1-indexed)
- Buffer indexing always uses `.bufferIndex` (0-indexed)
- Compile-time type safety — you can't accidentally pass a raw int where a `UniverseAddress` is expected

**Residual risk:** None. The type system prevents the bug.

---

### RISK-15: sACN Universe Numbering Mismatch

**Severity:** High
**What happens:** Same root cause as RISK-08 but specific to sACN. Off-by-one bugs in sACN universe numbering cause universe 2 data to appear on universe 1 or vice versa.

**SDK mitigation — SOLVED IN CODE:**

Same `UniverseAddress` type as RISK-08. The `.sacn` getter returns 1-indexed values directly. The sACN multicast group calculation uses the correct 1-indexed universe number.

**Residual risk:** None. Solved by the same type-safe approach.

---

## Medium Risks

### RISK-09: Professional LD Resistance to Unknown Apps on Their Network

**Severity:** Medium
**What happens:** A touring LD walks into a venue, sees an unknown device broadcasting ArtPoll on "their" lighting network, and is not happy. They may demand it be removed, creating conflict with the venue operator who relies on ShowUp for ambient lighting.

**SDK mitigation — SOLVED IN CODE:**

```dart
class StealthMode {
  /// When true, ShowUp goes completely silent on the network:
  /// - No ArtPoll broadcasts
  /// - No sACN output
  /// - No OSC pings or heartbeats
  /// - No console detection
  /// ShowUp only listens (sACN input for monitoring is still possible).
  bool enabled = false;

  /// Stealth mode can be toggled from:
  /// - Status bar console indicator (long-press)
  /// - Stage Setup > Coexistence > Stealth Mode toggle
  /// - Quick Actions in Perform
}
```

- When stealth mode is on, ShowUp produces zero network traffic related to lighting
- ShowUp can still LISTEN (sACN input for monitoring/capture) since listening doesn't produce packets
- The LD's console sees no unknown devices
- Venue operator can re-enable coexistence after the touring LD departs

**Residual risk:** Social/political — the LD may still object to any device on the network, even passive ones. This is a human problem, not a technical one. ShowUp's ArtPoll response should include a clear device name ("ShowUp Ambient Controller") so the LD knows what it is if they do see it.

---

### RISK-10: Multiple Consoles on the Same Network

**Severity:** Medium
**What happens:** A venue has a ChamSys for house lights AND a touring MA3 for stage. ShowUp's wizard assumes one console. Discovery finds two.

**SDK mitigation — SOLVED IN CODE:**

```dart
class ConsoleDetector {
  /// Returns ALL detected consoles, not just the first one.
  Stream<List<DetectedConsole>> get detectedConsoles => ...;

  /// The setup wizard shows a picker if >1 console is found:
  /// "We found 2 consoles on your network. Which one should
  ///  ShowUp work with?"
  /// Future: support simultaneous coexistence with multiple consoles
  /// (e.g., ShowUp triggers house ChamSys AND stage MA3 from the
  /// same moment activation).
}
```

- Discovery returns a list, not a single result
- Wizard shows a console picker if >1 found
- Each detected console shows: name, IP, active universes, OEM code
- V1: single console coexistence. V2: multi-console with per-console trigger bindings

**Residual risk:** V1 only supports one console at a time. If the user needs to control both, they'd need to pick one. Multi-console support is a V2 feature.

---

### RISK-11: Console Firmware Updates Breaking OSC APIs

**Severity:** Medium
**What happens:** MA2→MA3 killed the Telnet API. Eos occasionally changes OSC addresses. ChamSys changes behavior between versions. An OSC command that worked yesterday stops working after a firmware update.

**SDK mitigation — PARTIALLY SOLVED IN CODE:**

```dart
class ConsoleProfile {
  /// Minimum firmware version this profile was tested against.
  String? minFirmware;

  /// OSC address variants by firmware version range.
  /// If ShowUp detects a different version, it can select
  /// the appropriate address pattern.
  Map<String, OscAddressSet>? firmwareVariants;

  /// Whether this profile is user-editable.
  /// Users can modify OSC addresses if the console's API changes
  /// before ShowUp releases an update.
  bool userEditable = true;

  /// Community profile registry URL (future).
  /// Users can download updated profiles without an app update.
  String? communityRegistryUrl;
}
```

- Console profiles are editable — if an OSC address changes, the user can fix it immediately without waiting for an app update
- Profiles include firmware version metadata
- Version detection: ShowUp queries the console's version on connection (Eos: `/eos/get/version`, MA3: via ArtPoll longName, Onyx: Telnet response)
- If a known version mismatch is detected, ShowUp can select alternate address patterns
- Future: community profile registry so users share profile fixes

**Residual risk:** A breaking firmware change with no alternate address pattern requires either a user edit or an app update. The user-editable profiles mitigate the urgency.

---

### RISK-16: Telnet Connection Stability (Onyx)

**Severity:** Medium
**What happens:** Telnet is a stateful TCP connection. If the connection drops silently (no FIN packet — just a dead socket), ShowUp won't know until the next command times out (which could be 30+ seconds with default TCP timeout).

**SDK mitigation — SOLVED IN CODE:**

```dart
class TelnetClient {
  /// TCP keepalive probes detect dead connections within seconds
  /// instead of waiting for the default TCP timeout.
  bool tcpKeepalive = true;
  Duration keepaliveInterval = Duration(seconds: 5);

  /// Automatic reconnection with exponential backoff.
  Duration initialReconnectDelay = Duration(seconds: 1);
  Duration maxReconnectDelay = Duration(seconds: 30);
  double backoffMultiplier = 2.0;

  /// Connection state stream for UI feedback.
  Stream<TelnetConnectionState> get stateStream => ...;

  /// On reconnect: re-run QLList to refresh cuelist state,
  /// then resume QLActive polling.
  Future<void> onReconnected() async {
    await loadCuelists();
    startActivePolling();
  }
}
```

- TCP keepalive detects dead connections within ~15 seconds
- Auto-reconnection with backoff prevents connection storms
- UI shows "Reconnecting..." during recovery
- On reconnect, the SDK re-syncs cuelist state automatically

**Residual risk:** None for the SDK. If Onyx Manager itself crashes, the Telnet API is unavailable until Manager restarts. ShowUp surfaces this clearly: "Onyx Manager connection lost."

---

## Low Risks

### RISK-03: ShowUp 44Hz vs Console Variable DMX Rate

**Severity:** Low
**What happens:** ShowUp sends DMX at 44Hz. The console may send at 30Hz, 40Hz, or 44Hz. When both hit the same sACN receiver, the receiver sees interleaved frames from two sources at different rates. Most receivers handle this fine via priority-based selection. Cheap receivers may flicker.

**SDK mitigation:** Not solvable in code. Documented.

**Documentation guidance:**
> ShowUp outputs sACN at 44Hz. If you experience flickering on shared universes, ensure your sACN receivers support multi-source input. Most professional receivers (ETC Net3, Pathport, Luminex) handle this correctly. Consumer-grade receivers (some Chinese Art-Net nodes) may not.

---

### RISK-06: Energy Efficient Ethernet (EEE) Causes Frame Drops

**Severity:** Low
**What happens:** Consumer/prosumer switches with EEE enabled put ports to sleep during quiet periods, missing the first packets when traffic resumes. This causes visible flicker on startup or after idle.

**SDK mitigation:** Not solvable in code. Documented.

**Documentation guidance:**
> Disable Energy Efficient Ethernet (EEE) on your network switch. Also called "Green Ethernet" or "IEEE 802.3az." This feature saves power by sleeping switch ports during quiet periods, which drops DMX frames. Most managed switches have an option to disable EEE per port. Unmanaged switches may have it enabled with no way to turn it off.

---

### RISK-12: Venue IT Policies Block Required Ports

**Severity:** Low (detectable)
**What happens:** Corporate venues, convention centers, and some churches have managed networks that block UDP, non-standard ports, or multicast traffic. ShowUp's sACN, Art-Net, and OSC connections fail silently.

**SDK mitigation — PARTIALLY SOLVED IN CODE:**

```dart
/// NetworkDiagnostic (see RISK-05) tests all required ports
/// and protocols before the wizard proceeds.
///
/// If a test fails, the diagnostic explains exactly what's blocked:
/// - "UDP port 6454 (Art-Net) is blocked. Ask your IT admin to allow it."
/// - "Multicast traffic is blocked. Switch to unicast mode."
/// - "TCP port 2323 (Onyx Telnet) is unreachable."
///
/// The diagnostic can be re-run from Stage Setup > Network Diagnostics.
```

**Residual risk:** ShowUp can detect the problem but can't fix the venue's network policy. The diagnostic gives the user clear information to share with IT.

---

## Mitigation Architecture Summary

### SDK Safety Layers (Defense in Depth)

```
Layer 1: UniverseAddress type safety
  └─ Prevents indexing bugs at compile time (RISK-08, RISK-15)

Layer 2: Universe role enforcement in DmxEngine
  └─ Console-owned universes never receive ShowUp output (RISK-01, RISK-13)
  └─ Protected channels are hard-blocked (RISK-13)

Layer 3: sACN channel strategy
  └─ Shared universes only output patched fixture channels (RISK-01)

Layer 4: Heartbeat monitoring
  └─ Detects console dropout within 15 seconds (RISK-02, RISK-16)
  └─ Protocol-specific pings for each console family

Layer 5: Failover safety defaults
  └─ Disabled by default, requires confirmation, never strobes (RISK-04, RISK-14)
  └─ Fade transitions prevent visual snaps

Layer 6: Network diagnostics
  └─ Multicast, unicast, TCP, ArtPoll tests (RISK-05, RISK-12)
  └─ Run before wizard proceeds

Layer 7: OSC reliability
  └─ Critical commands sent 3x, TCP preferred for Eos (RISK-17)

Layer 8: Stealth mode
  └─ Zero network output when touring LD is present (RISK-09)

Layer 9: Art-Net output controls
  └─ Unicast default, broadcast warnings and caps (RISK-07)
```

### What the SDK Cannot Solve

| Risk | Why | What We Do Instead |
|------|-----|-------------------|
| RISK-03 (DMX rate mismatch) | Console's output rate is not controllable by ShowUp | Document receiver requirements |
| RISK-06 (EEE on switches) | Hardware setting on the switch, not the console or ShowUp | Document how to disable EEE |
| RISK-11 (firmware breaking APIs) | Console manufacturers control their APIs | User-editable profiles + version detection |
| RISK-12 (venue IT policies) | Network configuration is outside ShowUp's control | Diagnostic tool with clear error messages |
