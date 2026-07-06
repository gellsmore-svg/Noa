# Windows Installer Analysis Bundle – Overview

This directory contains the detailed analysis documents for building a native Windows installer for the Noa / family AI stack.

## Documents in This Bundle

- **[windows-installer-analysis.md](windows-installer-analysis.md)**  
  Main analysis. Goals, scope (select repos except RS), architecture options, challenges, recommended tech stack, and phased plan.

- **[windows-service-options.md](windows-service-options.md)**  
  Deep dive into options for running long-lived components (especially the Hoglah worker) as Windows services or scheduled tasks. Covers NSSM, WinSW, native services, Task Scheduler, Docker, and integration with health checks.

- **[python-embedding-options.md](python-embedding-options.md)**  
  Analysis of strategies for delivering Python without (or with minimal) external dependencies: system Python + venv, official embeddable distribution, fully frozen bundles (PyInstaller etc.), and modern tooling like `uv`.

- **[windows-config-and-selection.md](windows-config-and-selection.md)**  
  How repo/component selection should work in the installer UI and what a sensible default local configuration looks like on Windows (paths, `.env`, per-tool configs, UIs, upgrade story).

## Quick Links to Supporting Files (in the Noa repo)

- `install/install.sh` + `install/lib.sh` – current Linux implementation (reference)
- `services/hoglah-worker.service` – systemd template
- `versions.lock` / `versions.git.lock` – pinning mechanism
- `health/healthcheck.sh` – validation logic to be ported
- `compose.yaml` – Mongo (and future services)
- `README.md` – high-level family description

## How to Use This Bundle

1. Start with `windows-installer-analysis.md` for the big picture.
2. Read the two specialized option documents when making concrete technology decisions.
3. Use `windows-config-and-selection.md` when designing the installer wizard pages and config generation.
4. Cross-reference the existing Linux scripts and lock files for behavioral parity.

## Status

These are living analysis documents created as part of the Windows porting effort. Update them as decisions are made and prototypes are built.

**Target outcome**: A maintainable, selectable, "default config works out of the box" Windows installer that coexists with the existing Linux path.