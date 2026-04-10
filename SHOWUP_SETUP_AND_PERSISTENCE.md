# ShowUp Console Setup, Configuration & Persistence

**How coexistence gets configured in ShowUp, how it's stored, and how it stays out of the way when there's no console.**

---

## The Zero-Config Principle

Console coexistence should never make ShowUp harder for someone who doesn't have a console. The default state is **Solo** — all coexistence features are invisible until a console is detected or the user opts in.

```
First launch:
  - No coexistence UI visible
  - No new settings to learn
  - ShowUp works exactly as it does today

Console detected on network:
  - Subtle notification slides in
  - User can set up coexistence or dismiss
  - Dismissed = stays in Solo mode, console icon in status bar for later

User taps "Set Up Coexistence":
  - 4-step wizard walks them through configuration
  - ~30 seconds for the common case (auto-detection fills most fields)
  - Configuration saved to their stage file
```

---

## Setup Flow: Step by Step

### Step 0: Console Detection (Automatic)

ShowUp's existing ArtPoll discovery runs in the background. When a known console OEM code or name pattern is detected:

**What the user sees:** A notification card slides in from the top-right:
```
┌──────────────────────────────────────┐
│  🔵  Console Detected               │
│  GrandMA3 Light at 192.168.1.100    │
│  Universes 1-4 active               │
│                                      │
│  [Set Up Coexistence]  [Not Now]     │
└──────────────────────────────────────┘
```

**What happens behind the scenes:**
- `ConsoleDetector` matches ArtPoll reply to a `ConsoleProfile`
- Scans `SwOut` ports to identify which universes the console is actively outputting
- Pre-populates the wizard with detected console type, IP, and active universes

**If user taps "Not Now":** The notification dismisses. A small blue console icon appears in the status bar. Tapping it later re-opens the coexistence setup. No configuration is stored.

---

### Step 1: Coexistence Mode

**What the user sees:** Three large cards with simple descriptions:

| Mode | Description | When to use |
|------|-------------|-------------|
| **Side by Side** | "Your fixtures, their fixtures. Separate universes." | Church with ShowUp movers + console wash. School with ShowUp LEDs + console conventionals. |
| **Trigger Mode** | "ShowUp sends commands to the console. One control surface." | Wedding DJ using ShowUp as the only interface. Operator who wants ShowUp's UI but all fixtures on the console. |
| **Layer Mode** | "ShowUp adds reactive effects underneath the console." | Concert venue with ShowUp ambient + touring LD on stage. Permanent installation with ShowUp as always-on ambient. |

**Default selection:** Auto-suggested based on detection:
- If console has many active universes and ShowUp has a separate patch → Side by Side
- If ShowUp has no fixtures patched yet → Trigger Mode
- If ShowUp and console share universes → Layer Mode

**What gets stored:** `coexistenceMode: 'sideBySide' | 'triggerOnly' | 'layered'`

---

### Step 2: Universe Assignment

**What the user sees:** A visual grid of universes 1-16, color-coded:

```
  ┌───┐ ┌───┐ ┌───┐ ┌───┐
  │ 1 │ │ 2 │ │ 3 │ │ 4 │
  │ 🔵│ │ 🔵│ │ 🔵│ │ 🔵│  ← Auto-detected as Console (blue)
  └───┘ └───┘ └───┘ └───┘
  ┌───┐ ┌───┐ ┌───┐ ┌───┐
  │ 5 │ │ 6 │ │ 7 │ │ 8 │
  │ 🟣│ │ 🟣│ │   │ │   │  ← Auto-assigned to ShowUp (purple)
  └───┘ └───┘ └───┘ └───┘

  🟣 ShowUp   🔵 Console   🟢 Shared   ⬜ Empty

  [Auto-Assign]  ← Avoids console's detected universes
```

**Tap to cycle:** Each tile cycles through ShowUp → Console → Shared → Empty.

**Auto-Assign logic:** Reads ArtPoll data to find console's active universes, assigns ShowUp to the first available non-conflicting universes. If ShowUp already has fixtures patched, preserves their universe assignments.

**Skipped in Trigger Mode** (ShowUp doesn't output DMX in Trigger Mode).

**What gets stored:** `universeRoles: { "1": "console", "2": "console", "5": "showup", "6": "showup" }`

---

### Step 3: Console Connection

**What the user sees:** Console profile auto-selected, connection fields pre-filled:

```
  Console:     [GrandMA3 Light ▼]  ← Auto-detected
  Protocol:    [OSC ▼]             ← Default for this console
  Console IP:  [192.168.1.100]     ← From ArtPoll
  Port:        [8000]              ← Default for this console

  [Test Connection]  ✅ Connected — response in 12ms
```

**Per-console defaults:**

| Console | Default Protocol | Default Port | Test Method |
|---------|-----------------|-------------|-------------|
| GrandMA3 | OSC | 8000 | Send `/gma3/cmd,s,"Version"` |
| ETC Eos | OSC (TCP) | 3032 | Connect TCP, send `/eos/get/version` |
| ChamSys MQ | OSC | 6553 (CREP) / user-set (OSC) | Send `/ch/playback/1/level` |
| Onyx | Telnet | 2323 | Connect TCP, send `QLList\r\n` |

**"Test Connection" button:** Sends a non-destructive query to the console and shows the response time. Green checkmark if successful, red X with error message if failed.

**For Onyx:** An additional note appears: "Onyx Manager must be running on the controller."

**For GrandMA3:** An optional section: "Install ShowUp Companion Plugin for bidirectional control" with a [Learn More] link.

**What gets stored:** `consoleProfile: { id, ip, port, protocol }`

---

### Step 4: Summary + Done

**What the user sees:**

```
  ┌──────────────────────────────────────┐
  │           🤝 You're in sync          │
  │                                      │
  │  ShowUp + GrandMA3 Light             │
  │  Mode: Side by Side                  │
  │  Console owns: Universes 1-4         │
  │  ShowUp owns: Universes 5-6          │
  │  Protocol: OSC on 192.168.1.100:8000 │
  │                                      │
  │  [Start Performing]  [Edit Setup]    │
  └──────────────────────────────────────┘
```

---

## Post-Setup: Aligning Fixtures, Cues, and Moments

### Fixture Alignment

**Problem:** The console has 40 fixtures. ShowUp needs to know about them to do anything useful (capture, complement, group mapping).

**Three import paths (in order of preference):**

1. **MVR Import** (GrandMA3, Eos, ChamSys)
   - User taps "Import Rig" in Stage Setup
   - Picks an `.mvr` file (emailed from LD, AirDropped, or on USB)
   - ShowUp parses fixtures, addresses, groups, and GDTF profiles
   - Preview screen: "Found 40 fixtures across 4 universes. Import?"
   - On confirm: fixtures added to `StageLightsConfig.patch[]`, groups added to `groups[]`
   - Universe roles auto-suggested based on which universes the imported fixtures occupy

2. **CSV Patch Import** (any console)
   - User taps "Import Patch List"
   - Column mapping wizard: "Which column is the fixture name? Address?"
   - Auto-detects common column names and address formats
   - Same preview + confirm flow as MVR

3. **Telnet Cuelist Import** (Onyx only)
   - On Telnet connection, ShowUp automatically runs `QLList`
   - Cuelist names appear as Console Quick Action buttons
   - No fixture data (just workflow names)

**Fixture ownership:** Imported console fixtures are automatically tagged `consoleOwned: true` in their patch entry. They appear in ShowUp's fixture list as grayed-out "monitoring only" entries. ShowUp doesn't output DMX for these fixtures — it uses them for:
- DMX sniffing (reverse-mapping captured values)
- Look capture (knowing which fixture channels to read)
- Complement mode (analyzing console colors to generate contrasting effects)
- Group suggestions (mapping console groups → ShowUp groups)

---

### Cue-to-Moment Alignment

**Problem:** The console has a cue list. ShowUp has moments. How do they line up?

**Trigger Binding Sheet (accessible from Perform):**

Each moment card in Perform has a small chain-link icon. Tapping it opens a binding sheet:

```
┌─────────────────────────────────────────────┐
│  When "Chorus" activates, tell the console: │
│                                             │
│  Action:  [Go to Cue ▼]                    │
│  Cue:     [3     ]                          │
│  List:    [1     ]  (Main)                  │
│                                             │
│  Execution: ○ ShowUp only                   │
│             ● Both (simultaneous)           │
│             ○ Console only                  │
│             ○ Sequential (ShowUp first)     │
│                                             │
│  [Test]  ← fires the command now            │
│                                             │
│           [Save]  [Cancel]                  │
└─────────────────────────────────────────────┘
```

**Available trigger actions:**

| Action | Parameters | Description |
|--------|-----------|-------------|
| Go to Cue | cueList, cueNumber | Fire a specific cue on the console |
| Fire Macro | macroNumber | Execute a console macro |
| Set Fader | fader, level | Set a console fader to a specific level |
| Release Cuelist | cueList | Release/stop a cuelist |
| Custom OSC | address, args | Send any OSC message |
| Custom Telnet | command | Send any Telnet command (Onyx) |

**Auto-suggest:** If ShowUp imported cuelist names (from Eos OSC, MQ CSV, or Onyx Telnet), the cue picker shows a dropdown with actual cue names instead of just numbers:
```
  Cue: [3 - Chorus Wash ▼]
```

**Bulk mapping shortcut:** "Auto-Map by Order" button maps ShowUp moments to console cues in order:
```
  Moment 1 (Intro)    → Console Cue 1
  Moment 2 (Verse)    → Console Cue 2
  Moment 3 (Chorus)   → Console Cue 3
  ...
```

User can then adjust individual mappings. This handles the 80% case where the moment/cue order roughly aligns.

---

### Console Quick Actions Setup

**Problem:** The user wants console shortcuts in Perform that aren't tied to moments.

**Setup (from Perform screen):**

Long-press the "Console" section header → "Edit Console Actions":

```
┌─────────────────────────────────────────┐
│  Console Quick Actions                  │
│                                         │
│  [+ Add Action]                         │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 🔵 Cue 1: Warm Wash            │    │
│  │    Action: Go to Cue 1          │    │
│  │    ← imported from console      │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 🔵 Blackout                     │    │
│  │    Action: Release All (RAQLDF) │    │
│  │    ← user-created               │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Import from Console]  ← queries the   │
│     console for cuelist names/palettes  │
└─────────────────────────────────────────┘
```

**"Import from Console" button behavior:**

| Console | What happens |
|---------|-------------|
| ETC Eos | OSC query `/eos/out/get/cuelist/{n}` → imports cue names as Quick Actions |
| GrandMA3 | If Companion Plugin is running, reads executor labels. Otherwise, user adds manually. |
| ChamSys MQ | Reads `/feedback/pb+exec` playback names. Or user imports from CSV. |
| Onyx | `QLList` via Telnet → imports cuelist names as Quick Actions |

---

### Captured Look Workflow

**Problem:** The LD programs looks on the console. ShowUp needs to store them.

**Capture flow (from Perform or Control screen):**

1. User taps "Capture" button → capture mode activates (pulsing border)
2. LD sets up desired look on the console
3. ShowUp reads incoming sACN/Art-Net data from console-owned universes
4. User taps "Save" → names the look, optionally assigns to a moment
5. Captured look appears in the Captured Looks row of Perform

**What gets stored per captured look:**

```json
{
  "id": "captured_warm_wash_1",
  "name": "Warm Wash",
  "kind": "captured",
  "capturedAt": "2026-04-10T20:15:00Z",
  "captureSource": "grandma3",
  "rawDmx": {
    "1": { "0": 255, "1": 128, "2": 64, "3": 0, ... },
    "2": { "0": 200, "1": 180, ... }
  },
  "snapshot": {
    "colorEffect": "static_",
    "paletteIndices": [14],
    "mainDimmer": 0.85,
    "centreX": 0.5,
    "centreY": 0.4,
    ...
  }
}
```

Two representations stored together:
- `rawDmx` — exact DMX values per universe/channel for perfect static reproduction
- `snapshot` — best-guess ShowUp effect parameters for editable reproduction

When recalled:
- **In Side by Side mode:** ShowUp outputs `rawDmx` on its own universes (if the captured fixtures are ShowUp-owned)
- **In Trigger mode:** ShowUp sends a trigger to fire the original console cue (stored as `sourceCueRef`)
- **In Layer mode:** ShowUp outputs `rawDmx` at its configured sACN priority

---

## Persistence Format

### Stage File (.showup-stage)

New fields added to `StageLightsConfig` (the `lights` object):

```json
{
  "lights": {
    "protocol": "sacn",
    "patch": [ ... ],
    "groups": [ ... ],
    "artNetTargets": [ ... ],
    "connectionMode": "direct",
    "relayTargetIp": null,
    "relayPort": 8454,
    "fogConfig": null,

    "coexistence": {
      "mode": "sideBySide",
      "consoleProfile": {
        "id": "grandma3",
        "displayName": "GrandMA3 Light",
        "manufacturer": "MA Lighting"
      },
      "consoleConnection": {
        "ip": "192.168.1.100",
        "port": 8000,
        "protocol": "osc",
        "telnetPort": null
      },
      "universeRoles": {
        "1": "console",
        "2": "console",
        "3": "console",
        "4": "console",
        "5": "showup",
        "6": "showup"
      },
      "sacnConfig": {
        "enabled": true,
        "defaultPriority": 100,
        "universePriorities": {
          "5": 100,
          "6": 100
        }
      },
      "failover": {
        "enabled": false,
        "fallbackLookId": null,
        "timeoutSeconds": 5
      },
      "companionPlugin": {
        "installed": true,
        "oscFeedbackPort": 9000
      }
    }
  }
}
```

**Key design decisions:**
- `coexistence` is a single nested object — clean, versionable, ignorable by old app versions
- `universeRoles` is a string-keyed map (JSON doesn't support integer keys)
- `sacnConfig` sits here because sACN priorities are venue-specific (not show-specific)
- `failover` is venue-specific (whether to auto-takeover depends on the console, not the show)
- `companionPlugin` tracks whether the MA3/MQ plugin setup has been done

**When `coexistence` is null/absent:** ShowUp operates in Solo mode. No coexistence UI shown. This is the backward-compatible default.

---

### Show File (.showup-show)

New fields added to `ShowLightsConfig` (the `lights` object):

```json
{
  "lights": {
    "selectedPackId": "concert",
    "customEventPacks": [ ... ],
    "looks": [ ... ],
    "customMoods": [ ... ],
    "customPaletteColors": [ ... ],
    "liveState": { ... },
    "tempo": { ... },

    "consoleTriggerBindings": [
      {
        "sourceType": "moment",
        "sourceId": "chorus_moment_id",
        "action": "fireCue",
        "parameters": {
          "cueList": "1",
          "cueNumber": "3"
        },
        "executionMode": "both",
        "delay": null,
        "enabled": true
      },
      {
        "sourceType": "macro",
        "sourceId": "bigFinish_macro_id",
        "action": "fireCue",
        "parameters": {
          "cueList": "1",
          "cueNumber": "10"
        },
        "executionMode": "both",
        "delay": null,
        "enabled": true
      }
    ],

    "consoleQuickActions": [
      {
        "id": "qa_1",
        "label": "Cue 1: Wash",
        "action": "fireCue",
        "parameters": { "cueList": "1", "cueNumber": "1" },
        "imported": true,
        "sortOrder": 0
      },
      {
        "id": "qa_blackout",
        "label": "Blackout",
        "action": "releaseAll",
        "parameters": {},
        "imported": false,
        "sortOrder": 1
      }
    ],

    "capturedLooks": [
      {
        "id": "captured_warm_wash_1",
        "name": "Warm Wash",
        "kind": "captured",
        "capturedAt": "2026-04-10T20:15:00Z",
        "captureSource": "grandma3",
        "sourceCueRef": { "cueList": "1", "cueNumber": "1" },
        "rawDmx": {
          "1": { "0": 255, "1": 128, "2": 64 },
          "2": { "0": 200, "1": 180 }
        },
        "snapshot": {
          "colorEffect": "static_",
          "colorSpeed": 0.5,
          "paletteIndices": [14],
          "mainDimmer": 0.85,
          "centreX": 0.5,
          "centreY": 0.4,
          "movementEffect": "static_",
          "groupDimmers": {},
          "groupOverrides": {}
        }
      }
    ],

    "consoleInputMappings": [
      {
        "sourceType": "osc",
        "sourceAddress": "/showup/fader/201",
        "targetParam": "masterDimmer",
        "rangeMin": 0.0,
        "rangeMax": 1.0
      },
      {
        "sourceType": "osc",
        "sourceAddress": "/showup/fader/202",
        "targetParam": "colorSpeed",
        "rangeMin": 0.0,
        "rangeMax": 1.0
      }
    ],

    "timecodeMarkers": [
      {
        "position": "00:02:15:00",
        "frameRate": 30,
        "momentId": "chorus_moment_id",
        "action": "activate"
      }
    ]
  }
}
```

**Key design decisions:**
- `consoleTriggerBindings` are show-specific (different shows map different moments to different cues)
- `consoleQuickActions` are show-specific (the DJ's wedding show has different shortcuts than their club show)
- `capturedLooks` are show-specific (captured from a specific console session)
- `consoleInputMappings` are show-specific (different shows may map faders to different params)
- `timecodeMarkers` are show-specific (timecoded to specific show content)

**Why not in the stage file?** The stage file represents the venue's hardware. The show file represents a specific performance at that venue. A wedding DJ might use the same venue (same stage file) but have different trigger bindings, quick actions, and captured looks for each wedding (different show files). This is consistent with how ShowUp already separates hardware (stage) from performance (show).

---

### Live State Extensions

New fields in `ShowLightsLiveStateConfig` (the `liveState` object):

```json
{
  "liveState": {
    "activeMoodIndex": 0,
    "masterDimmer": 75,
    ...existing fields...,

    "consoleState": {
      "connected": true,
      "lastHeartbeat": "2026-04-10T20:15:00Z",
      "activeCuelists": [1, 3],
      "overriddenParams": ["masterDimmer"],
      "failoverActive": false,
      "captureActive": false
    }
  }
}
```

**Note:** `consoleState` is runtime-only — it's saved to the recovery file for crash recovery but is not meaningful when loading a show file from scratch. On fresh load, `consoleState` is initialized from the live network state, not from the file.

---

## What Happens on Load

### Loading a stage file with coexistence config:

```
1. Parse coexistence config from JSON
2. If coexistence.mode != null:
   a. Set up universe roles in DmxEngine
   b. Initialize SacnTransport if sacnConfig.enabled
   c. Start ConsoleDetector with known console profile
   d. If console detected: show "Console Connected" indicator
   e. If console not found: show "Console Not Found" warning, offer retry
3. If coexistence is null:
   a. Solo mode — no coexistence UI, no console detection
```

### Loading a show file with trigger bindings:

```
1. Parse consoleTriggerBindings from JSON
2. Register bindings with TriggerRouter
3. Parse consoleQuickActions → populate Perform screen's Console section
4. Parse capturedLooks → add to look library with "captured" badge
5. Parse consoleInputMappings → configure ConsoleInputService
6. If stage file has no coexistence config:
   a. Trigger bindings are loaded but inactive (no console to send to)
   b. Quick Actions appear but are grayed out with "No console configured" tooltip
   c. Captured looks are available for recall as raw DMX
```

---

## Migration: What Happens to Existing Files

**Stage files without `coexistence`:** Work identically. `coexistence` field is null. Solo mode.

**Show files without `consoleTriggerBindings`:** Work identically. All new fields are empty arrays or null. No console-related UI appears in Perform.

**Old app version opens new file:** Silently ignores all `coexistence`, `consoleTriggerBindings`, `consoleQuickActions`, `capturedLooks`, `consoleInputMappings`, and `timecodeMarkers` fields. No crashes, no data loss. The coexistence data is preserved in the file but invisible to the older app.

**New app version opens old file:** All coexistence fields default to null/empty. Solo mode. User can set up coexistence through the wizard, which writes the new fields to the existing file.

**No migration step needed.** The file format is purely additive.
