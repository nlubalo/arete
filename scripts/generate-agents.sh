#!/bin/bash
#
# Generate platform-specific agent files from canonical agents/
#
# Usage:
#   ./scripts/generate-agents.sh --platform <opencode|copilot|codex> --output <dir>
#
# Examples:
#   ./scripts/generate-agents.sh --platform opencode --output ~/.config/opencode/agents
#   ./scripts/generate-agents.sh --platform copilot --output ~/.copilot/agents
#   ./scripts/generate-agents.sh --platform codex --output ~/.codex/agents
#
# Reads from: agents/*.md (Claude Code format)
# Generates platform-specific agents based on --platform flag

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$ROOT_DIR/agents"

usage() {
    cat << EOF
Usage: $(basename "$0") --platform <opencode|copilot|codex> --output <dir>

Generate platform-specific agent files from canonical agents/

Options:
  --platform <platform>   Target platform: opencode, copilot, or codex
  --output <dir>          Output directory for generated agents

Examples:
  $(basename "$0") --platform opencode --output ~/.config/opencode/agents
  $(basename "$0") --platform copilot --output ~/.copilot/agents
  $(basename "$0") --platform codex --output ~/.codex/agents
EOF
    exit 1
}

# Parse arguments
PLATFORM=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            [[ $# -ge 2 ]] || usage
            PLATFORM="$2"
            shift 2
            ;;
        --output)
            [[ $# -ge 2 ]] || usage
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [[ -z "$PLATFORM" ]] || [[ -z "$OUTPUT_DIR" ]]; then
    echo "Error: --platform and --output are required"
    echo ""
    usage
fi

if [[ "$PLATFORM" != "opencode" ]] && [[ "$PLATFORM" != "copilot" ]] && [[ "$PLATFORM" != "codex" ]]; then
    echo "Error: platform must be 'opencode', 'copilot', or 'codex'"
    echo ""
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Generating agents for $PLATFORM..."
echo "Output: $OUTPUT_DIR"
echo ""

# Process each agent file (skip references/ subdirectory)
for agent_file in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_file" ] || continue

    filename=$(basename "$agent_file")
    name="${filename%.md}"

    echo "Processing: $name"

    # Extract frontmatter and body
    in_frontmatter=false
    frontmatter_done=false
    description=""
    body=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---" ]] && [[ "$frontmatter_done" == false ]]; then
            if [[ "$in_frontmatter" == false ]]; then
                in_frontmatter=true
                continue
            else
                in_frontmatter=false
                frontmatter_done=true
                continue
            fi
        fi

        if [[ "$in_frontmatter" == true ]]; then
            # Extract description from frontmatter
            if [[ "$line" =~ ^description:\ *(.*) ]]; then
                description="${BASH_REMATCH[1]}"
            fi
        elif [[ "$frontmatter_done" == true ]]; then
            body+="$line"$'\n'
        fi
    done < "$agent_file"

    # Remove leading newline from body
    body="${body#$'\n'}"

    # Generate platform-specific version
    if [[ "$PLATFORM" == "opencode" ]]; then
        cat > "$OUTPUT_DIR/$filename" << EOF
---
description: $description
mode: subagent
---
$body
EOF
        echo "  -> $OUTPUT_DIR/$filename"

    elif [[ "$PLATFORM" == "copilot" ]]; then
        cat > "$OUTPUT_DIR/${name}.agent.md" << EOF
---
name: $name
description: $description
---
$body
EOF
        echo "  -> $OUTPUT_DIR/${name}.agent.md"
    elif [[ "$PLATFORM" == "codex" ]]; then
        # Embed the teaching reference so installed agents are self-contained.
        if [[ "$name" == "teacher" ]]; then
            body="${body//\[\`reference\/teaching-template.md\`\]\(reference\/teaching-template.md\)/the Teaching Template included below}"
            body+=$'\n'
            body+="$(cat "$AGENTS_DIR/references/teaching-template.md")"
        fi

        # TOML basic strings need backslashes and quotes escaped, including
        # triple quotes in future agent instructions. Preserve actual newlines.
        toml_description="${description//\\/\\\\}"
        toml_description="${toml_description//\"/\\\"}"
        toml_body="${body//\\/\\\\}"
        toml_body="${toml_body//\"/\\\"}"
        printf 'name = "%s"\ndescription = "%s"\ndeveloper_instructions = """\n%s"""\n' \
            "$name" "$toml_description" "$toml_body" > "$OUTPUT_DIR/${name}.toml"
        echo "  -> $OUTPUT_DIR/${name}.toml"
    fi

done

echo ""
echo "Done! Generated $PLATFORM agents in $OUTPUT_DIR"
