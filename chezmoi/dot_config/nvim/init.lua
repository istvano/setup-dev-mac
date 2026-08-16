-- Neovim configuration.
--
-- This file exists because neovim is $EDITOR in both shells and core.editor in git, so it
-- is what opens for a commit message, a `git rebase -i`, a quick fix over ssh, and every
-- EDITOR prompt on the machine — and it had no configuration at all. A repository that
-- gives `bindkey -e` its own paragraph of reasoning was shipping a bare editor as the
-- default one.
--
-- No plugins, and no plugin manager. ADR-031 rejects fetching unreviewed code at runtime
-- outside the Homebrew trust boundary, and that applies to lazy.nvim and packer exactly as
-- it applies to oh-my-zsh. Everything below is built into neovim, so this file has no
-- install step, cannot break on a network failure, and works the moment the binary exists.
--
-- The bar for a setting here is that its absence is a papercut in the editing this machine
-- actually does: commit messages, config files, and reading code that a real IDE is already
-- open on. It is deliberately not an IDE.

local opt = vim.opt

-- Clipboard shared with macOS.
--
-- Without this, yanking in nvim and pasting into a browser silently does nothing, which is
-- the single most common surprise for anyone who edits here occasionally. neovim finds
-- pbcopy/pbpaste on macOS by itself, so no provider configuration is needed.
opt.clipboard = "unnamedplus"

-- Line numbers, absolute only.
--
-- Relative numbers pay for themselves when you are driving motions all day, and cost you
-- when you are reading a stack trace that names line 412 — which is the traffic this editor
-- actually sees.
opt.number = true

-- Search that behaves the way the search in every other tool does.
--
-- smartcase only takes effect with ignorecase set: lowercase queries match anything,
-- and typing a capital means you meant it.
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Two spaces, expanded, matching this repository's own shell and Lua files. A project with
-- an .editorconfig or its own convention overrides this per buffer.
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Persistent undo, so closing a file does not discard its history. The directory is created
-- by neovim on first write.
opt.undofile = true

-- Keep context visible rather than letting the cursor sit against the edge.
opt.scrolloff = 5
opt.sidescrolloff = 8

-- True colour, which Ghostty supports. Without it the terminal's 256-colour approximation
-- is used and the Catppuccin palette configured for Ghostty is visibly wrong inside nvim.
opt.termguicolors = true

-- Show the effect of :s as it is typed, in a split. Built in since 0.6 and off by default.
opt.inccommand = "split"

-- Whitespace made visible, because trailing spaces and hard tabs in a repository that
-- runs shfmt are things you want to see rather than discover in review.
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Faster CursorHold, which drives the built-in highlight below.
opt.updatetime = 300

-- A visible flash on yank, so a motion that grabbed the wrong range is obvious immediately.
-- vim.hl.on_yank is built in; no plugin involved.
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Briefly highlight yanked text",
  callback = function()
    (vim.hl or vim.highlight).on_yank({ timeout = 150 })
  end,
})

-- Return to the last position when reopening a file, skipping commit messages: for those
-- the top of the buffer is always where you want to be.
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore the last cursor position",
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if ft == "gitcommit" or ft == "gitrebase" then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Clear search highlighting. <Esc> in normal mode otherwise does nothing, so this costs no
-- existing binding.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
