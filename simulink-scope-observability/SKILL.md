---
name: simulink-scope-observability
description: Use when building or reviewing Simulink / Simscape Electrical (SPS) models that contain switching devices (Mosfet, IGBT, Gto, Ideal Switch, Thyristor, Universal Bridge, Two-Level/Three-Level Converter, PWM or SVPWM Generator, Buck/Boost/Full-Bridge Converter blocks) — automatically add gate-signal scopes for every switching device and input/output voltage+current scopes, wire them cleanly via global Goto/From, run the model once, and pop all scope windows for the user.
---

# Simulink Switching-Device Scope Observability

Status: VERIFIED 2026-09-30 on host hp/R2024b — end-to-end smoke test on a
MOSFET buck demo (`C:\Users\hp\Desktop\MATLAB\Buck_Scope_Demo\`, 0 diagonal
lines, Vout 11.55 V vs 12 V ideal at 50% duty, 5 scopes opened with data).

Purpose: any switching-converter model this skill touches ships with waveform
observation built in — the gate/control signal of EVERY switch plus the
input/output voltage and current waveforms — so the user can watch the
converter operate without having to ask.

## When to apply

- Creating a model that contains switching devices, or when asked to
  "add scopes / show waveforms / let me observe".
- Reviewing an existing switching model that lacks scope coverage.

## Workflow

1. **Inventory the switches.** `find_system(mdl,'LookUnderMasks','all',
   'Type','Block')` and classify:
   - Discrete devices (Mosfet / IGBT / Gto / Ideal Switch / Thyristor):
     gate = `Inport(1)`. Branch that line into a Goto tag `g_<dev>`.
   - Bridge blocks (Universal Bridge, Two-Level / Three-Level Converter):
     ONE gate-vector Inport. Branch it to Goto `g_<stage>`; per-device axes
     come from a Demux at the scope side. Universal Bridge 6-vector order
     (measured): `[A_up; A_dn; B_up; B_dn; C_up; C_dn]`.
   - Modulators (PWM Generator, SVPWM Generator): output `P` vector — same
     Demux treatment; also tap the modulation reference (e.g. SVPWM
     alpha-beta inports) so the user sees duty evolve.
   - SPS converter blocks (Buck / Boost / Full-Bridge Converter): gate
     Inport `g`, same as discrete devices.
2. **Measure the input and output of the switching stage.**
   - Input voltage: Voltage Measurement in PARALLEL at the input node
     (terminals `LConn(1)` = +, `LConn(2)` = −; signal on Outport(1)).
   - Input current: Current Measurement in SERIES in the positive input
     lead. Sign convention: positive when entering `LConn`, exiting
     `RConn`. If the chain flows right-to-left, set the block
     `Orientation` to 'left' — ports mirror with the block, polarity is
     preserved.
   - Output voltage: Voltage Measurement across the output port or load.
   - Output current: Current Measurement in series with the load.
   - If the model already exposes an SPS measurement bus (machine m-bus,
     converter measurements param) or existing sensors, tap those signals
     with a Goto instead of duplicating hardware sensors.
3. **Build the scopes.**
   - Gate scope per switching stage: Demux (`Outputs` = N) → Scope created
     with `'NumInputPorts','N'`; then `try set_param(scope,
     'LayoutDimensions','[N 1]'); catch, end` — the param is rejected at
     add_block time, set it AFTER creation. One axis per device shows
     complementary pairs and duty directly.
   - I/O scopes: `Scope_Vin`, `Scope_Iin`, `Scope_Vout`, `Scope_Iout`
     (default separate; combine via Mux only if the user asks for compact).
   - Naming: scopes `Scope_<What>`, tags `g_<dev>`, `v_in`, `i_in`,
     `v_out`, `i_out`. Scopes are fed by **From** tags; the **Goto** sits at
     the signal source. No long trunks across the canvas. On flat canvases
     use a From COLUMN next to the scope: row pitch >= 26 px,
     `'ShowName','off'` on the relay Froms (name labels otherwise collide
     with the next row's tag text), and give each From-wire its own turn
     lane into the scope so no two share a vertical — see
     `simulink-power-electronics` -> `references/flat-pe-model-recipe.md`
     (scope zone + label-collision QA).
4. **Wiring aesthetics**: follow the `simulink-power-electronics` skill ->
   `references/layout-wiring-recipe.md` — explicit positions, signal lines
   `add_line(...,'autorouting','smart')` (manual Points on smart lines ARE
   discarded at save; a persistent manual route on a SIGNAL line =
   delete_line -> re-add with `'autorouting','off'` -> set Points snapped to
   the real port positions — see that file's 2026-10-02 additions),
   physical wires straight by PORT ALIGNMENT (manual Points are silently
   ignored on LConn/RConn lines), `diag_count` = 0 in every system, canvas
   screenshot + visual-judge pass.
5. **Run once and pop all scopes** (data lives only after a run):

```matlab
function open_scopes(skip)
% OPEN_SCOPES  Simulate once (unless skip), then open every scope window.
root = 'C:\path\to\model';  % real folder
cd(root);
mdl = 'ModelName';
f = fullfile(root, [mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl, 0); end   % MCP workers alternate:
load_system(f);                                 % never trust in-memory copy
if nargin < 1, skip = false; end
if ~skip, sim(mdl); end
scopes = {'Scope_Gates','Scope_Vin','Scope_Iin','Scope_Vout','Scope_Iout'};
for k = 1:numel(scopes)
    set_param(sprintf('%s/%s', mdl, scopes{k}), 'Open', 'on');  % '/', not fullfile
end
fprintf('SCOPES_OPEN (%d)\n', numel(scopes));
end
```

6. **QA.** Sim succeeds with all other metrics unchanged; every From tag
   resolves to a global Goto (an unresolved tag compiles but logs nothing —
   silent); canvas screenshot still passes the orthogonal-layout gate.

## Read the scopes as a build smoke test (caught a real bug once)

- Vout pinned at the INPUT value while Iout = 0 -> a shunt branch (output
  cap / load) is floating: check BOTH terminals of every shunt element —
  the bottom/rail wire is easy to remember and the top/node wire easy to
  forget. Also check freewheel-diode anode actually reaches the rail.
- Vout far above D*Vin at light current -> converter went DCM (ripple >
  load current); raise fsw or L, do not "fix" it in the controller.
- Iin = 0 with Vout finite -> the gate is not reaching the device or the
  series path is broken upstream of the input measurement.

## Verified facts (R2024b, host hp — trust these, do not re-derive)

- Voltage Measurement: terminals `LConn(1)` = +, `LConn(2)` = −; signal on
  `Outport(1)`; there is no RConn.
- Current Measurement: series `LConn(1)` = in (+), `RConn(1)` = out;
  `Outport(1)` = current, positive entering LConn.
- Universal Bridge gate order `[A_up; A_dn; B_up; B_dn; C_up; C_dn]`,
  `RConn(1)` = DC+, `RConn(2)` = DC−. SVPWM Generator (2-Level) output P
  uses the same order; alpha-beta input mode = 2 scalar inports Ualpha/Ubeta.
- Scope `'LayoutDimensions'` cannot be set at add_block time (param error) —
  try/catch after creation.
- Goto/From across systems requires `TagVisibility','global'`.
