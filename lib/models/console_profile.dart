/// Describes a lighting console's communication protocol, OSC/MIDI addressing,
/// and network detection patterns.
///
/// Built-in profiles are provided for GrandMA3, ETC Eos, ChamSys MagicQ,
/// and Obsidian Onyx. Users can create custom profiles for other consoles.
class ConsoleProfile {
  /// Unique profile identifier (e.g., 'grandma3', 'eos', 'chamsys_mq', 'onyx').
  final String id;

  /// Human-readable name (e.g., 'GrandMA3').
  final String displayName;

  /// Manufacturer name (e.g., 'MA Lighting').
  final String manufacturer;

  /// Preferred control protocol for outbound triggers.
  final ConsoleProtocol preferredProtocol;

  /// Default OSC port for this console.
  final int? oscPort;

  /// OSC address patterns for console commands.
  /// Template variables: {cueList}, {cue}, {page}, {fader}, {key}, {macro}, {pb}.
  final ConsoleOscPatterns? oscPatterns;

  /// MIDI settings for this console.
  final ConsoleMidiSettings? midiSettings;

  /// How to detect this console on the network.
  final ConsoleDetectionPatterns detection;

  /// Default sACN priority when coexisting with this console.
  /// Most consoles default to 100; ShowUp should typically be lower.
  final int defaultSacnPriority;

  const ConsoleProfile({
    required this.id,
    required this.displayName,
    required this.manufacturer,
    required this.preferredProtocol,
    this.oscPort,
    this.oscPatterns,
    this.midiSettings,
    required this.detection,
    this.defaultSacnPriority = 50,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'manufacturer': manufacturer,
        'preferredProtocol': preferredProtocol.name,
        if (oscPort != null) 'oscPort': oscPort,
        if (oscPatterns != null) 'oscPatterns': oscPatterns!.toJson(),
        if (midiSettings != null) 'midiSettings': midiSettings!.toJson(),
        'detection': detection.toJson(),
        'defaultSacnPriority': defaultSacnPriority,
      };

  factory ConsoleProfile.fromJson(Map<String, dynamic> json) => ConsoleProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        manufacturer: json['manufacturer'] as String,
        preferredProtocol: ConsoleProtocol.values.firstWhere(
          (p) => p.name == json['preferredProtocol'],
          orElse: () => ConsoleProtocol.osc,
        ),
        oscPort: json['oscPort'] as int?,
        oscPatterns: json['oscPatterns'] != null
            ? ConsoleOscPatterns.fromJson(
                json['oscPatterns'] as Map<String, dynamic>)
            : null,
        midiSettings: json['midiSettings'] != null
            ? ConsoleMidiSettings.fromJson(
                json['midiSettings'] as Map<String, dynamic>)
            : null,
        detection: ConsoleDetectionPatterns.fromJson(
            json['detection'] as Map<String, dynamic>),
        defaultSacnPriority: json['defaultSacnPriority'] as int? ?? 50,
      );
}

/// Protocol used for outbound console communication.
enum ConsoleProtocol { osc, midi, msc, telnet }

/// OSC address templates for controlling a specific console.
class ConsoleOscPatterns {
  /// Fire a cue. Template vars: {cueList}, {cue}.
  /// Example (Eos): '/eos/cue/{cueList}/{cue}/fire'
  /// Example (MA3): '/gma3/cmd' with body 'Go+ Cue {cue}'
  final String? fireCue;

  /// Set a fader level. Template vars: {page}, {fader}.
  final String? setFader;

  /// Fire a playback/executor key. Template vars: {page}, {key}, {pb}.
  final String? firePlayback;

  /// Fire a macro. Template vars: {macro}.
  final String? fireMacro;

  /// Send a raw text command (e.g., MA3's /gma3/cmd).
  final String? sendCommand;

  /// Go back one cue. Template vars: {cueList}, {cue}.
  final String? goBack;

  /// Release a playback. Template vars: {pb}.
  final String? releasePlayback;

  /// Whether fireCue uses the command address with a string body
  /// (MA3 style) vs a dedicated address (Eos style).
  final bool cueViaCommand;

  const ConsoleOscPatterns({
    this.fireCue,
    this.setFader,
    this.firePlayback,
    this.fireMacro,
    this.sendCommand,
    this.goBack,
    this.releasePlayback,
    this.cueViaCommand = false,
  });

  /// Resolve a template string by replacing {key} placeholders with values.
  String resolve(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        if (fireCue != null) 'fireCue': fireCue,
        if (setFader != null) 'setFader': setFader,
        if (firePlayback != null) 'firePlayback': firePlayback,
        if (fireMacro != null) 'fireMacro': fireMacro,
        if (sendCommand != null) 'sendCommand': sendCommand,
        if (goBack != null) 'goBack': goBack,
        if (releasePlayback != null) 'releasePlayback': releasePlayback,
        'cueViaCommand': cueViaCommand,
      };

  factory ConsoleOscPatterns.fromJson(Map<String, dynamic> json) =>
      ConsoleOscPatterns(
        fireCue: json['fireCue'] as String?,
        setFader: json['setFader'] as String?,
        firePlayback: json['firePlayback'] as String?,
        fireMacro: json['fireMacro'] as String?,
        sendCommand: json['sendCommand'] as String?,
        goBack: json['goBack'] as String?,
        releasePlayback: json['releasePlayback'] as String?,
        cueViaCommand: json['cueViaCommand'] as bool? ?? false,
      );
}

/// MIDI configuration for a console.
class ConsoleMidiSettings {
  /// Default MIDI channel (0-15).
  final int channel;

  /// Note number for cue fire (NoteOn).
  final int? fireCueNote;

  /// CC number for fader control.
  final int? faderCc;

  /// Whether to use MIDI Show Control (MSC) instead of raw MIDI.
  final bool useMsc;

  /// MSC device ID (0-111, 127 = all call).
  final int mscDeviceId;

  /// MSC command format (0x01 = lighting.general).
  final int mscCommandFormat;

  const ConsoleMidiSettings({
    this.channel = 0,
    this.fireCueNote,
    this.faderCc,
    this.useMsc = false,
    this.mscDeviceId = 127,
    this.mscCommandFormat = 0x01,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (fireCueNote != null) 'fireCueNote': fireCueNote,
        if (faderCc != null) 'faderCc': faderCc,
        'useMsc': useMsc,
        'mscDeviceId': mscDeviceId,
        'mscCommandFormat': mscCommandFormat,
      };

  factory ConsoleMidiSettings.fromJson(Map<String, dynamic> json) =>
      ConsoleMidiSettings(
        channel: json['channel'] as int? ?? 0,
        fireCueNote: json['fireCueNote'] as int?,
        faderCc: json['faderCc'] as int?,
        useMsc: json['useMsc'] as bool? ?? false,
        mscDeviceId: json['mscDeviceId'] as int? ?? 127,
        mscCommandFormat: json['mscCommandFormat'] as int? ?? 0x01,
      );
}

/// How to identify a console on the network via ArtPoll replies.
class ConsoleDetectionPatterns {
  /// Known OEM codes from ArtPollReply.
  final List<int> oemCodes;

  /// Substrings to match in the node's short/long name.
  final List<String> namePatterns;

  /// ESTA manufacturer codes.
  final List<int> estaCodes;

  const ConsoleDetectionPatterns({
    this.oemCodes = const [],
    this.namePatterns = const [],
    this.estaCodes = const [],
  });

  /// Returns true if the given ArtPoll reply fields match this console.
  bool matches({
    required int oemCode,
    required String shortName,
    required String longName,
    int? estaCode,
  }) {
    if (oemCodes.contains(oemCode)) return true;
    if (estaCode != null && estaCodes.contains(estaCode)) return true;
    final combined = '${shortName.toLowerCase()} ${longName.toLowerCase()}';
    return namePatterns.any((p) => combined.contains(p.toLowerCase()));
  }

  Map<String, dynamic> toJson() => {
        'oemCodes': oemCodes,
        'namePatterns': namePatterns,
        'estaCodes': estaCodes,
      };

  factory ConsoleDetectionPatterns.fromJson(Map<String, dynamic> json) =>
      ConsoleDetectionPatterns(
        oemCodes: (json['oemCodes'] as List?)?.cast<int>() ?? [],
        namePatterns: (json['namePatterns'] as List?)?.cast<String>() ?? [],
        estaCodes: (json['estaCodes'] as List?)?.cast<int>() ?? [],
      );
}

/// Connection details for a detected or manually configured console.
class ConsoleConnection {
  /// Console IP address.
  final String ip;

  /// OSC port (if using OSC protocol).
  final int? oscPort;

  /// Telnet port (if using Telnet protocol). Default 2323 for Onyx.
  final int? telnetPort;

  /// MIDI device ID string (if using MIDI).
  final String? midiDeviceId;

  /// Active protocol for this connection.
  final ConsoleProtocol protocol;

  const ConsoleConnection({
    required this.ip,
    this.oscPort,
    this.telnetPort,
    this.midiDeviceId,
    required this.protocol,
  });

  /// The port for the active protocol.
  int? get activePort {
    switch (protocol) {
      case ConsoleProtocol.osc:
        return oscPort;
      case ConsoleProtocol.telnet:
        return telnetPort ?? 2323;
      case ConsoleProtocol.midi:
      case ConsoleProtocol.msc:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        if (oscPort != null) 'oscPort': oscPort,
        if (telnetPort != null) 'telnetPort': telnetPort,
        if (midiDeviceId != null) 'midiDeviceId': midiDeviceId,
        'protocol': protocol.name,
      };

  factory ConsoleConnection.fromJson(Map<String, dynamic> json) =>
      ConsoleConnection(
        ip: json['ip'] as String,
        oscPort: json['oscPort'] as int?,
        telnetPort: json['telnetPort'] as int?,
        midiDeviceId: json['midiDeviceId'] as String?,
        protocol: ConsoleProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => ConsoleProtocol.osc,
        ),
      );
}
