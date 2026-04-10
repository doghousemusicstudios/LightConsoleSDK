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

**Connection:** OSC over UDP, default port 8000.

**What ShowUp can do:**
- Fire cues via `/gma3/cmd` with text commands ("Go+ Cue 3")
- Set fader levels via `/gma3/Page{n}/Fader{n}` with float values
- Fire macros via `/gma3/cmd` ("Macro 1")
- Send any MA3 command-line instruction via OSC
- Share the network via sACN priority-based merging
- Import MVR files exported from MA3 (native MVR support)
- Import GDTF fixture definitions (MA co-created the standard)
- Detect MA3 on the network via ArtPoll OEM codes

**What ShowUp cannot do:**
- Receive per-fader position feedback (MA3 only sends sequence-level feedback natively; a third-party plugin is needed for per-fader OSC output)
- Use MIDI Show Control (MA3 does not support MSC)
- Receive cue state changes without polling

**Special considerations:**
- MA3 uses a command-based OSC API — most operations go through `/gma3/cmd` with a text body, unlike the address-based APIs of other consoles
- OSC bundles are not supported
- Localhost port conflicts are possible if ShowUp runs on the same machine

---

### ETC Eos Family (Eos, Ion, Element, ColorSource)

**Connection:** OSC over TCP (preferred, port 3032) or UDP. Third-party port 3037.

**What ShowUp can do:**
- Fire cues via `/eos/cue/{list}/{cue}/fire`
- Set fader levels via `/eos/fader/{bank}/{index}` (0.0-1.0)
- Control individual channels via `/eos/chan/{chan}`
- Fire macros via `/eos/macro/{macro}/fire`
- Send command-line instructions via `/eos/cmd`
- **Receive full bidirectional feedback** — fader positions, wheel values, active cue info, patch data via `/eos/out/` addresses
- Use MIDI Show Control (MSC) for cue triggers
- Share the network via sACN (ETC invented sACN / E1.31)
- Import MVR files (Eos v3.2+)
- Import GDTF fixture definitions (Eos v3.2.4+)
- Detect Eos on the network via ArtPoll

**What ShowUp cannot do:**
- Receive GDTF multi-cell fixture data (import limitation)
- Control ColorSource non-AV models (reduced networking on base models)

**Special considerations:**
- Eos has the most comprehensive OSC API of any lighting console — it's the best integration target
- TCP is preferred over UDP for reliability; supports both OSC 1.0 and 1.1 (SLIP) framing
- 3-second debounce on fader feedback after OSC-driven moves
- Show Control settings must be enabled manually on the console

---

### ChamSys MagicQ (MQ500, MQ250, MQ80, MQ70, MQ60, MQ40)

**Connection:** OSC over UDP, user-configurable ports (must be >1024).

**What ShowUp can do:**
- Control playbacks 1-10 via built-in OSC addresses (`/ch/playback/{n}/go`, `/ch/playback/{n}/level`)
- Fire macros via `/ch/macro/{n}/go`
- Send command strings
- Share the network via sACN
- Import MVR files
- Import GDTF fixture definitions (first major console to support GDTF)
- Detect MagicQ on the network via ArtPoll

**What ShowUp cannot do:**
- Control more than 10 playbacks without AUTOM (automation) configuration on the console side
- Use TCP (UDP only — less reliable delivery)
- Use OSC on MQ40 and MQ40N consoles (not supported on these models)
- Use OSC on MagicQ PC without "Unlocked Mode"

**Special considerations:**
- MagicQ PC/Mac/Linux is free with 64 universes of output — the best free offering of any console
- The 10-playback OSC limitation means users with complex cue layouts need to configure AUTOM on the console for broader control
- OSC bundles can be received but not transmitted
- Control network requires firewall disable for OSC on some configurations

---

### Obsidian Onyx (NX4, NX2, NX1, NX Wing)

**Connection:** OSC over UDP, user-configurable ports.

**What ShowUp can do:**
- Control playback faders 1-10 and buttons 1-20 (Go/Pause/Release)
- Set GrandMaster and FlashMaster levels
- Trigger 50+ keyboard functions via OSC
- Use MIDI Show Control (MSC) for cue triggers — Onyx's strongest integration point
- Use MIDI notes and timecode
- Share the network via sACN and Art-Net
- Detect Onyx on the network via ArtPoll

**What ShowUp cannot do:**
- Import MVR files (Onyx does not support MVR export)
- Import GDTF fixture definitions natively (not confirmed in current versions)
- Use OSC/MIDI in FREE mode (restricted to evaluation periods)
- Receive bidirectional OSC feedback
- Control more than 10 playback faders via OSC

**Special considerations:**
- ONYX FREE mode limits output to 1 universe and restricts OSC/MIDI to evaluation — this is a significant limitation for free-tier users
- Port labeling is inverted: Onyx's "Output Port" maps to the external tool's "Input Port" and vice versa
- MIDI/MSC is the strongest protocol path for Onyx integration
- Missing MVR/GDTF means rig import requires CSV patch export from Onyx

---

## Console Feature Gap Analysis

### Protocol Support Matrix

| Feature | GrandMA3 | ETC Eos | ChamSys MQ | Onyx |
|---------|:--------:|:-------:|:----------:|:----:|
| OSC Output (ShowUp → Console) | Yes | **Best** | Limited (10 PBs) | Limited (10 faders) |
| OSC Input (Console → ShowUp) | Plugin needed | **Full native** | Unknown | No |
| MIDI Show Control | **No** | Yes | Partial | **Yes** |
| MIDI Notes/CC | Yes | Yes | Yes | Yes |
| sACN Output | Yes | **Yes (inventor)** | Yes | Yes |
| sACN Priority Merging | Yes | Yes | Yes | Yes |
| Art-Net | Yes | Yes | Yes | Yes |
| MVR Import/Export | **Yes (native)** | Yes (import) | Yes (import) | **No** |
| GDTF Fixtures | **Yes (co-creator)** | Yes (limited) | Yes | **No** |
| Bidirectional Faders | **No** | **Yes** | No | No |
| Free Software | No | Nomad (limited) | **64 universes** | 1 universe |

### Integration Quality by Use Case

| Use Case | GrandMA3 | ETC Eos | ChamSys MQ | Onyx |
|----------|:--------:|:-------:|:----------:|:----:|
| Fire cues from ShowUp moments | Good | **Excellent** | Good | Good (MSC) |
| Capture console looks | Good | **Excellent** | Good | Good |
| Console fader → ShowUp control | Requires plugin | **Native** | Limited | No |
| Import console's fixture patch | **Excellent** (MVR+GDTF) | Good (MVR) | Good (MVR+GDTF) | **CSV only** |
| Auto-failover on disconnect | Good | Good | Good | Good |
| Universe priority merging | Good | **Excellent** | Good | Good |
| Zero-config detection | Good | Good | Good | Good |

### Recommended Coexistence Mode by Console

| Console | Best Mode | Why |
|---------|-----------|-----|
| GrandMA3 | **Side by Side** or **Layer** | MA3's command-based OSC works well for triggers, but lack of bidirectional feedback makes full Layer mode the sweet spot — ShowUp fills reactive gaps |
| ETC Eos | **Any mode** | Eos's rich bidirectional OSC makes all modes work equally well. Trigger Mode is especially powerful because ShowUp can read back cue state |
| ChamSys MQ | **Side by Side** | The 10-playback OSC limit means Trigger Mode works best for simple shows. Side by Side avoids OSC limitations entirely |
| Onyx | **Trigger Mode** (via MSC) | Onyx's OSC is limited, but MSC support is solid. MIDI triggers bypass OSC limitations. CSV patch import fills the MVR gap |

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
