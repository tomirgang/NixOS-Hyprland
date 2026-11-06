-- Lid handling for frame, replaces KooL's UserConfigs/user_laptops.lua.
--
-- The internal panel is only switched off with the lid closed AND another
-- monitor showing the session. Otherwise Hyprland falls back to its virtual
-- FALLBACK output and hyprlock draws there, which leaves the panel black.
--
-- The binds need locked = true: a bind without it does not fire on the lock
-- screen, so opening the lid would not bring the panel back.
--
-- External monitors are not touched here, their rules in monitors.lua match by
-- description and stay in charge.

local INTERNAL = "eDP-1"
local LID_STATE = "/proc/acpi/button/lid/LID0/state"
local USER_MONITORS = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
  .. "/hypr/UserConfigs/monitors.lua"

local function lid_closed()
  local file = io.open(LID_STATE, "r")
  if not file then
    return false
  end
  local state = file:read("*a")
  file:close()
  return state:find("closed", 1, true) ~= nil
end

local function external_active()
  for _, monitor in ipairs(hl.get_monitors() or {}) do
    if monitor.name ~= INTERNAL and monitor.name ~= "FALLBACK" then
      return true
    end
  end
  return false
end

-- Mode, position and scale of the panel from monitors.lua, without applying the
-- rules in that file. DisplayProfile.sh rewrites it, so nothing is hardcoded.
local function internal_rule()
  local rule = {}
  local apply_rule = hl.monitor
  hl.monitor = function(spec)
    if type(spec) == "table" and spec.output == INTERNAL then
      rule = spec
    end
  end
  pcall(dofile, USER_MONITORS)
  hl.monitor = apply_rule
  return rule
end

-- Last state set here. Changing a monitor fires monitor.removed again, the guard
-- ends that loop.
local panel_disabled = nil

local function apply_lid_state()
  local disable = lid_closed() and external_active()
  if disable == panel_disabled then
    return
  end
  panel_disabled = disable

  if disable then
    hl.monitor({ output = INTERNAL, disabled = true })
    return
  end

  -- disabled = false has to be set, a replayed rule without it leaves the
  -- output off.
  local rule = internal_rule()
  hl.monitor({
    output = INTERNAL,
    disabled = false,
    mode = rule.mode or "preferred",
    position = rule.position or "auto",
    scale = rule.scale or "auto",
  })
end

hl.bind("switch:on:Lid Switch", apply_lid_state, { locked = true })
hl.bind("switch:off:Lid Switch", apply_lid_state, { locked = true })

-- The last external monitor unplugged while the lid is closed.
hl.on("monitor.removed", apply_lid_state)
