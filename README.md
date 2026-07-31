# setupx

`setupx` is a lightweight installer for developer tools using a JSON manifest. It supports commands like `install`, `update`, `doctor`, and a `choco`-style `n <package>` installer.

## Usage

Run commands from the repository root:

```bash
./main.sh help
./main.sh list
./main.sh install web
./main.sh install-tool web "Node.js"
./main.sh n node
```

You can also use the helper script:

```bash
./sx n node
```

## `n` command

The `n` command installs a tool by its `name` or `package` value from `data.json`.

Examples:

```bash
./sx n node
./sx n git
```

## Commands

- `help` — Show help
- `menu` — Interactive menu
- `sysinfo` — OS and package manager info
- `list` — List configured categories
- `list-tools <category>` — List tools in a category
- `install <category>` — Install all tools in a category
- `install-all` — Install every category
- `install-tool <category> <tool>` — Install a specific tool by category
- `n <package>` — Install tool by package or name
- `update <category>` — Update all tools in a category
- `update-all` — Update every category
- `doctor <category>` — Run doctor checks for a category
- `checklist` — Show installed/missing checklist
- `list-installed` — Show installed tools
- `list-missing` — Show missing tools
- `show-category <category>` — Show category details

## Data Manifest

All tools are defined in `data.json` with install, update, and check commands.

## Generated catalog

A separate hierarchical source file, `tools_catalog.json`, documents the full toolkit taxonomy. Use `scripts/generate_data_json.py` to regenerate `data.json` from this catalog when the toolkit list changes:

```bash
python3 scripts/generate_data_json.py
```

The output file is `data.generated.json` by default, and you can inspect or copy it into `data.json` after review.
