-- WezTerm settings for pi: keyboard protocol + Emacs-style copy mode.
--
-- This file is a plain table, not a config: it is loaded from your own
-- wezterm.lua so it never takes over settings you already made. Add this after
-- your config table is built:
--
--   local pi = dofile(wezterm.config_dir .. '/pi.lua')
--   for k, v in pairs(pi) do config[k] = v end      -- pi.lua wins on these keys
--
-- `require 'pi'` does not work: WezTerm does not put the config directory on
-- package.path. Everything here is additive, so a merge cannot drop your own
-- bindings; only `keys` and `key_tables.copy_mode` are replaced wholesale.
--
-- Written without wezterm.config_builder(): builds before 2022-11 do not have
-- it (20220903, the last release for glibc 2.27, errors on it).
local wezterm = require 'wezterm'
local act = wezterm.action

local copy_and_close = act.Multiple {
  { CopyTo = 'ClipboardAndPrimarySelection' },
  { CopyMode = 'Close' },
}

return {
  -- Report real Shift+Enter / Alt+Enter instead of hoping they are
  -- distinguishable from Enter and Ctrl+J (see pi's terminal-setup doc).
  -- Builds without the Kitty protocol ignore this field silently.
  enable_kitty_keyboard = true,

  keys = {
    -- WezTerm binds Alt+Enter to fullscreen by default, which swallows pi's
    -- follow-up queue. Forward the CSI-u form pi expects instead.
    { key = 'Enter', mods = 'ALT', action = act.SendString '\x1b[13;3u' },
  },

  -- Emacs chords for scrollback, with the Vi table kept underneath: normal-mode
  -- keys stay untouched, so the shell's own Emacs keymap still does line editing.
  key_tables = {
    copy_mode = {
      -- point motion
      { key = 'a', mods = 'CTRL', action = act.CopyMode 'MoveToStartOfLine' },
      { key = 'e', mods = 'CTRL', action = act.CopyMode 'MoveToEndOfLineContent' },
      { key = 'b', mods = 'CTRL', action = act.CopyMode 'MoveLeft' },
      { key = 'f', mods = 'CTRL', action = act.CopyMode 'MoveRight' },
      { key = 'p', mods = 'CTRL', action = act.CopyMode 'MoveUp' },
      { key = 'n', mods = 'CTRL', action = act.CopyMode 'MoveDown' },

      -- scrolling: C-v forward a screen, M-v back a screen
      { key = 'v', mods = 'CTRL', action = act.CopyMode 'PageDown' },
      { key = 'v', mods = 'ALT', action = act.CopyMode 'PageUp' },

      -- kill ring: C-w (kill-region), M-w (kill-ring-save)
      { key = 'w', mods = 'CTRL', action = copy_and_close },
      { key = 'w', mods = 'ALT', action = copy_and_close },

      -- Vi keys below; block selection moves one modifier out
      { key = 'v', mods = 'SHIFT|CTRL', action = act.CopyMode { SetSelectionMode = 'Block' } },
      { key = 'Tab', mods = 'NONE', action = act.CopyMode 'MoveForwardWord' },
      { key = 'Tab', mods = 'SHIFT', action = act.CopyMode 'MoveBackwardWord' },
      { key = 'Enter', mods = 'NONE', action = act.CopyMode 'MoveToStartOfNextLine' },
      { key = 'Escape', mods = 'NONE', action = act.CopyMode 'Close' },
      { key = 'Space', mods = 'NONE', action = act.CopyMode { SetSelectionMode = 'Cell' } },
      { key = '$', mods = 'NONE', action = act.CopyMode 'MoveToEndOfLineContent' },
      { key = '$', mods = 'SHIFT', action = act.CopyMode 'MoveToEndOfLineContent' },
      { key = '0', mods = 'NONE', action = act.CopyMode 'MoveToStartOfLine' },
      { key = 'G', mods = 'NONE', action = act.CopyMode 'MoveToScrollbackBottom' },
      { key = 'G', mods = 'SHIFT', action = act.CopyMode 'MoveToScrollbackBottom' },
      { key = 'H', mods = 'NONE', action = act.CopyMode 'MoveToViewportTop' },
      { key = 'H', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportTop' },
      { key = 'L', mods = 'NONE', action = act.CopyMode 'MoveToViewportBottom' },
      { key = 'L', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportBottom' },
      { key = 'M', mods = 'NONE', action = act.CopyMode 'MoveToViewportMiddle' },
      { key = 'M', mods = 'SHIFT', action = act.CopyMode 'MoveToViewportMiddle' },
      { key = 'O', mods = 'NONE', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
      { key = 'O', mods = 'SHIFT', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
      { key = 'V', mods = 'NONE', action = act.CopyMode { SetSelectionMode = 'Line' } },
      { key = 'V', mods = 'SHIFT', action = act.CopyMode { SetSelectionMode = 'Line' } },
      { key = '^', mods = 'NONE', action = act.CopyMode 'MoveToStartOfLineContent' },
      { key = '^', mods = 'SHIFT', action = act.CopyMode 'MoveToStartOfLineContent' },
      { key = 'b', mods = 'NONE', action = act.CopyMode 'MoveBackwardWord' },
      { key = 'b', mods = 'ALT', action = act.CopyMode 'MoveBackwardWord' },
      { key = 'c', mods = 'CTRL', action = act.CopyMode 'Close' },
      { key = 'f', mods = 'ALT', action = act.CopyMode 'MoveForwardWord' },
      { key = 'g', mods = 'NONE', action = act.CopyMode 'MoveToScrollbackTop' },
      { key = 'g', mods = 'CTRL', action = act.CopyMode 'Close' },
      { key = 'h', mods = 'NONE', action = act.CopyMode 'MoveLeft' },
      { key = 'j', mods = 'NONE', action = act.CopyMode 'MoveDown' },
      { key = 'k', mods = 'NONE', action = act.CopyMode 'MoveUp' },
      { key = 'l', mods = 'NONE', action = act.CopyMode 'MoveRight' },
      { key = 'm', mods = 'ALT', action = act.CopyMode 'MoveToStartOfLineContent' },
      { key = 'o', mods = 'NONE', action = act.CopyMode 'MoveToSelectionOtherEnd' },
      { key = 'q', mods = 'NONE', action = act.CopyMode 'Close' },
      { key = 'v', mods = 'NONE', action = act.CopyMode { SetSelectionMode = 'Cell' } },
      { key = 'w', mods = 'NONE', action = act.CopyMode 'MoveForwardWord' },
      { key = 'y', mods = 'NONE', action = copy_and_close },
      { key = 'PageUp', mods = 'NONE', action = act.CopyMode 'PageUp' },
      { key = 'PageDown', mods = 'NONE', action = act.CopyMode 'PageDown' },
      { key = 'LeftArrow', mods = 'NONE', action = act.CopyMode 'MoveLeft' },
      { key = 'LeftArrow', mods = 'ALT', action = act.CopyMode 'MoveBackwardWord' },
      { key = 'RightArrow', mods = 'NONE', action = act.CopyMode 'MoveRight' },
      { key = 'RightArrow', mods = 'ALT', action = act.CopyMode 'MoveForwardWord' },
      { key = 'UpArrow', mods = 'NONE', action = act.CopyMode 'MoveUp' },
      { key = 'DownArrow', mods = 'NONE', action = act.CopyMode 'MoveDown' },
    },
  },
}