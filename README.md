# T3 Code local voice setup

This repo records the working Windows + WSL T3 Code installation and keeps its
source and startup scripts together. The checkout lives at
`/home/anton/t3setup` in the **Ubuntu** WSL distro. The installed Windows
desktop app and its existing history remain where they were.

## Layout

- `t3code/` is a submodule pinned to `AntonC9018/t3code`,
  `voice-openvino`. It contains the T3 microphone, language selector, and
  server-side proxy to the local speech endpoint.
- `voice/` is a private submodule pinned to
  `AntonC9018/whisper-dictation-local`. Its `openvino/server.py` accepts
  English, Russian, or automatic detection. The installed multilingual
  `base` model supports all three modes.
- `windows/` contains the login launcher, crash monitor, voice launcher, and
  deployment script. Deployed copies live in `D:\Stuff\utils\agent`.
- `nixos/t3setup.nix` is the optional NixOS WSL T3 server module. A copy is
  imported by `~/nix-config` in NixOS.
- `runtime/` holds an extracted prebuilt Linux T3 release. It is ignored by
  Git. `state/` and logs are ignored too.

Clone with `git clone --recurse-submodules`. The voice repo is private, so
the GitHub account used for cloning needs access. Install a prebuilt release
or build T3 separately; no release binary or model weights are in Git.

## Current architecture

```text
phone browser --HTTPS/Tailscale--> Windows T3 desktop web server (:3773)
                                      |        |
                                      |        +--> Ubuntu WSL backend for coding sessions
                                      |
                                      +--> local speech proxy (T3_SPEECH_OPENVINO_URL)
                                                 |
                                                 v
                                      ubuntu-test voice server (:8001)
                                                 |
                                                 +--> whisper.cpp OpenVINO encoder on Intel GPU
                                                 +--> whisper.cpp CPU decoder, multilingual base model

Windows login shortcut --> D:\Stuff\utils\agent\Start-T3CodeAtLogin.ps1
                                   |--> Windows T3 desktop app
                                   +--> Watch-T3VoiceServer.ps1
                                             +--> Run-T3VoiceServer.sh
                                                   +--> Ubuntu t3setup/voice submodule
```

The voice server binds to `127.0.0.1:8001`. T3 proxies audio to it; the phone
does not contact the voice server directly. Browsers on a phone require HTTPS
for microphone access. The Tailscale HTTPS origin is
`https://laptop.tail380146.ts.net/`. The monitor polls the endpoint and
restarts the `ubuntu-test` process if it stops responding. Its launch script
mounts Ubuntu's `~/t3setup` in `ubuntu-test` at
`/mnt/ubuntu-t3setup`, then runs `voice/openvino/server.py`.

The GPU build and model remain in `ubuntu-test:/root/src/whisper.cpp`.
They are local runtime data, not submodules. The live voice process was
started from the old Windows checkout. The next monitor restart will use the
Ubuntu submodule; keep the old checkout until that happens. The Windows app
and its history are not moved by this setup.

## Deploy the Windows launch scripts

From Windows PowerShell:

```powershell
& '\\wsl.localhost\Ubuntu\home\anton\t3setup\windows\Install-T3Windows.ps1'
```

This copies the three launch scripts to `D:\Stuff\utils\agent`. It does
not restart the running T3 app or voice server. The existing startup shortcut
still points to the deployed launcher.

The installed desktop executable is
`C:\Users\Anton\AppData\Local\Programs\t3code\T3 Code (Alpha).exe`,
version `0.0.43-preview.20260926.1`. It reads the same user data as the old
installation. The bundled web client opens without dev-server bundling.

## NixOS WSL migration switch

The NixOS config imports `modules/nixos/t3setup.nix` and exposes
`my.t3setup.enable`. It is disabled in normal use while Ubuntu runs the
backend. To stage the prebuilt Linux release in NixOS, extract
`t3-0.0.43-preview.20260926.1-linux-x64.tar.gz` into
`/home/anton/t3setup/runtime` with `--strip-components=1`.
The option enables `nix-ld` for the release binary and a system-level
`t3code` service with `Restart=on-failure`. It binds to
`127.0.0.1:9773` and uses a separate
`/home/anton/t3setup/state/nixos` data directory so a trial cannot change
the current Windows/Ubuntu history. It points speech to the existing
`127.0.0.1:8001` voice server, which is reachable across these WSL distros.

Enable it in NixOS `~/nix-config/hosts/nixos-wsl/local.nix` and rebuild:

```nix
my.t3setup.enable = true;
my.t3setup.port = 9773;
```

```sh
sudo nixos-rebuild switch --flake ~/nix-config#nixos-wsl
systemctl status t3code
curl -I http://127.0.0.1:9773/
```

To return to Ubuntu-only use, set the flag to `false` and rebuild. This
switch prepares the NixOS T3 web backend. The Intel GPU voice runtime still
lives in `ubuntu-test`; moving the GPU binary and model to NixOS is a
separate migration step.

## Checks and updates

The current T3 fork branch is pinned at `4e1e7ddb`. The original voice PR
is [pingdotgg/t3code#8928](https://github.com/pingdotgg/t3code/pull/8928).
On 2026-09-27 its head was `8dc1ac1a`. GitHub's comparison found 63
commits on the PR branch after this fork's common ancestor
`64d55174`. Upstream `main` also advanced to `de251fc2`. No merge or
rebuild was done for this update check. Review those changes before rebasing
the installed fork.

The live endpoints are `http://127.0.0.1:3773/` for T3 and
`http://127.0.0.1:8001/` for voice. For an isolated voice test,
run the launch script in `ubuntu-test` with `T3_VOICE_PORT=8002` and then
request `/sample?language=en`. Leave port 8001 and the current app running.
The NixOS trial uses port 9773 and its own state directory.

On 2026-09-27, port 8002 transcribed the English sample as "Good morning. I
am testing faster whisper on this machine." with HTTP 200. The NixOS
service on port 9773 returned HTTP 200 from both NixOS and Windows. A forced
service failure restarted it once and it returned HTTP 200 again. The live
Windows T3 port 3773 and voice port 8001 remained available throughout.

NixOS WSL currently reports a failed `anton` user D-Bus activation at the end
of `nixos-rebuild switch`. The T3 system service started and passed the checks
above despite that existing WSL user-session issue. Check `systemctl status
t3code` after a rebuild instead of relying only on the command exit code.
The old source path `~/t3code-voice-build` in Ubuntu is a symlink to this
repo's `t3code/` checkout for existing shell references. Model files,
release binaries, logs, recordings, credentials, and user history stay out
of this Git repo.