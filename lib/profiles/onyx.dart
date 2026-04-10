import '../models/console_profile.dart';

/// Obsidian Onyx (formerly Martin M-Series) console profile.
///
/// Onyx uses a clean, cuelist-based OSC API. Each cuelist has
/// Go/Level/Release commands. MIDI is also well-supported.
const onyxProfile = ConsoleProfile(
  id: 'onyx',
  displayName: 'Obsidian Onyx',
  manufacturer: 'Obsidian Control Systems',
  preferredProtocol: ConsoleProtocol.osc,
  oscPort: 2323,
  oscPatterns: ConsoleOscPatterns(
    fireCue: '/Mx/Cuelist/{cueList}/Go',
    setFader: '/Mx/Cuelist/{cueList}/Level',
    firePlayback: '/Mx/Cuelist/{pb}/Go',
    fireMacro: '/Mx/Macro/{macro}/Go',
    sendCommand: '/Mx/Cmd',
    goBack: '/Mx/Cuelist/{cueList}/Back',
    releasePlayback: '/Mx/Cuelist/{pb}/Release',
    cueViaCommand: false,
  ),
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    fireCueNote: 0,
    faderCc: 0,
    useMsc: true,
    mscDeviceId: 1,
    mscCommandFormat: 0x01,
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x4F62], // 'Ob' for Obsidian
    namePatterns: ['onyx', 'obsidian', 'nx4', 'nx2', 'nx1', 'nx wing', 'm-series', 'm-play', 'm-touch'],
    estaCodes: [0x4F42], // 'OB'
  ),
  defaultSacnPriority: 50,
);
