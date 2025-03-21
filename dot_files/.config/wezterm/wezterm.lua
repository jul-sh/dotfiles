local wezterm = require 'wezterm'

return {
  keys = {
    -- Option + Left Arrow: Move back one word
    {
        key = 'LeftArrow',
        mods = 'OPT',
        action = wezterm.action.SendString('\x1bb'),  -- \x1b is the Escape character.
    },
    -- Option + Right Arrow: Move forward one word
    {
        key = 'RightArrow',
        mods = 'OPT',
        action = wezterm.action.SendString('\x1bf'),
    },
  },
  hide_tab_bar_if_only_one_tab = true,
  font = wezterm.font {
    family = "Iosevka Julsh Mono",  -- Corrected font name, assuming it's installed
    weight = "Medium",          -- Corrected to a valid weight string
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
  font_dirs = {},  -- Leave this empty to use the default system font directories
  -- Example of adding a custom font directory (uncomment and modify if needed):
  -- font_dirs = { "/path/to/your/custom/fonts" },

  -- Other good defaults:
  enable_wayland = true,  -- Use Wayland if available.  Set to false to force X11.
}
