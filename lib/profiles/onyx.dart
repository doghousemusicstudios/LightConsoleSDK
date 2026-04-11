import '../models/console_profile.dart';

/// Obsidian Onyx (formerly Martin M-Series) console profile.
///
/// Onyx's primary integration path is the Telnet API on port 2323
/// via Onyx Manager. This provides direct cuelist control (GQL, GTQ,
/// SQL) with no 10-fader limit, plus cuelist name import (QLList)
/// and active state polling (QLActive).
///
/// OSC (via ShowCockpit driver) and MIDI Show Control are secondary
/// protocols with more limited capabilities.
const onyxProfile = ConsoleProfile(
  id: 'onyx',
  displayName: 'Obsidian Onyx',
  manufacturer: 'Obsidian Control Systems',
  preferredProtocol: ConsoleProtocol.telnet,
  // Telnet port for Onyx Manager. OSC uses a separate, user-configured port.
  oscPort: null,
  oscPatterns: ConsoleOscPatterns(
    // OSC patterns via ShowCockpit — secondary path, limited to 10 faders.
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
    namePatterns: [
      'onyx', 'obsidian', 'nx4', 'nx2', 'nx1', 'nx wing',
      'm-series', 'm-play', 'm-touch',
    ],
    estaCodes: [0x4F42], // 'OB'
  ),
  defaultSacnPriority: 50,
  heartbeat: HeartbeatConfig(
    strategy: HeartbeatStrategy.telnetPoll,
    port: 2323,
  ),
);

/// Default Telnet port for Onyx Manager.
const onyxTelnetPort = 2323;
