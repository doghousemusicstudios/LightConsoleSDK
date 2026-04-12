import '../models/console_profile.dart';

/// Avolites Titan console profile (Arena, Sapphire Touch, Tiger Touch,
/// Quartz, T2, T3, Titan Mobile).
///
/// Titan uses an HTTP/JSON WebAPI on port 4430 as the primary external
/// control interface. This is the same API used by the official Titan
/// Remote app and Bitfocus Companion.
///
/// No OSC support. MIDI input only (MSC for triggers). MIDI output
/// requires custom macros.
///
/// Note: WebAPI is NOT available on Titan One or T1 dongle.
const avolitesProfile = ConsoleProfile(
  id: 'avolites_titan',
  displayName: 'Avolites Titan',
  manufacturer: 'Avolites',
  preferredProtocol: ConsoleProtocol.http,
  // No OSC port — Titan uses HTTP on 4430.
  oscPort: null,
  oscPatterns: null,
  midiSettings: ConsoleMidiSettings(
    channel: 0,
    useMsc: true,
    mscDeviceId: 0,
    mscCommandFormat: 0x01,
  ),
  detection: ConsoleDetectionPatterns(
    oemCodes: [0x4176], // 'Av' for Avolites
    namePatterns: [
      'avolites', 'titan', 'sapphire', 'tiger touch', 'arena',
      'quartz', 'diamond', 'd9',
    ],
    estaCodes: [0x4156], // 'AV'
  ),
  defaultSacnPriority: 100,
  heartbeat: HeartbeatConfig(
    strategy: HeartbeatStrategy.httpGet,
    port: 4430,
    httpPath: '/titan/get/System/SoftwareVersion',
  ),
);

/// Default HTTP port for the Titan WebAPI.
const titanWebApiPort = 4430;

/// Titan WebAPI script providers for use with HttpConsoleClient.executeScript().
abstract class TitanProviders {
  static const playbacks = 'Playbacks';
  static const fixtures = 'Fixtures';
  static const masters = 'Masters';
  static const system = 'System';
  static const show = 'Show';
  static const colours = 'Colours';
  static const titan = 'Titan';
}
