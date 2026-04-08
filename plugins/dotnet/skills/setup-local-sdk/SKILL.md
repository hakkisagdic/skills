---
name: setup-local-sdk
description: >
  Set up a local .NET SDK installation using the global.json `paths` feature
  (.NET 10+), including workload installation (MAUI, wasm-tools, etc.). Downloads a
  prerelease or specific SDK version into a project-local `.dotnet/` directory
  and configures global.json so `dotnet` resolves it automatically, without
  touching the system-wide installation.
  Use when a user wants to try a .NET preview, test against a specific SDK
  version, or create reproducible team/CI install scripts.
  Do NOT use when the user wants a system-wide install, is on .NET < 10, needs a
  runtime-only install, or is not using SDK-style commands.
---

# setup-local-sdk

## Purpose

Guide the user through installing a .NET SDK into a project-local directory
(`.dotnet/`) and wiring it up via the `global.json` `paths` feature introduced
in .NET 10. The examples below use .NET 11, but this workflow works with any SDK
version — prerelease or stable, current or future.

The result is a fully isolated SDK that:

- Does **not** modify the system-wide .NET installation.
- Is picked up automatically by `dotnet` commands run from the project root.
- Can be deleted with a single `rm -rf .dotnet/` to revert.

### Target personas

| Persona | What they need | Emphasis |
|---|---|---|
| **Cautious hobbyist** | Try a preview without risk | Reversibility, safety |
| **Team lead** | Evaluate a preview for the team | Install scripts, reproducibility |
| **OSS maintainer** | Test against previews in CI | CI integration, automation |
| **Curious developer** | Try a new feature NOW | Speed, minimal steps |

## When to use

- User wants to install a prerelease or specific .NET SDK version locally.
- User wants to test a new .NET feature without affecting other projects.
- User needs reproducible SDK setup for a team or CI pipeline.
- User asks about `global.json` `paths`, local SDK installs, or safe preview testing.
- User wants to test MAUI or other workloads on a preview SDK.

## When NOT to use

- User wants to install the SDK **system-wide** — direct them to the official
  installer or `dotnet-install` without `--install-dir`.
- User is on a .NET version **older than 10** — the `paths` feature does not
  exist; explain the requirement and stop.
- User needs a **runtime-only** installation (e.g., to run `dotnet app.dll`) —
  `paths` applies to SDK resolution only, not apphost or `dotnet exec`.
- The project does **not use SDK-style commands** — `paths` has no effect
  outside of the SDK resolver.

## Inputs / Prerequisites

| Input | Required | Default | Notes |
|---|---|---|---|
| Channel or version | No | `11.0` | e.g. `11.0`, `STS`, `LTS`, or an exact version like `11.0.100-preview.2.26159.112` |
| Quality | No | `preview` | One of: `daily`, `preview`, `GA` |
| Install directory | No | `.dotnet` | Relative to the project root |

### Prerequisites the agent must verify before proceeding

1. **A .NET 10+ SDK is installed globally** — run `dotnet --version` and confirm
   the major version is ≥ 10. If not, stop and explain that the host `dotnet`
   must be v10+ to understand the `paths` key.
2. **curl** is available (macOS/Linux) or **PowerShell** is available (Windows).

## Workflow

Follow these steps in order. Each step includes a checkpoint the agent must
verify before continuing.

### Step 1 — Clarify what to install

If the user did not specify a channel, quality, or exact version, ask:

> What .NET SDK would you like to install locally?
> For example: "latest .NET 11 preview", ".NET 11 daily build", or a specific
> version like "11.0.100-preview.2.26159.112".

Map the answer to `--channel` and `--quality` flags for the install script.

**Checkpoint:** Agent has concrete values for `--channel` and `--quality`
(or `--version`).

### Step 2 — Verify .NET 10+ host

```bash
dotnet --version
```

Parse the major version. If < 10, stop and tell the user:

> The global.json `paths` feature requires .NET 10 or later as the host SDK.
> Your current version is {version}. Please install .NET 10+ system-wide first.

**Checkpoint:** Major version ≥ 10 confirmed.

### Step 3 — Detect operating system

Check the OS by running `uname -s 2>/dev/null`. If the command succeeds, use
the bash script path. If it fails (Windows), use PowerShell commands.

```bash
uname -s 2>/dev/null
```

> **Git Bash / Cygwin edge case:** If `uname -s` returns a value starting with
> `MINGW` or `CYGWIN`, use the PowerShell install path instead.

If `uname` fails or is unavailable, assume Windows and use PowerShell:

```powershell
$IsWindows  # $true
```

Determine which script to use: macOS/Linux → `dotnet-install.sh`, Windows → `dotnet-install.ps1`.

**Checkpoint:** OS detected; correct script variant selected.

### Step 4 — Check for existing local SDK

Before installing, check whether a `.dotnet/` directory already exists:

```bash
test -d .dotnet && echo "exists" || echo "not found"
```

If `.dotnet/` already exists, ask the user:

> A local SDK installation already exists at `.dotnet/`. Would you like to
> **update** it with the new version, or **skip** installation and keep the
> current one?

- If the user wants to **update**, proceed to Step 5.
- If the user wants to **skip**, jump to Step 6 (identify the installed version).

**Checkpoint:** Decision made — update or skip installation.

### Step 5 — Download and run the install script

> **Security note:** The install script is from Microsoft's official URL
> (https://dot.net/v1/dotnet-install.sh). The user can inspect it before running.

**macOS / Linux:**

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
bash /tmp/dotnet-install.sh \
  --channel <CHANNEL> \
  --quality <QUALITY> \
  --install-dir .dotnet
```

**Windows (PowerShell):**

```powershell
Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile "$env:TEMP\dotnet-install.ps1"
& "$env:TEMP\dotnet-install.ps1" `
  -Channel <CHANNEL> `
  -Quality <QUALITY> `
  -InstallDir .dotnet
```

If the user provided an exact `--version`, replace `--channel`/`--quality` with
`--version <VERSION>`.

> **Safety note:** This downloads the SDK into `.dotnet/` inside the project.
> Nothing outside this folder is modified. Delete it at any time to revert.

**Checkpoint:** Install script exits with code 0; `.dotnet/` directory exists
and contains a `dotnet` binary.

### Step 6 — Identify the installed version

**macOS / Linux:**

```bash
./.dotnet/dotnet --version
```

**Windows (PowerShell):**

```powershell
.\.dotnet\dotnet.exe --version
```

Record the exact version string (e.g., `11.0.100-preview.2.26159.112`). This is
needed for `global.json`.

**Checkpoint:** Exact version string captured.

### Step 7 — Install workloads (if requested)

**Trigger keywords:** "MAUI", "mobile", "workload", "Blazor WASM",
"cross-platform".

If the user mentioned any of the above, or if appropriate for their scenario,
ask whether they need workloads installed:

> Do you need any .NET workloads installed on this local SDK?
> Common workloads: `maui`, `wasm-tools`, `maui-android`, `maui-ios`.

If yes, install using the **local** `dotnet` binary:

**macOS / Linux:**

```bash
./.dotnet/dotnet workload install <workload>
```

**Windows (PowerShell):**

```powershell
.\.dotnet\dotnet.exe workload install <workload>
```

> **No sudo needed:** Because the SDK lives in a user-owned `.dotnet/` folder,
> workload installs do not require elevated permissions.

Verify the workload was installed:

**macOS / Linux:**

```bash
./.dotnet/dotnet workload list
```

**Windows (PowerShell):**

```powershell
.\.dotnet\dotnet.exe workload list
```

> **Always use `./.dotnet/dotnet` for workload commands.** Workload metadata is
> stored relative to the dotnet root of the host process. Running `dotnet workload
> install` or `dotnet workload list` through the system host puts metadata in the
> wrong location — the system host's dotnet root, not `.dotnet/`. The `paths`
> feature routes SDK resolution but does **not** redirect workload storage.
> (See [dotnet/sdk#49825](https://github.com/dotnet/sdk/issues/49825).)

**Checkpoint:** Requested workloads appear in `./.dotnet/dotnet workload list`
output.

### Step 8 — Create or update global.json

Write (or merge into an existing) `global.json` in the project root:

```json
{
  "sdk": {
    "version": "<INSTALLED_VERSION>",
    "allowPrerelease": true,
    "rollForward": "latestFeature",
    "paths": [".dotnet", "$host$"],
    "errorMessage": "Required .NET SDK not found. Run ./install-dotnet.sh (or .ps1) to install it locally."
  }
}
```

Key details:
- `paths` lists `.dotnet` first so the local SDK takes priority.
- `$host$` is a sentinel that tells the resolver to also search the system-wide
  location as a fallback.
- `rollForward: "latestFeature"` allows roll-forward to later feature bands
  (including patches), not just patch-level updates.
- `errorMessage` tells other developers how to get the SDK if `.dotnet/` is
  missing.

**Merging into an existing global.json:** If `global.json` already exists, read
it first and preserve any existing properties (such as `msbuild-sdks`, `tools`,
or `test`). Add or update **only** the `sdk` section. When updating the `sdk`
section, preserve any existing `sdk` properties not being set (e.g.,
user-defined `rollForward` or `workloadVersion`). Only add or overwrite:
`version`, `allowPrerelease`, `paths`, and `errorMessage`. If the `sdk` section
already exists, warn the user about any keys being overwritten. If `global.json`
does not exist, create it from scratch using the template above.

> **Laziest path:** When the user just wants a quick setup and doesn't need
> version pinning or team reproducibility, use this minimal `global.json`:
>
> ```json
> {
>   "sdk": {
>     "paths": [".dotnet", "$host$"]
>   }
> }
> ```
>
> This is the shortest config that activates local SDK resolution. Use the full
> version-pinned template above when the user wants reproducibility, team setups,
> or CI integration.

**Checkpoint:** `global.json` exists and contains the correct `sdk` section.

### Step 9 — Update .gitignore

Append `.dotnet/` to `.gitignore` if not already present:

```bash
grep -qxF '.dotnet/' .gitignore 2>/dev/null || echo '.dotnet/' >> .gitignore
```

> **Safety note:** The `.dotnet/` folder can be hundreds of MB. It must not be
> committed to source control.

**Checkpoint:** `.gitignore` contains `.dotnet/`.

### Step 10 — Create team install scripts

**Trigger:** Execute this step if the user mentioned "team", "share", "CI",
"pipeline", "reproducible", "colleagues", or "scripts" in their request.
Otherwise, offer: "Would you also like install scripts so your team can set up
with one command?"

**install-dotnet.sh:**

```bash
#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR=".dotnet"
CHANNEL="11.0"
QUALITY="preview"
SCRIPT_URL="https://dot.net/v1/dotnet-install.sh"
WORKLOADS=("${@}")  # pass workload names as arguments, e.g. ./install-dotnet.sh maui wasm-tools

echo "Installing .NET SDK ($CHANNEL, $QUALITY) into $INSTALL_DIR..."
echo "Downloading install script from $SCRIPT_URL (Microsoft official)..."
curl -sSL "$SCRIPT_URL" -o /tmp/dotnet-install.sh
bash /tmp/dotnet-install.sh \
  --channel "$CHANNEL" \
  --quality "$QUALITY" \
  --install-dir "$INSTALL_DIR"

# Auto-detect installed version and create/update global.json
SDK_VERSION=$("$INSTALL_DIR/dotnet" --version)
echo "Installed SDK version: $SDK_VERSION"

if [ -f global.json ]; then
  echo "WARNING: global.json already exists. Backing up to global.json.bak"
  cp global.json global.json.bak
fi

cat > global.json <<EOF
{
  "sdk": {
    "version": "$SDK_VERSION",
    "allowPrerelease": true,
    "rollForward": "latestFeature",
    "paths": [".dotnet", "\$host\$"],
    "errorMessage": "Required .NET SDK not found. Run ./install-dotnet.sh (or .ps1) to install it locally."
  }
}
EOF
echo "Created global.json pinned to $SDK_VERSION"

# Update .gitignore
grep -qxF '.dotnet/' .gitignore 2>/dev/null || echo '.dotnet/' >> .gitignore
echo "Ensured .dotnet/ is in .gitignore"

# Install workloads if any were requested
if [ ${#WORKLOADS[@]} -gt 0 ]; then
  echo "Installing workloads: ${WORKLOADS[*]}..."
  "$INSTALL_DIR/dotnet" workload install "${WORKLOADS[@]}"
fi

echo "Done. SDK version: $SDK_VERSION"
```

```bash
chmod +x install-dotnet.sh
```

**install-dotnet.ps1:**

```powershell
param(
    [string[]]$Workloads = @()   # e.g. .\install-dotnet.ps1 -Workloads maui,wasm-tools
)
$ErrorActionPreference = 'Stop'
$installDir = '.dotnet'
$channel = '11.0'
$quality = 'preview'
$scriptUrl = 'https://dot.net/v1/dotnet-install.ps1'

Write-Host "Installing .NET SDK ($channel, $quality) into $installDir..."
Write-Host "Downloading install script from $scriptUrl (Microsoft official)..."
Invoke-WebRequest -Uri $scriptUrl -OutFile "$env:TEMP\dotnet-install.ps1"
& "$env:TEMP\dotnet-install.ps1" `
  -Channel $channel `
  -Quality $quality `
  -InstallDir $installDir

# Auto-detect installed version and create/update global.json
$sdkVersion = & "$installDir\dotnet.exe" --version
Write-Host "Installed SDK version: $sdkVersion"

if (Test-Path 'global.json') {
    Write-Host "WARNING: global.json already exists. Backing up to global.json.bak"
    Copy-Item 'global.json' 'global.json.bak'
}

@"
{
  "sdk": {
    "version": "$sdkVersion",
    "allowPrerelease": true,
    "rollForward": "latestFeature",
    "paths": [".dotnet", "`$host`$"],
    "errorMessage": "Required .NET SDK not found. Run ./install-dotnet.sh (or .ps1) to install it locally."
  }
}
"@ | Set-Content -Path 'global.json' -Encoding UTF8
Write-Host "Created global.json pinned to $sdkVersion"

# Update .gitignore
if (-not (Test-Path .gitignore) -or -not (Select-String -Path .gitignore -Pattern '^\\.dotnet/$' -Quiet)) {
    Add-Content -Path .gitignore -Value '.dotnet/'
}
Write-Host "Ensured .dotnet/ is in .gitignore"

# Install workloads if any were requested
if ($Workloads.Count -gt 0) {
    Write-Host "Installing workloads: $($Workloads -join ', ')..."
    & "$installDir\dotnet.exe" workload install @Workloads
}

Write-Host "Done. SDK version: $sdkVersion"
```

These scripts should be committed to the repo so teammates can run them.

**Checkpoint:** Scripts are executable and match the channel/quality used in
Step 5.

### Step 11 — Verify SDK resolution

```bash
dotnet --version
```

Run this from the project root (where `global.json` lives). The output should
match the version installed in Step 6.

If it does not match, troubleshoot:
- Is `global.json` in the current directory or a parent?
- Does `paths` contain `.dotnet`?
- Is the host `dotnet` v10+?

**Checkpoint:** `dotnet --version` output matches the locally installed version.

### Step 12 — Summarize and explain cleanup

Tell the user what was done:

> ✅ **Local SDK setup complete.**
>
> - Installed .NET SDK {version} into `.dotnet/`.
> - Configured `global.json` to resolve the local SDK first.
> - Added `.dotnet/` to `.gitignore`.
> {if scripts created: - Created `install-dotnet.sh` and `install-dotnet.ps1`
>   for your team.}
>
> **To clean up later:**
> 1. Delete the `.dotnet/` directory: `rm -rf .dotnet/`
>    (This also removes any installed workloads automatically.)
> 2. Remove the `paths` and `errorMessage` keys from `global.json`.
> 3. (Optional) Delete `install-dotnet.sh` / `install-dotnet.ps1`.
> 4. Run `dotnet build` to confirm your project works with the system-wide SDK
>    again.
>
> Your system-wide .NET installation was never modified.

## Validation

After completing the workflow, verify:

1. `dotnet --version` (from project root) shows the locally installed version.
2. `dotnet --info` shows the SDK path pointing to `.dotnet/`.
3. `dotnet build` (if a project exists) succeeds with the local SDK.
4. Running `dotnet --version` from **outside** the project still shows the
   system-wide SDK (confirming no global side effects).

## Common pitfalls

| Pitfall | Cause | Fix |
|---|---|---|
| `paths` key is ignored | Host `dotnet` is < v10 | Install .NET 10+ system-wide |
| Wrong SDK resolves | `global.json` is in a parent directory | Check for `global.json` files up the directory tree |
| `dotnet app.dll` uses wrong runtime | `paths` applies to SDK resolution only, not apphost or `dotnet exec` | Use `dotnet run` instead, or set `DOTNET_ROOT` |
| `.dotnet/` is huge | SDKs include targeting packs, templates, etc. | Expected; always gitignore |
| Install script fails on proxy/firewall | Corporate network blocks `dot.net` | Download the script and SDK manually; use `--install-dir` |
| Teammates get "SDK not found" | `.dotnet/` is gitignored and they haven't run the install script | Ensure `errorMessage` in `global.json` directs them to the script |
| CI build fails | CI image doesn't have .NET 10+ host | Add a step to install .NET 10+ globally first, then run the local install script |
| MAUI templates not available | Forgot to install workloads on the local SDK | Run `./.dotnet/dotnet workload install maui` using the local binary |
