import '../models/console_profile.dart';

/// ChamSys MagicQ console profile.
///
/// MagicQ uses playback-centric OSC addressing where each playback
/// has go/release/level commands. The OSC API is straightforward
/// and well-suited to ShowUp's trigger model.
const chamsysMqProfile = ConsoleProfile(
  id: 'chamsys_mq',
  displayName: 'ChamSys MagicQ',
  manufacturer: 'ChamSys',
  preferredProtocol: ConsoleProtocol.osc,
  oscPort: 6553,
  oscPatterns: ConsoleOscPatterns(
    fireCue: '/ch/playback/{pb}/go',
    setFader: '/ch/playback/{pb}/level',
    firePlayback: '/ch/playback/{pb}/go',
    fireMacro: '/ch/macro/{macro}/go',
    sendCommand: '/ch/cmd',
    goBack: '/ch/playback/{pb}/back',
    releasePlayback: '/ch/playback/{pb}/release',
    cueViaCommand: false,
  ),
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    fireCueNote: 1,
    faderCc: 1,
    useMsc: true,
    mscDeviceId: 0,
    mscCommandFormat: 0x01,
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x4368], // 'Ch' in ASCII-ish
    namePatterns: ['chamsys', 'magicq', 'magic q', 'mq500', 'mq250', 'mq80', 'mq70', 'mq60', 'mq40'],
    estaCodes: [0x4348], // 'CH'
  ),
  defaultSacnPriority: 50,
);
