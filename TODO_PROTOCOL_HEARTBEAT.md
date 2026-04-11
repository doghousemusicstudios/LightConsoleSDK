# Protocol-Level Heartbeat — Implementation Status

**Status:** Implemented and validated for all 4 console families.
**Remaining:** ShowUp app integration (wiring ProtocolHeartbeat into app providers).

---

## Implementation Summary

`ProtocolHeartbeat` in `lib/health/protocol_heartbeat.dart` implements validated, console-specific heartbeat strategies:

- **Eos:** TCP SLIP push stream on port 3037. Eos sends `/eos/out/user` at ~10Hz on connect. Requires at least one push packet before reporting online (prevents false positive if OSC TX is disabled).
- **MA3:** HTTP GET on port 8080. MA3's web remote returns HTTP 200 when alive. No OSC config needed.
- **MQ:** TCP connect on port 4914. Connection accepted = alive. Requires "Enable remote control" in MQ settings.
- **Onyx:** TCP Telnet on port 2323. Connection state is the signal; QLActive sent as keep-alive.

`ConsoleOscService.connect()` auto-selects TCP SLIP for Eos and UDP for others based on the profile's heartbeat strategy. Tests in `console_osc_service_test.dart` prove the transport selection via a recording mock.

`ProtocolHeartbeat.fromFailoverConfig()` wires `FailoverConfig.timeoutSeconds` to heartbeat interval and missedThreshold.

### SDK Files

| File | What It Does |
|------|-------------|
| `lib/health/protocol_heartbeat.dart` | Per-strategy probe logic (push stream, HTTP, TCP connect, Telnet) |
| `lib/models/console_profile.dart` | `HeartbeatConfig` + `HeartbeatStrategy` enum |
| `lib/output/osc_client.dart` | UDP + TCP SLIP transport modes |
| `lib/output/console_osc_service.dart` | Auto-selects transport from profile |
| `lib/profiles/etc_eos.dart` | `tcpPushStream` on 3037, `streamPrefix: '/eos/out/'` |
| `lib/profiles/grandma3.dart` | `httpGet` on 8080 |
| `lib/profiles/chamsys_mq.dart` | `tcpConnect` on 4914 |
| `lib/profiles/onyx.dart` | `telnetPoll` on 2323 |

### Test Coverage

| Test File | Tests | Coverage |
|-----------|:-----:|---------|
| `protocol_heartbeat_test.dart` | 15 | Strategy construction, fromFailoverConfig timing, tcpConnect offline detection, event stream wiring |
| `console_osc_service_test.dart` | 9 | Transport selection via recording mock (tcpSlip for Eos, udp for others, explicit override) |
| `health_monitor_stream_test.dart` | 8 | fromStream isOnline tracking, uptime, event relay |
| `health_failover_test.dart` | 17 | Full FailoverService with requireConfirmation, fade timing |

---

## Validated Results (2026-04-11, on this Mac)

### ETC Eos Nomad

- **Port 3037** (Third-Party OSC) with **TCP SLIP** encoding works
- Port 3032 (native) does not respond to third-party connections
- UDP does not work on any port — Eos requires TCP for third-party OSC
- Eos pushes `/eos/out/user` at ~10Hz as soon as a TCP client connects — no query needed
- Eos Show Control > OSC TX must be enabled

### GrandMA3 onPC

- MA3 receives and executes OSC commands (fader moved on `/gma3/Page1/Fader201`)
- MA3 does NOT send any OSC responses to any query — confirmed with 8 different address patterns
- OSC Echo pattern (`/gma3/cmd "Echo 'heartbeat'"`) — no response even with Send Command = Yes
- TCP on ports 9000, 8000, 9001 — all refused. MA3 onPC (Mac) does not expose TCP OSC.
- **HTTP Web Remote on port 8080 — returns HTTP 200.** No OSC config needed.
- MA3's "Port" field is the port it listens on. Conflicted with localhost when set to 8000 (MA3 bound `*:8000`). Changed to 9000 — works.
- MA3 requires an active network session for OSC processing.
- MA3's Destination IP must NOT be 127.0.0.1 — use the machine's LAN IP.
- Companion Plugin remains valuable for fader feedback/cue state but is NOT required for heartbeat.

### ChamSys MagicQ PC

- TCP port 4914 accepts connections when "Enable remote control" and "Enable remote access" are both Yes in Setup > Net.
- No HTTP web server on any port — MagicQ PC does not expose HTTP.
- CREP on UDP 6553 does not respond in Demo Mode.
- OSC requires hardware dongle for Unlocked Mode.
- MagicQ closes TCP after receiving an unrecognized command, but the handshake succeeding is sufficient.

### Heartbeat Configuration Summary

| Console | Strategy | Port | Validated | Plugin/Dongle? |
|---------|----------|:----:|:---------:|:--------------:|
| **ETC Eos** | TCP SLIP push stream | 3037 | Yes | No |
| **GrandMA3** | HTTP GET | 8080 | Yes | No |
| **ChamSys MQ** | TCP connect | 4914 | Yes | No |
| **Onyx** | TCP Telnet | 2323 | Implemented | No (Onyx Manager only) |

---

## Remaining: ShowUp App Integration

The SDK heartbeat is complete. ShowUp needs to:

1. Instantiate `ProtocolHeartbeat` from the active `ConsoleProfile.heartbeat` config
2. Wire `ProtocolHeartbeat.events` to `ConsoleHealthMonitor.fromStream()`
3. Wire `ConsoleHealthMonitor` to `FailoverService`
4. Surface `monitor.isOnline` in the console status indicator (top bar dot)
5. Use `ConsoleOscService.connect()` instead of raw `OscClient.connect()` (auto-selects transport)

All of this is provider wiring in `lights_providers.dart` — no SDK changes needed.

---

## Probe Scripts (tool/)

Retained for re-testing against firmware updates:

| Script | Console | What It Tests |
|--------|---------|---------------|
| `eos_heartbeat_probe.dart` | Eos | TCP length-prefix on 3032 (failed) |
| `eos_heartbeat_probe2.dart` | Eos | All framing modes — discovered TCP SLIP on 3037 works |
| `ma3_heartbeat_probe.dart` | MA3 | UDP OSC queries (no responses) |
| `ma3_fader_test.dart` | MA3 | Fader movement (confirmed commands arrive) |
| `ma3_echo_and_http_probe.dart` | MA3 | Echo pattern (failed) + HTTP 8080 (success) |
| `ma3_tcp_probe.dart` | MA3 | TCP on 9000/8000/9001 (all refused) |
| `mq_heartbeat_probe.dart` | MQ | HTTP + CREP (both failed in Demo Mode) |
| `mq_tcp_probe.dart` | MQ | TCP 4914 (success) + UDP ports |
