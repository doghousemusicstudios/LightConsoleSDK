import '../models/console_profile.dart';

/// ETC Eos / Ion / Element / ColorSource console profile.
///
/// Validated on ETC Eos Nomad (localhost, 2026-04-11):
/// - TCP SLIP on port 3037 (third-party OSC) — full bidirectional
/// - Eos pushes /eos/out/user at ~10Hz on TCP connect
/// - Port 3032 (native) does not respond to third-party connections
/// - UDP does not work for Eos third-party OSC
const etcEosProfile = ConsoleProfile(
  id: 'eos',
  displayName: 'ETC Eos Family',
  manufacturer: 'ETC',
  preferredProtocol: ConsoleProtocol.osc,
  oscPort: 3037, // Third-party OSC (TCP SLIP). Native 3032 is for ETC apps.
  oscPatterns: ConsoleOscPatterns(
    fireCue: '/eos/cue/{cueList}/{cue}/fire',
    setFader: '/eos/fader/1/{fader}',
    firePlayback: '/eos/sub/{pb}',
    fireMacro: '/eos/macro/{macro}/fire',
    sendCommand: '/eos/cmd',
    goBack: '/eos/cue/{cueList}/back',
    releasePlayback: '/eos/sub/{pb}',
    cueViaCommand: false,
  ),
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    useMsc: true,
    mscDeviceId: 1,
    mscCommandFormat: 0x01,
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x0068, 0x6574], // ETC OEM codes
    namePatterns: ['eos', 'ion', 'element', 'colorsource', 'etc '],
    estaCodes: [0x4554], // 'ET' in ASCII
  ),
  defaultSacnPriority: 50,
  heartbeat: HeartbeatConfig(
    strategy: HeartbeatStrategy.tcpPushStream,
    port: 3037,
    streamPrefix: '/eos/out/',
  ),
);

/// Eos requires TCP SLIP transport, not UDP.
/// Use OscTransport.tcpSlip when connecting.
const eosOscTransport = 'tcpSlip';
