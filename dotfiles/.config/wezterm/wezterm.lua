local wezterm = require 'wezterm'

-- Track manual fresh mode toggle per-pane
wezterm.GLOBAL.fresh_mode_panes = wezterm.GLOBAL.fresh_mode_panes or {}

-- Helper to check if fresh editor is active (auto-detect OR manual toggle)
local function is_fresh(pane)
  -- Check manual toggle first
  local pane_id = tostring(pane:pane_id())
  if wezterm.GLOBAL.fresh_mode_panes[pane_id] then
    return true
  end
  -- Auto-detect local fresh process
  local process = pane:get_foreground_process_name()
  return process and process:match('fresh$')
end

-- Toggle fresh mode manually (for SSH)
local function toggle_fresh_mode(window, pane)
  local pane_id = tostring(pane:pane_id())
  local is_enabled = wezterm.GLOBAL.fresh_mode_panes[pane_id]
  wezterm.GLOBAL.fresh_mode_panes[pane_id] = not is_enabled
  local new_state = not is_enabled
  window:toast_notification('WezTerm', 'Fresh mode: ' .. (new_state and 'ON' or 'OFF'), nil, 2000)
end

-- Helper to create a conditional keybinding:
-- When fresh is active: send Ctrl+key to fresh
-- When fresh is not active: perform the fallback WezTerm action (or do nothing)
local function cmd_to_ctrl_in_fresh(key, fallback_action)
  return wezterm.action_callback(function(window, pane)
    if is_fresh(pane) then
      window:perform_action(wezterm.action.SendKey{ key = key, mods = 'CTRL' }, pane)
    elseif fallback_action then
      window:perform_action(fallback_action, pane)
    end
  end)
end

-- Show "FRESH" indicator in right status when manual mode is active
wezterm.on('update-right-status', function(window, pane)
  local pane_id = tostring(pane:pane_id())
  if wezterm.GLOBAL.fresh_mode_panes[pane_id] then
    window:set_right_status(wezterm.format({
      { Background = { Color = '#5f5fff' } },
      { Foreground = { Color = '#ffffff' } },
      { Text = ' FRESH ' },
    }))
  else
    window:set_right_status('')
  end
end)

-- set size of newly opened windows. ref https://github.com/wezterm/wezterm/issues/3173
wezterm.on('window-config-reloaded', function(window, pane)
  -- approximately identify this gui window, by using the associated mux id
  local id = tostring(window:window_id())

  -- maintain a mapping of windows that we have previously seen before in this event handler
  local seen = wezterm.GLOBAL.seen_windows or {}
  -- set a flag if we haven't seen this window before
  local is_new_window = not seen[id]
  -- and update the mapping
  seen[id] = true
  wezterm.GLOBAL.seen_windows = seen

  -- now act upon the flag
  if is_new_window then
    window:set_inner_size(2500, 1700)
    window:focus()
  end
end)

return {
  window_close_confirmation = "NeverPrompt",
  keys = {
    -- Option + Left Arrow: Move back one word
    {
      key = 'LeftArrow',
      mods = 'OPT',
      action = wezterm.action.SendString('\x1bb'),   -- \x1b is the Escape character.
    },
    -- Option + Right Arrow: Move forward one word
    {
      key = 'RightArrow',
      mods = 'OPT',
      action = wezterm.action.SendString('\x1bf'),
    },
    -- Shift + Enter: Send newline
    {
      key = 'Enter',
      mods = 'SHIFT',
      action = wezterm.action.SendString('\n'),
    },

    -- Toggle fresh mode manually (for SSH sessions)
    { key = 'f', mods = 'CMD|SHIFT', action = wezterm.action_callback(toggle_fresh_mode) },

    -- Fresh editor: Cmd → Ctrl mappings (auto-detect locally, or when toggled)
    -- Editing
    { key = 's', mods = 'CMD', action = cmd_to_ctrl_in_fresh('s', nil) },  -- Save
    { key = 'z', mods = 'CMD', action = cmd_to_ctrl_in_fresh('z', nil) },  -- Undo
    { key = 'y', mods = 'CMD', action = cmd_to_ctrl_in_fresh('y', nil) },  -- Redo
    { key = 'f', mods = 'CMD', action = cmd_to_ctrl_in_fresh('f', nil) },  -- Find
    { key = 'h', mods = 'CMD', action = cmd_to_ctrl_in_fresh('h', nil) },  -- Find & Replace
    { key = '/', mods = 'CMD', action = cmd_to_ctrl_in_fresh('/', nil) },  -- Toggle comment
    { key = 'd', mods = 'CMD', action = cmd_to_ctrl_in_fresh('d', nil) },  -- Multi-cursor select

    -- Interface
    { key = 'p', mods = 'CMD', action = cmd_to_ctrl_in_fresh('p', nil) },  -- Command Palette
    { key = 'e', mods = 'CMD', action = cmd_to_ctrl_in_fresh('e', nil) },  -- File Explorer
    { key = ',', mods = 'CMD', action = cmd_to_ctrl_in_fresh(',', nil) },  -- Settings

    -- Tabs & Windows (with WezTerm fallbacks)
    { key = 'n', mods = 'CMD', action = cmd_to_ctrl_in_fresh('n', wezterm.action.SpawnWindow) },  -- New file / New window
    { key = 't', mods = 'CMD', action = cmd_to_ctrl_in_fresh('t', wezterm.action.SpawnTab('CurrentPaneDomain')) },  -- New tab
    { key = 'w', mods = 'CMD', action = cmd_to_ctrl_in_fresh('w', wezterm.action.CloseCurrentTab{ confirm = false }) },  -- Close tab
    { key = 'q', mods = 'CMD', action = cmd_to_ctrl_in_fresh('q', wezterm.action.QuitApplication) },  -- Quit
  },
  hide_tab_bar_if_only_one_tab = true,
  font = wezterm.font {
    family = "Iosevka Charon Mono", -- Corrected font name, assuming it's installed
    weight = "Medium",             -- Corrected to a valid weight string
  },
  font_size = 18.0,
  adjust_window_size_when_changing_font_size = true,

  -- Set the initial window size.  Crucially, we use *columns* and *lines*,
  -- not pixel width and height.  Wezterm sizes windows in terms of the
  -- character cell size.
  initial_cols = 160,
  initial_rows = 36,

  -- These settings (color_scheme and window_background_opacity) are *optional*
  -- but make the output more visually consistent and demonstrate additional config.
  color_scheme = "Apple System Colors",

  window_background_opacity = 1, -- Makes the background slightly transparent

  -- Disable the scrollbar (optional, but cleans up the UI)
  enable_scroll_bar = false,

  -- Adjust line height.  This can improve readability, especially with
  -- monospaced fonts.  A value of 1.0 is the default.  Values greater
  -- than 1.0 increase spacing, less than 1.0 decrease it.
  line_height = 1,

  -- This section helps resolve the "No fonts matched" error.  It ensures
  -- wezterm looks in standard font directories *and* allows you to add
  -- custom font directories if necessary.
  -- It is generally a GOOD IDEA to have this in your config.
  font_dirs = {}, -- Leave this empty to use the default system font directories
  -- Example of adding a custom font directory (uncomment and modify if needed):
  -- font_dirs = { "/path/to/your/custom/fonts" },

  -- Other good defaults:
  enable_wayland = true, -- Use Wayland if available.  Set to false to force X11.

  -- This stops WezTerm from quitting the whole window when a single pane/tab exits.
  exit_behavior = "Close",
}
