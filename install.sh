#!/bin/bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf $TMP' EXIT

echo "Installing third-party skills..."

# --- vercel-labs/agent-skills ---
echo "  → vercel-react-best-practices, web-design-guidelines"
git clone --depth 1 --filter=blob:none --sparse https://github.com/vercel-labs/agent-skills.git "$TMP/agent-skills"
cd "$TMP/agent-skills"
git sparse-checkout set skills/react-best-practices skills/web-design-guidelines
cp -r skills/react-best-practices "$SCRIPT_DIR/vercel-react-best-practices"
cp -r skills/web-design-guidelines "$SCRIPT_DIR/web-design-guidelines"

# --- planning-with-files ---
echo "  → planning-with-files"
git clone --depth 1 https://github.com/OthmanAdi/planning-with-files.git "$TMP/planning"
mkdir -p "$SCRIPT_DIR/planning-with-files"
cp "$TMP/planning/skills/planning-with-files/SKILL.md" "$SCRIPT_DIR/planning-with-files/"

# --- Three.js mega-skill (mrgoonie) ---
echo "  → threejs"
git clone --depth 1 --filter=blob:none --sparse https://github.com/mrgoonie/claudekit-skills.git "$TMP/claudekit"
cd "$TMP/claudekit"
git sparse-checkout set .claude/skills/threejs
cp -r .claude/skills/threejs "$SCRIPT_DIR/threejs"

# --- Three.js 10-pack (CloudAI-X) ---
echo "  → threejs-fundamentals, geometry, materials, lighting, textures, animation, loaders, shaders, postprocessing, interaction"
git clone --depth 1 --filter=blob:none --sparse https://github.com/CloudAI-X/threejs-skills.git "$TMP/threejs-skills"
cd "$TMP/threejs-skills"
git sparse-checkout set skills/threejs-fundamentals skills/threejs-geometry skills/threejs-materials skills/threejs-lighting skills/threejs-textures skills/threejs-animation skills/threejs-loaders skills/threejs-shaders skills/threejs-postprocessing skills/threejs-interaction
for skill in threejs-fundamentals threejs-geometry threejs-materials threejs-lighting threejs-textures threejs-animation threejs-loaders threejs-shaders threejs-postprocessing threejs-interaction; do
  cp -r "skills/$skill" "$SCRIPT_DIR/$skill"
done

# --- Zustand Patterns ---
echo "  → zustand-patterns"
npx --yes skills add https://github.com/yonatangross/orchestkit --skill zustand-patterns --target "$SCRIPT_DIR/.temp-install" 2>/dev/null
cp -rL "$SCRIPT_DIR/.temp-install/zustand-patterns" "$SCRIPT_DIR/zustand-patterns" 2>/dev/null || true
rm -rf "$SCRIPT_DIR/.temp-install"

# --- React Native Best Practices ---
echo "  → react-native-best-practices"
npx --yes skills add https://github.com/callstackincubator/agent-skills --skill react-native-best-practices --target "$SCRIPT_DIR/.temp-install" 2>/dev/null
cp -rL "$SCRIPT_DIR/.temp-install/react-native-best-practices" "$SCRIPT_DIR/react-native-best-practices" 2>/dev/null || true
rm -rf "$SCRIPT_DIR/.temp-install"

# --- WebGPU Three.js TSL ---
echo "  → webgpu-threejs-tsl"
git clone --depth 1 --filter=blob:none --sparse https://github.com/dgreenheck/webgpu-claude-skill.git "$TMP/webgpu"
cd "$TMP/webgpu"
git sparse-checkout set skills/webgpu-threejs-tsl
cp -r skills/webgpu-threejs-tsl "$SCRIPT_DIR/webgpu-threejs-tsl"

echo ""
echo "Done. Installed 16 skills."
echo ""
echo "Custom skills (already in repo):"
echo "  bem-class-names-only  nextjs-hydration-rules  dto-mapper-layer"
echo "  react-fe-skill        js-coding-conventions   ts-conventions"
echo "  axios-fetch-conventions  lodash-conventions   ahooks-best-practices"
