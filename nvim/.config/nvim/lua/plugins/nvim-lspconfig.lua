-- LSP: Language Server Protocol configuration
-- Provides: code intelligence, go-to-definition, rename, diagnostics, etc.
-- Mason auto-installs language servers; servers table configures each one
--
-- Keymaps (buffer-local when LSP attaches):
--   <leader>rn = rename symbol    <leader>ca = code action
--   gD = go to declaration        K = hover docs (built-in)
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'williamboman/mason.nvim', opts = {} }, -- LSP/tool installer UI (:Mason)
    'williamboman/mason-lspconfig.nvim', -- bridges mason and lspconfig
    'WhoIsSethDaniel/mason-tool-installer.nvim', -- auto-install tools
    { 'j-hui/fidget.nvim', opts = {} }, -- LSP progress notifications
    { 'saghen/blink.cmp' }, -- completion capabilities
  },
  config = function()
    -- Keymaps: set when LSP attaches to buffer
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
        map('<leader>ca', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })
        map('gD', vim.lsp.buf.declaration, 'Go to declaration')

        -- Helper: check if LSP client supports a method (handles 0.10 vs 0.11 API)
        local function client_supports_method(client, method, bufnr)
          if vim.fn.has 'nvim-0.11' == 1 then
            return client:supports_method(method, bufnr)
          else
            return client:supports_method(method, { bufnr = bufnr })
          end
        end

        -- Document Highlight: highlight other references to symbol under cursor
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- The following code creates a keymap to toggle inlay hints in your
        -- code, if the language server you are using supports them
        -- inlay hints
        -- This may be unwanted, since they displace some of your code
        -- if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
        --   map('<leader>th', function()
        --     vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
        --   end, '[T]oggle Inlay [H]ints')
        -- end
        -- toggle inlay hints off when entering insert and toggle on when leaving
        -- vim.api.nvim_create_autocmd('InsertEnter', {
        --   callback = function()
        --     vim.lsp.inlay_hint.enable(false)
        --   end,
        -- })
        --
        -- vim.api.nvim_create_autocmd('InsertLeave', {
        --   callback = function()
        --     vim.lsp.inlay_hint.enable(true)
        --   end,
        -- })
      end,
    })

    -- Diagnostics: how errors/warnings are displayed
    vim.diagnostic.config {
      severity_sort = true, -- show errors before warnings
      float = { border = 'rounded', source = 'if_many' }, -- floating window style
      underline = { severity = vim.diagnostic.severity.ERROR }, -- only underline errors
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {}, -- nerd font icons in sign column
      -- virtual_lines = {
      --   current_line = true,
      -- },
      --@type vim.diagnostic.Opts.VirtualText
      -- virtual_text = {
      --   enabled = false,
      --   source = 'if_many',
      --   spacing = 2,
      --   format = function(diagnostic)
      --     local diagnostic_message = {
      --       [vim.diagnostic.severity.ERROR] = diagnostic.message,
      --       [vim.diagnostic.severity.WARN] = diagnostic.message,
      --       [vim.diagnostic.severity.INFO] = diagnostic.message,
      --       [vim.diagnostic.severity.HINT] = diagnostic.message,
      --     }
      --     return diagnostic_message[diagnostic.severity]
      --   end,
      -- },
    }

    -- Capabilities: tell LSP servers what features neovim/blink.cmp support
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend(
      'force',
      capabilities,
      require('blink-cmp').get_lsp_capabilities({ textDocument = { completion = { completionItem = { snippetSupport = false } } } }, false)
    )

    -- Language Servers: each key is auto-installed by Mason
    -- Override settings per-server; see :help lspconfig-all for available servers
    local servers = {
      -- Go
      gopls = {
        settings = {
          gopls = {
            gofumpt = true,
            codelenses = {
              gc_details = false,
              generate = true,
              regenerate_cgo = true,
              run_govulncheck = true,
              test = true,
              tidy = true,
              upgrade_dependency = true,
              vendor = true,
            },
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
            analyses = {
              nilness = true,
              unusedparams = true,
              unusedwrite = true,
              useany = true,
            },
            usePlaceholders = true,
            completeUnimported = true,
            staticcheck = true,
            directoryFilters = { '-.git', '-.vscode', '-.idea', '-.vscode-test', '-node_modules' },
            semanticTokens = true,
          },
        },
      },

      -- Bash/Shell
      bashls = { filetypes = { 'sh', 'zsh' } },

      -- GraphQL
      graphql = {},

      -- TypeScript/JavaScript (vtsls = Vue TypeScript Language Server fork)
      vtsls = {
        filetypes = {
          'javascript',
          'javascriptreact',
          'javascript.jsx',
          'typescript',
          'typescriptreact',
          'typescript.tsx',
        },
        settings = {
          complete_function_calls = true,
          vtsls = {
            enableMoveToFileCodeAction = true,
            autoUseWorkspaceTsdk = true,
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
              },
            },
          },
          typescript = {
            tsserver = {
              maxTsServerMemory = 16384,
              -- log = 'terse',
            },
            updateImportsOnFileMove = { enabled = 'always' },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              parameterNames = { enabled = 'all' },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = true },
            },
          },
        },
      },

      -- ESLint (linting for JS/TS)
      eslint = {
        enable = true,
        format = { enable = true },
        packageManager = 'yarn',
        autoFixOnSave = true,
        codeActionsOnSave = { mode = 'all', rules = { '!debugger', '!no-only-tests/*' } },
        lintTask = { enable = true },
      },

      -- Ruby: Sorbet (type checker)
      sorbet = {
        cmd = { 'bundle', 'exec', 'srb', 'tc', '--lsp' },
        filetypes = { 'ruby' },
        capabilities = capabilities,
      },

      -- Ruby: Rubocop (linter/formatter)
      rubocop = {
        cmd = { 'bundle', 'exec', 'rubocop', '--lsp', '--no-server' },
        filetypes = { 'ruby' },
        capabilities = capabilities,
      },

      -- Python: basedpyright (type checker, pyright fork)
      basedpyright = {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = { typeCheckingMode = 'basic', inlayHints = { callArgumentNames = true } },
          },
        },
      },

      -- Python: Ruff (fast linter/formatter)
      ruff = {
        init_options = {
          settings = {
            lineLength = 88, -- black default (use 120 for more space)
            lint = {
              enable = true,
              -- Rules: https://docs.astral.sh/ruff/rules/
              select = {
                'E', -- pycodestyle errors
                'W', -- pycodestyle warnings
                'F', -- pyflakes
                'I', -- isort (import sorting)
                'B', -- flake8-bugbear
                'C4', -- flake8-comprehensions
                'UP', -- pyupgrade
                'SIM', -- flake8-simplify
                'TCH', -- type-checking imports
                'RUF', -- ruff-specific rules
              },
              ignore = {
                'E501', -- line too long (formatter handles this)
              },
            },
            format = {
              preview = true, -- enable preview style formatting
            },
            organizeImports = true,
          },
        },
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false -- basedpyright handles hover
        end,
      },

      -- Lua
      lua_ls = {
        settings = {
          Lua = {
            codeLens = {
              enable = true,
            },
            completion = {
              callSnippet = 'Replace',
            },
            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            diagnostics = { disable = { 'missing-fields' } },
            hint = {
              enable = true,
              setType = false,
              paramType = true,
              paramName = 'Enable',
              semicolon = 'Enable',
              arrayIndex = 'Enable',
            },
          },
        },
      },
    }

    -- Mason: auto-install servers and tools (run :Mason to manage)
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, { 'stylua' }) -- add non-LSP tools
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- Mason-lspconfig: auto-enable installed LSPs
    require('mason-lspconfig').setup {
      automatic_enable = true,
      automatic_installation = true,
      ensure_installed = {}, -- mason-tool-installer handles this
    }

    -- Apply server configs from the servers table
    for server_name, config in pairs(servers) do
      vim.lsp.config(server_name, config)
    end
  end,
}
