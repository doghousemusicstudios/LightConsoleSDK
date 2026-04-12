import '../models/console_profile.dart';

/// GrandMA2 (MA Lighting) console profile.
///
/// MA2 uses a Telnet CLI on port 30000 (with a read-only monitor on 30001)
/// as its primary external control interface. Unlike MA3, MA2 has NO
/// native OSC support — OSC requires a third-party plugin (OSC_Mate).
///
/// MA2 is still widely deployed in churches, theaters, corporate venues,
/// and touring. The Command Wing + onPC is one of the most common mid-market
/// setups. MA2 onPC remains available as free software.
///
/// Key differences from MA3:
/// - Telnet (port 30000) instead of OSC
/// - Login required (username/password)
/// - Full command-line access via Telnet
/// - WebSocket on port 8080 (community-documented)
/// - No OSC without third-party plugin
///
/// Console models: Full Size, Light, Ultra-Light, Command Wing, Fader Wing.
const grandMa2Profile = ConsoleProfile(
  id: 'grandma2',
  displayName: 'GrandMA2',
  manufacturer: 'MA Lighting',
  preferredProtocol: ConsoleProtocol.telnet,
  // No native OSC. Telnet on port 30000 is the primary protocol.
  oscPort: null,
  oscPatterns: null,
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    useMsc: false, // MA2 uses MIDI notes, not MSC
    mscDeviceId: 1,
    mscCommandFormat: 0x01,
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x0001, 0x0D14], // MA Lighting OEM codes (shared with MA3)
    namePatterns: ['grandma2', 'gma2', 'ma2'],
    estaCodes: [0x4D41], // 'MA' in ASCII
  ),
  defaultSacnPriority: 50,
  heartbeat: HeartbeatConfig(
    strategy: HeartbeatStrategy.httpGet,
    port: 8080,
    httpPath: '/',
  ),
);

/// Default Telnet port for GrandMA2.
const grandMa2TelnetPort = 30000;

/// GrandMA2 Telnet command reference.
///
/// MA2 Telnet accepts any command-line instruction. Login is required
/// before commands are accepted. Commands are case-sensitive.
///
/// Common commands for ShowUp integration:
/// ```
/// login <username>           — authenticate (required first)
/// Goto Cue 3                 — fire cue 3 on default executor
/// Goto Cue 3 Executor 1.1   — fire cue 3 on specific executor
/// Go+                        — advance to next cue
/// Go-                        — go back one cue
/// Off Executor 1.1           — release executor
/// BlackOut                   — toggle blackout
/// Master 50                  — set grand master to 50%
/// Macro 1                    — fire macro 1
/// Clear                      — clear programmer
/// ```
///
/// Telnet also supports reading state:
/// ```
/// List Cue 1                 — list cues in cue list 1
/// Info Session               — session information
/// ```
abstract class GrandMa2Commands {
  static const login = 'login';
  static const gotoCue = 'Goto Cue';
  static const goNext = 'Go+';
  static const goBack = 'Go-';
  static const offExecutor = 'Off Executor';
  static const blackout = 'BlackOut';
  static const master = 'Master';
  static const macro = 'Macro';
  static const clear = 'Clear';
  static const listCue = 'List Cue';
}
