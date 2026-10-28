# Arete for Codex

Install Arete skills and custom subagents for a current Codex release.

## Quick Install

```bash
git clone https://github.com/jesgarram/arete.git ~/.codex/arete

# Install skills without replacing your existing skills directory
mkdir -p ~/.agents/skills
for skill in ~/.codex/arete/skills/*; do
  ln -s "$skill" ~/.agents/skills/
done

# Generate architect, researcher, and teacher
~/.codex/arete/scripts/generate-agents.sh \
  --platform codex \
  --output ~/.codex/agents
```

## Per-Project Install

Run from the target project root:

```bash
mkdir -p .agents/skills
cp -r /path/to/arete/skills/* .agents/skills/

/path/to/arete/scripts/generate-agents.sh \
  --platform codex \
  --output .codex/agents
```

Start a new Codex session after installing or regenerating agents.

## Usage

Invoke skills with Codex's `$skill-name` syntax:

```text
$brainstorm I want to refactor our auth service
$ground
$explore
$decide
$stress
$ship
```

The brainstorm and ship skills request delegation when research, teaching, or diagrams are needed. You can also request agents directly:

```text
Use the researcher subagent to investigate repository auth patterns.
Use the teacher subagent to explain event sourcing in this brainstorm's context.
Use architect subagents in parallel to diagram these two ADR sections.
```

- `researcher` returns repository or web findings with sources.
- `teacher` writes explanations to `context/teachings/`; its generated instructions include the teaching template.
- `architect` returns a Mermaid diagram or `NO_DIAGRAM`.

## Configuration and Limitations

[Current Codex releases](https://learn.chatgpt.com/docs/agent-configuration/subagents) enable subagents by default and discover custom TOML agents in `~/.codex/agents/` or `.codex/agents/`. If your configuration disables them, set `enabled = true` in the existing `[agents]` section of your Codex `config.toml`.

- **Phase invocation**: Claude Code's `Skill(...)` calls are platform-specific. Invoke each phase skill explicitly in Codex.
- **Model routing**: Researcher uses `gpt-6-luna` with `high` reasoning; Architect and Teacher use `gpt-6.1-sol` with `medium` reasoning. These Codex counterparts preserve the lighter Researcher and more capable Architect/Teacher roles, following the [Codex subagent guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents). Your account must have access to the selected models. Edit `codex_model` and `codex_reasoning_effort` in `agents/*.md`, then regenerate to customize them. Claude's `model` settings remain separate. Agents without Codex overrides inherit the parent session's settings.
- **Permissions and tools**: subagents inherit the parent session's permissions and available tools. Web research requires available search tools. Tool names in canonical instructions (Glob, Grep, Read, WebSearch, WebFetch) refer to the equivalent Codex capabilities.
- **Parallel work**: agents share the project filesystem. Assign separate output files and collect results before using them. Delegation consumes additional tokens.

## Updating Agents

Edit canonical instructions in `agents/`, then rerun the generation command. Generation replaces matching output files, including local customizations, and leaves unrelated files alone. No manual registration in `config.toml` is needed.
