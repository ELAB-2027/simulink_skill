# Local Machine Setup (hp / R2024b)

Machine-specific environment, tool mapping, and verified build experience for
this host. Read this before the first model build or simulation of a session.

## Environment (verified 2026-09-13)

- MATLAB R2024b Update 9 (24.2), academic license, Windows 11.
- Toolboxes: Simulink, Simscape, Simscape Electrical, Simscape Battery,
  Control System, Motor Control Blockset, and the full university suite.
- Local model asset root: `C:\Users\hp\matlab-power-electronics-skill\`
  - `models/` 39 basic `.slx` in 7 categories (dc-dc, inverter, rectifier,
    pfc, modulation, control-test, hybrid)
  - `advanced_models/` 10 advanced `.slx` (Totem-Pole GaN PFC, MMC-HVDC,
    PMSM FOC, VSG, CLLLC, FCS-MPC, ADRC Buck, TPS-DAB, interleaved Boost
    PFC, STATCOM), each with a README
  - `contest-designs/`, `LLC_Resonant/`, `LLC_V2/`, `SOC_Estimation/`,
    `DC_Electronic_Load/`, `research/`
  - 55 `.slx` total. Use these as references/patterns; edit only after
    saving a derived copy.
- MCP server: `matlab-mcp-core-server-win64.exe` at the asset root,
  configured in `C:\Users\hp\.zcode\cli\config.json` with
  `--matlab-root C:\Program Files\MATLAB\R2024b` and
  `--initial-working-folder C:\Users\hp\matlab-power-electronics-skill`.

## Tool Surface Mapping

This host provides 4 MATLAB MCP tools, not the Simulink Agentic Toolkit
surface. Map workflow steps accordingly:

| Workflow need | Local tool |
| --- | --- |
| `model_overview` / `model_read` | `evaluate_matlab_code` with `find_system`, `get_param` probes |
| `model_query_params` | `evaluate_matlab_code` with `get_param` |
| `model_edit` | generated `.m` script via `run_matlab_file` (preferred for complex edits) |
| compile / simulate / measure | `.m` script: `sim`, then numeric checks on logged data |
| static script check | `check_matlab_code` |

Write complex operations as a reproducible `.m` script and run it with
`run_matlab_file`; avoid long probe chains. Keep scripts ASCII in `fprintf`
strings to avoid codepage issues on the Chinese-locale host.

## powerlib Port Map (verified on R2024b)

Verified empirically by building and simulating a buck converter:

- DC Voltage Source: `RConn(1)` = plus, `LConn(1)` = minus.
- Mosfet: `LConn(1)` = drain, `RConn(1)` = source, `Inport(1)` = gate.
- Diode: `LConn(1)` = anode, `RConn(1)` = cathode. Buck freewheel diode:
  cathode to switch node, `Orientation='up'` puts the cathode on top.
- Voltage Measurement: both terminals are on `LConn` (`LConn(1)` = plus,
  `LConn(2)` = minus); there is no `RConn`.
- Series RLC Branch: `LConn(1)` left, `RConn(1)` right before rotation.
- Ground: single `LConn(1)`.

## Control Block Pitfalls (verified)

- Sum with `Inputs='+-'`: `Inport(1)` = plus, `Inport(2)` = minus. Reference
  goes to plus, feedback to minus. Reversed symptom: PI saturates at the
  lower limit, Vout near 0 with tiny ripple.
- PID Controller mask: output limits require
  `LowerSaturationLimit <= InitialConditionForIntegrator /
  InitialConditionForFilter <= UpperSaturationLimit`, otherwise mask
  initialization errors. Anti-windup: `'AntiWindupMode','clamping'`.
- Breaker (`'External','on'`, closes when control > 0) only opens at a
  natural current zero crossing; implement DC load steps as "close a series
  branch" (Breaker + resistor, Step 0->1 at the disturbance time).

## Layout Enforcement (required for generated models)

> UPDATED 2026-09-30: the arrangeSystem + manual-Points flow below is
> superseded for SPS models by `references/layout-wiring-recipe.md`
> (explicit positions + `autorouting','smart'`, port-aligned straight power
> wires, diag_count = 0, screenshot + visual-judge gate). Manual Points are
> discarded by smart routing and silently ignored on physical lines.

Apply after wiring, before saving:

1. Set an explicit `Position` for every block.
2. `Simulink.BlockDiagram.arrangeSystem(mdl)` (warning is harmless on SPS
   models), then reset every line via
   `set_param(line,'Points',zeros(0,2))`.
3. Manhattan-fix remaining diagonal segments and count violations (diagonal
   segments, block overlaps, line crossings) — all must be 0. A working
   implementation of the counter/fixer is
   `contest-designs/infineon-wbg-isolated-bidirectional-600w/validate_and_orthogonalize_model_layout.m`.
4. Screenshot the canvas as visual evidence before reporting "layout clean".

## Verified Baseline: Closed-Loop Buck

24 V -> 12 V, fsw 50 kHz, L = 100 uH, C = 220 uF, voltage-mode PI
(P = 0.02, I = 150, duty clamped [0.02 0.9]), load step 2 A -> 4 A at
t = 0.15 s: steady-state error 0.13%, dip 9.88 V with clean recovery,
0 diagonal segments. Use as the starting point for closed-loop DC-DC work.

## Known Incident: License Error 5201

Symptom: modal dialog "无法与所需的 MathWorks 服务通信(错误 5201)", MATLAB
unresponsive, then the process exits; all MCP calls time out. Cause:
MathWorks Service Host not running. Fix: restart MATLAB desktop (PowerShell
`Start-Process 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe'`); the
service host starts with it and MCP recovers. Check `tasklist` for
`MATLAB.exe` and `MathWorksServiceHost.exe` before deeper debugging.

## Known Incident: MCP "timeout waiting for worker to start" (2026-10-02)

After a long session the MCP server may report `timeout waiting for worker
to start` even with MATLAB.exe running, and never recover. Fallback that
kept the session productive: run everything through the shell instead —
`"C:\Program Files\MATLAB\R2024b\bin\matlab.exe" -batch "cd(...); build_x; sim_x"`
(background it, poll the `*_out.txt` logs). Note a second desktop MATLAB
may hold the model; `bdIsLoaded` + `close_system(mdl,0)` in every script
keeps `-batch` runs safe.
