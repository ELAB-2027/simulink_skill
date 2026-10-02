# Verified Layout & Wiring Recipe for Programmatic SPS Models

Status: VERIFIED 2026-09-30 on host hp/R2024b by building `PMSM_FOC.slx`
(user-approved self-iteration; evidence: 77 top-level lines + control
subsystem, 0 diagonal segments in every system, two visual-judge passes,
closed-loop metrics stable across re-layouts). Reuse wholesale before any
programmatic model build or re-layout.
Extended 2026-10-02 (flat three-phase AFE build, user-approved): routing-
engine behavior, corridor/rail algorithm for bridges, net-aware crossing
QA, label-collision QA, and vectorized control chains — see the
`2026-10-02 ADDITIONS` section at the end.

## Non-negotiable wiring rules

1. Signal lines: `add_line(..., 'autorouting', 'smart')`. NEVER combine
   smart routing with manual `set_param(h,'Points',...)` on the same line —
   the routing engine discards/overrides manual points on save/reopen.
2. Physical (LConn/RConn) power lines: manual `Points` are silently ignored
   (set_param succeeds, readback unchanged). Make power wires straight by
   ALIGNING BLOCKS instead: read port coordinates via
   `get_param(portHandle,'Position')` and nudge the partner block's Position
   until ports share y (horizontal wire) or x (vertical wire).
   Example: DC Voltage Source ports sit at top-15/+? measure, do not guess.
3. Every block gets an explicit, grid-planned `Position`. Reserve label
   space: Bus Selector / Mux / Goto output labels render to the RIGHT of the
   port and can be ~150 px long; keep the next column of blocks clear.
4. Terminal sides decide placement. Universal Bridge: phase terminals
   (LConn 1..3) on the LEFT edge, DC terminals (RConn 1=+, 2=-) on the RIGHT
   edge, gate Inport top-left. Natural chain: PMSM <- Current Measurement <-
   UB <- DC source (DC at the right, ports y-aligned). Current Measurement
   blocks are y-aligned to the UB phase ports by construction.
5. Current Measurement polarity: measured current is positive entering
   LConn. If the chain flows right-to-left, set the block `Orientation`
   to 'left' — ports mirror WITH the block, LConn stays LConn, so the sign
   is preserved. (Verified: closed-loop metrics unchanged.)
6. Cross-canvas signals: global Goto/From pairs (Goto clustered near the
   source, From near the consumer). No long trunks across the canvas.
7. Names/labels: keep block names short; leave vertical gap >= 10 px between
   stacked small blocks (From/Goto) or their text labels collide.

## QA gate (run before claiming "layout clean")

```matlab
function [nd, nl] = diag_count(sys)      % 0 diagonals required, all systems
    lh = find_system(sys, 'FindAll', 'on', 'Type', 'line');   % 'line', not 'lines'
    nd = 0; nl = numel(lh);
    for k = 1:nl
        try
            pts = get_param(lh(k), 'Points');
            for j = 1:size(pts,1)-1
                dx = pts(j+1,1)-pts(j,1);  dy = pts(j+1,2)-pts(j,2);
                if abs(dx) > 1e-9 && abs(dy) > 1e-9, nd = nd + 1; end
            end
        catch
        end
    end
end
```

Screenshot per system: `print('-sModel', '-dpng', '-r110', file)` from a
script FILE run via `run_matlab_file` (the interactive eval call times out at
30 s while the export continues server-side; poll the output file). Then
dispatch the visual-judge agent on the PNGs and treat fail items as a work
list. Smart routing may emit small orthogonal jogs — acceptable; diagonals
are not.

## Port coordinates and safe connect helpers (paste into build script)

```matlab
function p = ports_of(blk)                 % position matrices per port family
    h = get_param(blk, 'PortHandles');
    p = struct('Inport', grab(h.Inport), 'Outport', grab(h.Outport), ...
               'LConn', grab(h.LConn), 'RConn', grab(h.RConn));
end
function m = grab(arr)
    m = zeros(numel(arr), 2);
    for k = 1:numel(arr), m(k,:) = get_param(arr(k), 'Position'); end
end
function p = port_pos(blk, typ, num)       % typ in Inport/Outport/LConn/RConn
    h = get_param(blk, 'PortHandles');
    p = get_param(h.(typ)(num), 'Position');
end
function hl = wl(sys, src, dst, varargin)  % signal connect, names RELATIVE to sys
    hl = add_line(sys, src, dst, 'autorouting', 'smart');
end
```

Branching: a second `add_line` from the same source port auto-branches.

## R2024b library facts verified this session

- Library root is `sps_lib` (`powerlib` is an empty legacy shell).
  Blocks: `sps_lib/Sources/DC Voltage Source`,
  `sps_lib/Power Electronics/Universal Bridge`,
  `sps_lib/Electrical Machines/Permanent Magnet Synchronous Machine`,
  `sps_lib/Sensors and Measurements/Current Measurement`,
  `sps_lib/Passives/Series RLC Branch`, `sps_lib/Utilities/Ground`,
  `sps_lib/powergui`.
- SVPWM: `sps_lib/Power Electronics/Power Electronics Control/SVPWM Generator\n(2-Level)`
  (name contains a newline). Set `InputType` to 'alpha-beta components' on
  the COPY (library is locked) -> 2 scalar inports Ualpha, Ubeta; params
  `Fc` (carrier Hz), `Ts`, `SwitchingPattern`. Output P is a 6-vector.
- UB gate vector order (measured): [A_up; A_dn; B_up; B_dn; C_up; C_dn];
  RConn(1)=DC+, RConn(2)=DC-. Battery: RConn(1)=+ (top), LConn(1)=- (bottom).
- PMSM m-bus (Bus Selector) signal names: 'Rotor speed wm (rad/s)',
  'Rotor angle thetam (rad)', 'Electromagnetic torque Te (N*m)',
  'Stator current is_a (A)', ...
- Mux parameter is `Inputs`, Demux parameter is `Outputs`; Demux width must
  divide the input width. Fcn block has ONE (vector) input — multi-variable
  via Mux + `u(1),u(2),u(3)` in the expression. `'ABC'(k)` literal char
  indexing is invalid MATLAB.
- Discrete PID params: `Controller='PI'`, `TimeDomain='Discrete-time'`,
  `SampleTime`, `P`, `I`, `InitialConditionForIntegrator`,
  `LimitOutput`, `UpperSaturationLimit`, `LowerSaturationLimit`,
  `AntiWindupMode='clamping'`.
- Native signal logging (preferred over To Workspace — see pitfalls):
  `set_param(portHandle,'DataLogging','on','DataLoggingNameMode','Custom',
  'DataLoggingName','name')` (port handle, NOT line handle; param is
  `DataLoggingName`), read back from `S.logsout.get(name).Values`.

## Formula / convention pitfalls that cost hours (same session)

- Inverse Park must be `Ualpha = Vd*cos(th) - Vq*sin(th)`,
  `Ubeta = Vd*sin(th) + Vq*cos(th)`. The plausible-looking
  `-Vd*sin(th)+Vq*cos(th)` form swaps the d/q basis vectors and the closed
  loop destabilizes with currents "stuck" near the d-axis.
- SPS PMSM rotor-angle convention: machine d-axis sits at `p*thetam - pi/2`
  in the alpha-beta frame. Verify per model with DC-alignment calibration:
  lock the rotor with a DC current vector at gamma in {0, pi/2, pi, 3*pi/2};
  delta0 = gamma - p*thetam_lock must agree across all four (was -pi/2,
  consistent to 1e-6). A voltage-drag calibration is contaminated by the
  load angle and gives wrong offsets.
- Small-inertia motors (J ~ 1e-3): an aggressive speed loop saturates iq,
  back-EMF exceeds Vdc/2 and the loop limit-cycles. Tune for ~110 rad/s
  bandwidth and clamp iq to rated current.

## Harness pitfalls (MATLAB MCP on this host)

- Interactive evals and script runs may land on DIFFERENT MATLAB workers.
  Before simulating, always `close_system(mdl,0)` + `load_system(absolute
  path)` and assert a fingerprint block exists — a stale in-memory copy
  silently returns old results.
- `sim()` may wipe earlier script variables in this harness; derive paths
  from `pwd` (set by `cd` at script start), not variables defined earlier.
- To Workspace capture into the base workspace was unreliable across
  workers; S.logsout was deterministic. Prefer signal logging.
- Physical-line manual Points are ignored (see rule 2).
- `matlab -batch "cd(...); script"` beats interactive MCP evals for anything
  over ~20 s (interactive calls time out at 30 s while the op continues or
  dies). Write results to text files and poll them from the shell.
- A syntax error introduced into a build script silently leaves the OLD
  `.slx` on disk and stale `*_out.txt` logs; after patching a build script,
  verify the new build actually ran (fresh log timestamp / new block count)
  before trusting QA output.

## 2026-10-02 ADDITIONS (flat three-phase AFE build, hp/R2024b)

Evidence: flat 102-block model `ThreePhase_AFE_PFC` built from a
regenerating script; wire QA counts driven 21 -> 12 -> 8 -> 7 -> 3 -> 1
crossings by geometry alone; label collisions 13 -> 0; 0 diagonals;
closed-loop metrics unchanged across all re-layouts. All items below were
reproduced at least twice in that build.

### Routing-engine behavior (empirical)

- Smart autorouting prefers: vertical first at the source x, then a long
  horizontal at (or near) the destination port y, then a short entry. A
  far-apart source/destination therefore yields a "lane at destination y"
  even when a shorter 1-bend route exists.
- When the straight lane is blocked by a BLOCK, smart routing detours —
  sometimes wildly (observed: around the canvas top at y < 0, or a
  rectangular loop hugging the block). Detours are a placement smell: move
  or shrink the obstruction instead of accepting the loop.
- BLOCKING-BY-PLACEMENT is a steering tool: deliberately put a small block
  (e.g. a From tag) on an undesired straight lane to force the router onto
  a parallel lane. Used to push DC+ drain-to-drain hops off y55 (where gate
  ports live, same height) onto a clean y44 lane.
- Manual `Points` on a smart-routed SIGNAL line are discarded at save (the
  old "Points" rule 1 extends to this). Persistent manual route on a signal
  line: `delete_line` -> `add_line(sys, outH, inH, 'autorouting','off')` ->
  `set_param(h,'Points',...)`. Then snap: first/last row to the REAL port
  positions and align row-2 / row(end-1) y to the ports, else the port stub
  (+-5 px outside the block edge) renders a diagonal.
- `autorouting','off'` initially draws a straight diagonal — always follow
  with `set_param Points` in the same call frame.
- Same-net daisy chains (port-to-port lines sharing a trunk) render as ONE
  wire with junction dots. That is correct schematic practice; QA must
  classify by net (union of lines sharing a `SrcPortHandle`) or it will
  report false "overlaps".

### Port geometry, measured (R2024b sps_lib)

Read actual positions via PortHandles after placement; do NOT assume:

- `Mosfet`, Orientation down, Position [x1 y1 x2 y2]:
  drain = (cx, y1-15), source = (cx, y2+15), gate = (cx-20, y1-15).
  Gate and drain sit at the SAME height -> inter-leg DC+ hops at drain y
  will pass exactly through the neighbouring gate port. Force a lane.
- `Series RLC Branch` (C type, Orientation down, tall block): the icon
  auto-shrinks; ports landed at 1/4 and 3/4 of the requested height, not at
  the requested edges. Always re-read ports after add_block.
- `Three-Phase V-I Measurement`: RConn1/2/3 (phases) and signal out1/out2
  (Vabc, Iabc) are ALL on the right edge, interleaved vertically. Any tag
  cluster placed right of the block fights the phase feed lanes; route the
  signal tags with explicit points (exit right of the block first, then run
  left) or place the demux/tag cluster in a different zone fed by a From.
- `Breaker` (External on, Orientation down): the control inport renders on
  the TOP edge beside LConn1 — a control feed from above collides with the
  DC+ entry. Prefer a Mosfet as a load switch (gate at top-LEFT, horizontal
  feed, body diode polarity chosen so OFF blocks the load current).
- Relay mask rule: `OnSwitchValue >= OffSwitchValue` or mask init fails.
- Rate Limiter params: `RisingSlewLimit` / `FallingSlewLimit`.
- Goto/From tags are case-sensitive and an unmatched From may NOT hard-error
  at update — it ran and produced garbage (36 A circulating current).
  Verify tag round-trips programmatically (GotoTag sets vs From GotoTag
  sets, exact string match) as a build-time assert.

### Corridor/rail algorithm for bridge power stages

For a flat 3-phase bridge fed from one side (worst-case routing problem):

1. Measure real port coordinates of legs, then design LANES, not wires:
   - DC+ rail: hops between ADJACENT drain ports at their common y; if a
     conflict exists at that y (gate ports!), block the straight path with
     small blocks to force one parallel lane; daisy geographically
     (Q1->Q3->Q5->capacitor), never across three legs in one line.
   - DC- rail: same along the source ports.
2. Find the free horizontal WINDOWS through each leg x-range: between the
   upper block bottom and the series-link top, and between the link bottom
   and the lower block top (~10-15 px each). Middle/far phase feeds cross
   downstream legs INSIDE these windows without touching the links.
3. Staircase multi-row feeds (e.g. inductor ladder): map source port order
   (top-down) to row order monotonically, AND stagger the row x positions
   diagonally so the router's turn points order correctly (upper row turns
   first). Same-x rows make the router interleave turns and self-cross.
4. The farthest phase feed may need the under-bridge corridor (below the
   lower devices, above the DC- rail), crossing the DC- rail exactly once.
   Achievable minimum for a 3-leg left-fed bridge: 1 crossing.
5. Feed target choice flattens routes: connecting to the mid-node BOTTOM
   port (lower device drain) instead of the TOP port (upper source) is the
   same electrical node but yields a flatter, shorter route.

### QA gates (code sketches live in the AFE project folder)

Wiring-quality ladder — this is the ordered bar a user actually applies
(distilled from four rounds of user feedback on the 2026-10-02 AFE build:
"messy" -> "don't cross" -> "don't overlap" -> "run straighter"). Design
and验收 in this order; earlier items are hard gates, the last is a target:

1. no diagonals (hard)
2. no wire-wire crossings except the topological minimum (hard)
3. no wire-on-wire overlap except same-net T-junctions (hard)
4. no wire through any label text / no label-label collision (hard)
5. straight runs, few bends: mean <= ~1.5 turns/line, flag any line > 3
   turns (soft gate — optimize by moving the blocking block, never accept
   a router detour loop)

- diag_count (existing) — diagonals must be 0 everywhere.
- Net-aware crossing/overlap counter: collect all line Points -> segments;
  skip same-line and same-`SrcPortHandle` pairs; proper intersection via
  strict sign test (endpoint touches excluded); collinear overlap > 2 px.
  Report every crossing WITH line endpoints so fixes are surgical.
- Label-collision checker: estimated bboxes for block name labels (below
  block, ~6 px/char), From/Goto tag text (centered inside, SPILLS when the
  block is narrower than ~6*len+8 px), wire-name labels (midpoint), and
  annotations (~0.62*fontsize px/char). Fix by: `ShowName','off'` on pure
  tag-relay blocks, larger row pitch (>= 24-26 px for stacked tag rows),
  moving tag blocks out of name-label bands.
- Wire-through-tag checker: axis-parallel segment bbox vs tag-text boxes.
- Bend census: turns = size(Points,1)-2 per line; report lines >= 3 turns.
  Mean ~1.2 turns/line is achievable on a 100+-block flat PE model.
- A visual judge can misread in-block icon glyphs (MOSFET body diode) as
  junction dots. Before "fixing" a ghost short, prove it electrically
  (balanced 3-phase sim) or via a port-level netlist.

### Structure choices that remove crossings wholesale

- Net-tag architecture: EVERY control/measurement/gate connection via
  Goto/From tags; zones then have only local wires, and re-laying out one
  zone never re-routes another. Gate drives: From[g_k] + a SHORT named
  wire `g_k` right at each device gate (visible AND tidy), written by
  Gotos at the drive chains and read again by scopes.
- Vectorize control chains to kill fan-out matrices: a 3x3 matrix Gain
  (`Multiplication','Matrix(K*u)'`, K = I - ones/3) does abc common-mode
  removal in ONE block; Discrete Transfer Fcn and Gain/Product are
  element-wise on vectors. A 16-block 3x3 demux/sum fan-out (16 crossings)
  collapsed to a straight 9-block chain (0 crossings).
- Complementary gates without a NOT chain: two Relays on the same error
  with swapped `On/OffOutputValue` — avoids the long inverter feedback
  drop that used to cross everything.
