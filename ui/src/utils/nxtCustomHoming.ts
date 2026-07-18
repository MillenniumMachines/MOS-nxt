/**
 * Generate direction-aware custom platform home*.g macros.
 * HomeAt: 1 = min endstop (negative home), 2 = max endstop (positive home).
 */

export type CustomHomeAt = 1 | 2

export type CustomHomingInput = {
  xHomeAt: CustomHomeAt
  yHomeAt: CustomHomeAt
  zHomeAt: CustomHomeAt
  /** When set with includeA, generate homea.g and call it from homeall. */
  aHomeAt?: CustomHomeAt | null
  includeA?: boolean
}

function axisLetter(i: 0 | 1 | 2 | 3): 'X' | 'Y' | 'Z' | 'A' {
  return i === 0 ? 'X' : i === 1 ? 'Y' : i === 2 ? 'Z' : 'A'
}

/**
 * Signed first-pass travel expression toward the endstop.
 * Minus must be inside `{}` (RRF: `Z{-(…)}`, not `Z-{…}` → "expected number after 'Z'").
 */
function homeTravelExpr(axis: 0 | 1 | 2 | 3, homeAt: CustomHomeAt): string {
  const a = `move.axes[${axis}]`
  const span = `${a}.max - ${a}.min + 5`
  return homeAt === 1 ? `{-(${span})}` : `{${span}}`
}

function backoffExpr(homeAt: CustomHomeAt): string {
  return homeAt === 1 ? '{5}' : '{-5}'
}

function slowHomeExpr(homeAt: CustomHomeAt): string {
  return homeAt === 1 ? '{-5*2}' : '{5*2}'
}

function g92Line(axis: 0 | 1 | 2 | 3, homeAt: CustomHomeAt): string {
  const L = axisLetter(axis)
  const a = `move.axes[${axis}]`
  const pos = homeAt === 1 ? `${a}.min` : `${a}.max`
  return `G53 G92 ${L}{${pos}}`
}

/** Raise spindle; G0 requires Z already homed (home Z first / use homeall). */
function raiseZSafeLines(): string[] {
  return [
    'if { !move.axes[2].homed }',
    '    abort {"Home Z first - clearance raise needs Z homed"}',
    'G53 G0 Z{move.axes[2].max}'
  ]
}

function zTravelGuardLines(): string[] {
  return [
    'if { move.axes[2].min >= move.axes[2].max }',
    '    abort {"Z limits invalid - set Custom Z Min/Max, Save, reboot"}'
  ]
}

export function buildCustomHomexG(input: CustomHomingInput): string {
  const ha = input.xHomeAt
  return [
    '; homex.g — nxt platform custom (generated)',
    '; Direction from nxtCustomXHomeAt (1=min, 2=max).',
    '',
    'G91',
    'G21',
    'G94',
    '',
    '; Raise Z for clearance',
    ...raiseZSafeLines(),
    '',
    '; First pass toward X endstop',
    `G53 G1 H1 X${homeTravelExpr(0, ha)} F{1800}`,
    '',
    'if { ! sensors.endstops[0].triggered }',
    '    abort {"X endstop not triggered after full axis travel. Check motor and endstop!"}',
    '',
    '; Back off',
    `G53 G1 H2 X${backoffExpr(ha)}`,
    '',
    '; Slow second pass',
    `G53 G1 H1 X${slowHomeExpr(ha)} F{180}`,
    '',
    g92Line(0, ha),
    ''
  ].join('\n')
}

export function buildCustomHomeyG(input: CustomHomingInput): string {
  const ha = input.yHomeAt
  return [
    '; homey.g — nxt platform custom (generated)',
    '; Direction from nxtCustomYHomeAt (1=min, 2=max).',
    '',
    'G91',
    'G21',
    'G94',
    '',
    ...raiseZSafeLines(),
    '',
    `G53 G1 H1 Y${homeTravelExpr(1, ha)} F{1800}`,
    '',
    'if { ! sensors.endstops[1].triggered }',
    '    abort {"Y endstop not triggered after full axis travel. Check motor and endstop!"}',
    '',
    `G53 G1 H2 Y${backoffExpr(ha)}`,
    '',
    `G53 G1 H1 Y${slowHomeExpr(ha)} F{180}`,
    '',
    g92Line(1, ha),
    ''
  ].join('\n')
}

export function buildCustomHomezG(input: CustomHomingInput): string {
  const ha = input.zHomeAt
  return [
    '; homez.g — nxt platform custom (generated)',
    '; Direction from nxtCustomZHomeAt (1=min, 2=max).',
    '',
    'G91',
    'G21',
    'G94',
    '',
    ...zTravelGuardLines(),
    '',
    'var toolZ = null',
    '',
    'if { state.currentTool != -1 }',
    '    set var.toolZ = { tools[state.currentTool].offsets[2] }',
    '    G10 L1 P{state.currentTool} Z0',
    '',
    `G53 G1 H1 Z${homeTravelExpr(2, ha)} F{1800}`,
    '',
    'if { ! sensors.endstops[2].triggered }',
    '    abort {"Z endstop not triggered after full axis travel. Check motor and endstop!"}',
    '',
    `G53 G1 H2 Z${backoffExpr(ha)}`,
    '',
    `G53 G1 H1 Z${slowHomeExpr(ha)} F{180}`,
    '',
    g92Line(2, ha),
    '',
    'if { var.toolZ != null }',
    '    G10 L1 P{state.currentTool} Z{var.toolZ}',
    ''
  ].join('\n')
}

export function buildCustomHomeaG(input: CustomHomingInput): string {
  const ha = input.aHomeAt ?? 1
  return [
    '; homea.g — nxt platform custom (generated)',
    '; Direction from nxtCustomAHomeAt (1=min, 2=max).',
    '',
    'G91',
    'G21',
    'G94',
    '',
    ...raiseZSafeLines(),
    '',
    `G53 G1 H1 A${homeTravelExpr(3, ha)} F{1800}`,
    '',
    'if { #sensors.endstops > 3 }',
    '    if { ! sensors.endstops[3].triggered }',
    '        abort {"A endstop not triggered after full axis travel. Check motor and endstop!"}',
    '',
    `G53 G1 H2 A${backoffExpr(ha)}`,
    '',
    `G53 G1 H1 A${slowHomeExpr(ha)} F{180}`,
    '',
    g92Line(3, ha),
    ''
  ].join('\n')
}

export function buildCustomHomeallG(input: CustomHomingInput): string {
  const xHa = input.xHomeAt
  const yHa = input.yHomeAt
  const lines = [
    '; homeall.g — nxt platform custom (generated)',
    '; Homes Z, then X and Y together. Directions from nxtCustom*HomeAt.',
    '',
    'G91',
    'G21',
    'G94',
    '',
    'M98 P"homez.g"',
    '',
    `G53 G1 H1 X${homeTravelExpr(0, xHa)} Y${homeTravelExpr(1, yHa)} F{1800}`,
    '',
    'if { ! sensors.endstops[0].triggered }',
    '    abort {"X endstop not triggered after full axis travel. Check motor and endstop!"}',
    'if { ! sensors.endstops[1].triggered }',
    '    abort {"Y endstop not triggered after full axis travel. Check motor and endstop!"}',
    '',
    `G53 G1 H2 X${backoffExpr(xHa)} Y${backoffExpr(yHa)}`,
    '',
    `G53 G1 H1 X${slowHomeExpr(xHa)} Y${slowHomeExpr(yHa)} F{180}`,
    '',
    g92Line(0, xHa),
    g92Line(1, yHa),
    ''
  ]
  if (input.includeA && input.aHomeAt != null) {
    lines.push('if { fileexists("0:/sys/homea.g") }')
    lines.push('    M98 P"homea.g"')
    lines.push('')
  }
  return lines.join('\n')
}

export function buildAllCustomHomingFiles(input: CustomHomingInput): Record<string, string> {
  const out: Record<string, string> = {
    'homex.g': buildCustomHomexG(input),
    'homey.g': buildCustomHomeyG(input),
    'homez.g': buildCustomHomezG(input),
    'homeall.g': buildCustomHomeallG(input)
  }
  if (input.includeA && input.aHomeAt != null) {
    out['homea.g'] = buildCustomHomeaG(input)
  }
  return out
}

export function homeAtFromDraft(value: number | null | undefined, fallback: CustomHomeAt): CustomHomeAt {
  return value === 2 ? 2 : value === 1 ? 1 : fallback
}
