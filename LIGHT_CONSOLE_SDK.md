# LightConsoleSDK

**ShowUp's co-pilot when the LD is around. Its stunt double when they're not.**

---

## What This SDK Does

LightConsoleSDK is a pure Dart library that enables ShowUp (Mac/iPad) to work alongside professional lighting consoles — GrandMA3, ETC Eos, ChamSys MagicQ, and Obsidian Onyx — without replacing them.

Lighting consoles are unmatched at precise cue programming, complex multi-part sequences, and tracking systems. ShowUp is built for reactive, generative, music-driven lighting that consoles can't do. The SDK bridges these two worlds.

```
Console Owns                    ShowUp Owns
──────────────────────────────────────────────
Cue stacks & tracking           Music-reactive effects
Precise timing sequences        Mood-based generation
Complex multi-part cues         Mobile/tablet control
Raw programmer workflows        Instant looks & moments
House lights & specials         Dynamic crowd lighting

                Bridge Layer
           ┌─────────────────────┐
           │  OSC / MIDI / sACN  │
           │  Universe separation│
           │  Trigger mapping    │
           │  Look capture       │
           └─────────────────────┘
```

---

## Real-World Benefits

### Church Volunteer — "Sarah's Sunday"
**Setup:** Community church, ETC ColorSource 20, 12 PARs, 4 movers.

Without ShowUp: Sarah programs 3-4 static cues per song. Songs change last minute. No reactive lighting. Worship feels flat.

With the SDK: ShowUp controls reactive movers on universe 3 while the ETC handles house lights on universes 1-2. When Sarah taps "Chorus" in ShowUp, it fires Cue 3 on the ETC via OSC and simultaneously launches a reactive color wash on the movers. Song changes take seconds, not 15 minutes of reprogramming.

### Wedding DJ — "Marcus at the Manor"
**Setup:** Upscale venue, ChamSys MagicQ, 40 fixtures. House LD leaves at 6pm.

Without ShowUp: Marcus presses GO on an unfamiliar console all night from a sticky note. The $50K rig runs at 20% of its potential.

With the SDK: Before the LD leaves, Marcus hits "Capture" — ShowUp snapshots each of the LD's looks as raw DMX. Marcus maps Dinner → captured warm look, First Dance → captured spotlight, Open Dancing → ShowUp's reactive party mode. The LD leaves. Marcus runs everything from his iPad. The couple gets Instagram-worthy lighting.

### Concert Venue — "The Roxy House System"
**Setup:** 500-cap venue, GrandMA3 Light, touring acts bring their own LD.

Without ShowUp: Between sets, house lights are fluorescent or off. The venue feels dead during changeovers.

With the SDK: ShowUp runs permanently on ambient fixtures (LED strips, architectural lighting) on universes 5-6 with sACN priority 50 (lower than the console's 100). Between sets, ShowUp generates ambient mood lighting that reacts to house music. When the touring LD takes the stage, their MA3 output overrides on stage universes automatically. The LD can optionally ride ShowUp's intensity with a physical fader on their console via OSC passthrough.

### School Theater — "Ms. Chen's Musical"
**Setup:** High school, Onyx console, 24 conventionals + 8 new LED PARs.

Without ShowUp: Ms. Chen programs 60+ cues on Onyx for the conventionals but has no time for the new LEDs. They sit on static blue all show.

With the SDK: ShowUp controls the 8 LED PARs on their own universe. Onyx runs the cue stack for conventionals. For each scene, ShowUp runs mood-matched reactive lighting on the LEDs. When Ms. Chen presses GO for scene 12 on Onyx, ShowUp automatically transitions too via MIDI Show Control.

### Small Club — "DJ Luna's Residency"
**Setup:** Nightclub, no console, 16 LED PARs + 4 movers.

ShowUp runs standalone — all features work as they do today. The console coexistence features don't add complexity. The SDK is invisible until there's a console to talk to.

---

## SDK Architecture

### 38 Dart files across 10 modules — zero Flutter dependency

```
light_console_sdk/
├── transport/          sACN E1.31 output + input, Art-Net receiver
├── models/             Universe roles, console profiles, triggers, captured looks
├── discovery/          ArtPoll-based console detection, profile registry
├── output/             OSC client, MIDI output, console command services
├── import/             MVR, GDTF, and CSV patch parsers
├── capture/            DMX snapshot capture, incoming fader control
├── health/             Heartbeat monitoring, auto-failover, event logging
├── export/             Look → DMX CSV table export
├── advanced/           Dynamic sACN priority, timecode sync, complement analysis
└── profiles/           Built-in configs for MA3, Eos, MagicQ, Onyx
```

### Three Coexistence Modes

**Side by Side** — ShowUp and the console each own separate DMX universes. No overlap, no conflicts. ShowUp controls its fixtures; the console controls its own. Universe roles are color-coded: purple = ShowUp, blue = console, green = shared.

**Trigger Mode** — ShowUp sends cue/macro commands to the console via OSC or MIDI but does not output any DMX itself. The console handles all fixture control. ShowUp's Perform screen becomes a remote control for the console with moment-based workflow instead of cue-list workflow.

**Layer Mode** — ShowUp adds a reactive lighting layer underneath the console using sACN priority-based merging. The console's output always takes precedence (higher priority). ShowUp fills the gaps between console cues with reactive, music-driven effects. When the console fires a cue, ShowUp automatically lowers its priority to stay out of the way.

---

## How ShowUp Interacts with Each Console

### GrandMA3 (MA Lighting)

**Connection:** OSC over UDP, user-configurable port (commonly 8000). Also: WebSocket on port 8080 (undocumented), SFTP on port 22.

**What ShowUp can do:**
- Fire cues via `/gma3/cmd` with text commands ("Go+ Cue 3")
- Set fader levels via `/gma3/Page{n}/Fader{n}` with float values
- Fire macros via `/gma3/cmd` ("Macro 1")
- Send any MA3 command-line instruction via OSC
- Share the network via sACN priority-based merging
- Import MVR files exported from MA3 (native MVR support)
- Import GDTF fixture definitions (MA co-created the standard)
- Detect MA3 on the network via ArtPoll OEM codes

**Bidirectional feedback (via ShowUp Companion Lua Plugin):**
- MA3 supports Lua 5.4.4 plugins that run directly on the console
- The plugin polls executor state via `GetExecutor(N):GetFader({})` at ~10Hz
- Broadcasts fader positions, active cue numbers, and playback state via `SendOSC`
- This is the established community pattern — RikSolo, ArtGateOne, and pam-osc all use it
- ShowUp ships a ready-to-install `.lua` plugin in `companion_plugins/grandma3/`
- Addresses: `/showup/fader/{n}` (0.0-1.0), `/showup/cue/active` (cue name), `/showup/playback/{n}/state` (active/released)
- No event callbacks in Lua — polling is the only approach, but 10Hz is more than sufficient

**Console fader → ShowUp parameter:**
- With the Companion Plugin installed, the LD assigns an executor to "ShowUp Intensity"
- Plugin sends `/showup/param/masterDimmer,f,0.75` whenever the fader moves
- ShowUp's `ConsoleInputService` maps it to master dimmer, color speed, movement, etc.

**What ShowUp cannot do natively (without plugin):**
- Receive per-fader position feedback (sequence-level only)
- Use MIDI Show Control (MA3 does not support MSC)
- Parse show files directly (proprietary binary format)

**Alternative protocols:**
- WebSocket on port 8080 — undocumented but functional; potential reverse-engineering target for richer state
- XML export from console — sequence/cue data can be exported and parsed for cue names, timing
- MA-Net3 (UDP multicast port 30020) — proprietary, undocumented, not usable by third parties
- DMX sniffing via sACN — read MA3's output to infer fixture state (universal fallback)

**Special considerations:**
- MA3 uses a command-based OSC API — most operations go through `/gma3/cmd` with a text body
- OSC bundles are not supported
- MA3 onPC (free) supports full OSC and Lua for SDK development/testing
- Localhost port conflicts are possible if ShowUp runs on the same machine

---

### ETC Eos Family (Eos, Ion, Element, ColorSource)

**Connection:** OSC over TCP (preferred, port 3032) or UDP. Third-party OSC on port 3037 (v3.1.0+, TCP SLIP only, ~10Hz updates).

**What ShowUp can do:**
- Fire cues via `/eos/cue/{list}/{cue}/fire`
- Set fader levels via `/eos/fader/{bank}/{index}` (0.0-1.0)
- Control individual channels via `/eos/chan/{chan}`
- Fire macros via `/eos/macro/{macro}/fire`
- Send command-line instructions via `/eos/cmd`
- Use MIDI Show Control (MSC) for cue triggers (up to 32 MSC sources)
- Share the network via sACN (ETC invented sACN / E1.31)
- Import MVR files (Eos v3.2+)
- Import GDTF fixture definitions (Eos v3.2.4+)
- Detect Eos on the network via ArtPoll

**Full bidirectional feedback (native, no plugins needed):**
- **Cue events:** `/eos/out/event/cue/{list}/{cue}/fire` and `.../stop` — ShowUp knows exactly when and which cue fires
- **Active cue:** `/eos/out/active/cue` — current running cue broadcast
- **Channel data:** `/eos/out/get/params/{channel}` — intensity, pan, tilt, focus, color parameters (v3.2+)
- **Patch info:** `/eos/out/get/patch/{chan}/{part}/list/{index}/{count}` — address mapping, fixture type, current level
- **Fader positions:** `/eos/out/fader/` — real-time fader positions
- **Palettes:** `/eos/out/get/cp/{n}` (color), `/eos/out/get/fp/{n}` (focus), `/eos/out/get/bp/{n}` (beam) — palette metadata and channel assignments
- **Cue lists:** `/eos/out/get/cuelist/{n}`, `/eos/out/get/cue/{list}/{cue}/{part}` — full cue list structure
- **Groups/subs/macros:** `/eos/out/get/group/{n}`, `/eos/out/get/sub/{n}`, `/eos/out/get/macro/{n}`
- **Events:** `/eos/out/event/sub/{n}`, `/eos/out/event/macro/{n}`, `/eos/out/event/relay/{n}/{group}`

**Console fader → ShowUp parameter (native):**
- LD assigns a fader on their desk; Eos broadcasts the value via `/eos/out/fader/`
- ShowUp maps incoming fader values to master dimmer, color speed, movement intensity, etc.
- 3-second debounce after OSC-driven fader moves (the only quirk)

**Preset translation path:**
- Read palette names + channel assignments via OSC queries
- Fire each cue in sequence, capture resulting DMX via sACN
- Build a ShowUp look library that matches the console's cue structure
- CSV export available via File > Export > CSV (cue metadata + channel moves)

**ColorSource family:**
- Uses `/cs/` prefix, NOT `/eos/` — completely different OSC namespace
- UDP only (ports 8005/8006), much simpler command set
- AV models add audio/video transport controls; non-AV has reduced networking
- Minimal feedback compared to Eos's rich `/eos/out/` system

**What ShowUp cannot do:**
- Receive GDTF multi-cell fixture data (import limitation)
- Get bulk "all channel output levels" via OSC (must use sACN sniffing for that)
- Parse Eos show files directly (.esf/.esf2/.esf3d — proprietary binary)

**Special considerations:**
- Eos has the most comprehensive OSC API of any lighting console — the best integration target
- Eos Nomad (free) supports full OSC bidirectional capability for SDK development — no cost
- Show Control settings must be enabled manually on the console (Setup > Device > Network)

---

### ChamSys MagicQ (MQ500, MQ250, MQ80, MQ70, MQ60, MQ40)

**Connection:** OSC over UDP (user-configurable ports, >1024). Also: ChamSys Remote Ethernet Protocol (CREP) on port 6553.

**What ShowUp can do:**
- Control playbacks 1-10 via built-in OSC addresses (`/ch/playback/{n}/go`, `/ch/playback/{n}/level`)
- Fire macros via `/ch/macro/{n}/go`
- Send command strings
- Share the network via sACN
- Import MVR files
- Import GDTF fixture definitions (first major console to support GDTF)
- Detect MagicQ on the network via ArtPoll

**Bidirectional feedback (built-in, no plugins needed):**
- **`/feedback/pb+exec`** — MagicQ automatically transmits playback and execute state changes. ShowUp knows when playbacks fire, release, and where faders are.
- **`K` macro prefix** — Any cue's macro field can include `K/showup/cue/fired,3` to send an OSC message when that specific cue executes. This is precise per-cue feedback.
- **`mqosc` generic personality** — A patchable 1-channel "fixture" that transmits an OSC message whenever its DMX value changes. Put it on a fader; value changes become OSC. Effectively turns any DMX channel into an OSC control channel.
- **MIDI transmit** — MagicQ sends MIDI notes when main playbacks are operated. Configurable via `miditable.txt`. ShowUp can listen for MIDI to know playback state.

**Console fader → ShowUp parameter (built-in):**
- `mqosc` personality on a fader → value changes transmit as OSC → ShowUp maps to parameter
- Or: use `/feedback/pb+exec` to read playback fader positions directly
- Or: CREP binary protocol for full bidirectional playback state

**Alternative protocols:**
- **CREP (ChamSys Remote Ethernet Protocol):** UDP port 6553. Binary packet: `CREP` header + version + sequence + ASCII commands. Bidirectional — send commands and receive state. Documented for third parties.
- **DMX input → AUTOM:** Incoming DMX values on specified channels can trigger playback, cue stack, macro, or layout functions. ShowUp could output a DMX "control channel" that MagicQ acts on.
- **CSV palette export:** Color, position, and beam palettes can be exported as CSV with raw values. ShowUp can parse these to populate its color palette with the console's palette colors.

**What ShowUp cannot do:**
- Control more than 10 playbacks without AUTOM configuration on the console side
- Use TCP (UDP only)
- Use OSC on MQ40 and MQ40N consoles (not supported on these models)
- Use OSC on MagicQ PC without "Unlocked Mode" (requires ChamSys hardware dongle)
- Parse `.shw` show files directly (proprietary binary)

**Special considerations:**
- MagicQ PC/Mac/Linux is free with 64 universes — but OSC/MIDI requires hardware dongle for "Unlocked Mode"
- MagicQ's feedback capabilities were significantly undersold in initial research — it has more bidirectional options than any console except Eos

---

### Obsidian Onyx (NX4, NX2, NX1, NX Wing)

**Connection:** Telnet API on port 2323 (primary, via Onyx Manager). Also: OSC over UDP (ShowCockpit driver), MIDI/MSC input, UDP commands.

**What ShowUp can do via Telnet API (port 2323):**
- **Fire any cuelist:** `GQL {n}` — no 10-fader limit, works with any cuelist number
- **Go to specific cue:** `GTQ {cuelist},{cue}` — direct cue access within any cuelist
- **Release cuelist:** `RQL {n}` — release a specific cuelist
- **Pause cuelist:** `PQL {n}` — pause playback
- **Set cuelist level:** `SQL {n},{level}` — set fader level 0-255 for ANY cuelist
- **Release all:** `RAQL` (all cuelists), `RAQLO` (cuelists + overrides), `RAQLDF` (dimmer first)
- **Release all overrides:** `RAO`
- **Clear programmer:** `CLRCLR`
- **List all cuelists:** `QLList` — returns cuelist numbers and names (e.g., "00002 - House Lights")
- **List active cuelists:** `QLActive` — returns which cuelists are currently running
- **Check cuelist state:** `IsQLActive {n}` — boolean active check

**What ShowUp can do via OSC (ShowCockpit driver):**
- Control playback faders 1-10 and buttons 1-20 (Go/Pause/Release)
- Set GrandMaster and FlashMaster levels
- Trigger 50+ keyboard functions
- Use MIDI Show Control (MSC) for cue triggers

**Bidirectional feedback (Telnet API transforms this):**
- **`QLActive` polling at 1Hz** — ShowUp knows which cuelists are active and can detect when new cues fire. This was previously listed as impossible.
- **`QLList` on connect** — ShowUp imports all cuelist names to populate Console Quick Action buttons. Previously listed as "no export mechanism."
- **`IsQLActive {n}`** — check specific cuelist state on demand
- **OSC feedback** for main playback faders/buttons (via ShowCockpit)
- **DMX sniffing via sACN** — read Onyx's output to capture fixture state (universal fallback)

**Console fader → ShowUp parameter:**
- `SQL {n},{level}` read-back via polling — ShowUp can track cuelist levels
- Main playback fader positions via OSC (ShowCockpit feedback)
- DMX control channel convention as additional fallback (U16/Ch500)

**What the Telnet API does NOT solve:**
- No MVR or GDTF support (still no rig data export)
- No palette/preset data export (cuelist names only, not contents)
- No per-fixture parameter feedback beyond DMX sniffing
- Requires Onyx Manager running on the console
- No MIDI output from Onyx (still receive-only)
- Show files (.ONYX) remain proprietary binary

**Software tier considerations:**

| Tier | Universes | OSC/MIDI | Telnet API | Notes |
|------|-----------|----------|------------|-------|
| FREE | 1 | 5-min trial | **Needs verification** | Onyx Manager required |
| NOVA | 4 | Trial only | **Needs verification** | Requires NX-DMX or NETRON |
| NOVA+ | 4 | **Full** | **Full** | Requires NX-Touch/K/P |
| LIVE 8-128 | 8-128 | **Full** | **Full** | License key required |

**Special considerations:**
- The Telnet API (port 2323) bypasses ShowCockpit's limitations entirely — direct cuelist control with no 10-fader cap
- Onyx Manager must be running on the controller for Telnet to work
- Community-proven: [obsidian_onyx_python](https://github.com/jeffmikels/obsidian_onyx_python) and [Bitfocus Companion](https://github.com/bitfocus/companion-module-obsidiancontrol-onyx) both use this API successfully
- Port labeling is inverted for OSC: Onyx's "Output Port" = ShowUp's input
- Telnet + DMX sniffing together provide a workable integration despite Onyx's API limitations

---

## Console Feature Gap Analysis

### Protocol Support Matrix

| Feature | GrandMA3 | ETC Eos | ChamSys MQ | Onyx |
|---------|:--------:|:-------:|:----------:|:----:|
| OSC Output (ShowUp → Console) | Yes (via /cmd) | **Best** (dedicated addresses) | Yes (10 PBs built-in) | Limited (10 faders via OSC) |
| Telnet/TCP Control | No | No | No | **Yes — any cuelist, any cue** |
| OSC Input (Console → ShowUp) | **Lua plugin** | **Full native** | **Built-in feedback** | Main PBs only |
| MIDI Show Control | No | **Yes** (32 sources) | Partial | **Yes** |
| MIDI Transmit (Console → ShowUp) | Notes only | MSC + Notes | **Notes on playback** | None |
| sACN Output | Yes | **Yes (inventor)** | Yes | Yes |
| sACN Priority Merging | Yes | Yes | Yes | Yes |
| Art-Net | Yes | Yes | Yes | Yes |
| MVR Import/Export | **Yes (co-creator)** | Yes (import) | Yes (import) | **No** |
| GDTF Fixtures | **Yes (co-creator)** | Yes (limited) | Yes (first adopter) | **No** |
| Bidirectional State | **Yes (via plugin)** | **Yes (native)** | **Yes (built-in)** | **Yes (Telnet polling)** |
| Cuelist Names Readable | Via XML export | Via OSC query | Via CSV export | **Yes (QLList via Telnet)** |
| Alternative Protocol | Lua API, WebSocket | — | **CREP (binary UDP)** | **Telnet API (port 2323)** |
| Free Software | onPC (no DMX out) | Nomad (no DMX out) | **64 universes free** | 1 universe free |

### Integration Quality by Use Case

| Use Case | GrandMA3 | ETC Eos | ChamSys MQ | Onyx |
|----------|:--------:|:-------:|:----------:|:----:|
| Fire cues from ShowUp moments | **Good** | **Excellent** | **Good** | **Good (Telnet GTQ)** |
| Capture console looks (DMX) | **Good** | **Excellent** | **Good** | Good |
| Console fader → ShowUp control | **Good (plugin)** | **Excellent (native)** | **Good (built-in)** | **Good (Telnet SQL poll)** |
| Know when console fires a cue | **Good (plugin)** | **Excellent (events)** | **Good (K macro)** | **Good (QLActive poll)** |
| Import cuelist names | Via XML export | Via OSC query | Via CSV export | **Yes (QLList via Telnet)** |
| Import console's fixture patch | **Excellent** (MVR+GDTF) | Good (MVR+GDTF) | Good (MVR+GDTF+CSV) | **CSV only** |
| Import console's color palettes | XML export | CSV export | **CSV palette export** | **No export** |
| Console preset → ShowUp Look | DMX capture + XML | **OSC query + CSV** | DMX capture + CSV | **DMX capture + Telnet** |
| Auto-failover on disconnect | Good | Good | Good | Good |
| Universe priority merging | Good | **Excellent** | Good | Good |

### Integration Grades

| Console | Grade | Rationale |
|---------|:-----:|-----------|
| GrandMA3 | **A-** | Lua plugin solves the feedback gap. Strong MVR/GDTF. Command-based OSC is flexible. WebSocket is a bonus target. |
| ETC Eos | **A+** | Best integration of any console. Full bidirectional OSC with cue events, fader feedback, palette queries. |
| ChamSys MQ | **B+** | Built-in feedback was undersold initially. CREP protocol adds a real bidirectional channel. MIDI transmit. Best free software. |
| Onyx | **B-** | Telnet API (port 2323) transforms integration — cuelist names, active state polling, direct cue/fader control with no 10-fader cap. Still no MVR/GDTF/palette export. |

### Recommended Coexistence Mode by Console

| Console | Best Mode | Why |
|---------|-----------|-----|
| GrandMA3 | **Any mode (with plugin)** | Lua plugin makes all modes viable. Layer Mode is natural for touring where ShowUp adds reactive ambiance beneath the LD's programming. |
| ETC Eos | **Any mode** | Eos's rich bidirectional OSC makes all modes work equally well. Trigger Mode is especially powerful because ShowUp can subscribe to cue execution events. |
| ChamSys MQ | **Side by Side** or **Trigger** | Built-in playback feedback makes Trigger Mode more viable than initially assessed. Side by Side avoids the 10-playback limit. |
| Onyx | **Trigger Mode** (via Telnet + MSC) | Telnet API bypasses OSC's 10-fader limit — direct cuelist control + active state polling. MSC for MIDI-based triggering. DMX sniffing for look capture. |

---

## ShowUp Integration Points

### Persistence Layer

The SDK extends ShowUp's existing `.showup-stage` and `.showup-show` file formats:

**Stage file** (venue hardware) gains:
- `coexistenceMode` — solo / sideBySide / triggerOnly / layered
- `consoleProfileId` — which console profile is active
- `consoleConnection` — IP, OSC port, protocol
- `universeRoles` — per-universe ownership (ShowUp / Console / Shared)
- `sacnTargets` — sACN output configuration
- `failoverConfig` — auto-takeover settings

**Show file** (performance) gains:
- `consoleTriggerBindings` — moment/macro → console command mappings
- `capturedLooks` — DMX snapshots from console with raw channel data
- `timecodeMarkers` — MTC position → moment activation links

### Activation Flow

When a user taps a moment in ShowUp's Perform screen:

```
User taps "Chorus"
  → ShowUp applies the Chorus look (colors, movement, dimmer)
  → SDK's TriggerRouter fires the mapped console command:
      GrandMA3: /gma3/cmd "Go+ Cue 3"
      ETC Eos:  /eos/cue/1/3/fire
      ChamSys:  /ch/playback/1/go
      Onyx:     MSC GO Cue 3
  → Console executes its Cue 3
  → Both systems transition simultaneously
```

When a user taps a macro like "Big Finish":

```
User taps "Big Finish"
  → ShowUp fires its WOW strobe effect (3-second ramp)
  → SDK simultaneously sends console blackout command
  → ShowUp strobes on its universes
  → Console goes dark on its universes
  → Coordinated multi-system effect from one tap
```

### Failover

```
Console goes offline (heartbeat timeout)
  → SDK detects via ArtPoll/OSC heartbeat monitoring
  → If failover enabled:
      → ShowUp temporarily takes over console-owned universes
      → Applies fallback look (last capture / ambient / blackout)
      → Shows notification: "Console offline — ShowUp taking over"
  → Console comes back online:
      → ShowUp fades back to its own universes over 2 seconds
      → Console regains control seamlessly
```

---

## Companion Plugins

The SDK includes console-side scripts that extend feedback capabilities beyond what stock console software provides.

### `companion_plugins/grandma3/ShowUpCompanion.lua`
A Lua plugin that runs directly on the GrandMA3 console. Polls executor state at ~10Hz and broadcasts to ShowUp via OSC:
- Fader positions for executors 201-215 (configurable)
- Active playback state (playing/released)
- Current cue name and number per sequence
- Page change notifications

Installation: Copy to `/ma/ma3_library/datapools/plugins/` on the console. Add an OSC "In & Out" entry pointing to ShowUp's IP. The plugin auto-starts and requires no further configuration.

### `companion_plugins/chamsys/ShowUpCueMacros.txt`
A set of `K` macro templates for ChamSys cue stacks. Each cue can include `K/showup/cue/fired,{cue_number}` in its macro field to notify ShowUp when that specific cue executes. The file provides copy-pasteable macro strings for common workflows.

### Console-Side DMX Control Channel Convention
For consoles without rich OSC feedback (especially Onyx), the SDK defines a convention:
- Patch a dimmer-only fixture at Universe 16, Address 500
- Assign it to a fader labeled "ShowUp"
- ShowUp reads this channel via sACN input and maps its value (0-255) to master dimmer (0.0-1.0)
- Additional channels at 501-504 can map to color speed, movement speed, effect intensity, and excitement

This is a universal fallback that works with ANY console on ANY network.

---

## Console → ShowUp Sync

### What Can Flow from Console to ShowUp

**ETC Eos (richest):**
- Cue execution events → auto-advance ShowUp moments
- Fader positions → control ShowUp parameters in real-time
- Palette names and channel assignments → populate ShowUp's look library metadata
- Active channel selections → highlight corresponding ShowUp fixture groups
- Group definitions → suggest ShowUp group mappings

**GrandMA3 (via Companion Plugin):**
- Executor fader positions → control ShowUp parameters
- Active cue per sequence → sync ShowUp moment state
- Page changes → switch ShowUp's active event pack or bank

**ChamSys MagicQ (built-in):**
- Playback state changes → sync ShowUp moment state
- Per-cue OSC via K macros → precise cue-to-moment mapping
- MIDI note-on for playbacks → ShowUp knows which playback fired
- Palette CSV export → import console colors into ShowUp's palette

**Obsidian Onyx (limited):**
- Main playback fader positions → limited ShowUp parameter control
- DMX channel sniffing → infer console state from output
- MSC commands (inbound) → ShowUp can listen for MSC it receives

### Console Shortcuts in ShowUp's Perform Screen

ShowUp's Perform screen has room for additional "looks" real estate. The SDK enables **Console Quick Actions** — a row of buttons in ShowUp's Perform screen that map directly to console-specific operations:

**Imported from console (when data is available):**
- Cue list names from Eos OSC queries → "Front Wash", "Blue Backlight" buttons
- Palette names from ChamSys CSV export → quick color recall buttons
- Captured look thumbnails → visual recall of console states

**User-configurable console shortcuts:**
- "Console Cue 5" → fires a specific cue without a moment mapping
- "Console Macro 3" → fires a console macro independently
- "Console Blackout" → sends the console's blackout command
- "Console Release All" → releases all playbacks on the console
- "Console Next Cue" → advances the console's active cue list

These appear in a collapsible "Console" section on the Perform screen, visually distinguished with blue (console-blue) styling. They're stored in the show file alongside trigger bindings.

---

## Technical Specifications

| Specification | Value |
|---------------|-------|
| Language | Dart (pure, no Flutter dependency) |
| Files | 38 source files |
| Lines of code | ~5,400 |
| Dependencies | `collection` only |
| sACN packet format | ANSI E1.31-2018 |
| sACN port | 5568 (standard) |
| Art-Net port | 6454 (standard) |
| OSC format | OSC 1.0 over UDP |
| MIDI format | CoreMIDI via dart:ffi (macOS/iOS) |
| MSC format | MIDI SysEx per MIDI Show Control spec |
| DMX refresh rate | 44Hz (matches ShowUp engine) |
| Max universes | 16 (expandable) |
| Console profiles | 4 built-in + custom |
| Import formats | MVR (ZIP/XML), GDTF (ZIP/XML), CSV/TSV |
