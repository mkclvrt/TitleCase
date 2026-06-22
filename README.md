# Title Case (menu-bar app)

A tiny, fully native macOS menu-bar app that converts text to title case in
**Chicago** (default) or **AP** style. No external dependencies, no Python runtime,
no web calls — just compiled Swift + AppKit.

## Layout
- `src/TitleCaseEngine.swift` — the casing rules (the only file you'll likely tweak).
- `src/App.swift` — the menu-bar UI and global hotkey.
- `tests/main.swift` — assertions for the engine.
- `TitleCase.icon` — app icon (Icon Composer document); any `*.icon` here is compiled
  into the bundle by `build.sh` via `actool`.
- `build.sh` — compiles, bundles, adds the icon, ad-hoc signs, installs to `~/Applications`.

## Build / reinstall
```sh
./build.sh
open ~/Applications/TitleCase.app
```

## Run the tests
```sh
swiftc src/TitleCaseEngine.swift tests/main.swift -o /tmp/tctest && /tmp/tctest
```

## Using it
- **Menu bar icon** (looks like the `textformat` glyph, top-right): click it →
  *Convert Clipboard to Title Case*. (Copy your text first, then paste the result.)
- **Global hotkey** (default **⌃⌥T**): title-cases whatever is on the clipboard.
- **Style → Chicago / AP**: choose the capitalization style (default **Chicago**).
  The difference is prepositions of four or more letters: Chicago lowercases them
  ("A Song about Love"), AP capitalizes them ("A Song About Love"). The setting is
  remembered between launches.
- **Change Hotkey…**: click it, then press the new combo (must include ⌘, ⌃, or ⌥;
  Esc cancels). The new shortcut takes effect immediately and persists.
- **Replace selection in place**: enable this from the menu to make the hotkey copy
  the current selection, title-case it, and paste it back automatically. This needs
  **Accessibility** permission — macOS will prompt; approve *TitleCase* under
  System Settings → Privacy & Security → Accessibility, then toggle it on again.
- **Launch at Login**: toggle from the menu so it's always available.

## Tweaking the rules
- **Short lowercase word list** (used by both styles): edit `baseSmall` in
  `src/TitleCaseEngine.swift`.
- **Long prepositions** (lowercased only in Chicago): edit `longPrepositions` in
  the same file.
- **Default hotkey** (before any in-app change): the fallbacks in `hotKeyCode` /
  `hotKeyMods` in `src/App.swift`. Day-to-day, just use *Change Hotkey…* in the menu.

Settings are stored in `defaults` under `com.mkclvrt.titlecase` (`titleStyle`,
`hotKeyCode`, `hotKeyMods`, `hotKeyDisplay`, `autoPasteInPlace`).

Re-run `./build.sh` after any change.
