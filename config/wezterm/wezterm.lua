-- Minimal WezTerm config for a machine that has none. install.sh only writes
-- this file when ~/.config/wezterm/wezterm.lua does not exist; if you already
-- have one, add these two lines to it instead:
--
--   local pi = dofile(wezterm.config_dir .. '/pi.lua')
--   for k, v in pairs(pi) do config[k] = v end
local wezterm = require 'wezterm'

local config = {}

config.scrollback_lines = 10000
config.hide_tab_bar_if_only_one_tab = true

local pi = dofile(wezterm.config_dir .. '/pi.lua')
for k, v in pairs(pi) do config[k] = v end

return config