# Console Coexistence Backlog

## Vision

ShowUp should never try to replace a GrandMA3, ETC Eos, ChamSys MagicQ, or Onyx.
Instead, ShowUp should be the best possible **companion** to those consoles —
handling the things consoles are bad at (reactive, generative, music-driven lighting)
while letting the console do what it does best (precise cue programming, complex
multi-part sequences, tracking systems).

**One sentence:** "ShowUp plays nice with your console."

**The product promise:** A ShowUp user who walks into a venue with an existing
console should feel like they gained a superpower, not hit a wall.

---

## Strategic Positioning

```
Console Owns                    ShowUp Owns
----------------------------------------------
Cue stacks & tracking           Music-reactive effects
Precise timing sequences        Mood-based generation
Complex multi-part cues         Mobile/tablet control
Raw programmer workflows        Instant looks & moments
House lights & specials         Dynamic crowd lighting

         Bridge Layer
    OSC / MIDI / sACN Priority
    Universe separation
    Trigger mapping
    Look capture
```

### Guardrail Alignment

Per `LIGHTS_ADVANCED_BOUNDARIES.md`, every feature below passes these tests:
1. Does not make Perform or Control harder to understand
2. Does not require a programmer-first mental model
3. Is not exclusively useful for existing console owners
4. Enhances Groups, Looks, Moods, and Macros rather than replacing them
5. Does not force console vocabulary before being useful

---

## Venue Benefit Stories

### Story 1: Church Volunteer — "Sarah's Sunday"

**Setup:** Community church, 200 seats, ETC ColorSource 20 console, 12 PARs, 4 movers.
The worship leader picks songs Thursday night. Sarah (volunteer) runs lights Sunday.

**Today (without ShowUp coexistence):**
- Sarah programs 3-4 static cues on the ETC for each song
- Songs change last minute; she scrambles to reprogram
- No reactive lighting — everything is manual GO presses
- Worship feels flat; pastor wants "more energy" but Sarah can't keep up

**Tomorrow (with ShowUp coexistence):**
- ShowUp connects to the network, detects the ETC ColorSource
- Sarah sets up coexistence: ETC owns universes 1-2 (house lights, specials), ShowUp owns universe 3 (LED strips, movers)
- She maps worship moments: "Verse" fires ETC cue 3 (warm wash), "Chorus" fires ETC cue 4 (brighter) — ShowUp handles reactive color on the movers
- Sunday morning: worship leader changes setlist. Sarah just picks new moments in ShowUp — the ETC cues fire automatically, movers react to music
- Service feels alive. Pastor is thrilled. Sarah didn't touch the ETC once during service.

**Key features used:** Console detection, universe separation, moment-to-cue trigger mapping, OSC output to Eos

---

### Story 2: Wedding DJ — "Marcus at the Manor"

**Setup:** Upscale wedding venue, ChamSys MagicQ install with 40 fixtures.
House LD programs key looks, leaves at 6pm. Marcus (DJ) arrives at 4pm for setup.

**Today:**
- House LD programs 8 cues and writes them on a sticky note
- Marcus has to manually press GO on an unfamiliar console all night
- When the couple wants something special, Marcus can't do it
- The expensive lighting rig runs at 20% of its potential

**Tomorrow:**
- ShowUp detects ChamSys on the network
- Marcus imports the venue's MVR file (house LD emailed it) — ShowUp auto-patches all 40 fixtures
- Before the LD leaves, Marcus hits "Capture" — ShowUp records each of the LD's 8 looks as ShowUp Looks
- Marcus maps: Dinner → captured warm look, First Dance → captured spotlight look, Open Dancing → ShowUp's reactive party mode
- The LD leaves. Marcus runs everything from his iPad. ChamSys executes the captured looks via triggers, ShowUp generates the reactive magic
- The couple gets Instagram-worthy lighting. Marcus books 3 more weddings from referrals.

**Key features used:** Console detection, MVR patch import, look capture from console, trigger mapping, auto-failover

---

### Story 3: School Theater — "Ms. Chen's Spring Musical"

**Setup:** High school auditorium, Onyx (Obsidian) console, 24 conventional fixtures, 8 LED PARs added for the musical.

**Today:**
- Theater teacher programs the entire show on Onyx (60+ cues)
- New LED PARs are added for effect but she doesn't have time to program them into every cue
- LEDs sit on static blue all show. Waste of $2,000 in new fixtures.

**Tomorrow:**
- ShowUp controls the 8 new LED PARs on their own universe
- Onyx runs the cue stack for the musical (conventionals, house lights)
- For each scene, ShowUp runs mood-matched reactive lighting on the LEDs
- Musical number? ShowUp goes to "Hype" mood with music-reactive effects
- Dramatic scene? ShowUp fades to slow warm amber wash
- Ms. Chen maps ShowUp moments to Onyx cues — when she presses GO for scene 12, ShowUp automatically transitions too
- The new LEDs finally earn their keep. Students love the "concert feel."

**Key features used:** Universe separation, sACN output, MIDI triggers to Onyx, scene-generator with console awareness

---

### Story 4: Concert Venue — "The Roxy House System"

**Setup:** 500-cap live music venue, GrandMA3 Light, touring acts bring their own LD.

**Today:**
- Between sets, house lights are either full-on fluorescent or off
- Touring LDs bring their own show files and run the stage rig
- No ambient lighting during changeovers — venue feels dead
- House manager wants "vibe" between sets but has no one to run lights

**Tomorrow:**
- ShowUp runs permanently on house ambient fixtures (LED strips, architectural lighting) on universes 5-6
- ShowUp's sACN priority is set to 50 (lower than console's default 100)
- Between sets: ShowUp generates ambient mood lighting, reacts to house music
- Touring LD takes the stage: their MA3 output overrides on stage universes, ShowUp stays on ambient
- LD can optionally assign a fader on MA3 to control ShowUp's intensity (OSC passthrough)
- Changeovers feel like part of the show. Venue books more acts because "the room always feels alive."

**Key features used:** sACN priority layering, console detection, OSC fader passthrough, auto-failover, universe roles

---

### Story 5: Small Club — "DJ Luna's Residency"

**Setup:** Nightclub, no console, 16 LED PARs + 4 moving heads. ShowUp IS the lighting system.

**Today / Tomorrow:**
- Luna runs ShowUp standalone. All features work as they do today.
- The console coexistence features don't add complexity — "Solo" mode is the default
- sACN output gives her a future path if the venue ever installs a console
- GDTF fixture import means she can use any modern fixture without waiting for ShowUp to add it to the library

**Key features used:** GDTF import, sACN output (future-proofing). No console coexistence needed — but the option is there.

---

## Phase 1: Foundation

### F1.1 — sACN (E1.31) Transport

**What:** Full sACN output transport implementing the existing `TransportInterface` abstraction.

**Why:** sACN is the industry standard for multi-source DMX. Unlike Art-Net, sACN has built-in per-universe priority — the single most important feature for console coexistence. It also supports multicast, which scales better on large networks.

**User-facing:**
- New protocol option in Connect screen: Art-Net / sACN / Relay (sACN button currently disabled)
- Priority slider in stage setup (default 100, adjustable 0-200)
- Same fixture/universe workflow as Art-Net — user doesn't need to understand the difference

**Venue impact:**
- Every major console speaks sACN
- Priority-based merging means ShowUp and console can share a network without conflict
- Multicast reduces network chatter on large rigs

**Technical plumbing:**
```
New files:
  lib/lights/transport/sacn_service.dart

Implementation:
  - Implements TransportInterface (connect, sendUniverse, disconnect, etc.)
  - E1.31 packet construction:
    - Root Layer: preamble (0x0010), postamble (0x0000), ACN packet identifier
    - Framing Layer: source name (ShowUp + device name), priority, universe, sequence
    - DMP Layer: 512 bytes of DMX data
  - Multicast addressing: 239.255.{universe_high}.{universe_low}
  - Unicast mode as fallback (direct IP targeting)
  - Sequence counter per universe (0-255, wrapping)
  - Priority field: configurable per universe (default 100)

Model changes:
  - StageLightsConfig: already has protocol: 'sacn' field, just needs priority field
  - Add sacnPriority to stage file serialization

UI changes:
  - Enable sACN button in connect_screen.dart
  - Add priority slider to stage setup (only shown when sACN selected)
  - Tooltip: "Lower priority means the console wins when both are outputting"
```

**Dependencies:** None (transport abstraction already exists)
**Effort:** Medium
**Risk:** Low — straightforward protocol implementation

---

### F1.2 — Universe Role Assignment

**What:** Let users tag each universe as ShowUp-owned, console-owned, or shared.

**Why:** The fundamental principle of coexistence is: stay out of each other's way. Universe roles make this explicit and enforceable.

**User-facing:**
- New "Universe Map" section in Stage Setup
- Visual grid of universes (1-16) with color-coded roles
- Purple = ShowUp, Blue = Console, Green = Shared
- Tap a universe to change its role
- ShowUp only outputs DMX on ShowUp-owned and shared universes
- Fixtures on console-owned universes are visible but grayed out (monitoring only)

**Venue impact:**
- Prevents the #1 coexistence problem: two sources fighting over the same channels
- Makes the mental model crystal clear for non-technical users
- Church volunteers, school teachers, DJs can all understand "your stuff, my stuff"

**Technical plumbing:**
```
New models:
  lib/lights/models/universe_role.dart
    - UniverseRole enum: showupOwned, consoleOwned, shared
    - UniverseConfig: { universe: int, role: UniverseRole, sacnPriority: int?, label: String? }

Model changes:
  - StageLightsConfig: add Map<int, UniverseConfig> universeRoles
  - stage_file.dart: serialize/deserialize universe roles

Engine changes:
  - DmxEngine.sendUniverse(): check universe role before sending
    - showupOwned: send normally
    - shared: send with configured priority
    - consoleOwned: skip (no output)
  - TransportRouter: respect universe roles in routing decisions

UI:
  - New UniverseMapWidget in stage setup
  - Color-coded universe tiles with role selector
  - Fixture list filtered by universe role (grayed for console-owned)
  - PatchManager: warn if user patches fixture to console-owned universe
```

**Dependencies:** F1.1 (sACN priority makes shared universes meaningful)
**Effort:** Medium
**Risk:** Low

---

### F1.3 — Console Detection via ArtPoll

**What:** Extend existing ArtPoll discovery to identify known lighting consoles by OEM code and present a friendly "console found" notification.

**Why:** The magic moment. ShowUp should proactively discover the console and offer to set up coexistence — not wait for the user to configure everything manually.

**User-facing:**
- ShowUp performs its normal Art-Net discovery on the network
- If a known console OEM code is detected, a notification card slides in
- Card shows: console name, IP address, detected universes
- Two options: "Set Up Coexistence" or "Ignore"
- If ignored, a subtle console icon appears in the status bar for later

**Venue impact:**
- Zero-friction onboarding for coexistence
- User doesn't need to know the console's IP or protocol
- Reduces setup time from 15+ minutes (manual config) to 30 seconds (guided wizard)

**Technical plumbing:**
```
New files:
  lib/lights/services/console_detector.dart
  lib/lights/models/console_profile.dart

ConsoleDetector service:
  - Wraps ArtNetService.discoveryStream
  - Maintains registry of known console OEM codes:
    - MA Lighting (GrandMA): OEM 0x0001
    - ETC: OEM 0x0068 (varies by product)
    - ChamSys: OEM varies
    - Obsidian (Onyx): OEM varies
  - Also checks node longName/shortName for console identifiers
  - Emits ConsoleDetectedEvent when found
  - Tracks detected console state (connected, lost, reconnected)

ConsoleProfile model:
  {
    id: String,               // 'grandma3', 'eos', 'chamsys-mq', 'onyx'
    displayName: String,      // 'GrandMA3'
    manufacturer: String,     // 'MA Lighting'
    protocol: String,         // 'osc' | 'midi' | 'msc'
    oscPort: int?,            // default port for OSC
    oscAddressPatterns: {     // console-specific OSC addresses
      fireCue: '/gma3/cmd',
      setFader: '/gma3/Page{page}/Fader{fader}',
      goPlayback: '/gma3/Page{page}/Key{key}',
    },
    midiChannel: int?,
    detectionPatterns: {      // how to identify this console
      oemCodes: [0x0001],
      namePatterns: ['grandMA', 'gMA3'],
    },
  }

Built-in profiles (JSON assets):
  - assets/console_profiles/grandma3.json
  - assets/console_profiles/etc_eos.json
  - assets/console_profiles/chamsys_mq.json
  - assets/console_profiles/onyx.json

UI:
  - ConsoleDetectionNotification widget (animated card)
  - Status bar console indicator (icon + tooltip)
  - Quick-access panel from status bar tap
```

**Dependencies:** Existing ArtPoll discovery
**Effort:** Medium
**Risk:** Medium — OEM code detection is imperfect; name-based fallback needed

---

### F1.4 — Coexistence Setup Wizard

**What:** Guided 3-4 step wizard that walks the user through configuring ShowUp to work alongside their console.

**Why:** Console coexistence involves several concepts (universe separation, protocol, triggers) that are individually simple but collectively overwhelming if presented as a settings dump. A wizard makes it approachable.

**User-facing:**
- Triggered from console detection notification or from Stage Setup menu
- Step 1: Choose coexistence mode
  - "Side by Side" — ShowUp and console each own separate universes
  - "Trigger Mode" — ShowUp sends cue triggers, console handles all DMX
  - "Layer Mode" — ShowUp adds a reactive layer with lower priority
- Step 2: Universe assignment (auto-suggested based on detection)
  - Visual universe map with drag-and-drop
  - "Auto-assign" button that avoids console's universes
- Step 3: Console profile selection + connection test
  - Dropdown with auto-detected console pre-selected
  - "Test Connection" button that sends a ping and shows result
- Step 4: Summary + done
  - Recap of configuration
  - "Start Performing" button

**Venue impact:**
- Reduces setup anxiety for non-technical users
- Prevents misconfiguration (the wizard enforces valid states)
- The "auto-assign" option means most users just click through 4 screens

**Technical plumbing:**
```
New UI:
  lib/ui/lights/setup/coexistence_wizard.dart
    - CoexistenceWizard: multi-step wizard widget
    - CoexistenceModeSelector: radio cards for mode selection
    - UniverseAssignmentStep: interactive universe map
    - ConsoleProfileStep: profile picker + connection test
    - CoexistenceSummaryStep: recap + confirmation

New models:
  lib/lights/models/coexistence_config.dart
    - CoexistenceMode enum: solo, sideBySide, triggerOnly, layered
    - CoexistenceConfig: { mode, consoleProfile, universeRoles, triggers }

State management:
  - coexistenceConfigProvider: Riverpod provider for config
  - Persisted in stage file alongside existing lights config
  - Applied to DmxEngine, TransportRouter, and trigger services on save

Wizard logic:
  - Step 1 determines which subsequent steps are shown
    - triggerOnly mode skips universe assignment
    - sideBySide mode shows full universe map
    - layered mode shows priority configuration
  - Auto-suggest: reads ArtPoll data to detect console's active universes
  - Connection test: sends OSC/MIDI ping based on profile
```

**Dependencies:** F1.2 (universe roles), F1.3 (console detection)
**Effort:** Large
**Risk:** Low — wizard pattern is well-understood

---

## Phase 2: Trigger System

### F2.1 — OSC Console Output Service

**What:** A dedicated OSC output service for sending commands to lighting consoles, separate from the existing mixer OSC client.

**Why:** ShowUp already has a battle-tested `OscClient` for mixer control. Console triggering uses the same protocol but different addressing, ports, and behavior. A separate service keeps concerns clean and allows independent lifecycle management.

**User-facing:**
- No direct UI — this is plumbing consumed by the trigger mapping system
- User sees triggers fire in the console status panel

**Venue impact:**
- Enables ShowUp to control any OSC-capable console
- ETC Eos, GrandMA3, and ChamSys all have documented OSC APIs

**Technical plumbing:**
```
New files:
  lib/lights/services/console_osc_service.dart

ConsoleOscService:
  - Wraps OscClient with console-specific behavior
  - Configured from ConsoleProfile.oscAddressPatterns
  - Methods:
    - fireCue(cueList, cueNumber)
    - setFader(page, fader, level)
    - firePlayback(playback)
    - fireMacro(macroNumber)
    - sendRawCommand(commandString)  // for MA3's /gma3/cmd
  - Each method resolves the console-specific OSC address from the profile
  - Logs all sent messages for debug panel
  - Connection health monitoring (heartbeat if supported)

Console-specific OSC address maps:

  ETC Eos:
    fireCue:    /eos/cue/{list}/{cue}/fire
    setFader:   /eos/fader/{fader}
    fireMacro:  /eos/macro/{macro}/fire
    setChannel: /eos/chan/{chan}
    goBack:     /eos/cue/{list}/back

  GrandMA3:
    fireCue:    /gma3/cmd  (body: "Go+ Cue {cue}")
    setFader:   /gma3/Page{page}/Fader{fader}
    fireKey:    /gma3/Page{page}/Key{key}
    goBack:     /gma3/cmd  (body: "GoBack Cue {cue}")

  ChamSys MagicQ:
    fireCue:    /ch/playback/{pb}/go
    setFader:   /ch/playback/{pb}/level
    releasePb:  /ch/playback/{pb}/release

  Onyx:
    fireCue:    /Mx/Cuelist/{n}/Go
    setFader:   /Mx/Cuelist/{n}/Level
    release:    /Mx/Cuelist/{n}/Release
```

**Dependencies:** Existing OscClient
**Effort:** Medium
**Risk:** Low — OSC is a simple protocol; console APIs are documented

---

### F2.2 — MIDI Console Output Service

**What:** Platform MIDI output plugin and service for sending MIDI notes, CC messages, and MIDI Show Control (MSC) to consoles.

**Why:** Many consoles accept MIDI triggers even when OSC isn't available. Older Onyx/Obsidian installs especially rely on MIDI. MSC is a standardized protocol for show control across consoles.

**User-facing:**
- MIDI device selector in console profile setup
- Channel/note/CC configuration (with sensible defaults per console profile)

**Venue impact:**
- Covers consoles and use cases where OSC isn't supported
- MIDI is universal — works with consoles, media servers, audio playback
- MSC is the professional standard for multi-system show control

**Technical plumbing:**
```
New files:
  lib/lights/services/console_midi_service.dart
  lib/lights/services/midi_platform_plugin.dart  (or flutter package)

Platform MIDI plugin:
  - macOS: CoreMIDI via dart:ffi or MethodChannel
  - iOS: CoreMIDI (same framework, different entitlement)
  - Windows: Windows MIDI API via dart:ffi
  - Linux: ALSA sequencer API
  - Package candidate: flutter_midi_command (existing pub.dev package)
  
  Methods:
    - listOutputDevices() → List<MidiDevice>
    - openOutput(deviceId) → MidiOutput
    - sendNoteOn(channel, note, velocity)
    - sendNoteOff(channel, note)
    - sendCC(channel, controller, value)
    - sendProgramChange(channel, program)
    - sendMSC(deviceId, commandFormat, command, cue, cueList)
    - close()

ConsoleMidiService:
  - Configured from ConsoleProfile.midiSettings
  - Methods parallel to ConsoleOscService:
    - fireCue(cueNumber) → sends note on or MSC GO
    - setFader(faderNumber, level) → sends CC
    - fireMacro(macroNumber) → sends note or MSC command
  - MSC command construction:
    - SysEx: F0 7F {deviceId} 02 {commandFormat} {command} {data} F7
    - Commands: GO (01), STOP (02), RESUME (03), GO_OFF (0B)
    - Cue/list encoding per MSC spec

MIDI Show Control message format:
  F0 7F [device_id] 02 [command_format] [command] [cue_data] F7
  
  command_format: 01 (lighting.general)
  command: 01=GO, 02=STOP, 03=RESUME, 04=TIMED_GO
  cue_data: ASCII cue number + 00 delimiter + cue list
```

**Dependencies:** Platform MIDI plugin
**Effort:** Large (cross-platform native plugin)
**Risk:** Medium — platform MIDI APIs vary significantly

---

### F2.3 — Moment-to-Console Trigger Mapping

**What:** Bind ShowUp moments to console commands, so activating a moment in Perform automatically fires the corresponding cue/macro on the console.

**Why:** This is the core value proposition of console coexistence. The user orchestrates both systems from ShowUp's simple Perform interface.

**User-facing:**
- Each moment card in Perform shows a small chain-link icon
- Tapping the icon opens a trigger binding sheet
- Sheet shows: "When [Chorus] fires, tell the console to..."
  - Action type: Go to Cue / Fire Macro / Set Fader / Custom Command
  - Parameters: cue number, fader level, etc.
- "Test" button sends the trigger immediately (for verification)
- During performance, triggers fire automatically when moments activate
- Visual feedback: chain-link icon pulses briefly when trigger fires

**Venue impact:**
- Single control surface for both systems
- No need to touch the console during a show
- Reduces operator count (one person runs both instead of two)

**Technical plumbing:**
```
New models:
  lib/lights/models/console_trigger.dart
    ConsoleTriggerBinding:
      momentId: String
      action: ConsoleTriggerAction (enum: fireCue, fireMacro, setFader, customOsc, customMidi)
      parameters: Map<String, dynamic>  // cueNumber, cueList, faderLevel, etc.
      protocol: TriggerProtocol (enum: osc, midi, msc)
      enabled: bool
      delay: Duration?  // optional delay before firing

    ConsoleTriggerAction:
      fireCue → { cueList: String, cueNumber: String }
      fireMacro → { macroNumber: int }
      setFader → { page: int, fader: int, level: double }
      customOsc → { address: String, args: List }
      customMidi → { channel: int, type: String, data1: int, data2: int }

State management:
  - consoleTriggerBindingsProvider: Map<String, ConsoleTriggerBinding>
  - Persisted in stage file under coexistenceConfig.triggers

Execution:
  - MomentActivationListener: watches for moment changes in perform state
  - On moment change → looks up trigger binding → sends via ConsoleOscService or ConsoleMidiService
  - Respects delay if configured
  - Logs trigger events for debug panel

UI:
  lib/ui/lights/show/trigger_binding_sheet.dart
    - Bottom sheet opened from moment card chain-link icon
    - Action type selector (radio buttons with icons)
    - Parameter fields (contextual based on action type)
    - Console profile name shown for context
    - Test button with result indicator
    - Enable/disable toggle
```

**Dependencies:** F2.1 or F2.2 (OSC or MIDI output), F1.4 (coexistence config)
**Effort:** Medium
**Risk:** Low

---

### F2.4 — Macro-to-Console Command Mapping

**What:** Same trigger mapping pattern for macros/actions — the "Big Finish" macro can fire both ShowUp's flash FX and a console command simultaneously.

**Why:** Macros are the quick-fire actions in ShowUp's Perform screen. Linking them to console commands means the operator has instant access to coordinated multi-system effects.

**User-facing:**
- Same chain-link pattern as moments
- Each macro card can have an optional console trigger
- Configurable: ShowUp-only, console-only, or both
- "Both" mode fires ShowUp's effect AND the console command simultaneously

**Venue impact:**
- "Big Finish" = ShowUp strobe + console blackout cue — one tap
- "Reset Room" = ShowUp fades to ambient + console brings up house lights — one tap
- Coordinated multi-system actions from a single interface

**Technical plumbing:**
```
Extension of F2.3:
  - ConsoleTriggerBinding also supports macroId (not just momentId)
  - MacroExecutionListener: watches for macro activations
  - Parallel execution: ShowUp effect + console trigger fire simultaneously
  - Configurable execution mode per macro:
    - showupOnly: only ShowUp effect
    - consoleOnly: only console trigger (ShowUp effect suppressed)
    - both: parallel execution
    - sequential: ShowUp first, then console (or reverse), with configurable delay

Model changes:
  - EventPackMacro: add optional consoleTrigger field
  - ConsoleTriggerBinding: add executionMode field

UI:
  - Same trigger_binding_sheet.dart with macro-specific options
  - Execution mode toggle: "ShowUp Only / Console Only / Both"
```

**Dependencies:** F2.3
**Effort:** Small (extension of existing trigger system)
**Risk:** Low

---

## Phase 3: Rig Sync

### F3.1 — MVR (My Virtual Rig) Import

**What:** Import MVR files exported from consoles or CAD software to auto-populate ShowUp's fixture patch and groups.

**Why:** Re-patching 40 fixtures manually in ShowUp when they're already patched in the console is a dealbreaker. MVR is the industry standard for rig data exchange — supported by GrandMA3, Vectorworks, Capture, WYSIWYG, and increasingly all major platforms.

**User-facing:**
- "Import Rig" button in Stage Setup
- File picker for .mvr files
- Preview screen showing discovered fixtures, addresses, groups
- User confirms import; ShowUp auto-patches everything
- Option to import groups as ShowUp fixture groups (with name mapping)

**Venue impact:**
- Eliminates 15-30 minutes of manual patching per venue
- Wedding DJs can get the venue's MVR file in advance and arrive pre-configured
- Churches can update their rig once (in console) and re-export to ShowUp

**Technical plumbing:**
```
New files:
  lib/lights/fixtures/mvr_parser.dart
  lib/lights/fixtures/gdtf_resolver.dart  (for GDTF fixture type matching)

MVR format:
  - ZIP archive containing:
    - GeneralSceneDescription.xml (main file)
    - GDTF fixture type files (.gdtf)
    - Optional: 3D models, textures (ignored by ShowUp)
  
  Key XML elements:
    <Layers>
      <Layer name="Stage">
        <Fixtures>
          <Fixture name="Spot 1" uuid="..." gdtfSpec="Generic@Dimmer">
            <Addresses>
              <Address break="0">1.001</Address>  <!-- universe.address -->
            </Addresses>
          </Fixture>
        </Fixtures>
      </Layer>
    </Layers>
    
    <GroupObjects>
      <GroupObject name="Front Wash" uuid="...">
        <ChildList>uuid1,uuid2,uuid3</ChildList>
      </GroupObject>
    </GroupObjects>

MvrParser:
  - extractZip(File mvrFile) → temp directory
  - parseSceneDescription(xml) → MvrScene
  - MvrScene:
    - fixtures: List<MvrFixture>
      - name, uuid, gdtfSpec, universe, address, position
    - groups: List<MvrGroup>
      - name, fixtureUuids
    - layers: List<MvrLayer>

GdtfResolver:
  - Takes gdtfSpec string (e.g., "Chauvet@Intimidator Spot 110")
  - Searches ShowUp's fixture library for match:
    1. Exact match by manufacturer + name
    2. Fuzzy match by name similarity
    3. Match by GDTF file included in MVR archive
    4. Fallback: prompt user to select from library
  - Returns FixtureDefinition or null

Import flow:
  1. Parse MVR file
  2. For each fixture: resolve GDTF spec → FixtureDefinition
  3. Create FixtureInstances with correct addresses/universes
  4. Create FixtureGroups from MVR groups
  5. Present preview to user
  6. On confirm: apply to PatchManager
  7. Optionally auto-assign universe roles based on MVR layers
```

**Dependencies:** None (new parser, uses existing PatchManager)
**Effort:** Large
**Risk:** Medium — MVR spec is complex; not all exports are conformant

---

### F3.2 — Console Patch Sheet Import (CSV)

**What:** Import a simple CSV or tab-delimited patch list from any console.

**Why:** MVR is the gold standard but not all consoles export it. Every console can export a patch list as CSV/text. This is the lowest-friction import path.

**User-facing:**
- "Import Patch List" option alongside MVR import
- File picker for .csv/.tsv/.txt files
- Column mapping screen: "Which column is the fixture name? Which is the DMX address?"
- Preview + confirm flow (same as MVR)

**Venue impact:**
- Works with ANY console, even legacy systems
- House LD can email a patch list in Excel; DJ imports before arriving
- No special software or export format required

**Technical plumbing:**
```
New files:
  lib/lights/fixtures/csv_patch_parser.dart
  lib/ui/lights/setup/csv_import_wizard.dart

CsvPatchParser:
  - parseCsv(String csvContent, CsvColumnMapping mapping) → List<ParsedFixture>
  - ParsedFixture: { name, fixtureType, universe, address, mode, groupName }
  
  CsvColumnMapping:
    nameColumn: int
    fixtureTypeColumn: int
    universeColumn: int
    addressColumn: int
    modeColumn: int?
    groupColumn: int?

CSV Import Wizard:
  Step 1: Load file, show raw table preview
  Step 2: Column mapping with dropdowns
    - Auto-detect common column names ("Name", "Fixture", "Address", "Universe", "DMX")
  Step 3: Fixture type matching
    - For each unique fixture type string, match to ShowUp library
    - Fuzzy search with manual fallback
  Step 4: Preview + confirm

Smart detection:
  - Auto-detect delimiter (comma, tab, semicolon)
  - Auto-detect header row
  - Recognize common address formats: "1.001", "U1 A001", "1/001", "001"
  - Handle universe:address vs flat address numbering
```

**Dependencies:** None
**Effort:** Medium
**Risk:** Low — CSV parsing is straightforward; column mapping handles format variations

---

### F3.3 — GDTF Fixture Type Import

**What:** Parse GDTF (General Device Type Format) files to add fixtures to ShowUp's library.

**Why:** GDTF is the modern replacement for manufacturer-specific fixture profiles. Newer fixtures ship with GDTF files. Supporting GDTF means ShowUp can handle any modern fixture without waiting for OFL or ChamSys library updates.

**User-facing:**
- "Import GDTF" option in fixture library
- File picker for .gdtf files
- Fixture appears in library immediately after import
- Can also be triggered automatically during MVR import (GDTF files embedded in MVR)

**Venue impact:**
- New fixtures work in ShowUp on day one (no waiting for library updates)
- Industry standard — manufacturers provide GDTF files on their websites
- Future-proofs ShowUp's fixture support

**Technical plumbing:**
```
New files:
  lib/lights/fixtures/gdtf_parser.dart

GDTF format:
  - ZIP archive containing:
    - description.xml (fixture definition)
    - Optional: 3D models, wheel images, thumbnails (ignored)
  
  Key XML elements:
    <FixtureType>
      <DMXModes>
        <DMXMode Name="Standard">
          <DMXChannels>
            <DMXChannel Offset="1" Default="0/1">
              <LogicalChannel Attribute="Dimmer"/>
            </DMXChannel>
            <DMXChannel Offset="2,3" Default="0/1">
              <LogicalChannel Attribute="Pan"/>
            </DMXChannel>
          </DMXChannels>
        </DMXMode>
      </DMXModes>
      <Wheels>
        <Wheel Name="Color 1">
          <Slot Name="Open" Color="FFFFFF"/>
          <Slot Name="Red" Color="FF0000"/>
        </Wheel>
      </Wheels>
    </FixtureType>

GdtfParser:
  - extractZip(File gdtfFile) → temp directory
  - parseDescription(xml) → FixtureDefinition
  - Attribute mapping: GDTF attribute names → ShowUp CapabilityType
    - "Dimmer" → CapabilityType.dimmer
    - "Pan" → CapabilityType.pan
    - "Tilt" → CapabilityType.tilt
    - "ColorAdd_R" → CapabilityType.red
    - "ColorAdd_G" → CapabilityType.green
    - "ColorAdd_B" → CapabilityType.blue
    - "Color1" → CapabilityType.colorWheel
    - "Gobo1" → CapabilityType.goboWheel
    - etc. (GDTF defines ~200 standard attributes)
  - Handle multi-byte channels (Offset="2,3" means coarse+fine)
  - Extract wheel definitions
  - Store as normalized format via CustomFixtureStorage
```

**Dependencies:** None
**Effort:** Medium
**Risk:** Medium — GDTF spec is large; initial implementation covers common attributes only

---

### F3.4 — Art-Net Console Auto-Detection Enhancement

**What:** Enrich the existing ArtPoll discovery to detect which universes a console is actively outputting on.

**Why:** During coexistence setup, ShowUp should know which universes are "taken" by the console. This enables auto-suggestion in the setup wizard.

**User-facing:**
- No direct UI — feeds into the coexistence setup wizard's auto-suggest
- Universe map shows detected console activity per universe

**Technical plumbing:**
```
Enhancement to existing ArtNetService:

ArtPollReply parsing already extracts:
  - IP address
  - Short/long name
  - Number of ports
  - OEM code

Add parsing of:
  - SwOut (output status per port): which ports are outputting
  - GoodOutput status byte: merge mode, sACN output, Art-Net output
  - BindIp: for multi-IP nodes
  - Port-Address (NetSwitch + SubSwitch + SwOut): universe numbers per port

New method:
  List<int> getActiveUniverses(ArtNetNode node)
  
Integration:
  - ConsoleDetector uses this to report: "GrandMA3 detected, outputting on universes 1-4"
  - Coexistence wizard auto-suggests ShowUp universes that don't conflict
```

**Dependencies:** Existing ArtPoll discovery
**Effort:** Small
**Risk:** Low

---

## Phase 4: Capture & Bidirectional Control

### F4.1 — DMX Input Listener (sACN/Art-Net Receive)

**What:** Listen for incoming DMX data on the network — the reverse of ShowUp's current output-only transport.

**Why:** Enables ShowUp to "see" what the console is outputting. Foundation for look capture, monitoring, and intelligent coexistence.

**User-facing:**
- No direct UI — consumed by capture workflow and monitoring panel
- Universe activity indicators show incoming data levels

**Venue impact:**
- ShowUp becomes network-aware, not just a blind DMX sender
- Enables capture, monitoring, and smart behavior

**Technical plumbing:**
```
New files:
  lib/lights/transport/sacn_receiver.dart
  lib/lights/transport/artnet_receiver.dart
  lib/lights/services/dmx_input_service.dart

SacnReceiver:
  - Joins multicast groups for configured universes
  - Parses E1.31 packets → extracts DMX data + source + priority
  - Emits DmxInputFrame: { universe, data: Uint8List(512), source, priority, timestamp }

ArtNetReceiver:
  - Listens on UDP 6454 for ArtDmx packets (same port, different direction)
  - Parses ArtDmx → extracts DMX data + source IP + universe
  - Emits DmxInputFrame

DmxInputService:
  - Manages receivers based on protocol config
  - Provides streams:
    - universeStream(int universe) → Stream<Uint8List>
    - activityStream() → Stream<Map<int, double>> (universe → activity level 0-1)
  - Snapshot capture: captureNow() → Map<int, Uint8List> (all universes)
  - Activity detection: isUniverseActive(int universe) → bool
```

**Dependencies:** None
**Effort:** Medium
**Risk:** Low — sACN/Art-Net receive is the reverse of existing send code

---

### F4.2 — Look Capture from Console

**What:** Record the console's current DMX output as a ShowUp LightLookSnapshot — "take a photo" of the lighting state.

**Why:** This is the killer workflow for the wedding DJ persona. The house LD programs looks on the console, ShowUp captures them, and the DJ can recall them later without touching the console.

**User-facing:**
- "Capture" button in Control screen toolbar (camera icon)
- Press to enter capture mode:
  - Screen shows pulsing border ("Recording...")
  - "Set up your look on the console, then tap Save"
  - Live DMX activity visualization shows data flowing in
- Tap "Save" to capture the current state
- Name the look, optionally assign to a moment
- Captured look appears in the look library with a "captured" badge

**Venue impact:**
- Bridge between console programming and ShowUp operation
- LD programs once, ShowUp remembers forever
- DJ doesn't need to know the console — just capture and recall
- Enables console-free operation after initial capture session

**Technical plumbing:**
```
New files:
  lib/lights/services/look_capture_service.dart
  lib/ui/lights/control/capture_overlay.dart

LookCaptureService:
  - Uses DmxInputService to read current DMX state
  - captureSnapshot() → CapturedDmxState
    - Reads all active universes
    - Maps DMX values back to fixture parameters using PatchManager
    - For each patched fixture:
      - Read dimmer channel → mainDimmer
      - Read RGB channels → nearest palette color
      - Read pan/tilt → centreX, centreY
      - Read color wheel → colorWheel position
      - Read gobo wheel → gobo selection
    - Constructs LightLookSnapshot from mapped values
  
  Challenges:
    - Reverse-mapping DMX values to ShowUp effects is imperfect
    - Static captures work well (exact values)
    - Dynamic effects (chases, rainbow) capture as a single freeze frame
    - Solution: capture as "static" look type, not as effect parameters
  
  Alternative approach (simpler, more reliable):
    - Capture raw DMX values per fixture channel
    - Store as a "raw DMX look" that bypasses the effect engine
    - On recall: directly set channel values instead of effect parameters
    - Pro: perfect reproduction of console output
    - Con: not editable in ShowUp's effect-based system
    - Hybrid: capture both raw DMX AND best-guess effect parameters
      - Raw DMX for faithful recall
      - Effect params for user editing after capture

CapturedLook model:
  - Extends LightLookConfig with:
    - rawDmx: Map<int, Map<int, int>>  // universe → channel → value
    - captureSource: String  // 'console', 'manual'
    - capturedAt: DateTime
  - kind: 'captured'

UI:
  CaptureOverlay:
    - Pulsing border animation (recording state)
    - DMX activity visualizer (per-universe bar graph)
    - Fixture state preview (colored dots for each fixture)
    - "Save" / "Cancel" buttons
    - Save dialog: name, moment assignment, group scope
```

**Dependencies:** F4.1 (DMX input listener)
**Effort:** Large
**Risk:** Medium — DMX-to-effect reverse mapping is inherently lossy

---

### F4.3 — Console Fader Passthrough (OSC/MIDI Input)

**What:** Accept incoming OSC or MIDI from the console to control ShowUp parameters — the console LD can dial ShowUp's intensity up and down from their own faders.

**Why:** In venue scenarios where a professional LD is running the console, they need to be able to control ShowUp's contribution without switching to a different interface. A fader on their desk that maps to "ShowUp intensity" keeps them in their workflow.

**User-facing:**
- Console profile setup includes "Incoming Control" section
- Map incoming OSC addresses or MIDI CC to ShowUp parameters:
  - Master dimmer
  - Color speed
  - Movement speed
  - Effect intensity
  - Specific group dimmers
- Live indicator shows when console is controlling a parameter (override badge)

**Venue impact:**
- Pro LDs stay on their console — they don't need to touch ShowUp
- Concert venue LD can "ride" ShowUp's reactive layer with a physical fader
- Seamless integration into existing console workflow

**Technical plumbing:**
```
New files:
  lib/lights/services/console_input_service.dart

ConsoleInputService:
  - OscServer: listens on configured port for incoming OSC messages
  - MidiInputListener: receives MIDI from configured device
  - Maps incoming messages to ShowUp parameters:
    - parameterMappings: List<ConsoleInputMapping>
      - ConsoleInputMapping: { source (osc_address | midi_cc), target (showup_param), range }
  - Applies values to ShowUp state:
    - Master dimmer → LightsStateNotifier.setMasterDimmer()
    - Color speed → EffectEngine.setColorSpeed()
    - Group dimmer → PatchManager.setGroupDimmer()
  - Override indicator: tracks which parameters are currently externally controlled
  - Timeout: if no input received for 10s, release override (parameter returns to ShowUp control)

Predefined mappings per console profile:
  GrandMA3:
    /gma3/Page1/Fader9 → masterDimmer (0.0-1.0)
    /gma3/Page1/Fader10 → colorSpeed (0.0-1.0)
  ETC Eos:
    /eos/fader/1/1 → masterDimmer
    /eos/fader/1/2 → colorSpeed
```

**Dependencies:** F2.1 (OSC service), MIDI input plugin
**Effort:** Medium
**Risk:** Low

---

## Phase 5: Polish & Completeness

### F5.1 — Console Status Dashboard

**What:** Compact, expandable panel showing real-time console connection health, universe activity, and trigger log.

**User-facing:**
- Small console icon in ShowUp's status bar
  - Green dot: connected and healthy
  - Yellow dot: detected but not configured
  - Red dot: connection lost
  - No icon: solo mode (no console)
- Tap icon to expand dashboard panel:
  - Console name + IP + uptime
  - Universe activity bars (like audio meters, per-universe)
  - Last 10 trigger events log
  - ShowUp priority level indicator
  - "Reconfigure" button → back to wizard

**Venue impact:**
- At-a-glance confidence that everything is working
- Quick diagnosis when something goes wrong
- No need to check the console itself for connection status

**Technical plumbing:**
```
New UI:
  lib/ui/shell/console_status_indicator.dart
  lib/ui/lights/status/console_dashboard_panel.dart

ConsoleStatusIndicator:
  - Reads from ConsoleDetector.connectionState
  - Animated dot with color transitions
  - Tap handler to toggle dashboard panel

ConsoleDashboardPanel:
  - SlideUp panel from status bar
  - Real-time universe activity bars from DmxInputService.activityStream()
  - Trigger log from ConsoleTriggerService.eventLog
  - Priority display from CoexistenceConfig
  - Connection health from ConsoleDetector heartbeat
```

**Dependencies:** F1.3 (console detection), F4.1 (DMX input), F2.3 (trigger system)
**Effort:** Medium
**Risk:** Low

---

### F5.2 — OSC/MIDI Debug Panel

**What:** Debug panel showing all outgoing and incoming OSC/MIDI messages related to console communication.

**User-facing:**
- Accessible from Console Dashboard → "Debug" tab
- Real-time scrolling log of messages
- Filter by direction (in/out), protocol (OSC/MIDI), success/failure
- Tap a message to see full details (address, args, timestamp)
- "Clear" and "Pause" buttons

**Venue impact:**
- Essential for troubleshooting "why isn't the console responding?"
- Follows the pattern of ShowUp's existing OSC debug panel for mixers

**Technical plumbing:**
```
Extension of existing osc_debug_panel.dart pattern:
  lib/ui/lights/status/console_debug_panel.dart
  
  - Consumes log streams from ConsoleOscService and ConsoleMidiService
  - Each log entry: { timestamp, direction, protocol, address/channel, args/data, success }
  - Filterable ListView with auto-scroll
  - Message detail sheet on tap
```

**Dependencies:** F2.1, F2.2 (OSC/MIDI services)
**Effort:** Small
**Risk:** Low

---

### F5.3 — Look Export as DMX State Table

**What:** Export a ShowUp LightLookSnapshot as a CSV of DMX channel values that a console operator can reference or import.

**User-facing:**
- "Export" option on any Look in the library
- Generates CSV: Fixture Name, Universe, Channel, Value, Parameter
- Share via system share sheet (AirDrop, email, files)

**Venue impact:**
- Console LD can see exactly what ShowUp is doing in their language (DMX values)
- Reference sheet for manual console programming
- Some consoles can import CSV-format presets

**Technical plumbing:**
```
New file:
  lib/lights/services/look_export_service.dart

LookExportService:
  - exportAsCsv(LightLookConfig, PatchManager) → String
  - For each fixture in patch:
    - Compute DMX values from look snapshot (run through effect engine once)
    - Output: fixture name, universe, start address, channel offset, value, parameter name
  - Format:
    "Fixture","Universe","Address","Channel","Value","Parameter"
    "Spot 1",1,1,1,255,"Dimmer"
    "Spot 1",1,1,2,128,"Red"
    ...
```

**Dependencies:** None
**Effort:** Small
**Risk:** Low

---

### F5.4 — Console Health Auto-Failover

**What:** When the console disconnects from the network, ShowUp optionally takes over its universes with fallback looks.

**User-facing:**
- Toggle in coexistence config: "Take over if console goes offline"
- Configure fallback look per universe (or "last captured" or "blackout")
- When console drops: ShowUp shows notification "Console offline — ShowUp taking over"
- When console returns: ShowUp fades back to its own universes

**Venue impact:**
- The show doesn't stop if the console crashes or loses network
- Concert venue: if touring LD's console reboots, ShowUp keeps ambient going
- Wedding: if ChamSys freezes at midnight, ShowUp ensures the dance floor stays lit

**Technical plumbing:**
```
Extension of ConsoleDetector:
  - Heartbeat monitoring: periodic ArtPoll or OSC ping
  - Timeout threshold: configurable (default 5 seconds)
  - On timeout: emit ConsoleOfflineEvent
  
FailoverService:
  - Listens for ConsoleOfflineEvent
  - Temporarily overrides universe roles: console-owned → showup-owned
  - Applies fallback looks to newly-owned universes
  - Raises sACN priority if in layered mode
  - On ConsoleReconnectedEvent: fades back to normal roles over configurable duration
```

**Dependencies:** F1.2 (universe roles), F1.3 (console detection)
**Effort:** Medium
**Risk:** Medium — false positives could cause unexpected behavior

---

## Phase 6: Advanced Workflows

### F6.1 — sACN Priority Dynamic Adjustment

**What:** ShowUp dynamically adjusts its sACN priority based on context — lower during console cue execution, higher during ShowUp-led moments.

**User-facing:**
- "Dynamic Priority" toggle in layered mode config
- ShowUp automatically manages priority based on what's happening
- Optional manual override via a priority slider in Perform

**Venue impact:**
- Seamless handoffs between console and ShowUp during a show
- Console cues always "pop through" ShowUp's layer when they fire
- Between cues, ShowUp's reactive layer fills naturally

**Technical plumbing:**
```
Extension of SacnTransport:
  - setPriority(int universe, int priority): dynamic per-universe priority changes
  - Requires re-sending sACN packets with updated priority field
  - Priority profiles:
    - consoleCueActive: priority 20 (very low, console dominates)
    - showupMomentActive: priority 80 (medium-high, ShowUp leads)
    - idle: priority 50 (balanced, HTP decides)
  - Trigger: ConsoleTriggerService reports when it just fired a cue → lower priority
  - Timer: after configurable duration (default 3s), fade priority back up
```

**Dependencies:** F1.1 (sACN), F2.3 (trigger system)
**Effort:** Medium
**Risk:** Medium — priority changes mid-stream can cause visible flickers if not faded

---

### F6.2 — Timecode Input (LTC/MTC)

**What:** Accept linear timecode (LTC) or MIDI timecode (MTC) from the console's clock to auto-advance ShowUp moments.

**User-facing:**
- "Timecode Sync" option in performance settings
- Timecode source: MIDI (MTC) or Audio (LTC)
- Marker mapping: timecode positions → moment activations
- Timeline view showing markers and current position
- Override: operator can always manually activate moments

**Venue impact:**
- Theater: ShowUp moments advance automatically with the show's master clock
- Concert: pre-programmed shows with timecoded lighting
- Worship: if the service runs on a click track, lights follow

**Technical plumbing:**
```
New files:
  lib/lights/services/timecode_service.dart
  lib/lights/models/timecode_marker.dart

MTC Reception:
  - MIDI Quarter Frame messages (F1 {data})
  - Assemble full timecode: hours:minutes:seconds:frames
  - Frame rates: 24, 25, 29.97df, 30 fps
  - Emit TimecodePositionEvent

LTC Reception:
  - Audio input → LTC decoder
  - Extract timecode from audio signal
  - Higher complexity — may require native plugin

TimecodeMarker:
  - position: TimecodePosition (HH:MM:SS:FF)
  - momentId: String
  - action: 'activate' | 'deactivate'

TimecodeService:
  - Markers sorted by position
  - On position update: check if any markers passed, fire moment activations
  - Handles forward and backward timecode (scrubbing)
```

**Dependencies:** MIDI input plugin (from F2.2)
**Effort:** Large
**Risk:** High — timecode sync requires precise timing; LTC needs audio processing

---

### F6.3 — Console-Aware Scene Generation

**What:** ShowUp's scene generator considers which fixtures the console controls and generates complementary looks for ShowUp's fixtures.

**User-facing:**
- Scene generator automatically excludes console-controlled fixtures
- Optional: "Complement" mode that analyzes console output and generates contrasting looks
  - Console has warm front wash → ShowUp generates cool back wash
  - Console has slow fade → ShowUp generates slow matching fade
- Requires DMX input to analyze console state

**Venue impact:**
- Looks automatically avoid conflicts with console programming
- Generated looks complement rather than clash
- No manual adjustment needed after generation

**Technical plumbing:**
```
Extension of SceneGenerator:
  - Filter fixtures by universe role before generating
  - In complement mode:
    - Read current console DMX via DmxInputService
    - Analyze dominant color (average RGB across console fixtures)
    - Generate complementary palette (color wheel opposite)
    - Match energy level (slow console → slow ShowUp, fast → fast)
    - Avoid duplicate movement patterns
```

**Dependencies:** F1.2 (universe roles), F4.1 (DMX input)
**Effort:** Medium
**Risk:** Low — extends existing generator with additional filters

---

## Architecture Overview

### Data Flow

```
                    ┌─────────────────────────────────────────────┐
                    │                 ShowUp App                    │
                    │                                              │
                    │  ┌──────────┐  ┌───────────┐  ┌──────────┐ │
                    │  │ Perform  │  │  Control   │  │ Advanced │ │
                    │  │ Screen   │  │  Screen    │  │  Screen  │ │
                    │  └────┬─────┘  └─────┬──────┘  └────┬─────┘ │
                    │       │              │               │       │
                    │  ┌────▼──────────────▼───────────────▼────┐ │
                    │  │         Lighting State Manager          │ │
                    │  │  (moments, looks, effects, macros)     │ │
                    │  └────┬──────────────────────────────┬────┘ │
                    │       │                              │      │
                    │  ┌────▼────────┐          ┌─────────▼───┐  │
                    │  │ DMX Engine  │          │  Trigger     │  │
                    │  │ (44Hz loop) │          │  Router      │  │
                    │  └────┬────────┘          └──┬───────┬──┘  │
                    │       │                      │       │      │
                    │  ┌────▼────────────┐   ┌────▼──┐ ┌──▼───┐ │
                    │  │ Transport Layer │   │ OSC   │ │ MIDI │ │
                    │  │ (sACN/Art-Net)  │   │ Out   │ │ Out  │ │
                    │  └────┬────────────┘   └───┬───┘ └──┬───┘ │
                    │       │                    │        │      │
                    └───────┼────────────────────┼────────┼──────┘
                            │                    │        │
                   ─────────┼────────────────────┼────────┼──── Network
                            │                    │        │
                    ┌───────▼──────┐    ┌────────▼────────▼────┐
                    │  DMX Nodes   │    │   Lighting Console   │
                    │  (fixtures)  │    │  (MA3/Eos/MQ/Onyx)   │
                    │              │    │                       │
                    │  ShowUp's    │    │  Receives triggers    │
                    │  universes   │    │  Outputs its own DMX  │
                    └──────────────┘    └───────────┬───────────┘
                                                    │
                                           ─────────┼──── Network
                                                    │
                                            ┌───────▼──────┐
                                            │  DMX Nodes   │
                                            │  (fixtures)  │
                                            │              │
                                            │  Console's   │
                                            │  universes   │
                                            └──────────────┘
```

### Bidirectional Data Flow (Phase 4+)

```
    ShowUp                              Console
    ──────                              ───────
    
    DMX Output ──── sACN/Art-Net ────► Fixtures (ShowUp universes)
    
    OSC/MIDI ──── Triggers ──────────► Cue execution
    
    DMX Input ◄──── sACN/Art-Net ──── DMX Output (console universes)
    
    OSC/MIDI ◄──── Fader control ──── LD's faders
    
    Capture ◄───── DMX snapshot ────── Console look state
```

### New File Structure

```
lib/lights/
  transport/
    transport_interface.dart        (existing)
    transport_router.dart           (existing, extended)
    artnet_service.dart             (existing)
    artnet_packet.dart              (existing)
    websocket_transport.dart        (existing)
    sacn_service.dart               (NEW — Phase 1)
    sacn_receiver.dart              (NEW — Phase 4)
    artnet_receiver.dart            (NEW — Phase 4)
  
  services/
    console_detector.dart           (NEW — Phase 1)
    console_osc_service.dart        (NEW — Phase 2)
    console_midi_service.dart       (NEW — Phase 2)
    console_trigger_service.dart    (NEW — Phase 2)
    console_input_service.dart      (NEW — Phase 4)
    dmx_input_service.dart          (NEW — Phase 4)
    look_capture_service.dart       (NEW — Phase 4)
    look_export_service.dart        (NEW — Phase 5)
    failover_service.dart           (NEW — Phase 5)
    timecode_service.dart           (NEW — Phase 6)
  
  models/
    universe_role.dart              (NEW — Phase 1)
    console_profile.dart            (NEW — Phase 1)
    coexistence_config.dart         (NEW — Phase 1)
    console_trigger.dart            (NEW — Phase 2)
    timecode_marker.dart            (NEW — Phase 6)
  
  fixtures/
    mvr_parser.dart                 (NEW — Phase 3)
    gdtf_parser.dart                (NEW — Phase 3)
    gdtf_resolver.dart              (NEW — Phase 3)
    csv_patch_parser.dart           (NEW — Phase 3)

lib/ui/lights/
  setup/
    coexistence_wizard.dart         (NEW — Phase 1)
    universe_map_widget.dart        (NEW — Phase 1)
    csv_import_wizard.dart          (NEW — Phase 3)
    mvr_import_wizard.dart          (NEW — Phase 3)
  
  show/
    trigger_binding_sheet.dart      (NEW — Phase 2)
  
  control/
    capture_overlay.dart            (NEW — Phase 4)
  
  status/
    console_dashboard_panel.dart    (NEW — Phase 5)
    console_debug_panel.dart        (NEW — Phase 5)

lib/ui/shell/
  console_status_indicator.dart     (NEW — Phase 5)

assets/
  console_profiles/
    grandma3.json                   (NEW — Phase 1)
    etc_eos.json                    (NEW — Phase 1)
    chamsys_mq.json                 (NEW — Phase 1)
    onyx.json                       (NEW — Phase 1)
```

---

## Open Questions & Risks

### Technical Risks

1. **sACN priority race conditions**: Two sources changing priority simultaneously can cause visible flicker. Mitigation: fade priority changes over 500ms.

2. **OSC console API stability**: Console manufacturers may change OSC APIs between firmware versions. Mitigation: console profiles are user-editable; community can maintain profiles.

3. **MIDI platform plugin complexity**: Cross-platform native MIDI is non-trivial. Mitigation: start with macOS/iOS only (CoreMIDI); expand to Windows/Linux later.

4. **MVR spec conformance**: Not all tools export compliant MVR. Mitigation: handle common deviations gracefully; fall back to manual patching.

5. **DMX-to-effect reverse mapping**: Capturing console output as ShowUp effects is inherently lossy. Mitigation: capture raw DMX + best-guess effects; let user choose.

### Product Risks

1. **Complexity creep**: Console coexistence adds significant configuration surface area. Mitigation: wizard handles 90% of cases; advanced options are hidden until needed.

2. **Support burden**: Users will ask "why isn't it working with my console?" Mitigation: debug panel, connection test, community console profiles.

3. **Identity confusion**: Users might start thinking of ShowUp as a console. Mitigation: language, positioning, and UX all reinforce "companion" not "replacement."

### Open Questions

1. Should ShowUp detect consoles proactively (always scanning) or only when user initiates?
2. How to handle multiple consoles on the same network?
3. Should console profiles be updatable from a cloud registry?
4. What's the minimum viable trigger mapping for V1? (Just fireCue, or full macro/fader?)
5. Should captured looks be tagged differently from generated looks in the UI?
6. How does coexistence interact with the existing tablet/remote continuity plan?
