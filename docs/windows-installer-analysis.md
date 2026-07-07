# Windows Installer Analysis Bundle

**Date:** 2026-07-06  
**Status:** Analysis & Planning  
**Scope:** Native Windows installer for the Noa/family stack. Allows selection of repos (explicitly excluding Relational-Substrate / RS). Produces a default local configuration suitable for a fresh Windows machine.  
**Related Documents (this bundle):**
- [windows-service-options.md](windows-service-options.md)
- [python-embedding-options.md](python-embedding-options.md)
- [windows-config-and-selection.md](windows-config-and-selection.md)

## Executive Summary

The current Noa installer (`install/install.sh` + `lib.sh`) is Unix-centric (Debian/WSL, systemd, pipx, Docker Compose for Mongo, bash). A Windows-native installer is required for broader adoption.

**Core Requirements**
- GUI or wizard-based selection of family components (Tirzah, Mahalath, Hoglah, Milcah, UIs, supporting libs). **RS is deliberately excluded**.
- Automatic generation of a working "default local config" (`.env`, tool configs, data directories, paths).
- Minimal external dependencies on the target machine after installation.
- Support for long-running background work (Hoglah worker).
- Reliable on clean Windows 10/11 (including non-admin or standard user scenarios where possible).
- Maintainable alongside the Linux path (share as much logic/config as possible).

**High-Level Recommendation**
Use **Inno Setup** (free, mature, excellent component selection) + PowerShell helper scripts.  
Provide two primary packaging modes (configurable at build or install time):
1. **Embedded Python** (recommended for "just works" experience).
2. **System Python + venv** (lighter installer, requires Python 3.11+).

For services, prefer **NSSM** or **WinSW** wrappers around the existing Hoglah worker logic, with Docker Desktop as the default for Mongo (matching current compose.yaml).

## Current Linux Model (for reference)

From `Noa/README.md`, `install/`, `versions.lock`, `health/healthcheck.sh`, and `services/hoglah-worker.service`:

- **Mongo**: Docker Compose (`compose.yaml`).
- **Ollama**: Always external (host), configured by `OLLAMA_BASE_URL`.
- **Tools**: Installed via `pipx` from pinned versions (local paths or git refs via `versions.*.lock`).
- **Family libs** (Galeed, Keturah, Cairn-lang): Pre-installed into tool venvs (never pipx-installed as top-level apps).
- **Hoglah worker**: systemd user service (template in `services/`) or background pidfile fallback.
- **Config**: Single `.env` + per-tool `config.yaml` (or equivalent). Shared queue dir.
- **UIs**: Mahlah + Mizpah (Node/Vite) – currently built separately and served by Tirzah or standalone.
- **Health**: `health/healthcheck.sh` validates paths, services, CLIs, Mongo, etc.

**Windows Portability Gaps** (already identified in reports):
- Hardcoded WSL paths (`/mnt/c/.../ollama.exe`, `/etc/resolv.conf` reads in Mahalath/Tirzah).
- systemd units.
- `~` / `$HOME` assumptions and `pipx` paths.
- Bash-only scripts.
- Docker volume path handling.

## Scope – Repos / Components

**Included by default / selectable** (the "family"):
- Core libs: `galeed`, `keturah`, `cairn-lang`
- Runtimes: `tirzah`, `mahalath`, `hoglah`, `milcah` (optional/experimental)
- UIs: `Mahlah`, `Mizpah`
- Supporting: Hoglah worker, shared Mongo (via compose or alternative), config generation

**Explicitly excluded**:
- `Relational-Substrate` (RS) – different stack, research-focused, Node-heavy, not part of the Noa-orchestrated family.

**Selection Model** (see `windows-config-and-selection.md`):
- Inno Setup "Components" page (tree or flat list with descriptions).
- "Core Family" group (recommended).
- Individual toggles.
- "With UIs" preset.
- "Minimal (Hoglah + Tirzah only)" preset.
- Installer must respect dependencies (e.g., installing Tirzah without Galeed/Keturah should still pull the libs).

## High-Level Architecture Options

### Option A: "Thin Orchestrator + External Tools" (Recommended)
- Installer downloads/clones selected repos (or uses pre-built wheels once published).
- Uses embedded or system Python + venvs.
- Renders default Windows config into `%LOCALAPPDATA%\Noa` (or user-chosen dir).
- Registers Hoglah worker via service wrapper.
- Starts Mongo via `docker compose` (assumes Docker Desktop) or offers native Mongo MSI.
- Creates Start Menu shortcuts + a simple launcher for UIs and health check.
- Post-install PowerShell health check (equivalent of `healthcheck.sh`).

**Pros**: Matches current design, easy to keep in sync with Linux.
**Cons**: Still depends on Docker Desktop and Ollama installer.

### Option B: "More Self-Contained"
- Embed Python + minimal Node runtime (or use portable Node).
- Use SQLite for Hoglah (already supported) to reduce Docker need.
- Bundle or download small Mongo community server (or use file-based for demo).
- Single "Noa" executable / tray app that manages everything.

**Pros**: Fewer external installs.
**Cons**: Much larger installer, more complex maintenance, GPU passthrough for Ollama still external.

### Option C: Hybrid with WSL (Not Recommended as Primary)
- Install via WSL + Noa bash scripts.
- Provide a simple Windows launcher that starts WSL services.
- Still useful as fallback, but user asked for (presumably native) Windows experience.

## Key Challenges & Mitigations

1. **Paths & Environment**
   - Use `%LOCALAPPDATA%\Noa`, `%APPDATA%\Noa`, or user-selected root.
   - Normalize all paths in generated `.env` and configs.
   - Handle spaces in paths (quote everything).

2. **Background Execution (Hoglah worker)**
   - See dedicated [windows-service-options.md](windows-service-options.md).

3. **Python Isolation**
   - See dedicated [python-embedding-options.md](python-embedding-options.md).

4. **Dependencies**
   - Git (for cloning during install or updates).
   - Python 3.11+.
   - Node.js (for Mahlah/Mizpah build/serve).
   - Docker Desktop (for Mongo) or alternative.
   - Ollama (official Windows release – installer can download/launch it).
   - Visual C++ Redistributables (for some wheels).

5. **Ollama on Windows**
   - Official installer puts it at `C:\Users\<user>\AppData\Local\Programs\Ollama\ollama.exe`.
   - Tools already have some Windows path logic; must be made robust and default to `http://localhost:11434`.

6. **UIs (Mahlah / Mizpah)**
   - Build step requires Node.
   - Runtime: either serve via `vite preview` / simple http server, or package as Electron (bigger).
   - Provide desktop shortcuts + optional "run on login".

7. **Updates & Isolation**
   - Use versioned install directories or per-user venvs.
   - Provide `upgrade.ps1` equivalent.
   - Consider `versions.lock` style pinning.

8. **Permissions & UAC**
   - Installer should request elevation only when necessary (service registration, Docker, Program Files).
   - Prefer per-user install (`%LOCALAPPDATA%`).

9. **Testing**
   - GitHub Actions `windows-latest`.
   - Clean VM images (no Docker, no Python, no Ollama).
   - Automated smoke tests after install.

## Recommended Tech Stack

- **Installer**: Inno Setup 6 (`.iss` script + Pascal + `[Components]` + `[Tasks]`).
- **Scripting**: PowerShell 5.1+ (or PowerShell 7 if we can assume it).
- **Python packaging**: Official embeddable zip (for Option A) or system Python + `venv`.
- **Service wrapper**: NSSM (small, widely used, no Java) or WinSW.
- **Config templating**: Simple PowerShell string replacement or a small helper script (avoid heavy templating).
- **Download/Extract**: Inno's built-in or `DownloadTemporaryFile` + 7-Zip if needed.
- **UI selection**: Inno components page + custom pages for destination + prerequisites.

## Phased Implementation Plan

**Phase 0 – Foundations (Portability)**
- Fix all WSL-hardcoded paths in Tirzah/Mahalath/etc.
- Make `healthcheck.sh` logic available as cross-platform (PowerShell + bash).
- Create `Noa/install/windows/` with `lib.ps1` mirroring key functions.

**Phase 1 – Minimal Installer**
- Basic Inno Setup that installs one tool (e.g., Hoglah) + default config.
- Generates `.env` and runs a post-install health check.
- Documents prerequisites.

**Phase 2 – Full Selection + Services**
- Component tree for all repos (exclude RS).
- NSSM/WinSW service for Hoglah worker.
- Docker Compose integration (or prompt for it).
- Node install + UI build for Mahlah/Mizpah.

**Phase 3 – Python Embedding + Polish**
- Optional "Use embedded Python" checkbox.
- Code signing.
- Better error messages + rollback.
- Start Menu group + optional desktop icons.
- `upgrade.ps1` + auto-update hooks.

**Phase 4 – Advanced**
- Self-updating installer.
- Tray app for managing services.
- MSI dual (Inno + WiX) for enterprise.
- Integration with winget / Chocolatey manifests.

## Risks & Open Questions

- **Docker on Windows**: Many corporate environments block Docker Desktop. Provide SQLite-only mode for Hoglah + instructions for external Mongo.
- **Ollama GPU**: Must remain external (no easy embedding).
- **Size**: Embedding Python + Node + multiple wheels can exceed 200-400 MB. Offer "download on demand" vs "bundle everything".
- **Maintenance Burden**: Every change to Linux install scripts must have a Windows counterpart. Consider a shared data-driven approach (e.g., `setup/repos.yaml` already exists in `setup/`).
- **Python Version Skew**: Tools declare `>=3.11`. Installer must enforce or bundle a known-good version.
- **Licensing**: Ensure all bundled components allow redistribution.

## Next Steps (for implementers)

1. Review this bundle + the three companion docs.
2. Create `Noa/install/windows/` skeleton (PowerShell libs + example `.iss`).
3. Fix the highest-impact portability issues (ollama paths).
4. Prototype a minimal Inno Setup that produces a working Tirzah install with default config.
5. Iterate on service + embedding choices based on real Windows testing.

See the companion documents in this bundle for deep dives into services and Python embedding.

---

*This document is part of the Windows installer analysis bundle stored under `Noa/docs/`. It should be kept in sync with `install/`, `versions*.lock`, and the main family tools.*
