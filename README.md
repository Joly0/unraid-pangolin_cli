# unraid-pangolin_cli

An Unraid plugin that installs the [Pangolin CLI](https://docs.pangolin.net/manage/clients/install-client#pangolin-cli-linux-macos-windows) and adds a settings page to connect your server to a [Pangolin](https://pangolin.net) instance as a **machine client**. This lets you reach private resources directly on your Unraid host.

## Install

Add the following URL in **Plugins > Install Plugin** (or via Community Apps):

```
https://github.com/Joly0/unraid-pangolin_cli/raw/main/pangolin_cli.plg
```

## Usage

1. In your Pangolin dashboard, create a **machine client** and copy its **Client ID** and **Client secret**.
2. On Unraid, open **Settings > Pangolin CLI**.
3. Enter your **endpoint URL**, **Client ID** and **Client secret**.
4. Click **Apply** to connect. Optionally enable **Start automatically on boot**.

The `pangolin` binary is also available from the Unraid terminal.

## How it works

- The webGui files (settings page + `/etc/rc.d/rc.pangolin` service script) ship in a Slackware `.txz` package under `packages/`, reinstalled on every boot.
- The `pangolin` binary is downloaded from the [fosrl/cli](https://github.com/fosrl/cli) releases to the flash drive (`/boot/config/plugins/pangolin_cli/`) and restored to `/usr/local/bin/pangolin` on each boot (Unraid's root filesystem is volatile).
- The client runs as a machine client via `pangolin up --endpoint … --id … --secret …`.
- Connection settings are stored in `/boot/config/plugins/pangolin_cli/pangolin_cli.cfg`.

## Development

Edit files under `source/`, then rebuild the package and refresh the `.plg` MD5:

```bash
./build.sh
```

Bump `<!ENTITY version>` (and `cliVersion` when updating the CLI) in `pangolin_cli.plg` before building a release. Commit the regenerated `packages/*.txz` and the updated `.plg`.

## Repository layout

```
pangolin_cli.plg                                  installer
build.sh                                          packages source/ -> packages/*.txz
packages/                                          built .txz (committed, served via raw)
source/
  etc/rc.d/rc.pangolin                             service control (start/stop/status)
  install/slack-desc                               Slackware package metadata
  usr/local/emhttp/plugins/pangolin_cli/
    PangolinCLI.page                               Settings page
    README.md                                      plugin description
```

## Trademarks & attribution

This is an **unofficial, community-maintained** plugin. It is **not affiliated with,
sponsored by, or endorsed by Fossorial, Inc.**

"Pangolin" and the Pangolin logo are trademarks of Fossorial, Inc. The Pangolin
logo image bundled with this plugin
(`source/usr/local/emhttp/plugins/pangolin_cli/pangolin_cli.png`) is the property
of Fossorial, Inc., taken from the [fosrl/pangolin](https://github.com/fosrl/pangolin)
repository, and is used solely to identify the Pangolin software this plugin
integrates with.

The Pangolin CLI binary installed by this plugin is published by Fossorial, Inc.
via [fosrl/cli](https://github.com/fosrl/cli) and is downloaded from its official
releases at install time; it is licensed under its own terms (AGPL-3.0, with
commercial licensing available from Fossorial, Inc.).

See [NOTICE](NOTICE) for details.
