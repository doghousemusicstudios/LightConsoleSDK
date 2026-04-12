import '../models/console_profile.dart';

/// GrandMA3 (MA Lighting) console profile.
///
/// The MA3 uses a command-based OSC API where most operations are sent
/// as text commands to `/gma3/cmd`. Faders and keys have direct addresses
/// on `/gma3/Page{page}/Fader{fader}` and `/gma3/Page{page}/Key{key}`.
const grandMa3Profile = ConsoleProfile(
  id: 'grandma3',
  displayName: 'GrandMA3',
  manufacturer: 'MA Lighting',
  preferredProtocol: ConsoleProtocol.osc,
  oscPort: 8000,
  oscPatterns: ConsoleOscPatterns(
    // MA3 fires cues via text command: "Go+ Cue {cue}"
    fireCue: '/gma3/cmd',
    cueViaCommand: true,
    setFader: '/gma3/Page{page}/Fader{fader}',
    firePlayback: '/gma3/Page{page}/Key{key}',
    fireMacro: '/gma3/cmd', // body: "Macro {macro}"
    sendCommand: '/gma3/cmd',
    goBack: '/gma3/cmd', // body: "GoBack Cue {cue}"
    releasePlayback: '/gma3/cmd', // body: "Off Executor {pb}"
  ),
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    useMsc: true,
    mscDeviceId: 1,
    mscCommandFormat: 0x01, // lighting.general
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x0001, 0x0D14], // MA Lighting OEM codes
    namePatterns: ['grandma3', 'gma3', 'ma3', 'ma lighting'],
    estaCodes: [0x4D41], // 'MA' in ASCII
  ),
  defaultSacnPriority: 50,
  heartbeat: HeartbeatConfig(
    strategy: HeartbeatStrategy.httpGet,
    port: 8080,
    httpPath: '/',
  ),
);
