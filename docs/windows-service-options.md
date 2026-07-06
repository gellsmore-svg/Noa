# Windows Service Installation Options

**Part of the Windows Installer Analysis Bundle**  
**Date:** 2026-07-06  
**See also:** [windows-installer-analysis.md](windows-installer-analysis.md), [python-embedding-options.md](python-embedding-options.md)

## Goals

Replace or augment the Linux `systemd` user service for the **Hoglah worker** (and potentially other long-running components) on Windows while keeping the experience as close as possible to the current model.

Current Linux behavior (from `services/hoglah-worker.service`, `install/lib.sh`, `health/healthcheck.sh`):
- `Type=simple`
- `EnvironmentFile=...`
- `ExecStart=hoglah run --real`
- `Restart=on-failure`
- Survives logout via `loginctl enable-linger`
- Fallback to background process + `$HOGLAH_QUEUE_DIR/worker.pid`

On Windows we need equivalent "always-running in background, restart on failure, survives logout, observable" behavior.

## Primary Options

### 1. NSSM (Non-Sucking Service Manager) – Recommended for simplicity

**What it is**: Tiny (~300KB) open-source service wrapper. Wraps any executable (including Python scripts or `hoglah.exe`) as a real Windows service.

**How it fits the Noa model**:
- Installer downloads `nssm.exe` (or bundles it).
- During post-install:
  ```powershell
  nssm install NoaHoglahWorker "$hoglahPath" run --real
  nssm set NoaHoglahWorker AppDirectory "$installRoot"
  nssm set NoaHoglahWorker AppEnvironmentExtra "HOGLAH_QUEUE_DIR=..." "OLLAMA_BASE_URL=..."
  nssm set NoaHoglahWorker AppStdout "$logDir\worker.log"
  nssm set NoaHoglahWorker AppStderr "$logDir\worker.err"
  nssm set NoaHoglahWorker Start SERVICE_AUTO_START
  nssm start NoaHoglahWorker
  ```
- Healthcheck can use `sc query` or `Get-Service`.

**Pros**:
- Extremely simple to script.
- Excellent stdout/stderr redirection + rotation.
- Handles restarts, dependencies, environment.
- Works with both embedded Python and system Python.
- Widely used in the Python/Windows OSS world.

**Cons**:
- External binary (must be downloaded or bundled; small license burden).
- Not "pure Microsoft".

**Implementation sketch** (PowerShell helper):
```powershell
function Install-HoglahWorkerService {
    param($HoglahExe, $EnvFile, $LogDir)
    $nssm = Join-Path $PSScriptRoot "tools\nssm.exe"
    & $nssm install NoaHoglahWorker $HoglahExe "run" "--real"
    & $nssm set NoaHoglahWorker AppEnvironmentFile $EnvFile
    & $nssm set NoaHoglahWorker AppStdout (Join-Path $LogDir "hoglah-worker.log")
    & $nssm set NoaHoglahWorker AppStderr (Join-Path $LogDir "hoglah-worker.err")
    & $nssm set NoaHoglahWorker Start SERVICE_AUTO_START
    & $nssm start NoaHoglahWorker
}
```

### 2. WinSW (Windows Service Wrapper)

**What it is**: Java-based (small) or .NET version. Uses an XML config file.

**Pros**:
- Very configurable (XML).
- Good logging, rotation, environment.
- Actively maintained.

**Cons**:
- Requires Java (for classic WinSW) or .NET runtime.
- Slightly more complex than NSSM for simple cases.

**Use case**: If you already ship Java or want very rich configuration.

### 3. Native Windows Service (pywin32 or `python -m win32serviceutil`)

**Approach**: Turn the Hoglah worker itself into a proper Windows service using `pywin32`.

Example skeleton (added to Hoglah or a thin wrapper):
```python
import win32serviceutil
import win32service
import win32event
import servicemanager

class HoglahWorkerService(win32serviceutil.ServiceFramework):
    _svc_name_ = "NoaHoglahWorker"
    _svc_display_name_ = "Noa Hoglah Worker"

    def __init__(self, args):
        super().__init__(args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)

    def SvcDoRun(self):
        servicemanager.LogMsg(...)
        # call the real hoglah run logic here (or subprocess)
        # block until stop
```

**Pros**:
- No extra binaries.
- Deep Windows integration.

**Cons**:
- Requires `pywin32` in the environment (complicates embedding and venvs).
- More code to maintain.
- Harder to get stdout redirection right.

**Verdict**: Good for advanced cases, overkill for Noa MVP.

### 4. Task Scheduler (Scheduled Task)

**Approach**: Create a task that runs at logon + repeats every minute (or "run whether user is logged on or not").

```powershell
$action = New-ScheduledTaskAction -Execute $hoglahPath -Argument "run --real"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName "NoaHoglahWorker" -Action $action -Trigger $trigger -Principal $principal
```

**Pros**:
- Built into Windows, no extra tools.
- Easy to configure "run at startup", "restart on failure".
- Works without admin in some configurations.

**Cons**:
- Not a "real" service (no `sc query`, different event logs).
- Restart logic is cruder than NSSM.
- Can be confusing for users.

**Use case**: Quick-and-dirty or when NSSM/WinSW is forbidden by policy.

### 5. Docker Compose (for Hoglah itself)

Run the worker inside a container (bind-mount the queue dir and env).

**Pros**: Consistent with Mongo.
**Cons**:
- Still requires Docker Desktop.
- GPU access for Ollama becomes more complicated.
- Not the current model (Hoglah is meant to be lightweight host process).

Only recommended if the user chooses full containerized mode.

### 6. MongoDB Service Options

Current: Docker Compose only.

**Windows options**:
- **Docker Desktop Compose** (status quo) – simplest for Noa.
- **MongoDB Community Server** (official MSI) – registers `MongoDB` service automatically.
  - Installer can download + run MSI silently, then point configs at `mongodb://localhost:27017`.
- **Embedded / file-based** for demo mode (Hoglah already supports SQLite; Tirzah/Mahalath are harder).

**Recommendation**: Default to Docker Compose. Offer "Use native MongoDB" checkbox that downloads the Community MSI.

## Healthcheck & Observability on Windows

Port the checks from `health/healthcheck.sh`:
- `Get-Service NoaHoglahWorker` or `sc query`
- Process existence via pidfile fallback.
- Log tailing (`Get-Content -Wait -Tail`).
- `docker compose ps` for Mongo.

Example PowerShell health snippet:
```powershell
$svc = Get-Service -Name NoaHoglahWorker -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') { "OK: Hoglah worker service" }
```

## Integration with Installer

In the Inno Setup `[Run]` or post-install PowerShell:
1. Render `hoglah-worker.service` equivalent (or NSSM XML/config).
2. Call the registration function.
3. Start the service.
4. Record the chosen method in the generated `.env` or a `Noa\state.json` so healthcheck and upgrade know what to do.

Support "service type" in config:
```
HOGLAH_SERVICE_BACKEND=nssm   # or "taskscheduler", "docker", "none"
```

## Trade-offs Summary

| Option          | Complexity | External Binary | Restart Quality | Windows-native feel | Admin required |
|-----------------|------------|-----------------|-----------------|---------------------|----------------|
| NSSM            | Low        | Yes (tiny)      | Excellent       | Good                | Yes (for install) |
| WinSW           | Medium     | Yes             | Excellent       | Good                | Yes            |
| pywin32 native  | High       | No              | Good            | Best                | Yes            |
| Task Scheduler  | Low        | No              | Medium          | Acceptable          | Sometimes      |
| Docker only     | Medium     | Docker Desktop  | Good            | Different           | Yes            |

**Recommendation for MVP**: NSSM for the Hoglah worker + Docker Compose for Mongo. Provide Task Scheduler as a "no external tools" fallback.

## Open Questions

- Should the installer offer to install NSSM/WinSW automatically?
- Do we want a unified "Noa Service Manager" tray app later?
- How do we handle multiple users on the same machine (per-user services vs machine services)?
- Logging rotation and size limits on Windows.

See the main analysis for how this fits into the overall Windows installer plan.