import '../models/console_profile.dart';

/// ETC Eos / Ion / Element / ColorSource console profile.
///
/// ETC consoles have a well-documented, address-based OSC API where each
/// command has a dedicated address path. This makes Eos one of the easiest
/// consoles to integrate with via OSC.
const etcEosProfile = ConsoleProfile(
  id: 'eos',
  displayName: 'ETC Eos Family',
  manufacturer: 'ETC',
  preferredProtocol: ConsoleProtocol.osc,
  oscPort: 3032,
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
);
