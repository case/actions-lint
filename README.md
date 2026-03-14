# actions-lint

A reusable GitHub Action that runs standard linters against a repository. Tools are installed via [mise](https://mise.jdx.dev/) and cached automatically.

## Usage

```yaml
- uses: actions/checkout@v6
- uses: case/actions-lint@main
```

By default, this runs four infrastructure linters that apply to virtually any repo. To enable language-specific linters, override the `linters` input:

```yaml
- uses: actions/checkout@v6
- uses: case/actions-lint@main
  with:
    linters: |
      hadolint
      shellcheck
      yamllint
      actionlint
      ruff
      golangci-lint
```

## Inputs

| Input     | Description                                  | Required | Default                                              |
|-----------|----------------------------------------------|----------|------------------------------------------------------|
| `linters` | Multi-line list of linters to run (one per line). Inline `#` comments are supported. | No | `hadolint`, `shellcheck`, `yamllint`, `actionlint` |

## Available linters

All tool versions are pinned in [`mise.toml`](mise.toml) and monitored by Renovate.

### Infrastructure (enabled by default)

| Linter       | Lints                          | Version |
|--------------|--------------------------------|---------|
| `hadolint`   | Dockerfiles                    | 2.14.0  |
| `shellcheck` | Shell scripts (`bin/*`, `*.sh`) | 0.11.0  |
| `yamllint`   | YAML files                     | 1.38.0  |
| `actionlint` | GitHub Actions workflows       | 1.7.11  |

### Language-specific (opt-in)

| Linter          | Lints                    | Version |
|-----------------|--------------------------|---------|
| `ruff`          | Python (lint + format)   | 0.15.5  |
| `golangci-lint` | Go                       | 2.11.1  |
| `pyright`       | Python (type checking)   | 1.1.408 |
| `blinter`       | Windows batch files      | 1.0.112 |
| `govulncheck`   | Go (vulnerability scan)  | 1.1.4   |

## Behavior

- Each linter **skips gracefully** if no matching files exist in the repo
- **yamllint** uses the repo's `.yamllint.yml` if present, otherwise falls back to the action's [default config](.yamllint.yml)
- **Caching**: `mise-action` caches all tool binaries automatically — subsequent runs restore from cache in ~3s
- File discovery excludes `.git/`, `node_modules/`, `vendor/`, `_site/`, and `.venv/`

## Local development

```sh
bin/setup   # check prerequisites, install tools via mise
bin/lint    # lint this repo using its own lint.sh
bin/test    # run lints + verify action structure
```

## Dependency updates

- **Tool versions** (`mise.toml`): monitored by [Renovate](https://docs.renovatebot.com/) via self-hosted instance
- **GitHub Actions** (`jdx/mise-action` in `action.yml`): monitored by [Dependabot](https://docs.github.com/en/code-security/dependabot)
