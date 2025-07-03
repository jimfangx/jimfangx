lua <<EOF
if vim.tbl_add_reverse_lookup ~= nil then
  vim.tbl_add_reverse_lookup = function(tbl) return tbl end
end
EOF

let mapleader = " "

" for vimtree
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" Line numbers
set number                     " Show absolute line numbers
set relativenumber            " Show relative line numbers

" Tabs and indentation
set tabstop=4                 " Number of spaces a <Tab> counts for
set shiftwidth=4              " Number of spaces to use for each step of (auto)indent
set expandtab                 " Use spaces instead of tabs
set smartindent               " Autoindent new lines smartly

" Search
set ignorecase                " Ignore case in search patterns...
set smartcase                 " ...unless uppercase is used
set incsearch                 " Show match while typing
set hlsearch                  " Highlight all matches on previous search

" UI
set cursorline                " Highlight the current line
set scrolloff=8               " Minimal number of lines to keep above/below cursor
set signcolumn=yes            " Always show the sign column

" File handling
" set noswapfile                " Don't use swapfile
set nobackup                  " Don't create backup files
set undofile                  " Enable persistent undo

" Colors
set termguicolors             " True color support in terminal
" Do not override terminal background
highlight Normal       ctermbg=none guibg=none
highlight NormalNC     ctermbg=none guibg=none
highlight EndOfBuffer  ctermbg=none guibg=none
highlight SignColumn   ctermbg=none guibg=none
highlight VertSplit    ctermbg=none guibg=none
highlight StatusLineNC ctermbg=none guibg=none
highlight MsgArea      ctermbg=none guibg=none
highlight NormalFloat  ctermbg=none guibg=none
highlight FloatBorder  ctermbg=none guibg=none
" Optional -- for popup menus
highlight Pmenu        ctermbg=none guibg=none
highlight PmenuSel     ctermbg=none guibg=none
" Auto-reset after colorscheme change - prevent your colorscheme from
" overriding this
autocmd ColorScheme * highlight Normal       guibg=none ctermbg=none
autocmd ColorScheme * highlight NormalNC     guibg=none ctermbg=none
autocmd ColorScheme * highlight EndOfBuffer  guibg=none ctermbg=none
autocmd ColorScheme * highlight SignColumn   guibg=none ctermbg=none
autocmd ColorScheme * highlight VertSplit    guibg=none ctermbg=none
autocmd ColorScheme * highlight StatusLineNC guibg=none ctermbg=none
autocmd ColorScheme * highlight MsgArea      guibg=none ctermbg=none
autocmd ColorScheme * highlight NormalFloat  guibg=none ctermbg=none
autocmd ColorScheme * highlight FloatBorder  guibg=none ctermbg=none


" Mouse
set mouse=a                   " Enable mouse support in all modes

" Clipboard
set clipboard=unnamedplus     " Use system clipboard

call plug#begin('~/.config/nvim/plugged')

" List your plugins here

Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.8' }

Plug 'neovim/nvim-lspconfig'  " Collection of LSP configs for built-in LSP client
Plug 'mason-org/mason.nvim' " Mason and its optional companion for LSPconfig
Plug 'mason-org/mason-lspconfig.nvim'


Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'

" For vsnip users.
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'

Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'jay-babu/mason-null-ls.nvim'

Plug 'nvim-lualine/lualine.nvim'
" If you want to have icons in your statusline choose one of these
Plug 'nvim-tree/nvim-web-devicons'

" hot key <leader> / to comment -- in visual itll block comment, in normal
" itll line comment
Plug 'numToStr/Comment.nvim'

" inline git blame
Plug 'lewis6991/gitsigns.nvim'

" bufferline/tabs on top 
Plug 'nvim-tree/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }

" nvim-tree - left bar file directory
Plug 'nvim-tree/nvim-tree.lua'


call plug#end()


lua << EOF
-- Setup mason and ensure servers are installed

-- Setup mason
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = {
    "bashls",
    "clangd",
    "jdtls",
    "marksman",
    "pyright",
  },
  automatic_installation = true,
})

-- Setup nvim-cmp (completion UI)
local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "buffer" },
  },
})

-- LSP client capabilities
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP config
local lspconfig = require("lspconfig")
local servers = { "bashls", "clangd", "jdtls", "marksman", "pyright" }

for _, server in ipairs(servers) do
  lspconfig[server].setup({
    capabilities = capabilities,
  })
end

-- Setup null-ls and biome formatter/diagnostic
local null_ls = require("null-ls")
require("mason-null-ls").setup({
  ensure_installed = { "biome" },
  automatic_installation = true,
})

null_ls.setup({
  sources = {
   -- null_ls.builtins.formatting.biome,
    null_ls.builtins.diagnostics.biome,
  },
})

-- Suppress deprecated vim.tbl_add_reverse_lookup warning
vim.tbl_add_reverse_lookup = function(tbl)
  return tbl
end

 

  -- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
  -- Set configuration for specific filetype.
  --[[ cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' },
    }, {
      { name = 'buffer' },
    })
 })
 require("cmp_git").setup() ]]-- 

  -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'buffer' }
    }
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = 'path' }
    }, {
      { name = 'cmdline' }
    }),
    matching = { disallow_symbol_nonprefix_matching = false }
  })


    -- bottom status line 
    require('lualine').setup {
    options = {
        theme = 'dracula',  -- 🌈 Preset theme (can be 'onedark', 'dracula', 'tokyonight', etc.) - https://github.com/nvim-lualine/lualine.nvim/blob/master/THEMES.md
        component_separators = '|',
        section_separators = '',
      }
    }

    
    -- Initialize Comment.nvim + bind hotkeys
    require('Comment').setup()

    -- Toggle line comment in NORMAL mode using <leader>/
    vim.keymap.set('n', '<leader>/', require('Comment.api').toggle.linewise.current, {
      noremap = true,
      silent = true
    })

    -- Toggle LINEWISE comment (e.g., // or #) in VISUAL mode using <leader>/
    vim.keymap.set('v', '<leader>/', function()
      -- Exit visual mode safely before applying comment
      local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
      vim.api.nvim_feedkeys(esc, 'x', false)
      require('Comment.api').locked('toggle.linewise')(vim.fn.visualmode())
    end, {
      noremap = true,
      silent = true
    })



    -- gitblame/signs config - https://github.com/lewis6991/gitsigns.nvim
    require('gitsigns').setup {
     signs = {
        add          = { text = '│' },
        change       = { text = '│' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
      }, 

      signcolumn = true,     -- Always show sign column
      numhl      = false,    -- Don't use number highlight
      linehl     = false,    -- Don't use line highlight
      word_diff  = false,    -- Set to true if you want word-level diffs

      -- Always show inline blame
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',  -- Position blame at end of line
        delay = 0,              -- No delay
        ignore_whitespace = false,
      },
    }


    -- bufferline
    require("bufferline").setup({
      options = {
        mode = "tabs",  -- Use real tab pages instead of buffers

        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level, diagnostics_dict, context)
          local icon = level:match("error") and " " or " "
          return " " .. icon .. count
        end,

        -- Sidebar (e.g., for nvim-tree)
        offsets = {
          {
            filetype = "NvimTree",
            text_align = "left",
            separator = true,
          },
        },

        -- Hover to show close buttons
        hover = {
          enabled = true,
          delay = 200,
          reveal = { "close" },
        },

        -- Underline the active tab
        highlights = {
            tab_separator_selected = {
              underline = "ff5c57",
            },
        },

        show_close_icon = true,
        show_tab_indicators = true,
        separator_style = "thin",
        always_show_bufferline = true,
        move_wraps_at_ends = true,
        color_icons = true
      },
    })

    -- vimtree/left sidebar
    require("nvim-tree").setup({
      sort_by = "case_sensitive",
      view = {
        width = 30,
        side = "left",
        preserve_window_proportions = true,
      },
      renderer = {
        group_empty = true,
        highlight_opened_files = "name",
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
        },
      },
      filters = {
        dotfiles = false,
      },
      git = {
        enable = true,
        ignore = false,
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
      },
    })

    -- vimtree, autoclose when its the last window
    vim.api.nvim_create_autocmd("BufEnter", {
      nested = true,
      callback = function()
        if #vim.api.nvim_list_wins() == 1 and vim.bo.filetype == "NvimTree" then
          vim.cmd("quit")
        end
      end,
    })


EOF

" Telescope bindings
nnoremap <silent> <leader>ff :lua require('telescope.builtin').find_files()<CR>
nnoremap <silent> <leader>fg :lua require('telescope.builtin').live_grep()<CR>
nnoremap <silent> <leader>fb :lua require('telescope.builtin').buffers()<CR>
nnoremap <silent> <leader>fh :lua require('telescope.builtin').help_tags()<CR>

" next & prev buffer - bufferline
nnoremap <leader>[ :BufferLineCyclePrev<CR>
nnoremap <leader>] :BufferLineCycleNext<CR>

" nvimtree keybinds
nnoremap <leader>b :NvimTreeToggle<CR>

nnoremap <leader>e :call ToggleNvimTreeFocus()<CR>
function! ToggleNvimTreeFocus()
  if &filetype ==# 'NvimTree'
    wincmd p
  else
    NvimTreeFocus
  endif
endfunction


