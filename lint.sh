#!/usr/bin/env bash
set -euo pipefail

# Generic lint runner for GitHub Actions composite action.
# Runs enabled linters against the repo, skipping each gracefully
# if no matching files exist.
#
# Inputs (via environment):
#   LINT_LINTERS  - newline-separated list of linters to run (inline # comments supported)
#   ACTION_PATH   - path to the action directory (for default configs)

# Resolve action path (set by action.yml, fallback to script's directory for local use)
ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")" && pwd)}"

# Parse enabled linters into an associative array for O(1) lookup
declare -A ENABLED
while IFS= read -r linter; do
  linter=$(echo "$linter" | sed 's/#.*//' | xargs)  # strip comments, trim whitespace
  [ -n "$linter" ] && ENABLED["$linter"]=1
done <<< "${LINT_LINTERS:-}"

PASS=0
FAIL=0
SKIPPED=0
FAILURES=()

run_linter() {
  local name="$1"
  shift
  local files=("$@")

  # Check if linter is enabled
  if [ -z "${ENABLED[$name]:-}" ]; then
    return
  fi

  # Check if files exist
  if [ ${#files[@]} -eq 0 ]; then
    echo "⏭️  $name: skipped (no matching files)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  echo "▶️  $name: checking ${#files[@]} file(s)..."
  local return_code=0
  case "$name" in
    hadolint)
      for f in "${files[@]}"; do
        hadolint "$f" || return_code=1
      done
      ;;
    shellcheck)
      shellcheck "${files[@]}" || return_code=1
      ;;
    yamllint)
      # Use repo's .yamllint.yml if present, otherwise use the action's default
      local yamllint_args=(--strict)
      if [ ! -f .yamllint.yml ] && [ ! -f .yamllint.yaml ] && [ -f "$ACTION_PATH/.yamllint.yml" ]; then
        yamllint_args+=(-c "$ACTION_PATH/.yamllint.yml")
      fi
      yamllint "${yamllint_args[@]}" "${files[@]}" || return_code=1
      ;;
    actionlint)
      actionlint "${files[@]}" || return_code=1
      ;;
    ruff)
      ruff check "${files[@]}" || return_code=1
      ruff format --check "${files[@]}" || return_code=1
      ;;
    golangci-lint)
      golangci-lint run ./... || return_code=1
      ;;
    pyright)
      pyright "${files[@]}" || return_code=1
      ;;
    blinter)
      blinter "${files[@]}" || return_code=1
      ;;
    govulncheck)
      govulncheck ./... || return_code=1
      ;;
    terraform-fmt)
      tofu fmt -check -recursive . || return_code=1
      ;;
    tflint)
      for dir in "${files[@]}"; do
        tflint --chdir "$dir" || return_code=1
      done
      ;;
  esac

  if [ $return_code -eq 0 ]; then
    echo "✅ $name: passed"
    PASS=$((PASS + 1))
  else
    echo "❌ $name: failed"
    FAIL=$((FAIL + 1))
    FAILURES+=("$name")
  fi
}

# --- Collect files for each linter ---

PRUNE='\( -path ./.git -o -path ./node_modules -o -path ./vendor -o -path ./_site -o -path ./.venv \)'

# Dockerfiles
mapfile -t dockerfiles < <(eval "find . $PRUNE -prune -o -name 'Dockerfile' -type f -print" 2>/dev/null)

# Shell scripts: bin/* and *.sh
mapfile -t shellfiles < <(eval "find . $PRUNE -prune -o \( -name '*.sh' -o -path '*/bin/*' \) -type f -print" 2>/dev/null)

# YAML files (skip pnpm-lock.yaml)
mapfile -t yamlfiles < <(eval "find . $PRUNE -prune -o \( -name '*.yaml' -o -name '*.yml' \) -not -name 'pnpm-lock.yaml' -type f -print" 2>/dev/null)

# GitHub Actions workflows
mapfile -t workflowfiles < <(find .github/workflows \( -name '*.yaml' -o -name '*.yml' \) -type f 2>/dev/null)

# Python files
mapfile -t pythonfiles < <(eval "find . $PRUNE -prune -o -name '*.py' -type f -print" 2>/dev/null)

# Go (presence of go.mod signals a Go module)
gofiles=()
if [ -f go.mod ]; then
  gofiles=("go.mod")
fi

# Windows batch files
mapfile -t batchfiles < <(eval "find . $PRUNE -prune -o \( -name '*.cmd' -o -name '*.bat' \) -type f -print" 2>/dev/null)

# Terraform files (check for .tf presence; terraform-fmt runs recursively, tflint needs directories)
mapfile -t tffiles < <(eval "find . $PRUNE -prune -o -name '*.tf' -type f -print" 2>/dev/null)
tfdirs=()
if [ ${#tffiles[@]} -gt 0 ]; then
  # terraform-fmt uses a sentinel so it's not skipped (it runs recursively from .)
  tfdirs=(.)
  # For tflint, find unique directories containing .tf files
  mapfile -t tflintdirs < <(printf '%s\n' "${tffiles[@]}" | xargs -I{} dirname {} | sort -u)
fi

# --- Run linters ---

run_linter "hadolint" "${dockerfiles[@]}"
run_linter "shellcheck" "${shellfiles[@]}"
run_linter "yamllint" "${yamlfiles[@]}"
run_linter "actionlint" "${workflowfiles[@]}"
run_linter "ruff" "${pythonfiles[@]}"
run_linter "golangci-lint" "${gofiles[@]}"
run_linter "pyright" "${pythonfiles[@]}"
run_linter "blinter" "${batchfiles[@]}"
run_linter "govulncheck" "${gofiles[@]}"
run_linter "terraform-fmt" "${tfdirs[@]}"
run_linter "tflint" "${tflintdirs[@]}"

# --- Summary ---

echo ""
echo "─────────────────────────────────────"

if [ $FAIL -eq 0 ]; then
  echo "✅ All checks passed. ($PASS passed, $SKIPPED skipped)"
else
  echo "❌ $FAIL failed, $PASS passed, $SKIPPED skipped: ${FAILURES[*]}"
  exit 1
fi
