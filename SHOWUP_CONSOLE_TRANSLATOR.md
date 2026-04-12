# ShowUp Console Translator

**Every ShowUp action mapped to every console. Every console event mapped back to ShowUp.**

---

## Part 1: ShowUp → Console (Outbound)

What happens at the console when a user does something in ShowUp.

---

### Moment Activation

**ShowUp action:** User taps a moment card (e.g., "Chorus") in Perform.

| Console | Protocol | Command Sent | Notes |
|---------|----------|-------------|-------|
| GrandMA3 | OSC | `/gma3/cmd,s,"Go+ Cue 3"` | Cue number from trigger binding. Text command via /cmd. |
| ETC Eos | OSC | `/eos/cue/1/3/fire` | List/cue from binding. Dedicated address, no text parsing. |
| ETC Eos | MSC | `F0 7F 01 02 01 01 33 00 31 F7` | MSC GO, Cue 3, List 1. SysEx format. |
| ChamSys MQ | OSC | `/ch/playback/1/go` | Playback number from binding. Built-in for PB 1-10. |
| Onyx | Telnet | `GTQ 1,3\r\n` | **Primary.** Go to cuelist 1, cue 3. Any cuelist, any cue. Port 2323. |
| Onyx | MSC | `F0 7F 01 02 01 01 33 F7` | Backup. MSC GO, Cue 3. Via MIDI. |
| Onyx | OSC | `/Mx/Cuelist/1/Go` | Last resort. Via ShowCockpit. Limited to 10 cuelists. |
| Avolites | HTTP | `GET /titan/script/Playbacks/FirePlaybackAtLevel?userNumber=3&level=1.0` | **HTTP with confirmed response.** Port 4430. |

**Execution modes per binding:**
- `showupOnly` — ShowUp applies its look; no console command sent
- `consoleOnly` — Console command fires; ShowUp suppresses its own look
- `both` — ShowUp applies its look AND fires the console command simultaneously
- `sequential` — ShowUp first, then console (or reverse), with configurable delay

---

### Macro Fire

**ShowUp action:** User taps a macro button (e.g., "Big Finish") in Perform.

| Console | Protocol | Command Sent | Notes |
|---------|----------|-------------|-------|
| GrandMA3 | OSC | `/gma3/cmd,s,"Macro 1"` | Macro number from binding. |
| ETC Eos | OSC | `/eos/macro/1/fire` | Dedicated macro fire address. |
| ChamSys MQ | OSC | `/ch/macro/1/go` | Macro execute via built-in OSC. |
| Onyx | Telnet | `GQL {n}\r\n` | Fire cuelist containing the macro. Or use dedicated macro cuelist. |
| Onyx | MSC | `F0 7F 01 02 01 07 31 F7` | MSC FIRE macro. Backup path via MIDI. |
| Avolites | HTTP | `GET /titan/script/Playbacks/FirePlaybackAtLevel?userNumber={n}&level=1.0` | Fire playback as macro. |

**Common macro → console pairings:**

| ShowUp Macro | Console Action | Why |
|-------------|----------------|-----|
| **Lift** | Console cue: brighter wash | Energy increase across both systems |
| **Pull Back** | Console cue: dim to 50% | Coordinated energy decrease |
| **Big Finish** | Console: blackout or strobe cue | ShowUp strobes its universes + console goes dark |
| **Reset Room** | Console: house lights up | ShowUp fades to ambient + console brings up work lights |
| **Room Glow** | Console: warm preset | Both systems transition to a warm idle state |

---

### Master Dimmer Change

**ShowUp action:** User adjusts the master dimmer slider.

| Console | Protocol | Command Sent | Notes |
|---------|----------|-------------|-------|
| GrandMA3 | OSC | `/gma3/Page1/Fader{n},f,0.75` | Optional. Map a specific executor to mirror ShowUp's master. |
| ETC Eos | OSC | `/eos/fader/1/{n},f,0.75` | Fader bank/index from binding. Float 0.0-1.0. |
| ChamSys MQ | OSC | `/ch/playback/{n}/level,i,192` | Level as 0-255 int. |
| Onyx | Telnet | `SQL {n},{level}\r\n` | Set any cuelist level, 0-255. No fader limit. Port 2323. |
| Onyx | OSC | `/Playbacks/1/Fader,f,0.75` | MainPlaybackFader via ShowCockpit. Limited to 10. |
| Avolites | HTTP | `GET /titan/script/Playbacks/FirePlaybackAtLevel?userNumber={n}&level=0.75` | Level 0.0-1.0 via HTTP. |

**When to mirror dimmer to console:** Only in Layer or Trigger mode where ShowUp wants the console to match its overall intensity. In Side by Side mode, dimmers are independent.

---

### Color/Movement Effect Change

**ShowUp action:** User changes color effect (e.g., "Rainbow") or movement (e.g., "Circle").

**Console translation:** Effects are ShowUp-native and procedural — they don't have direct console equivalents. However:

| Scenario | Console Action | Protocol |
|----------|---------------|----------|
| ShowUp changes mood/energy | Fire matching console cue | OSC/MSC trigger binding |
| ShowUp wants console to match intensity | Set console master fader | OSC fader command |
| ShowUp wants console to hold static | No command (console stays on current cue) | — |
| ShowUp wants console to blackout its fixtures | Fire console blackout cue | OSC/MSC cue fire |

**Key insight:** ShowUp doesn't translate its procedural effects into console parameters. Instead, it orchestrates *when* the console changes cues to complement what ShowUp is doing reactively. The console holds static states; ShowUp provides the motion.

---

### Event Pack / Mood Change

**ShowUp action:** User switches event pack (e.g., "Concert Pack" → "Wedding Pack") or mood.

| Console | What Happens |
|---------|-------------|
| GrandMA3 | Optional: fire a macro that loads a different page or sequence on the console |
| ETC Eos | Optional: switch to a different cue list via `/eos/cmd,s,"CueList 2"` |
| ChamSys MQ | Optional: change playback page or fire a different cue stack |
| Onyx | Optional: switch cuelist bank |

**This is a workflow-level mapping**, not a data translation. When the DJ switches from "Dinner" to "Dancing" in ShowUp, the console could optionally switch from its dinner cue stack to its dance cue stack. Configuration is manual — the user maps "when I switch to pack X, tell the console to do Y."

---

### Look Recall (Captured Look)

**ShowUp action:** User recalls a previously captured look (DMX snapshot from the console).

| Mode | What Happens |
|------|-------------|
| Side by Side | ShowUp outputs the captured DMX values on its own universes only. Console is unaffected. |
| Layer | ShowUp outputs captured values at its configured sACN priority. Console's output takes precedence if active. |
| Trigger | ShowUp sends a trigger to fire the original console cue that was active during capture. No DMX from ShowUp. |

**Captured look recall has two paths:**
1. **Raw DMX replay** — Exact channel values from capture. Perfect reproduction but static (no reactive animation).
2. **Effect parameter approximation** — Best-guess color/movement/dimmer from the capture. Editable in ShowUp's UI but imperfect.

---

### Console Quick Action (New Feature)

**ShowUp action:** User taps a console shortcut button in the "Console" section of Perform.

These are direct console commands that don't correspond to ShowUp looks or effects — they're pure console remote control:

| Quick Action | GrandMA3 | ETC Eos | ChamSys MQ | Onyx | Avolites |
|-------------|----------|---------|------------|------|----------|
| **Fire Cue {n}** | `/gma3/cmd "Go+ Cue {n}"` | `/eos/cue/1/{n}/fire` | `/ch/playback/1/go` | `GTQ 1,{n}` | `FirePlaybackAtLevel?userNumber={n}` |
| **Next Cue** | `/gma3/cmd "Go+"` | `/eos/cue/1/0/fire` | `/ch/playback/1/go` | `GQL 1` | N/A (fire by number) |
| **Previous Cue** | `/gma3/cmd "GoBack"` | `/eos/cue/1/back` | `/ch/playback/1/back` | MSC GO_BACK | N/A |
| **Blackout** | `/gma3/cmd "BlackOut"` | `/eos/cmd "Blackout"` | `/ch/playback/0/release` | `RAQLDF` | `KillAllPlaybacks` |
| **Release All** | `/gma3/cmd "Off Exec *"` | `/eos/cmd "Release"` | `/ch/release/all` | `RAQLO` | `KillAllPlaybacks` |
| **Console Macro {n}** | `/gma3/cmd "Macro {n}"` | `/eos/macro/{n}/fire` | `/ch/macro/{n}/go` | MSC FIRE {n} | N/A (fire playback) |
| **Set Fader** | `/gma3/Page1/Fader{n},f,val` | `/eos/fader/1/{n},f,val` | `/ch/playback/{n}/level` | `SQL {n},{val}` | `FirePlaybackAtLevel?level={val}` |

---

## Part 2: Console → ShowUp (Inbound)

What happens in ShowUp when the console does something.

---

### Console Fires a Cue → ShowUp Advances Moment

**How ShowUp knows a cue fired:**

| Console | Mechanism | Address/Data |
|---------|-----------|-------------|
| GrandMA3 | Companion Lua Plugin | `/showup/cue/active,s,"Cue 3"` (plugin broadcasts active cue) |
| ETC Eos | Native OSC event | `/eos/out/event/cue/1/3/fire` (automatic on cue execution) |
| ChamSys MQ | K macro in cue | `K/showup/cue/fired,3` (added to cue's macro field) |
| Onyx | Telnet `QLActive` polling | Poll at 1Hz; detect when cuelist becomes active/inactive. Returns cuelist numbers + names. |

**What ShowUp does with this information:**
1. Look up which ShowUp moment maps to this console cue (reverse trigger binding lookup)
2. Activate that moment — apply its look, effects, and energy level
3. Update the Perform screen to highlight the active moment
4. If no mapping exists, log the event but take no action

**This enables "console-driven show flow":** The LD runs cues on the console; ShowUp automatically follows with matching reactive looks. The operator doesn't need to touch ShowUp at all during the show.

---

### Console Fader Moves → ShowUp Parameter Changes

**How ShowUp reads fader values:**

| Console | Mechanism | Address/Data | Latency |
|---------|-----------|-------------|---------|
| GrandMA3 | Companion Plugin | `/showup/fader/201,f,0.75` | ~100ms (10Hz poll) |
| ETC Eos | Native OSC output | `/eos/out/fader/1/1,f,0.75` | ~100ms (10Hz on port 3037) |
| ChamSys MQ | `/feedback/pb+exec` | Auto-transmitted on change | Near-instant |
| ChamSys MQ | `mqosc` personality | OSC on DMX value change | 1 DMX frame (~22ms) |
| Onyx | Telnet `SQL` polling | Poll `IsQLActive` + level at 1Hz | ~1s latency |
| Onyx | Main PB faders (OSC) | OSC via ShowCockpit | Near-instant for main PBs |
| Any console | DMX sniffing fallback | sACN input, U16/Ch500 | 1 DMX frame (~22ms) |

**Default parameter mappings (user-configurable):**

| Console Fader | ShowUp Parameter | Range |
|--------------|-----------------|-------|
| Fader 1 (or designated) | Master Dimmer | 0.0 → 1.0 |
| Fader 2 | Color Speed | 0.0 → 1.0 |
| Fader 3 | Movement Speed | 0.0 → 1.0 |
| Fader 4 | Effect Intensity / Excitement | 0.0 → 1.0 |
| Fader 5 | Warmth | 0.0 → 1.0 |

**Override behavior:** When a console fader controls a ShowUp parameter, that parameter shows an "override" badge in ShowUp's UI. If no fader input is received for 10 seconds, the override releases and ShowUp resumes local control.

---

### Console Changes Color/Position → ShowUp Captures or Complements

**Via DMX sniffing (sACN input) — works with ALL consoles:**

| What ShowUp Reads | What ShowUp Does |
|------------------|-----------------|
| Console fixture RGB values change | In "Complement" mode: analyze dominant color, generate contrasting palette on ShowUp's fixtures |
| Console fixture intensity drops to 0 | ShowUp can increase its own output to fill the gap (Layer mode) |
| Console fixture pan/tilt moves | ShowUp can avoid the same positions or match them (configurable) |
| Console fires a dramatic blackout | ShowUp detects zero output, optionally fires its own dramatic effect |

**This is passive observation**, not protocol-level events. ShowUp reads the DMX output and infers intent. Works with any console on any network.

---

### Console Exports Palette Data → ShowUp Imports Colors

**One-time import workflow (not real-time sync):**

| Console | Export Format | What ShowUp Gets |
|---------|-------------|-----------------|
| GrandMA3 | XML export from console | Cue names, timing data, partial fixture values |
| ETC Eos | CSV export (File > Export) | Cue list structure, channel values per cue, metadata |
| ETC Eos | OSC query | `/eos/out/get/cp/{n}` returns palette name + channels |
| ChamSys MQ | CSV palette export | Raw color/position/beam values per palette entry |
| Onyx | Telnet `QLList` | Cuelist names and numbers (not palette data or fixture values) |

**How this populates ShowUp:**
- Color palette entries → ShowUp's custom palette colors (6 slots + extended)
- Cue names → ShowUp moment labels and console quick action buttons
- Position palettes → ShowUp's centreX/centreY preset positions
- Group definitions → Suggested ShowUp fixture group mappings

---

## Part 3: Console Shortcuts in ShowUp's Perform Screen

ShowUp's Perform screen has additional "looks" real estate that can display **Console Quick Actions** — a dedicated section for console-sourced controls.

---

### What Gets Imported

**From ETC Eos (richest source):**
```
OSC Query: /eos/out/get/cuelist/1
  → Cue list "Main Show": 12 cues
  → ShowUp creates 12 Quick Action buttons:
    [Cue 1: Preshow] [Cue 2: Intro] [Cue 3: Verse] ...

OSC Query: /eos/out/get/group/count → 8 groups
  → ShowUp suggests group mappings:
    "Front Wash" → ShowUp group "Front"
    "Back Truss" → ShowUp group "Back"

OSC Query: /eos/out/get/cp/count → 6 color palettes
  → ShowUp imports palette colors:
    "Deep Blue" → palette slot 1
    "Warm Amber" → palette slot 2
```

**From ChamSys MQ (via CSV export):**
```
CSV palette import:
  Color palette "Summer" → ShowUp palette slot 1
  Color palette "Winter" → ShowUp palette slot 2
  Position palette "Stage Left" → centreX = 0.25
  Position palette "Stage Right" → centreX = 0.75
```

**From GrandMA3 (via XML export + Companion Plugin):**
```
XML export: sequences and cue names
  → ShowUp creates Quick Action buttons from cue names

Companion Plugin: active page/executor layout
  → ShowUp mirrors the executor labels as Quick Action buttons
```

**From Onyx (via Telnet API):**
```
Telnet: QLList
  → "00001 - Main Show"
  → "00002 - House Lights"
  → "00005 - Dance Floor"
  → "00008 - Specials"
  → ShowUp creates Quick Action buttons:
    [Main Show] [House Lights] [Dance Floor] [Specials]
    Each fires GQL {n} via Telnet on tap.

Telnet: QLActive (polled at 1Hz)
  → ShowUp highlights active cuelists in the Quick Actions row
```

---

### How Console Shortcuts Appear in ShowUp

**Perform screen layout (with console connected):**

```
┌─────────────────────────────────────────────────┐
│  Moments    [Intro] [Verse] [Chorus] [Drop]     │  ← ShowUp moments (existing)
│             active ●                             │
├─────────────────────────────────────────────────┤
│  Console    [Cue 1: Wash] [Cue 5: Color]        │  ← Console Quick Actions (NEW)
│  GrandMA3   [Blackout] [Release All]             │  ← Blue-styled, collapsible
│             [Macro 1] [Macro 3]                  │
├─────────────────────────────────────────────────┤
│  Macros     [Lift] [Pull Back] [Big Finish]      │  ← ShowUp macros (existing)
│             [Reset Room]                         │
├─────────────────────────────────────────────────┤
│  Captured   [Warm Wash ●] [Blue Back ●]          │  ← Captured looks (NEW)
│  Looks      [Spotlight ●] [Dance Floor ●]        │  ← Recalled as raw DMX
└─────────────────────────────────────────────────┘
```

**Styling:** Console Quick Actions use blue (`--console-blue`) styling to visually distinguish them from ShowUp's purple controls. Captured looks show a small dot indicating they're DMX snapshots rather than procedural effects.

**Storage:** Console shortcuts are persisted in the show file under `consoleQuickActions`:
```json
{
  "consoleQuickActions": [
    { "label": "Cue 1: Wash", "action": "fireCue", "cueList": "1", "cueNumber": "1" },
    { "label": "Blackout", "action": "customOsc", "address": "/gma3/cmd", "args": ["BlackOut"] },
    { "label": "Macro 3", "action": "fireMacro", "macroNumber": 3 }
  ]
}
```

---

## Part 4: Preset Translation Matrix

Can a console's presets/cues be fully translated into ShowUp's Looks/Moments/Macros?

---

### The Fundamental Difference

| Console Concept | What It Stores | ShowUp Equivalent | Translation Fidelity |
|----------------|---------------|-------------------|---------------------|
| **Cue** | Static DMX values + fade times | **Look** (captured) | High (via DMX snapshot) |
| **Cue** | Palette references + tracking | **Look** (approximated) | Medium (must resolve palettes) |
| **Cue List** | Ordered sequence of cues | **Event Pack moments** | High (workflow mapping) |
| **Color Palette** | RGB/CMY values per fixture | **ShowUp palette colors** | High (direct value mapping) |
| **Position Palette** | Pan/tilt values per fixture | **centreX/centreY** | Medium (must normalize to 0-1) |
| **Effect** | Chase, rainbow, movement pattern | **ShowUp effect type** | Low (procedural vs programmed) |
| **Macro** | Console command sequence | **ShowUp macro** | Low (different paradigm) |
| **Group** | Fixture selection | **ShowUp fixture group** | High (fixture ID mapping) |

### Translation Paths by Console

**ETC Eos → ShowUp (best translation):**
```
1. Query cue list structure via OSC
2. For each cue:
   a. Fire it on the console
   b. Capture DMX output via sACN (raw look)
   c. Query /eos/out/get/params/{chan} for color/position (effect params)
   d. Create ShowUp Look with both raw + approximated data
3. Import color palettes via /eos/out/get/cp/{n} → ShowUp palette
4. Import groups via /eos/out/get/group/{n} → ShowUp groups
5. Map cue list order → moment sequence in an Event Pack
```

**GrandMA3 → ShowUp:**
```
1. Export sequences as XML from MA3
2. Parse cue names and sequence structure
3. For each cue:
   a. Fire via /gma3/cmd "Go+ Cue {n}"
   b. Capture DMX output via sACN
   c. Create ShowUp Look from captured DMX
4. Import MVR for fixture patch + groups
5. Map sequence order → moment sequence
```

**ChamSys MQ → ShowUp:**
```
1. Export color/position/beam palettes as CSV
2. Parse CSV → ShowUp palette colors + position presets
3. For each playback cue:
   a. Fire via /ch/playback/{n}/go
   b. Capture DMX output via sACN
   c. Create ShowUp Look from captured DMX
4. Import MVR for fixture patch + groups
5. Map playback order → moment sequence
```

**Onyx → ShowUp (via Telnet + DMX capture):**
```
1. Connect to Onyx Manager Telnet (port 2323)
2. QLList → get all cuelist names and numbers
3. For each cuelist:
   a. GQL {n} → fire cuelist via Telnet
   b. Capture DMX output via sACN
   c. Create ShowUp Look from captured DMX
   d. Label the look with the cuelist name from QLList
4. No MVR — manual fixture patching or CSV import
5. Map cuelist order → moment sequence using imported names
6. QLActive polling → auto-detect when LD changes cuelists
```

### What Can't Be Translated

| Console Feature | Why It Can't Translate |
|----------------|----------------------|
| **Tracking changes** | Console cues store only *changes* from previous cue. ShowUp looks are absolute snapshots. Translation requires firing cues in sequence to get the cumulative state. |
| **Complex multi-part cues** | Console cues can have parts that fire at different times within a single cue. ShowUp moments are atomic. |
| **Effects (chases/rainbows)** | Console effects are parameter-based with specific step tables. ShowUp effects are procedural algorithms. A console chase and a ShowUp rainbow may look similar but are fundamentally different data. |
| **Fixture-level timing** | Console cues can have per-fixture fade times. ShowUp's transition engine applies uniform fades. |
| **Programmer state** | Console's programmer (live adjustments not yet recorded) has no ShowUp equivalent beyond locked channels. |
| **Conditional cues** | Console cue lists can have follow/wait/halt triggers. ShowUp moments are operator-driven (no automatic sequencing in v1). |

### The Pragmatic Approach

Instead of perfect translation, the SDK takes a **capture + map** approach:

1. **Capture** the console's DMX output for each cue → raw ShowUp looks
2. **Map** the cue list structure → ShowUp moment sequence
3. **Import** palette data where available → ShowUp colors
4. **Leave the rest** to the operator — ShowUp's reactive effects add value precisely because they're different from what the console does

The goal is not to recreate the console's show in ShowUp. The goal is to give ShowUp enough context to be a useful companion.

---

## Part 5: Universal Fallback — DMX Sniffing

When all else fails, DMX sniffing works with every console on every network.

**How it works:**
1. ShowUp listens for sACN multicast (port 5568) on configured universes
2. For each incoming DMX frame, ShowUp reads the 512 channel values
3. Using the known fixture patch (from MVR, GDTF, CSV, or manual entry), ShowUp maps raw DMX values back to fixture parameters
4. This gives ShowUp a real-time view of what every fixture on the console's universes is doing

**What ShowUp can infer from DMX sniffing:**

| Fixture Parameter | DMX Channel Type | Inference Quality |
|------------------|-----------------|-------------------|
| Intensity | Dimmer channel | Exact |
| Color (RGB) | Red/Green/Blue channels | Exact |
| Color (CMY) | Cyan/Magenta/Yellow channels | Exact (inverted) |
| Color wheel position | Color wheel channel | Exact (with wheel def) |
| Pan / Tilt | Pan/Tilt channels | Exact |
| Gobo selection | Gobo wheel channel | Exact (with wheel def) |
| Zoom / Focus / Iris | Beam channels | Exact |
| Strobe rate | Strobe channel | Approximate |
| Effect speed | Speed channel | Approximate |

**What DMX sniffing cannot tell ShowUp:**
- Which cue is active (just the resulting output)
- Cue names or metadata
- Fade times (only the current state, not the trajectory)
- Whether the output is from a cue, the programmer, or an effect
- Console UI state (which fader the LD is touching)
