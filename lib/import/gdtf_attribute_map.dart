/// Maps GDTF standard attribute names to a normalized capability identifier.
///
/// GDTF defines ~200 standard attributes. This map covers the most common
/// ones that ShowUp's fixture system understands. Unknown attributes are
/// mapped to 'noFunction'.
///
/// The keys are GDTF attribute names as they appear in description.xml,
/// and the values are capability identifiers matching ShowUp's
/// CapabilityType enum names.
const Map<String, String> gdtfAttributeMap = {
  // ── Intensity ──
  'Dimmer': 'dimmer',
  'Dimmer1': 'dimmer',
  'DimmerFine': 'dimmerFine',

  // ── Color Mixing (Additive RGB/CMY) ──
  'ColorAdd_R': 'red',
  'ColorAdd_G': 'green',
  'ColorAdd_B': 'blue',
  'ColorAdd_W': 'white',
  'ColorAdd_A': 'amber',
  'ColorAdd_UV': 'uv',
  'ColorAdd_WW': 'warmWhite',
  'ColorAdd_CW': 'coolWhite',
  'ColorAdd_RFine': 'redFine',
  'ColorAdd_GFine': 'greenFine',
  'ColorAdd_BFine': 'blueFine',
  'ColorAdd_WFine': 'whiteFine',
  'ColorSub_C': 'cyan',
  'ColorSub_M': 'magenta',
  'ColorSub_Y': 'yellow',

  // ── Color Wheels ──
  'Color1': 'colorWheel',
  'Color2': 'colorWheel2',
  'Color1Fine': 'colorWheelFine',
  'ColorMacro1': 'colorMacro',

  // ── Color Temperature ──
  'CTC': 'colorTemp',
  'CTO': 'colorTemp',
  'CTB': 'colorTemp',
  'ColorRGB_Red': 'red',
  'ColorRGB_Green': 'green',
  'ColorRGB_Blue': 'blue',

  // ── Pan/Tilt ──
  'Pan': 'pan',
  'Tilt': 'tilt',
  'PanFine': 'panFine',
  'TiltFine': 'tiltFine',
  'PanRotate': 'panContinuous',
  'TiltRotate': 'tiltContinuous',

  // ── Gobo ──
  'Gobo1': 'goboWheel',
  'Gobo2': 'goboWheel2',
  'Gobo1Pos': 'goboRotation',
  'Gobo2Pos': 'goboRotation2',
  'Gobo1PosRotate': 'goboRotation',
  'Gobo1SelectSpin': 'goboWheel',
  'Gobo1SelectShake': 'goboWheel',

  // ── Beam ──
  'Iris': 'iris',
  'IrisPulseOpen': 'iris',
  'IrisPulseClose': 'iris',
  'Zoom': 'zoom',
  'ZoomFine': 'zoomFine',
  'Focus1': 'focus',
  'Focus1Fine': 'focusFine',

  // ── Prism / Frost ──
  'Prism1': 'prism',
  'Prism1Pos': 'prismRotation',
  'Prism1PosRotate': 'prismRotation',
  'Frost1': 'frost',
  'Frost2': 'frost',

  // ── Strobe / Shutter ──
  'Shutter1': 'strobe',
  'Shutter1Strobe': 'strobe',
  'StrobeDuration': 'strobe',
  'StrobeFrequency': 'strobe',
  'ShutterStrobe': 'strobe',

  // ── Speed / Control ──
  'PanTiltSpeed': 'speed',
  'EffectSpeed': 'speed',
  'IntensityMSpeed': 'speed',
  'ColorMSpeed': 'speed',
  'GoboMSpeed': 'speed',

  // ── Fog / Fan ──
  'Fog1': 'fog',
  'Fog1Intensity': 'fog',
  'Fan1': 'fan',

  // ── Auto Programs ──
  'Effects1': 'autoProgram',
  'Macro1': 'autoProgram',

  // ── Maintenance / Reset ──
  'LampControl': 'maintenance',
  'LampOn': 'maintenance',
  'LampOff': 'maintenance',
  'Reset': 'maintenance',
  'FixtureGlobalReset': 'maintenance',

  // ── Barrel (Rotation) ──
  'BarrelRotation': 'barrel',

  // ── Blade/Shaping ──
  'Blade1A': 'noFunction',
  'Blade1B': 'noFunction',
  'Blade2A': 'noFunction',
  'Blade2B': 'noFunction',
  'Blade3A': 'noFunction',
  'Blade3B': 'noFunction',
  'Blade4A': 'noFunction',
  'Blade4B': 'noFunction',
  'BladeRot': 'noFunction',
};

/// Resolve a GDTF attribute name to a ShowUp capability type name.
///
/// Returns 'noFunction' for unknown attributes.
String resolveGdtfAttribute(String gdtfAttribute) {
  // Direct match
  if (gdtfAttributeMap.containsKey(gdtfAttribute)) {
    return gdtfAttributeMap[gdtfAttribute]!;
  }

  // Fuzzy match: strip trailing digits and try again
  final stripped = gdtfAttribute.replaceAll(RegExp(r'\d+$'), '');
  if (gdtfAttributeMap.containsKey(stripped)) {
    return gdtfAttributeMap[stripped]!;
  }

  // Check for common prefixes
  if (gdtfAttribute.startsWith('ColorAdd_')) return 'noFunction';
  if (gdtfAttribute.startsWith('ColorSub_')) return 'noFunction';
  if (gdtfAttribute.startsWith('Pan')) return 'pan';
  if (gdtfAttribute.startsWith('Tilt')) return 'tilt';
  if (gdtfAttribute.startsWith('Gobo')) return 'goboWheel';
  if (gdtfAttribute.startsWith('Dimmer')) return 'dimmer';

  return 'noFunction';
}
