# Fresh install — a new machine or a new user

Stand the stack up from scratch, with no access to the developer's local repos
(the tools install from their **public git tags**). ~20 lines of commands.

## Host prerequisites (already present, shared)
- **Docker** (with the compose plugin) and permission to use it (the `docker` group).
- **Ollama** running on the host, reachable over HTTP (default `http://localhost:11434`).
  Noa does not manage Ollama — it just points at it.
- **Python 3.11+**, **pipx**, **git**, **curl**. Install pipx with
  `sudo apt-get install -y pipx` or `python3 -m pip install --user pipx && pipx ensurepath`.
- Make sure `~/.local/bin` is on your `PATH` (pipx installs the CLIs there). A fresh
  login is needed for new `docker` group membership to take effect.

## Steps
1. **Get Noa** (it is private — only its scripts are needed):
   ```bash
   gh repo clone gellsmore-svg/Noa noa && cd noa
   ```
2. **Configure** — copy the template and edit `.env`:
   ```bash
   cp .env.example .env
   ```
   - Set `OLLAMA_BASE_URL` to your host Ollama.
   - **If port 27017 is already in use on this machine** (another Mongo), pick a free
     port and keep the URIs consistent, e.g.:
     ```
     COMPOSE_PROJECT_NAME=<unique>     # isolates this stack's containers
     MONGO_PORT=27018
     MONGO_URI=mongodb://localhost:27018
     MAHALATH_MONGO_URI=mongodb://localhost:27018
     TIRZAH_MONGO_URI=mongodb://localhost:27018
     ```
3. **Install** from the public git tags (no dev-repo access needed):
   ```bash
   VERSIONS_LOCK=versions.git.lock ./install/install.sh
   ```
   This starts Mongo (Docker), pipx-installs the pinned tools, co-installs Mahalath
   into Tirzah's env (the semantic seam), and runs the health check.
4. **Verify**:
   ```bash
   ./health/healthcheck.sh
   ```

## Optional — prove semantic precision end-to-end
The smoke runs Tirzah's real prompt builder, resolving terms to Mahalath MPL labels.
Run it with the tools' own pipx venvs (they are isolated from the system Python):
```bash
set -a; . ./.env; set +a
~/.local/share/pipx/venvs/mahalath/bin/python workflows/seed_mahalath_demo.py
~/.local/share/pipx/venvs/tirzah/bin/python  workflows/semantic_smoke.py --semantic on
```
A passing run prints `PASS — semantic-on names an MPL sense the off-run does not`
with `label source: live Mahalath ontology`.

## Running as a separate test user (runuser/su)
`runuser`/`su` with a login shell can drop or reset `HOME`, which would make
`${HOME}/...` paths in `.env` resolve badly. The install/health/workflow scripts now
re-derive `HOME` from the passwd database before reading `.env`, so this is handled —
but if you script the run yourself, pass `HOME` explicitly to be safe:
```bash
runuser -u testuser -- env HOME=/home/testuser USER=testuser LOGNAME=testuser \
  /home/testuser/noa/install/install.sh
```

## Upgrades (later)
Bump `versions.git.lock` (or `versions.lock`) then:
```bash
VERSIONS_LOCK=versions.git.lock ./install/upgrade.sh   # backup → reinstall → migrate → health
```
