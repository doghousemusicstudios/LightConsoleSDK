# TODO: Protocol-Level Heartbeat for OSC Consoles

**Priority:** High (required before shipping health/failover as a safety feature)
**Estimated effort:** 2-3 hours implementation + testing
**Depends on:** MA3 onPC and/or Eos Nomad running for validation

---

## Current State

`ProtocolHeartbeat` exists in `lib/health/protocol_heartbeat.dart` and works for Telnet (Onyx) because TCP connection state is meaningful. For OSC consoles (MA3, Eos, MQ), it currently just checks `OscClient.isConnected`, which only tells us the local UDP socket is open — not that the console is receiving.

UDP is connectionless. A "connected" OSC client can be sending into the void if the console has gone offline, changed IP, or stopped its OSC session. The heartbeat needs to send an actual query and listen for a response.

---

## What Needs to Change

### 1. Add heartbeat fields to ConsoleProfile (~10 lines)

In `lib/models/console_profile.dart`:

```dart
class ConsoleProfile {
  // ... existing fields ...

  /// OSC address to send as a heartbeat ping.
  /// Must be a non-destructive query that the console responds to.
  final String? heartbeatAddress;

  /// Expected response address prefix to confirm the console is alive.
  /// If null, any response on the incoming stream counts as alive.
  final String? heartbeatResponsePrefix;
}
```

### 2. Per-console heartbeat configuration

| Console | Heartbeat Query | Expected Response | Notes |
|---------|----------------|-------------------|-------|
| **ETC Eos** | `/eos/get/version` | `/eos/out/get/version` | Best — returns version string reliably |
| **GrandMA3** | `/gma3/cmd,s,""` | Any response on `/gma3/` | Empty command is a no-op; MA3 may not respond. Alternative: check if `/gma3/Page1/Fader201` returns a value via Companion Plugin |
| **ChamSys MQ** | `/ch/playback/1/level` | Response with level value | Returns current level; lightweight |
| **Onyx** | N/A (Telnet `QLActive`) | TCP response | Already working via TelnetClient |

### 3. Implement real _pingOsc() (~30 lines)

In `lib/health/protocol_heartbeat.dart`, replace the current stub:

```dart
Future<bool> _pingOsc() async {
  if (_oscClient == null || !_oscClient.isConnected) return false;
  if (_heartbeatAddress == null) return _oscClient.isConnected; // fallback

  // Send the heartbeat query
  _oscClient.send(_heartbeatAddress);

  // Wait for any response within timeout
  try {
    final response = await _oscClient.messages
        .where((msg) => _heartbeatResponsePrefix == null ||
            msg.address.startsWith(_heartbeatResponsePrefix))
        .first
        .timeout(timeout);
    return true; // got a response
  } on TimeoutException {
    return false; // no response within timeout
  }
}
```

### 4. Update built-in profiles

In `lib/profiles/etc_eos.dart`:
```dart
heartbeatAddress: '/eos/get/version',
heartbeatResponsePrefix: '/eos/out/',
```

In `lib/profiles/grandma3.dart`:
```dart
// MA3's response behavior is less reliable for heartbeat.
// With Companion Plugin: poll /showup/heartbeat
// Without plugin: fall back to isConnected check
heartbeatAddress: null, // TODO: test with MA3 onPC
```

In `lib/profiles/chamsys_mq.dart`:
```dart
heartbeatAddress: '/ch/playback/1/level',
heartbeatResponsePrefix: null, // any response counts
```

---

## Validated Results (2026-04-11)

### ETC Eos Nomad — VALIDATED on localhost

- **Port 3037** (Third-Party OSC) with **TCP SLIP** encoding works perfectly
- Port 3032 (native) does not respond to third-party connections
- UDP does not work on any port — Eos requires TCP for third-party OSC
- **Eos pushes `/eos/out/user` at ~10Hz as soon as a TCP client connects** — no query needed
- Heartbeat strategy: connect TCP SLIP on 3037, listen for any `/eos/out/` message. If stream stops → offline.
- This is a **push-based heartbeat** — superior to query/response because there's no round-trip latency to manage
- Eos Show Control > OSC TX must be enabled

### GrandMA3 onPC — VALIDATED on localhost

- MA3 **receives and executes OSC commands** (fader moved on `/gma3/Page1/Fader201`)
- MA3 **does NOT send any OSC responses** to any query — confirmed with 8 different address patterns
- Port configuration: MA3's "Port" field is the port it **listens on** (not sends to). Conflicted with localhost when set to 8000 (MA3 bound `*:8000`). Changed to 9000 — works.
- TCP tested on ports 9000, 8000, 9001 — all refused. MA3 onPC (Mac) does not expose a TCP OSC listener.
- OSC Echo pattern (`/gma3/cmd "Echo 'heartbeat'"`) — no response even with Send Command = Yes.
- **HTTP Web Remote on port 8080 — WORKS.** `GET http://10.0.0.134:8080` returns HTTP 200 with HTML body.
  No OSC config needed, no Companion Plugin needed, no session-specific settings.
  This is the MA3 heartbeat: HTTP 200 = alive, connection refused/timeout = offline.
- Companion Plugin remains valuable for fader feedback and cue state, but is NOT required for heartbeat.
- **MA3 requires an active network session** for OSC to work. No session = no OSC processing.
- MA3's Destination IP in OSC config must NOT be 127.0.0.1 — use the machine's LAN IP (e.g., 10.0.0.134)

### Updated Heartbeat Configuration

| Console | Protocol | Port | Framing | Heartbeat Method | Confidence |
|---------|----------|------|---------|-----------------|:----------:|
| **ETC Eos** | TCP | 3037 | SLIP | **Push-based:** listen for `/eos/out/` stream. No query needed. | **High** |
| **GrandMA3** | HTTP | 8080 | HTTP GET | **Web Remote ping:** `GET http://<ip>:8080` → HTTP 200 = alive. No OSC config needed. | **Validated** |
| **ChamSys MQ** | UDP | user-set | Raw | Untested. Query `/ch/playback/1/level` — needs hardware dongle. | **Unknown** |
| **Onyx** | TCP | 2323 | Telnet | **TCP connection state + QLActive polling.** Already implemented. | **High** |

---

## Single-Machine Validation Plan

Most of this can be validated on a single Mac without buying hardware or setting up a second machine.

### What runs on the same Mac as ShowUp

| Console Software | macOS? | Cost | Network Setup | Heartbeat Testable? |
|-----------------|:------:|------|---------------|:-------------------:|
| **ETC Eos Nomad** | Yes | Free | `127.0.0.1:3032` (TCP) | **Yes — best target** |
| **MA3 onPC** | Yes | Free | Use LAN IP, not 127.0.0.1 (MA3 blocks localhost OSC port) | **Yes — with workaround** |
| **MagicQ PC** | Yes | Free download, but OSC needs ChamSys hardware dongle (~$100) | `127.0.0.1:user-port` | **Only with dongle** |
| **Onyx** | No (Windows only) | Free | Needs Windows VM (Parallels/UTM) + bridged network | **Only with VM** |

### Phase A: Eos on localhost (30 min, zero cost)

This is the fastest path to a validated heartbeat and should be done first.

```
1. Download ETC Eos Nomad from etcconnect.com (free, macOS)
2. Launch Eos, create new show
3. Enable OSC: Setup > Show Control > OSC
   - OSC RX: enabled
   - OSC TX: enabled
   - Third-Party OSC port: 3037 (or use native 3032)
4. In the SDK test:
   a. Connect OscClient to 127.0.0.1:3032 (TCP)
   b. Send /eos/get/version
   c. Listen for /eos/out/get/version response
   d. Verify response arrives within 1 second
5. Test offline detection:
   a. Quit Eos Nomad
   b. Verify heartbeat detects offline within missedThreshold * interval
   c. Relaunch Eos
   d. Verify heartbeat detects reconnected
6. Record: exact response format, latency, any quirks
```

**What this proves:** Full query/response heartbeat cycle for the richest OSC console. If this works, the heartbeat pipeline is validated end-to-end.

### Phase B: MA3 on localhost (45 min, zero cost)

```
1. Download MA3 onPC from malighting.com (free, macOS)
2. Launch MA3 onPC, create new session
3. Enable OSC: Setup > Network > Protocols
   - Add OSC "In & Out" configuration
   - Set destination IP to the Mac's LAN IP (e.g., 192.168.1.x)
   - Do NOT use 127.0.0.1 (MA3 blocks the port on localhost)
   - Note the TX/RX ports
4. In the SDK test:
   a. Connect OscClient to the Mac's LAN IP on the configured port
   b. Send /gma3/cmd "" (empty command, no-op)
   c. Listen for any /gma3/ response
   d. Check: does MA3 respond to empty commands?
5. If no response to empty command:
   a. Try: /gma3/Page1/Fader201 (fader query)
   b. Try: install Companion Plugin, send /showup/heartbeat
   c. Determine which approach gets a response
6. Test offline detection:
   a. Quit MA3 or disable the OSC session
   b. Verify heartbeat detects offline
7. Record: which query works, response format, latency
```

**What this proves:** Whether MA3 responds to any OSC query at all, and which address to use for heartbeat. This is the biggest unknown — MA3's OSC feedback is sequence-level, not query/response, so the heartbeat address might need to be Companion Plugin-specific.

### Phase C: MagicQ with dongle (30 min, ~$100 if no dongle)

**Skip this phase if no ChamSys hardware is available.** MQ heartbeat can be deferred.

```
1. Install MagicQ PC (free, macOS)
2. Connect ChamSys dongle (Mini Connect, Compact Connect, etc.)
3. Enable OSC: Setup > View Settings > Network > OSC TX/RX ports
4. Send /ch/playback/1/level, listen for response
5. Test offline detection
```

### Phase D: Onyx on Windows VM (1 hour, zero cost if VM available)

**Skip this phase initially.** Onyx Telnet heartbeat already works via TCP connection state. This is for validating the full QLActive polling path.

```
1. Install Windows VM (Parallels, UTM, or real Windows machine)
2. Install Onyx (free, 1 universe)
3. Install Onyx Manager, enable Telnet Server
4. Bridge VM network to Mac's LAN
5. Connect TelnetClient from Mac to VM's IP:2323
6. Send QLActive, verify response
7. Test offline: stop Onyx Manager, verify TCP disconnect detected
```

### Recommended Order

```
Phase A (Eos)  →  takes 30 min, validates the full pipeline
Phase B (MA3)  →  takes 45 min, resolves the biggest unknown
Phase C (MQ)   →  only if you have a dongle
Phase D (Onyx) →  only if you need to validate Telnet beyond connection state
```

After Phase A alone, the heartbeat can ship for Eos with confidence. MA3 needs Phase B to determine the right query address. MQ and Onyx can defer.

---

## Loopback Integration Test (no console software needed)

Even before installing any console software, we can validate the heartbeat pipeline with a mock OSC responder on localhost:

```dart
test('heartbeat detects online/offline via OSC query/response', () async {
  // Start a mock OSC "console" on localhost that responds to queries
  final mockConsole = await RawDatagramSocket.bind('127.0.0.1', 0);
  final mockPort = mockConsole.port;

  // Configure mock to respond to any OSC query with a version response
  mockConsole.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = mockConsole.receive();
      // Echo back a response
      final response = OscClient.encodeOscMessage(
        OscMessage(address: '/eos/out/get/version', args: ['3.4.2']),
      );
      mockConsole.send(response, datagram!.address, datagram.port);
    }
  });

  // Connect the SDK's heartbeat to the mock
  final oscClient = OscClient();
  await oscClient.connect('127.0.0.1', mockPort);
  final heartbeat = ProtocolHeartbeat(
    oscClient: oscClient,
    protocol: ConsoleProtocol.osc,
    interval: Duration(milliseconds: 200),
    missedThreshold: 2,
  );

  // Verify online detection
  heartbeat.start();
  await Future.delayed(Duration(milliseconds: 500));
  expect(heartbeat.isOnline, isTrue);

  // Kill the mock → verify offline detection
  mockConsole.close();
  await Future.delayed(Duration(seconds: 2));
  expect(heartbeat.isOnline, isFalse);

  heartbeat.dispose();
  oscClient.dispose();
});
```

This test validates the full pipeline (send query → receive response → track state → detect timeout) without any console software installed. It can run in CI.

---

## What This Unblocks

Once protocol heartbeat is validated:
- Health monitoring works on broadcast-filtered networks
- Health monitoring works with manual setup (no ArtPoll)
- Failover can be promoted from "experimental" to "production-ready"
- Console status indicator in ShowUp's top bar is trustworthy
