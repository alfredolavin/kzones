# kzones-zone-editor

Standalone visual editor for [KZones](https://github.com/gerritdevriese/kzones) layout
JSON. Not part of the packaged KWin script — a companion desktop app you install and
run separately, then copy its output into KZones' own **Layouts** config tab.

## Install

```sh
pipx install ./tools/zone-editor          # from a checkout of the kzones repo
# or, without cloning:
pipx install "git+https://github.com/gerritdevriese/kzones.git#subdirectory=tools/zone-editor"
```

## Run

```sh
kzones-zone-editor
```

See the main repo's [README](../../README.md#visual-zone-editor) for the full
edit-and-copy-back workflow.
