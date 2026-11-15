# DibsUI-Options

The settings window, profiles and minimap button shared by the DibsUI addons for World of Warcraft: Forever.

Every DibsUI addon needs it. Install it along with the addon. CurseForge installs it for you.

## What it does

- **One settings window** for every DibsUI addon. Open it with `/dibsui`, `/dui`, the minimap button, or
  Options > AddOns > DibsUI. Each addon adds its own tabs.
- **Profiles** shared by every character on your account. A profile holds the settings of every DibsUI addon,
  so switching changes them all.
- **One Unlock frames button** that unlocks every DibsUI addon's frames. `/dibsui lock` does the same.
- **The minimap button**, which you can drag around the minimap or hide.

## For addon authors: the module API

DibsUI-Options sets the global `DibsUIOptions`. Add `## Dependencies: DibsUI-Options` to your TOC, then
register at your `ADDON_LOADED`:

```lua
DibsUIOptions:RegisterModule({
	key = "MyModule",          -- also the key of your settings in each profile
	addon = "MyAddonFolder",   -- for the version shown on the Options > AddOns page
	title = "My Module",       -- heading over your tabs when more than one addon is installed
	order = 20,                -- where your tabs go (DibsUI is 10)
	cleanProfile = function(settings) return settings end, -- fill in defaults, fix bad values
	tabs = {
		{ label = "My Tab", build = function(content, context, relayout)
			return { Sync = function() end, SetCombatLocked = function(locked) end, Layout = flowFunction }
		end },
	},
	onProfileChanged = function(settings) end, -- the character switched profile (never in combat)
	isLocked = function() return true end,
	setLocked = function(locked) end,         -- never in combat
})

local settings = DibsUIOptions:GetProfile("MyModule") -- your table in the profile in use
local account = DibsUIOptions:GetAccount("MyModule")  -- your account-wide table
```

Other calls:

| Call | Does |
|---|---|
| `DibsUIOptions.version` | API version, `1` now |
| `DibsUIOptions.Widgets` | The controls and page layout the settings pages use (toggle rows, sliders, dropdowns, cards, flow layout, scroll page, color swatch, font menu, panels). See `Widgets.lua` for the list at the end |
| `:Open(moduleKey, tabLabel)` / `:Toggle()` | Open the window, on a module's tab |
| `:IsLocked()` / `:SetLocked(locked)` / `:NotifyLockChanged()` | Every module's frame lock |
| `:GetProfileName()`, `:GetProfileNames()`, `:UseProfile(name)`, `:CreateProfile(name, copyFrom)`, `:DeleteProfile(name)` | Profiles |
| `:ImportOnce(key, { profiles, characters, account, minimap, window })` | Bring a module's settings from before DibsUI-Options in, once |
| `:Print(message)` | Chat message with the DibsUI prefix |

The addons update separately, so keep old calls working when changing this API, and bump `version`.

## License

MIT
