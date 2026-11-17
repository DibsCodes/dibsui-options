# Changelog

## 0.2.2

- First full release, no longer a beta, so the CurseForge app installs it along with DibsUI. No changes in the game

## 0.2.1

- No changes in the game. Released again with DibsUI 0.3.2 and DibsUI-Party 0.1.1 so the suite's betas line up

## 0.2.0

- `/dui` followed by an addon's word opens the settings on its tab, such as `/dui party` for DibsUI-Party. Any other word lists the commands
- For addon authors: `RegisterCallback` and `Fire`, so DibsUI addons can follow each other's settings, and a `slash` word for the module. DibsUI-Party uses them to follow DibsUI's font and last names. API version 2

## 0.1.0

- First version: the settings window, profiles, minimap button, `/dibsui` and the Options > AddOns page,
  moved out of DibsUI so every DibsUI addon can share them.
- Brings DibsUI's profiles, which profile each character uses, and the minimap button's settings over from
  DibsUI the first time both are loaded.
