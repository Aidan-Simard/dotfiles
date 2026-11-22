-- review.lua — Neovim side of the pi <-> code-preview diff review.
--
-- Loaded by bridge.sh with dofile() and started through
-- luaeval("dofile(<this file>).start(<args file>)").
--
-- The pi extension has already opened the diff tab (code-preview.nvim); this
-- adds buffer-local Accept / Reject keys to it and writes the chosen decision
-- to a JSON file that the extension polls. Nothing here knows about pi beyond
-- that file.
--
-- State lives on _G.PI_REVIEW so repeated dofile() calls (each one creates a
-- fresh module table) still see the same active review.

local M = _G.PI_REVIEW or {}
_G.PI_REVIEW = M

local function read_json(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local raw = fh:read("*a")
  fh:close()
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == "table" then return decoded end
  return nil
end

local function write_json(path, value)
  local fh = io.open(path, "w")
  if not fh then return false end
  fh:write(vim.json.encode(value))
  fh:close()
  return true
end

local function resolve(decision)
  local active = M.active
  if not active or active.resolved then return end
  active.resolved = true
  write_json(active.decision_file, { decision = decision })
  M.cleanup()
end

function M.cleanup()
  local active = M.active
  if not active then return end

  for _, buf in ipairs(active.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      for _, key in ipairs({ active.keys.accept, active.keys.reject }) do
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
    end
  end

  if active.augroup then pcall(vim.api.nvim_del_augroup_by_id, active.augroup) end
  M.active = nil
end

--- Called by the buffer-local keymaps (and by tests / user config).
function M.decide(decision)
  local active = M.active
  if not active then return end
  if decision ~= "accept" and decision ~= "reject" then return end

  vim.notify(
    string.format("pi: %s %s", active.label, decision == "accept" and "accepted" or "rejected"),
    decision == "accept" and vim.log.levels.INFO or vim.log.levels.WARN
  )
  resolve(decision)
end

--- Start a review. @param args_file JSON written by index.ts:
---   { decision_file = "...", label = "src/foo.ts",
---     keys = { accept = "<leader>da", reject = "<leader>dr" } }
function M.start(args_file)
  local args = read_json(args_file)
  if not args or type(args.decision_file) ~= "string" then
    return false
  end

  -- A stale review from a previous proposal: drop its keys, but keep its
  -- decision file untouched (the extension already handled it).
  M.cleanup()

  local keys = args.keys or {}
  local accept = keys.accept or "<leader>da"
  local reject = keys.reject or "<leader>dr"
  local label = args.label or "proposed change"

  local bufs, seen = {}, {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if not seen[buf] then
      seen[buf] = true
      table.insert(bufs, buf)
    end
  end

  local augroup = vim.api.nvim_create_augroup("PiReview", { clear = true })
  M.active = {
    decision_file = args.decision_file,
    label = label,
    keys = { accept = accept, reject = reject },
    bufs = bufs,
    augroup = augroup,
    resolved = false,
  }

  for _, buf in ipairs(bufs) do
    vim.keymap.set("n", accept, function() M.decide("accept") end,
      { buffer = buf, nowait = true, desc = "pi: accept proposed change" })
    vim.keymap.set("n", reject, function() M.decide("reject") end,
      { buffer = buf, nowait = true, desc = "pi: reject proposed change" })

    -- Closing the preview another way (<leader>dq, :q, ...) counts as a
    -- reject: nothing was accepted.
    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
      group = augroup,
      buffer = buf,
      callback = function()
        local active = M.active
        if active and not active.resolved then resolve("closed") end
      end,
    })
  end

  vim.notify(
    string.format("pi: review %s — %s accept · %s reject", label, accept, reject),
    vim.log.levels.INFO
  )
  return true
end

return M
