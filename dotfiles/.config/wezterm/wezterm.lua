local wezterm = require 'wezterm'
local act = wezterm.action

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

local config = wezterm.config_builder()

config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font {
  family = "Iosevka Charon Mono", -- Corrected font name, assuming it's installed
  weight = "Medium",             -- Corrected to a valid weight string
}
config.font_size = 18.0
config.adjust_window_size_when_changing_font_size = true

-- Set the initial window size.
config.initial_cols = 160
config.initial_rows = 36

config.color_scheme = "Apple System Colors"
config.window_background_opacity = 1
config.enable_scroll_bar = false
config.line_height = 1
config.font_dirs = {}
config.enable_wayland = true
config.exit_behavior = "Close"

config.keys = {
  -- Option + Left Arrow: Move back one word
  {
    key = 'LeftArrow',
    mods = 'OPT',
    action = act.SendString('\x1bb'),
  },
  -- Option + Right Arrow: Move forward one word
  {
    key = 'RightArrow',
    mods = 'OPT',
    action = act.SendString('\x1bf'),
  },
}

-- Helper to map Cmd to Ctrl
local function map_cmd_to_ctrl(key)
    table.insert(config.keys, {
        key = key,
        mods = 'CMD',
        action = act.SendKey { key = key, mods = 'CTRL' },
    })
end

-- List of keys to map (Excluding 'c', 'v', and 'a' as requested)
local keys_to_map = {
    'b', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'w', 'x', 'y', 'z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    '[', ']', '\\', ';', "'", ',', '.', '/', '-', '='
}

for _, k in ipairs(keys_to_map) do
    map_cmd_to_ctrl(k)
end

-- Keep Cmd+C as Native Copy
table.insert(config.keys, {
    key = 'c',
    mods = 'CMD',
    action = act.CopyTo 'Clipboard',
})

-- Ensure Cmd+V remains Paste
table.insert(config.keys, {
    key = 'v',
    mods = 'CMD',
    action = act.PasteFrom 'Clipboard',
})

-- Keep Cmd+A as Native Select All
table.insert(config.keys, {
    key = 'a',
    mods = 'CMD',
    action = act.SelectTextAtMouseCursor 'Cell', -- This is a placeholder for native select all behavior in terminal
})

return config
