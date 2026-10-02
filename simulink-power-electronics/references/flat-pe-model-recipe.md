# Flat PE Model Recipe (No Subsystems) + AFE/PFC Build Patterns

Status: VERIFIED 2026-10-02 on host hp/R2024b by building the flat
three-phase AFE PFC model `ThreePhase_AFE_PFC` (32 VAC -> 48 VDC / 120 W)
from a regenerating script, driven by user feedback over four layout
rounds. Use when the user wants to SEE every device, gate, and wire on one
canvas (teaching/review models), or when building an active-front-end /
PFC rectifier. Pair with `layout-wiring-recipe.md` (wiring mechanics) and
`simscape-layout.md` (subsystem variant).

## When flat vs subsystems

- Flat (single level, no subsystems): user wants every switch visible,
  gate signals traceable, textbook-schematic look. Costs a bigger canvas
  and disciplined corridors; use the zone plan below.
- Subsystem split (`Power`/`Control`/`Diagnostics`): default for large or
  generated models (see `simscape-layout.md`). Do not mix: a half-split
  flat model is the worst of both.

## Flat zone plan (left to right, top to bottom)

```
title annotation (+ sample-time note)
① source zone: grid source -> V-I measurement -> feed ladder
② bridge zone: N legs vertical; DC+ rail on top lane, DC- rail on bottom
   lane; gate From tags just left of each device at port height
③ DC bus zone: capacitor, load switch, load, sensor, ground, [Vdc] tag
④ gate-drive zone (below bridge): one row per phase, two sub-chains
⑤ controller zone (bottom): reference row + regulator row, tags only
⑥ scope zone (far right): From-tag columns feeding multi-input scopes
timing note at the very bottom
```

- Number the zones in circled digits and title every zone with a SHORT
  Chinese/English annotation placed in a guaranteed-empty band (verify with
  the label-collision checker; annotations are wide, ~0.62*fontsize px per
  char). Add a bottom timing note (enable/soft-start/load-step schedule).
- Create annotations programmatically:
  `a = Simulink.Annotation(mdl, txt); a.Position = [x y]; a.FontSize = N;`
  (wrap in try/catch — the class constructor throws on some name strings).
- Annotation incidents to avoid (all hit on 2026-10-02): `powergui` renders
  its own "Discrete Ts" annotation below the block — keep zone ① text right
  of it or it gets occluded; the bottom timing note must sit BELOW the last
  content row (drive rows grew and swallowed it once — move the note when
  you add rows); annotation backgrounds are transparent, so text under any
  wire or block is unreadable — reserve a clean horizontal band per note.
- Annotation content that earned its keep: zone purpose, device mapping
  (g1/g2 = phase-A upper/lower ...), timing schedule, and the one
  unavoidable crossing if present.

## Device choices (user-visibility driven)

- Discrete `Mosfet` blocks (body diode built in: Rd/Vfd params) instead of
  `Universal Bridge` when the user must see six switches and six gate
  wires. Universal Bridge is fine when gates are abstracted.
- Leg wiring: upper source -> lower drain is the mid-node; feeds may tap
  EITHER mid-node port (pick the one that flattens the route).
- Load switch: a MOSFET in the DC return (gate top-LEFT, horizontal feed)
  instead of `Breaker` (whose top-edge control port collides with the DC+
  entry). Body diode orientation: antiparallel diode blocks the load
  current when OFF for a low-side N-ch placement, drain up.
- Scopes: one 6-input Scope for all gate drives (fed by a From[g1..g6]
  column, spacing >= 26 px, `ShowName off` on the relay Froms), plus
  bus-voltage and phase-current scopes.

## Net-tag dictionary (flat models live or die by this)

Publish tags at the source, consume with From at the point of use, keep
the tag set SMALL and lowercase-verified (tags are case-sensitive; a
mismatched From may run silently with garbage — assert Goto/From tag-set
equality in the build script):

`[Vabc] [Iabc] [Ia] [Ib] [Ic] [Vdc] [En] [iampG] [eA..eC] [irefa..irefc]
[g1..g6] [LoadOn]`

Gates: drive chains write [g_k]; each MOSFET gate has `From[g_k]` + a
short NAMED wire `g_k` (signal name = tag name = scope label, one concept).

## Control architecture that survived every layout round (AFE/PFC)

Hysteresis (bang-band) current loop + waveform-shaped reference + one
voltage PI — PLL-free, sign-convention-proof:

```
iref = (Kcm * Vabc) -> 1st-order LPF (anti-ripple) -> /Vgrid_pk -> * iamp
Kcm = eye(3) - ones(3)/3            % CM removal as ONE matrix gain
per phase: e = iref - i -> Relay(+-h) -> *En -> [g_upper]
           same e -> Relay'(swapped outputs) -> *En -> [g_lower]
Vdc: (Vref - Vdc)*En -> PI(+-Ilm, clamping) -> RateLimiter -> [iampG]
```

- Negative plant (bridge voltage up -> grid current down): verified by
  open-loop injection; relay polarity set from that measurement, not theory.
- Startup timing: En=0 with precharged bus (body diodes hold it) 0-0.3 s,
  enable with slew-limited current command, load step later. Prevents
  integrator windup + PLL/measurement shock.
- Low boost-ratio trap: keep Vdc >= ~1.1 * sqrt(2)*VLL or the loop loses
  current-control authority when the bus sags (slides to the diode-rectifier
  equilibrium). Soft-start slew + fast-ish voltage loop hold the bus above
  the margin through load steps.

## Debug/derivation algorithms that paid for themselves (reusable)

1. SVPWM normalization by experiment: drive a loaded bridge with a constant
   |Uref|=m, FFT the pole voltage; k = V1/(m*Vdc); here k*sqrt(3) = 1.017,
   i.e. `Uref = v_cmd*sqrt(3)/Vdc`, linear region |Uref| <= 1. Amplitude
   alone is NOT enough — also verify phase (a 90-deg rotation error passes
   an amplitude-only check).
2. Open-loop plant identification: bypass PI/FF, inject constant (vd,vq),
   read steady-state (Id,Iq); confirms plant gain sign and frame alignment
   at the rated operating point before closing loops.
3. Discrete sweeps when conventions fight: 4-rotation sweep (0/90/180/270)
   and FF-sign x PI-error-sign 2x2 sweep on a gated, precharged bus; judge
   by "command = grid vector => current ~ 0".
4. Energy-balance forensics for bus collapses: i_cap = C*dV/dt, i_brk =
   i_cap + i_load, compare with P_grid — locates whether the loss is load,
   source impedance, or lost modulation authority.
5. Source impedance semantics: `Three-Phase Source` with
   `SpecifyImpedance='on'` derives R/X from short-circuit level (defaults
   100 MVA/25 kV -> a ~16 mH phantom series L that collapses the terminal
   voltage under load). Set `'off'` to use the R/L fields verbatim.
6. Grounding rule: exactly ONE ground (DC-). A grounded source neutral
   (Yg) plus DC- ground diode-clamps every phase through the bridge body
   diodes — the model then cannot work no matter how good the control is.
7. Measurement hygiene: remove switching common-mode before using terminal
   voltages (matrix Kcm above or per-phase sums); filter at ~2 kHz for a
   20 kHz hysteresis/PWM carrier; feed relays RAW currents.

## Process (regenerating-script discipline)

- One idempotent `build_*.m` regenerates the whole `.slx` (delete, rebuild,
  wire, tag, annotate, log, save). Never hand-edit the model; iterate
  script -> build -> QA counters -> surgical geometry fix -> repeat.
- QA gate order: build log clean -> diag_count == 0 -> net-aware crossings
  == unavoidable minimum -> label collisions == 0 -> wire-through-tag == 0
  -> bend census reviewed (mean <= ~1.5 turns/line) -> closed-loop metrics
  unchanged -> screenshot (+ visual judge).
- Run via `matlab -batch`; interactive MCP evals time out at 30 s.
- Keep calibration/forensics scripts (normalization, sweeps, energy
  balance) in the project `debug_tools/` folder as the audit trail.
