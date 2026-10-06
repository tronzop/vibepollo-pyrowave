# Mark-PC PyroWave streaming

This fork builds the Windows streaming host on Mark-PC (RX 9070 XT, 2.5 GbE). It replaced Apollo on
2026-10-06. Upstream Vibepollo 2.0+ already ships the PyroWave encoder: D3D11 capture → Vulkan interop →
PyroWave, and it is on by default on Windows. This directory holds the build, install and client
scripts plus the gotchas found while setting it up.

| Piece | Where |
|---|---|
| Host | Vibepollo built from this fork, installed as `ApolloService` in `C:\Program Files\Apollo` |
| Host source on Mark-PC | `C:\src\Vibepollo` (remotes: `origin` = this fork, `upstream` = Nonary/Vibepollo) |
| Client | Nonary `moonlight-qt` `release/6.1.0-vrr18` on mediaos, built by `mediaos-client-build.sh` |

## Update / rebuild the host

From an MSYS2 UCRT64 shell on Mark-PC:

```bash
cd /c/src/Vibepollo && git pull && bash markpc/build.sh --update   # --deps on a fresh machine
```

Then, from an elevated PowerShell (or over SSH):

```powershell
C:\src\Vibepollo\markpc\install.ps1 -ViaTask
```

`install.ps1` backs up `config\`, installs the MSI and restores the server certificate, paired clients,
apps and `sunshine.conf`, so existing clients stay paired.

## Verified 2026-10-06

- Startup probe: `Found PyroWave encoder [Vulkan]`. `ServerCodecModeSupport` = 126026497, which
  includes all four PyroWave modes (8-bit and HDR10, each in 4:2:0 and 4:4:4).
- mediaos, KMS direct path, 4K60 HDR10 4:2:0 at 1 Gbps:
  - 59.9 fps received and decoded.
  - 0% network loss, 1 ms network latency.
  - Host processing 2–4 ms; PyroWave GPU encode about 2.2 ms.
  - Client decode 3–5 ms on Lunar Lake Arc.
  - About 2 MB per frame. The host paces sends to its 2.5 GbE link.

## Gotchas

- **WiX:** the WiX 3.14 *installer* needs .NET 3.5. The standalone binaries (`C:\tools\wix314`) don't.
- **`PSModulePath`:** a value inherited from pwsh 7 breaks Windows PowerShell 5.1 in the driver-packaging
  step (`Get-FileHash` not recognized). `build.sh` unsets it.
- **Link failures:** the link fails if anything is running `build\sunshine.exe`.
- **Installers over SSH:** `msiexec` and `dism` are refused from an SSH logon ("Access is denied" even
  when elevated). Run them through a SYSTEM scheduled task (`-ViaTask`).
- **Firewall for test builds:** a test build run from `build\` needs its own firewall rule. The MSI adds
  rules for the installed copy.
- **Client codec setting:** PyroWave must be selected explicitly. On mediaos, `Moonlight.conf` has
  `videocfg=5` and `bitrate=1000000`.
- **Client renderer:** the client needs the libplacebo Vulkan renderer for PyroWave, so it can't be
  built with `disable-libplacebo`. Under labwc there is no HDR because the Vulkan WSI lacks HDR10. The
  KMS direct path (`mediaos-direct`) does HDR10.
- **Client receive buffer:** set `net.core.rmem_max` to at least 16 MB on Linux clients, or the client
  warns that 4 MB of the 11 MB receive buffer it asked for was granted.
