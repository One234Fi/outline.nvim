local utils = require('outline.utils')

local M = {}
local all_kinds = {'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property', 'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable', 'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key', 'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter', 'Component', 'Fragment', 'TypeAlias', 'Parameter', 'StaticMethod', 'Macro',}

M.defaults = {
  guides = {
    enabled = true,
    markers = {
      bottom = '└',
      middle = '├',
      vertical = '│',
      horizontal = '─',
    },
  },
  outline_items = {
    show_symbol_details = true,
    show_symbol_lineno = false,
    highlight_hovered_item = true,
  },
  outline_window = {
    position = 'right',
    split_command = nil,
    width = 25,
    relative_width = true,
    wrap = false,
    focus_on_open = true,
    auto_close = false,
    auto_jump = false,
    show_numbers = false,
    show_relative_numbers = false,
    show_cursorline = true,
    hide_cursor = false,
    winhl = "OutlineDetails:Comment,OutlineLineno:LineNr",
    jump_highlight_duration = 500,
  },
  preview_window = {
    auto_preview = false,
    width = 50,
    min_width = 50,
    relative_width = true,
    border = 'single',
    open_hover_on_preview = false,
    winhl = '',
    winblend = 0,
  },
  symbol_folding = {
    autofold_depth = nil,
    auto_unfold_hover = true,
    markers = { '', '' },
  },
  keymaps = {
    show_help = '?',
    close = { '<Esc>', 'q' },
    goto_location = '<Cr>',
    peek_location = 'o',
    goto_and_close = '<S-Cr>',
    restore_location = "<C-g>",
    hover_symbol = '<C-space>',
    toggle_preview = 'K',
    rename_symbol = 'r',
    code_actions = 'a',
    fold = 'h',
    fold_toggle = '<tab>',
    fold_toggle_all = '<S-tab>',
    unfold = 'l',
    fold_all = 'W',
    unfold_all = 'E',
    fold_reset = 'R',
    down_and_jump = '<C-j>',
    up_and_jump = '<C-k>',
  },
  providers = {
    priority = { 'lsp', 'coc', 'markdown' },
    lsp = {
      blacklist_clients = {},
    },
  },
  symbols = {
    ---@type outline.FilterConfig?
    filter = nil,
    icon_source = nil,
    icon_fetcher = nil,
    icons = {
      File = { icon = '󰈔', hl = '@text.uri' },
      Module = { icon = '󰆧', hl = '@namespace' },
      Namespace = { icon = '󰅪', hl = '@namespace' },
      Package = { icon = '󰏗', hl = '@namespace' },
      Class = { icon = '𝓒', hl = '@type' },
      Method = { icon = 'ƒ', hl = '@method' },
      Property = { icon = '', hl = '@method' },
      Field = { icon = '󰆨', hl = '@field' },
      Constructor = { icon = '', hl = '@constructor' },
      Enum = { icon = 'ℰ', hl = '@type' },
      Interface = { icon = '󰜰', hl = '@type' },
      Function = { icon = '', hl = '@function' },
      Variable = { icon = '', hl = '@constant' },
      Constant = { icon = '', hl = '@constant' },
      String = { icon = '𝓐', hl = '@string' },
      Number = { icon = '#', hl = '@number' },
      Boolean = { icon = '⊨', hl = '@boolean' },
      Array = { icon = '󰅪', hl = '@constant' },
      Object = { icon = '⦿', hl = '@type' },
      Key = { icon = '🔐', hl = '@type' },
      Null = { icon = 'NULL', hl = '@type' },
      EnumMember = { icon = '', hl = '@field' },
      Struct = { icon = '𝓢', hl = '@type' },
      Event = { icon = '🗲', hl = '@type' },
      Operator = { icon = '+', hl = '@operator' },
      TypeParameter = { icon = '𝙏', hl = '@parameter' },
      Component = { icon = '󰅴', hl = '@function' },
      Fragment = { icon = '󰅴', hl = '@constant' },
      -- ccls
      TypeAlias =  { icon = ' ', hl = '@type' },
      Parameter = { icon = ' ', hl = '@parameter' },
      StaticMethod = { icon = ' ', hl = '@function' },
      Macro = { icon = ' ', hl = '@macro' },
    },
  },
}

M.o = {}

function M.has_numbers()
  return M.o.outline_window.show_numbers or M.o.outline_window.show_relative_numbers
end

function M.get_position_navigation_direction()
  if M.o.outline_window.position == 'left' then
    return 'h'
  else
    return 'l'
  end
end

function M.get_window_width()
  if M.o.outline_window.relative_width then
    return math.ceil(vim.o.columns * (M.o.outline_window.width / 100))
  else
    return M.o.outline_window.width
  end
end

function M.get_preview_width()
  if M.o.preview_window.relative_width then
    local relative_width = math.ceil(vim.o.columns * (M.o.preview_window.width / 100))

    if relative_width < M.o.preview_window.min_width then
      return M.o.preview_window.min_width
    else
      return relative_width
    end
  else
    return M.o.preview_window.width
  end
end

function M.get_split_command()
  local sc = M.o.outline_window.split_command
  if sc then
    return sc
  end
  if M.o.outline_window.position == 'left' then
    return 'topleft vs'
  else
    return 'botright vs'
  end
end

---Whether table == {}
---@param t table
local function is_empty_table(t)
  return t and next(t) == nil
end

local function table_has_content(t)
  return t and next(t) ~= nil
end

local function has_value(tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end

---Determine whether to include symbol in outline based on bufnr and its kind
---@param kind string
---@param bufnr integer
---@return boolean include
function M.should_include_symbol(kind, bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  -- There can only be one kind in markdown as of now
  if ft == 'markdown' or kind == nil then
    return true
  end

  local filter_table = M.o.symbols.filter[ft]
  local default_filter_table = M.o.symbols.filter['*']

  -- When filter table for a ft is not specified, all symbols are shown
  if not filter_table then
    if not default_filter_table then
      return true
    else
      return default_filter_table[kind] ~= false
    end
  end

  -- XXX: If the given kind is not known by outline.nvim (ie: not in
  -- all_kinds), still return true. Only exclude those symbols that were
  -- explicitly filtered out.
  return filter_table[kind] ~= false
end

---@param client vim.lsp.client|number
function M.is_client_blacklisted(client)
  if not client then
    return false
  end
  if type(client) == 'number' then
    client = vim.lsp.get_client_by_id(client)
    if not client then
      return false
    end
  end
  return has_value(M.o.providers.lsp.blacklist_clients, client.name)
end

---Retrieve and cache import paths of all providers in order of given priority
---@return string[]
function M.get_providers()
  if M.providers then
    return M.providers
  end

  M.providers = {}
  for _, p in ipairs(M.o.providers.priority) do
    if p == 'lsp' then
      p = 'nvim-lsp' -- due to legacy reasons
    end
    table.insert(M.providers, p)
  end
  return M.providers
end

function M.show_help()
  print 'Current keymaps:'
  print(vim.inspect(M.o.keymaps))
end

---Check for inconsistent or mutually exclusive opts.
-- Does not alter the opts. Might show messages.
function M.check_config()
  if M.o.outline_window.hide_cursor and not M.o.outline_window.show_cursorline then
    utils.echo("config", "Warning: hide_cursor enabled without cursorline enabled")
  end
end

---Resolve shortcuts and deprecated option conversions.
-- Might alter opts. Might show messages.
function M.resolve_config()
  ----- GUIDES -----
  local guides = M.o.guides
  if type(guides) == 'boolean' then
    M.o.guides = M.defaults.guides
    if not guides then
      M.o.guides.enabled = false
    end
  end
  ----- SPLIT COMMAND -----
  local sc = M.o.outline_window.split_command
  if sc then
    -- This should not be needed, nor is it failsafe. But in case user only provides
    -- the, eg, "topleft", we append the ' vs'.
    if not sc:find(' vs', 1, true) then
      M.o.outline_window.split_command = sc..' vs'
    end
  end
  ----- COMPAT (renaming) -----
  local dg = M.o.keymaps.down_and_goto
  local ug = M.o.keymaps.up_and_goto
  if dg then
    M.o.keymaps.down_and_jump = dg
    M.o.keymaps.down_and_goto = nil
  end
  if ug then
    M.o.keymaps.up_and_jump = ug
    M.o.keymaps.up_and_goto = nil
  end
  if M.o.outline_window.auto_goto then
    M.o.outline_window.auto_jump = M.o.outline_window.auto_goto
    M.o.outline_window.auto_goto = nil
  end
  ----- SYMBOLS FILTER -----
  M.resolve_filter_config()
end

---Ensure l is either table, false, or nil. If not, print warning using given
-- name that describes l, set l to nil, and return l.
---@generic T
---@param l T
---@param name string
---@return T
local function validate_filter_list(l, name)
  if type(l) == 'boolean' and l then
    utils.echo("config", ("Setting %s to true is undefined behaviour. Defaulting to nil."):format(name))
    l = nil
  elseif l and type(l) ~= 'table' and type(l) ~= 'boolean' then
    utils.echo("config", ("%s must either be a table, false, or nil. Defaulting to nil."):format(name))
    l = nil
  end
  return l
end

---Resolve shortcuts and compat opt for symbol filtering config, and set up
-- `M.o.symbols.filter` to be a proper `outline.FilterFtTable` lookup table.
function M.resolve_filter_config()
  ---@type outline.FilterConfig
  local tmp = M.o.symbols.filter
  tmp = validate_filter_list(tmp, "symbols.filter")

  ---- legacy form -> ft filter list ----
  if table_has_content(M.o.symbols.blacklist) then
    tmp = { ['*'] = M.o.symbols.blacklist }
    tmp['*'].exclude = true
    M.o.symbols.blacklist = nil
  else
    ---- nil or {} -> include all symbols ----
    -- For filter = {}: theoretically this would make no symbols show up. The
    -- user can't possibly want this (they should've disabled the plugin
    -- through the plugin manager); so we let filter = {} denote filter = nil
    -- (or false), meaning include all symbols.
    if not table_has_content(tmp) then
      tmp = { ['*'] = { exclude = true } }

    -- Lazy filter list -> ft filter list
    elseif tmp[1] then
      if type(tmp[1]) == 'string' then
        tmp = { ['*'] = vim.deepcopy(tmp) }
      else
        tmp['*'] = vim.deepcopy(tmp[1])
        tmp[1] = nil
      end
    end
  end

  ---@type outline.FilterFtList
  local filter = tmp
  ---@type outline.FilterFtTable
  M.o.symbols.filter = {}

  ---- ft filter list -> lookup table ----
  -- We do this so that all the O(N) checks happen once, in the setup phase,
  -- and checks for the filter list later on can be speedy.
  -- After this operation, filter table would have ft as keys, and for each
  -- value, it has each kind key denoting whether to include that kind for this
  -- filetype.
  -- {
  --   python = { String = false, Variable = true, ... },
  --   ['*'] = { File = true, Method = true, ... },
  -- }
  for ft, list in pairs(filter) do
    if type(ft) ~= 'string' then
      utils.echo("config", "ft (keys) for symbols.filter table can only be string. Skipping this ft.")
      goto continue
    end

    M.o.symbols.filter[ft] = {}

    list = validate_filter_list(list, ("filter list for ft '%s'"):format(ft))

    -- Ensure boolean.
    -- Catches setting some ft = false/nil, meaning include all kinds
    if not list then
      list = { exclude = true }
    else
      list.exclude = (list.exclude ~= nil and list.exclude) or false
    end

    -- If it's an exclude-list, set all kinds to be included (true) by default
    -- If it's an inclusive list, set all kinds to be excluded (false) by default
    for _, kind in pairs(all_kinds) do
      M.o.symbols.filter[ft][kind] = list.exclude
    end

    -- Now flip the switches
    for _, kind in ipairs(list) do
      M.o.symbols.filter[ft][kind] = not M.o.symbols.filter[ft][kind]
    end
    ::continue::
  end
end

function M.setup(options)
  vim.g.outline_loaded = 1
  M.o = vim.tbl_deep_extend('force', {}, M.defaults, options or {})
  M.check_config()
  M.resolve_config()
end

return M
