# Python Embedding Options for Windows Installer

**Part of the Windows Installer Analysis Bundle**  
**Date:** 2026-07-06  
**See also:** [windows-installer-analysis.md](windows-installer-analysis.md), [windows-service-options.md](windows-service-options.md)

## Goals

Provide a robust way to run the family Python tools (`tirzah`, `mahalath`, `hoglah`, `milcah`, plus libs `galeed`/`keturah`/`cairn-lang`) on a target Windows machine with minimal or zero external Python installation.

Current Linux model relies on:
- User-provided Python 3.11+
- `pipx` for isolated tool CLIs
- Manual `venv` creation + `--preinstall` of family libs into those venvs

On Windows we want similar isolation without forcing every user to manage Python themselves.

## Option Comparison

### Option 1: Require System Python + venv (Simplest, Current-like)

**Description**
- Installer checks for Python 3.11+ (via `py -3.11` launcher or `python --version`).
- If missing, offers to download the official installer (or aborts with clear instructions).
- For each selected tool, creates a venv in `%LOCALAPPDATA%\Noa\venvs\<tool>`.
- Uses `python -m pip install -e ".[dev,web]"` (or wheels) + pre-install of family libs.
- CLIs are exposed via generated `.bat` wrappers or by adding the venv `Scripts` dir to PATH (carefully).

**Implementation sketch (PowerShell)**
```powershell
$python = (Get-Command python).Source
& $python -m venv $venvPath
& "$venvPath\Scripts\python.exe" -m pip install --upgrade pip
& "$venvPath\Scripts\python.exe" -m pip install -e "$repoPath[web]" --find-links $wheelhouse
```

**Pros**
- Smallest installer size.
- Uses whatever Python the user already has (good for developers).
- Easiest to keep in sync with Linux `pipx` path.
- Full access to user's site-packages if needed.

**Cons**
- Requires Python on the machine.
- Version skew risk (user has 3.12, we tested on 3.11).
- "pipx" experience is not native on Windows (people expect one-click CLIs).
- UAC / long-path / permission issues when creating venvs in user dirs.

**When to choose**
- "Power user" or "developer" installers.
- When you want the lightest possible distribution.

### Option 2: Official Python Embeddable Zip (Recommended for "just works")

**Description**
- Download the official "embeddable" zip from python.org (e.g., `python-3.12.4-embed-amd64.zip`).
- Extract to `%LOCALAPPDATA%\Noa\python-3.12`.
- Use the embedded `python.exe` to create per-tool venvs or run directly (with `pth` files).
- The embeddable distribution is designed exactly for this use case (redistributable, no registry, no Start Menu).

**Key files in embeddable zip**
- `python.exe` / `pythonw.exe`
- `python312.zip` (stdlib)
- `python312._pth` (controls `sys.path`)
- No `pip` by default (we must bootstrap it or ship wheels).

**Bootstrapping pip in embedded Python**
```powershell
# Download get-pip.py once
Invoke-WebRequest https://bootstrap.pypa.io/get-pip.py -OutFile get-pip.py
& $embeddedPython get-pip.py --no-warn-script-location
```

Then install packages normally. For family libs, use `--find-links` to the wheelhouse built at installer creation time.

**Per-tool isolation**
- Create a venv using the embedded Python: `$embeddedPython -m venv $toolVenv`
- Or use "portable" layout by editing `._pth` files (more advanced, less isolation).

**Pros**
- Completely self-contained.
- No global Python pollution.
- Predictable version.
- Small enough (~25-30 MB compressed for Python itself).
- Works on machines without Python installed.

**Cons**
- Still need to handle pip / wheels.
- Some C-extension packages may need extra DLLs (Visual C++ Redist).
- `tkinter`, `ensurepip`, etc. may be stripped in the embeddable build (we usually don't need them).
- Updating the embedded Python requires rebuilding the installer.

**Implementation notes**
- Use Inno `[Files]` section with `Flags: nocompression` for the zip, then extract at runtime or pre-extract.
- Ship a `python-3.xx-embed` directory inside the installer.
- Generate a small `Noa\python\python.exe` shim that sets `PYTHONHOME` and `PYTHONPATH` correctly.

### Option 3: Fully Bundled / Frozen (PyInstaller, cx_Freeze, Nuitka, Briefcase)

**Description**
- Use PyInstaller (or similar) to turn each CLI (`tirzah`, `hoglah`, etc.) into a standalone `.exe`.
- One big folder or single-file exe per tool.
- Python runtime is completely hidden inside the bundle.

**Pros**
- Ultimate "no Python required" experience.
- Can include data files, native DLLs, etc.
- Single file deployment possible (with `--onefile`).

**Cons**
- **Much larger** installers (each tool can be 50-150+ MB).
- Slow startup (especially `--onefile` which extracts on every run).
- Rebuilding required for every Python or dependency change.
- Harder to support editable installs or "pip install extra packages".
- Debugging is painful (the frozen environment is different).
- Cross-tool sharing (family libs) becomes duplication.

**Variants**
- **Folder mode** (recommended over onefile for size/speed).
- **Onefile** only for tiny tools.
- Use `uv` or `pip` inside the bundle at first run for some flexibility.

**When it makes sense**
- Consumer-facing single-app products.
- Not ideal for a multi-tool family with shared libs.

**Current family reality**: Many tools are meant to be importable libraries + CLIs. Freezing breaks the "import tirzah" story for users who want to script against them.

### Option 4: Modern Tooling (uv, pipx on Windows, standalone Python)

**uv** (Astral)
- Extremely fast Python + package manager.
- Can create venvs and install in one command.
- Has experimental "standalone" Python downloads.
- Windows support is excellent.

**pipx on Windows**
- pipx itself works on Windows.
- Still requires a base Python.
- Gives the same isolated CLI experience as Linux.

**Standalone Python distributions** (e.g., from `python-build-standalone` or `uv python`)
- Similar to official embeddable but often more complete.

**Recommendation**: Consider `uv` as the engine behind Option 1 or 2. It can dramatically speed up the install step.

## Hybrid / Recommended Strategy for Noa

**Default path (good balance)**:
1. Offer a checkbox: "Include embedded Python (recommended for new machines)"
2. If checked → use Option 2 (embeddable zip) + `uv` or pip to populate per-tool venvs.
3. If unchecked → use Option 1 (system Python). Fail early with clear "Python 3.11+ required" message and download link.
4. Always pre-build a wheelhouse of the selected family libs during installer build time (using the same `build_family_wheelhouse` logic from `lib.sh`, ported to PowerShell or run under WSL/CI).

**Benefits**
- "Just works" for non-developers.
- Developers can opt out and use their existing Python.
- Size is reasonable (embeddable Python is ~30 MB, wheels for the family are small).

**Implementation artifacts needed**
- `Noa/install/windows/python-embed/` (or downloaded at build).
- `Noa/install/windows/build-wheelhouse.ps1` (or reuse/extend the existing logic).
- Generated `Noa\venvs\<tool>\Scripts\activate` wrappers + `.bat` launchers in PATH.

## Size Estimates (approximate, 2026)

- Embedded Python 3.12 (amd64): ~25-35 MB
- Core family wheels (galeed + keturah + cairn-lang): < 5 MB
- One tool (tirzah + deps): 10-20 MB
- Full stack + UIs (Node separate): 80-150 MB total installer (before compression)

Use Inno's compression + component download (if you split the installer) to keep the initial download reasonable.

## Gotchas Specific to Embedding

- **DLL hell**: Some packages (e.g., those using `cryptography`, `pymongo`, `torch` if ever added) require Visual C++ Redist or system DLLs. The installer should include `vc_redist.x64.exe` silently.
- **`._pth` file**: Critical for controlling `sys.path` in the embeddable distribution. You usually want to add the `Lib\site-packages` of the tool's venv.
- **Scripts / entry points**: Frozen or embedded installs still need `.exe` wrappers or `.bat` files that set `PATH` and `PYTHONPATH`.
- **Editable installs** (`-e`): Work inside an embedded Python venv, but the paths must be absolute Windows paths.
- **Multiprocessing / `sys.executable`**: Some libraries spawn children and expect the real `python.exe`. Test `hoglah` worker thoroughly.

## Decision Matrix

| Criteria                    | System Python + venv | Embedded Zip | Fully Frozen (PyInstaller) |
|----------------------------|----------------------|--------------|----------------------------|
| No Python install required | No                   | Yes          | Yes                        |
| Installer size             | Smallest             | Medium       | Largest                    |
| Startup speed              | Fast                 | Fast         | Slower (esp. onefile)      |
| Supports "import tirzah"   | Yes                  | Yes          | Hard / broken              |
| Easy to update tools       | Yes (reinstall)      | Yes          | Rebuild installer          |
| Corporate policy friendly  | Depends              | Good         | Best (no external Python)  |
| Maintenance effort         | Low                  | Medium       | High                       |

## Recommendation

For the Noa Windows installer:
- **Primary**: Embedded Python (Option 2) + per-tool venvs created at install time.
- **Fallback**: System Python path (with clear error).
- Use `uv` (if possible) or standard pip for speed.
- Pre-build and include a wheelhouse for the family libraries.
- Provide `.bat` launchers in a directory added to PATH (e.g., `%LOCALAPPDATA%\Noa\bin`).

This gives the best "it just works" experience while remaining maintainable.

See the main analysis document for how this choice interacts with service installation and overall installer architecture.