#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG_FILE = ROOT / "tools_catalog.json"
DEFAULT_OUTPUT = ROOT / "data.generated.json"

GUI_CASKS = {
    "google chrome": "google-chrome",
    "brave": "brave-browser",
    "mozilla firefox": "firefox",
    "microsoft edge": "microsoft-edge",
    "visual studio code": "visual-studio-code",
    "xcode": "xcode",
    "docker desktop": "docker",
    "google drive": "google-drive",
    "iterm2": "iterm2",
    "android studio": "android-studio",
    "jetbrains toolbox": "jetbrains-toolbox",
    "dbeaver": "dbeaver-community",
    "mysql workbench": "mysqlworkbench",
    "mongodb compass": "mongodb-compass",
    "redis insight": "redisinsight",
    "notion": "notion",
    "obsidian": "obsidian",
    "figma": "figma",
    "canva": "canva",
    "blender": "blender",
    "gimp": "gimp",
    "inkscape": "inkscape",
    "krita": "krita",
    "slack": "slack",
    "discord": "discord",
    "microsoft teams": "microsoft-teams",
    "zoom": "zoom",
    "telegram": "telegram",
    "whatsapp": "whatsapp",
    "safari": "safari",
    "arc": "arc",
    "opera": "opera",
    "opera gx": "opera-gx",
    "tor browser": "tor-browser",
    "dropbox": "dropbox",
    "onedrive": "one-drive",
    "icloud drive": "icloud",
    "mega": "mega",
    "android emulator": "android-platform-tools",
    "flutter sdk": "flutter",
    "dart sdk": "dart",
    "mongodb compass": "mongodb-compass",
}

CLI_NPM = {
    "vercel": "vercel",
    "netlify cli": "netlify-cli",
    "firebase cli": "firebase-tools",
    "supabase cli": "supabase",
    "railway cli": "railway",
    "neon cli": "neon-cli",
    "flyctl": "flyctl",
    "doctl": "doctl",
    "oci cli": "oci-cli",
    "aws cli": "awscli",
    "azure cli": "azure-cli",
    "google cloud cli": "google-cloud-sdk",
    "cloudflare wrangler": "wrangler",
    "gitlab cli": "gitlab-cli",
    "jenkins cli": "jenkins-cli",
    "circleci cli": "circleci-cli",
    "buildkite cli": "buildkite-cli",
    "act": "act",
    "npm": "npm",
    "yarn": "yarn",
    "bun": "bun",
    "deno": "deno",
    "cargo": "cargo",
    "sdkman": "sdkman",
    "poetry": "poetry",
    "rustup": "rustup",
}

PIPX_PACKAGES = {
    "hugging face cli": "huggingface_hub",
    "pipx": "pipx",
    "poetry": "poetry",
}

SPECIAL_PACKAGES = {
    "xcode (macos)": ("xcode", "brew"),
    "node.js (lts)": ("node", "brew"),
    "python": ("python", "brew"),
    "c/c++": ("llvm", "brew"),
    "java (jdk)": ("openjdk", "brew"),
    "github cli": ("gh", "brew"),
    "git": ("git", "brew"),
    "npm": ("npm", "npm"),
    "winget": ("winget", "brew"),
    "scoop": ("scoop", "brew"),
    "chocolatey": ("chocolatey", "brew"),
    "pip": ("python", "brew"),
    "pipx": ("pipx", "brew"),
    "windows terminal": ("windows-terminal", "brew"),
    "swift": ("swift", "brew"),
    "xcode": ("xcode", "brew"),
    "android studio": ("android-studio", "brew"),
}

TOOL_CHECK_OVERRIDES = {
    "google chrome": "open -Ra 'Google Chrome'",
    "brave": "open -Ra 'Brave Browser'",
    "mozilla firefox": "open -Ra 'Firefox'",
    "microsoft edge": "open -Ra 'Microsoft Edge'",
    "visual studio code": "open -Ra 'Visual Studio Code'",
    "xcode": "xcodebuild -version",
    "docker desktop": "open -Ra Docker",
    "google drive": "open -Ra 'Google Drive'",
    "iterm2": "open -Ra iTerm",
    "git": "git --version",
    "github cli": "gh --version",
    "node.js (lts)": "node --version",
    "python": "python3 --version",
    "c/c++": "clang++ --version",
    "java (jdk)": "java --version",
    "npm": "npm --version",
    "nvm": "command -v nvm",
    "flutter sdk": "flutter --version",
    "dart sdk": "dart --version",
    "android sdk": "command -v sdkmanager",
    "android emulator": "emulator -version",
    "adb": "adb --version",
    "fastboot": "fastboot --version",
    "scrcpy": "scrcpy --version",
}

INSTALL_COMMAND_OVERRIDES = {
    "homebrew": "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
}


def normalize_key(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"\s+", "_", text)
    text = re.sub(r"[^a-z0-9_]+", "", text)
    return re.sub(r"_+", "_", text).strip("_")


def infer_package_and_type(name: str) -> tuple[str, str]:
    key = name.strip().lower()
    if key in SPECIAL_PACKAGES:
        return SPECIAL_PACKAGES[key]
    if key in GUI_CASKS:
        return GUI_CASKS[key], "brew"
    if key in CLI_NPM:
        return CLI_NPM[key], "npm"
    if key in PIPX_PACKAGES:
        return PIPX_PACKAGES[key], "pipx"
    if "flutter" in key or "dart" in key or "node.js" in key or "python" in key or "openjdk" in key:
        if "npm" in key or "yarn" in key or "pnpm" in key:
            return normalize_key(key), "npm"
        if "pip" in key or "python" in key or "pipx" in key:
            return normalize_key(key), "pipx"
        if "flutter" in key or "dart" in key:
            return normalize_key(key), "brew"
    if key.startswith("aws cli") or key.startswith("azure cli") or key.startswith("google cloud cli"):
        return normalize_key(key), "brew"
    if key.endswith(" cli"):
        return normalize_key(key), "npm"
    if key in {"git", "node.js", "python", "nvm", "brew", "homebrew", "pip", "pipx", "java", "openjdk", "golang"}:
        if key == "npm":
            return "npm", "npm"
        if key == "pipx":
            return "pipx", "pipx"
        if key == "python":
            return "python", "brew"
        if key == "node.js":
            return "node", "brew"
        return normalize_key(key), "brew"
    if any(app in key for app in ["studio", "desktop", "drive", "browser", "terminal", "toolbox", "notion", "obsidian", "figma", "slack", "discord", "zoom"]):
        return normalize_key(key), "brew"
    return normalize_key(key), "brew"


def infer_check_command(name: str, package: str, install_type: str):
    key = name.strip().lower()
    if key in TOOL_CHECK_OVERRIDES:
        return TOOL_CHECK_OVERRIDES[key]
    if key == "pip":
        return "pip --version"
    if install_type == "brew":
        if key in GUI_CASKS:
            label = name
            if label.lower() == "brave":
                label = "Brave Browser"
            if label.lower() == "mozilla firefox":
                label = "Firefox"
            return f"open -Ra '{label}'"
        return f"command -v {package}"
    if install_type == "npm":
        return f"command -v {package}"
    if install_type == "pipx":
        return f"command -v {package}"
    return None


def infer_install_command(package: str, install_type: str) -> str:
    if install_type == "brew":
        if package in GUI_CASKS.values() or package in {"visual-studio-code", "xcode", "docker", "google-drive", "iterm2", "firefox", "microsoft-edge", "google-chrome"}:
            return f"brew install --cask {package}"
        return f"brew install {package}"
    if install_type == "npm":
        return f"npm install -g {package}"
    if install_type == "pipx":
        return f"pipx install {package}"
    return f"echo 'Install command not configured for {package}'"


def infer_update_command(package: str, install_type: str) -> str:
    if install_type == "brew":
        if package in GUI_CASKS.values() or package in {"visual-studio-code", "xcode", "docker", "google-drive", "iterm2", "firefox", "microsoft-edge", "google-chrome"}:
            return f"brew upgrade --cask {package}"
        return f"brew upgrade {package}"
    if install_type == "npm":
        return f"npm update -g {package}"
    if install_type == "pipx":
        return f"pipx upgrade {package}"
    return ""


def build_category_key(path_segments: list[str], top_id: str) -> str:
    normalized = [normalize_key(segment) for segment in path_segments]
    return f"{top_id}_{'_'.join(normalized)}"


def extract_tool_entries(tool_names: list[str]) -> list[dict]:
    entries = []
    for raw_name in tool_names:
        package, install_type = infer_package_and_type(raw_name)
        check = infer_check_command(raw_name, package, install_type)
        install = infer_install_command(package, install_type)
        update = infer_update_command(package, install_type)
        tool = {
            "name": raw_name,
            "type": install_type,
            "package": package,
            "check": check,
            "install": install,
            "update": update,
            "required": False,
        }
        if raw_name.strip().lower() == "homebrew":
            tool["install"] = INSTALL_COMMAND_OVERRIDES["homebrew"]
            tool["update"] = "brew update"
            tool["check"] = "brew --version"
        entries.append(tool)
    return entries


def flatten_catalog(catalog: dict) -> dict:
    categories = []
    category_data = {}

    for top in catalog.get("top_level_categories", []):
        top_id = normalize_key(top.get("id") or top.get("title"))
        if not top_id:
            continue
        for sub in top.get("subcategories", []):
            if "subcategories" in sub:
                for nested in sub.get("subcategories", []):
                    category_key = build_category_key([sub.get("name", ""), nested.get("name", "")], top_id)
                    categories.append(category_key)
                    category_data[category_key] = {
                        "description": f"{top.get('title')} > {sub.get('name')} > {nested.get('name')}",
                        "tools": extract_tool_entries(nested.get("tools", [])),
                    }
            else:
                category_key = build_category_key([sub.get("name", "")], top_id)
                categories.append(category_key)
                category_data[category_key] = {
                    "description": f"{top.get('title')} > {sub.get('name')}",
                    "tools": extract_tool_entries(sub.get("tools", [])),
                }

    return {
        "categories": categories,
        **category_data,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate setupx data.json from tools_catalog.json")
    parser.add_argument("--output", "-o", default=str(DEFAULT_OUTPUT), help="Output manifest file")
    args = parser.parse_args()

    if not CATALOG_FILE.exists():
        raise FileNotFoundError(f"Could not find {CATALOG_FILE}")

    catalog = json.loads(CATALOG_FILE.read_text(encoding="utf-8"))
    manifest = flatten_catalog(catalog)
    output_path = Path(args.output)
    output_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Generated manifest: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
