/// LightConsoleSDK — Console coexistence for ShowUp.
///
/// Turns ShowUp into a **co-pilot** when an LD is present, or a
/// **stunt double** when there's no LD around to work the console.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:light_console_sdk/light_console_sdk.dart';
///
/// // Detect consoles on the network
/// final detector = ConsoleDetector();
/// detector.startWatching(artNetDiscoveryStream);
/// detector.detectionStream.listen((result) {
///   print('Found ${result.profile.displayName} at ${result.node.ip}');
/// });
///
/// // Set up trigger routing
/// final router = TriggerRouter(
///   oscService: ConsoleOscService(profile: grandMa3Profile),
///   bindings: {'chorus-moment-id': ConsoleTriggerBinding(
///     sourceId: 'chorus-moment-id',
///     action: ConsoleTriggerAction.fireCue,
///     params: {'cueList': '1', 'cueNumber': '3'},
///   )},
/// );
///
/// // Fire from ShowUp's Perform screen
/// router.onMomentActivated('chorus-moment-id');
/// ```
library light_console_sdk;

// ── Models ──
export 'models/universe_role.dart';
export 'models/console_profile.dart';
export 'models/coexistence_config.dart';
export 'models/console_trigger.dart';
export 'models/captured_look.dart';
export 'models/timecode_marker.dart';
export 'models/console_input_mapping.dart';
export 'models/parsed_fixture.dart';

// ── Transport ──
export 'transport/sacn_packet.dart';
export 'transport/sacn_transport.dart';
export 'transport/sacn_receiver.dart';
export 'transport/artnet_receiver.dart';
export 'transport/dmx_input_service.dart';

// ── Discovery ──
export 'discovery/console_detector.dart';
export 'discovery/console_profiles_registry.dart';

// ── Console Output ──
export 'output/osc_client.dart';
export 'output/console_osc_service.dart';
export 'output/midi_output.dart';
export 'output/console_midi_service.dart';
export 'output/trigger_router.dart';

// ── Rig Import ──
export 'import/gdtf_attribute_map.dart';
export 'import/gdtf_parser.dart';
export 'import/mvr_parser.dart';
export 'import/csv_patch_parser.dart';

// ── Capture ──
export 'capture/look_capture_service.dart';
export 'capture/console_input_service.dart';

// ── Health ──
export 'health/console_health_monitor.dart';
export 'health/failover_service.dart';
export 'health/trigger_event_log.dart';

// ── Export ──
export 'export/look_export_service.dart';

// ── Advanced ──
export 'advanced/dynamic_priority_service.dart';
export 'advanced/timecode_service.dart';
export 'advanced/complement_analyzer.dart';

// ── Built-in Console Profiles ──
export 'profiles/grandma3.dart';
export 'profiles/etc_eos.dart';
export 'profiles/chamsys_mq.dart';
export 'profiles/onyx.dart';
