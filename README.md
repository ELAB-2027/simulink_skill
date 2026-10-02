# MATLAB / Simulink Skills

A collection of agent skills for MATLAB / Simulink power-electronics modeling,
inspection, debugging, and waveform observability. Each skill is a
self-contained folder with a `SKILL.md` entry point, designed for coding
agents that support the agent-skills convention (ZCode, Codex, Claude Code,
etc.).

一套面向 MATLAB / Simulink 电力电子建模的 Agent Skill 合集：模型检查、
波形与控制链路调试、元件布局，以及开关器件波形的可观测性。每个 skill
都是一个独立目录，入口为 `SKILL.md`，兼容支持 agent-skills 约定的主流
编码智能体（ZCode、Codex、Claude Code 等）。

## Skills / 技能列表

| Skill | What it does / 用途 |
| --- | --- |
| [`simulink-power-electronics`](simulink-power-electronics/) | Router-style skill for Simulink / Simscape Electrical power-electronics models: topology classification, model inspection, waveform & control debugging, schematic layout, and staged validation (`opened` → `compiled` → `simulated` → `measured`). Ships with 11 domain subskills (three-phase grid inverter, DC-DC converters, motor drives, batteries/BMS, multilevel MMC, HVDC/FACTS, and more), a reference library, and validation scripts. 电力电子模型的“路由型”技能：拓扑识别、模型检查、波形与控制调试、原理图布局、分级验证；含 11 个领域子技能、参考文档库与校验脚本。 |
| [`simulink-scope-observability`](simulink-scope-observability/) | Guarantees any switching-converter model ships with waveform observation built in: a gate-signal scope for EVERY switching device plus input/output voltage & current scopes, wired via global Goto/From, simulation run once, all scope windows popped open. 让每一个开关变换器模型自带波形观测：为每个开关器件加门极示波器，加上输入/输出电压电流示波器，通过全局 Goto/From 干净接线，跑一次仿真并弹出全部示波器窗口。 |

## Repository Layout / 仓库结构

```text
matlab-skills/
├── README.md                        # this file
├── LICENSE                          # Apache License 2.0
├── install.sh                       # installer (macOS / Linux / Git Bash)
├── install.ps1                      # installer (Windows PowerShell)
├── simulink-power-electronics/      # main router skill
│   ├── SKILL.md
│   ├── README.md                    # detailed docs / 详细文档
│   ├── references/                  # workflow, layout, debugging guides
│   ├── subskills/                   # 11 domain subskills
│   ├── scripts/                     # environment & structure validation
│   └── assets/
└── simulink-scope-observability/
    └── SKILL.md
```

## Installation / 安装

### One-line installer

**macOS / Linux / Git Bash:**

```bash
git clone https://github.com/ELAB-2027/simulink_skill.git
cd simulink_skill
./install.sh
```

**Windows PowerShell:**

```powershell
git clone https://github.com/ELAB-2027/simulink_skill.git
cd simulink_skill
.\install.ps1
```

The installers copy each skill folder into your agent's skills directory and
print where it went. Supported targets:

- ZCode: `~/.zcode/skills/` (or `~/.agents/skills/`)
- Claude Code: `~/.claude/skills/`
- Codex: `~/.codex/skills/`

### Manual install / 手动安装

Copy the skill folder you want into your agent's skills directory, then
restart the agent:

```bash
# example: ZCode / Claude Code
cp -r simulink-power-electronics  ~/.claude/skills/
cp -r simulink-scope-observability ~/.claude/skills/
```

## Usage / 使用

After installation, invoke the skill by name (or just describe the task —
agents auto-discover skills by their `description` front-matter):

```text
Please use simulink-power-electronics to read the current project, confirm
the Simulink MCP tools are reachable, and summarize the architecture of the
Simulink model. Then check for known bugs, modeling risks, or improvement
opportunities. Propose an edit plan first, and wait for my approval.
```

```text
给这个 Buck 变换器模型加上完整的波形观测：每个开关管的门极信号、
输入输出电压电流都要有示波器，接线用全局 Goto/From，跑一次仿真
并把所有示波器窗口弹出来。
```

## Toolchain / 工具链

Real model inspection, editing, and validation require:

- MATLAB R2023a or later
- Simulink
- MATLAB MCP Core Server (e.g. the `mcp__matlab__*` toolset)
- Simulink Agentic Toolkit (optional, for agentic model editing)

Models with physical electrical networks additionally require:

- Simscape
- Simscape Electrical

If MATLAB MCP is unavailable, the skills fall back to file/script review and
explicitly report that model-level inspection or validation is blocked.

## Validation / 校验

```bash
python3 simulink-power-electronics/scripts/check_environment.py
python3 simulink-power-electronics/scripts/validate_skill_structure.py --quiet
python3 simulink-power-electronics/subskills/three-phase-grid-inverter/scripts/print_table7_state_vectors.py --format json
```

`simulink-scope-observability` was verified end-to-end on MATLAB R2024b
(MOSFET buck demo: 0 diagonal wiring faults, Vout 11.55 V vs 12 V ideal at
50% duty, 5 scopes opened with live data).

## Contributing / 贡献

Contributions are welcome, especially model-derived debugging notes, layout
rules, validation scripts, and new domain subskills. `simulink-power-electronics`
supports user-approved self-iteration: it can review MathWorks examples or
open-source Simulink projects, extract repeatable patterns, and promote
validated findings into the skill.

## License / 许可证

[Apache License 2.0](LICENSE)
