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

## Validation Steps

1. **Eos Nomad (free):** Install on Mac, enable OSC, connect SDK's OscClient, verify `/eos/get/version` returns a response. Kill Nomad → verify heartbeat detects offline within `missedThreshold * interval` seconds.

2. **MA3 onPC (free):** Install on Windows VM or Mac (if available), enable OSC, test empty command and Companion Plugin heartbeat. Determine which approach is reliable.

3. **MagicQ PC (free with limitations):** Install, enable OSC (requires Unlocked Mode with hardware), test playback level query. If no hardware available, defer MQ heartbeat to when we have a dongle.

4. **Loopback test (no console):** Write a test that starts a mock OSC responder on localhost, sends heartbeat, verifies online/offline transitions. This can validate the pipeline without real console software.

---

## What This Unblocks

Once protocol heartbeat is validated:
- Health monitoring works on broadcast-filtered networks
- Health monitoring works with manual setup (no ArtPoll)
- Failover can be promoted from "experimental" to "production-ready"
- Console status indicator in ShowUp's top bar is trustworthy
