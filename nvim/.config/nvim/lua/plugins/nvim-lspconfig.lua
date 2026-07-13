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
        -- gd, gD, gr, gI handled by snacks picker (see snacks.lua)

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

        -- Inlay hints: enable by default, hide in insert mode to avoid text shifting
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
          vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
          end, '[T]oggle Inlay [H]ints')
        end

        vim.api.nvim_create_autocmd('InsertEnter', {
          buffer = event.buf,
          callback = function()
            vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
          end,
        })
        vim.api.nvim_create_autocmd('InsertLeave', {
          buffer = event.buf,
          callback = function()
            vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
          end,
        })
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
      virtual_lines = { current_line = true },
      virtual_text = false,
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

      -- GraphQL — reads graphql.config.js for schema + documents (fragment resolution)
      graphql = {
        filetypes = { 'graphql' },
        root_markers = { 'graphql.config.js', 'graphql.config.ts', '.graphqlrc.yml', '.graphqlrc.json', '.graphqlrc' },
      },

      -- TypeScript/JavaScript (vtsls = fast TS server, alternative to ts_ls)
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
        settings = {
          packageManager = 'yarn',
          codeActionOnSave = { enable = true, mode = 'all' },
          -- formatting disabled - conform handles it with prettier
        },
      },

      -- Ruby: ruby-lsp (Shopify) — go-to-def, symbols, diagnostics for all Ruby files
      -- Uses its own .ruby-lsp/Gemfile (eval_gemfile's the project Gemfile + adds ruby-lsp).
      -- Must NOT use `bundle exec` — ruby-lsp bootstraps its own composed bundle.
      ruby_lsp = {
        cmd = { 'ruby-lsp' },
        filetypes = { 'ruby' },
        root_markers = { 'Gemfile', '.ruby-lsp' },
        capabilities = capabilities,
        init_options = {
          enabledFeatures = {
            definition = true,
            references = true,
            documentSymbols = true,
            workspaceSymbol = true,
            codeActions = true,
            diagnostics = true,
            hover = true,
            completion = false, -- sorbet handles this
          },
        },
      },

      -- Ruby: Sorbet (type checker) — only in projects with sorbet/config
      sorbet = {
        cmd = {
          'bundle',
          'exec',
          'srb',
          'tc',
          '--lsp',
        },
        filetypes = { 'ruby' },
        root_markers = { 'sorbet', 'Gemfile' },
        capabilities = capabilities,
      },

      -- Ruby: Rubocop (linter/formatter) — only in projects with .rubocop.yml
      rubocop = {
        cmd = { 'bundle', 'exec', 'rubocop', '--lsp' },
        filetypes = { 'ruby' },
        root_markers = { '.rubocop.yml', 'Gemfile' },
        capabilities = capabilities,
        init_options = {
          safeAutocorrect = true,
        },
        on_attach = function(client)
          client.server_capabilities.hoverProvider = false -- sorbet handles hover
        end,
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

    -- Servers managed via bundle exec (not Mason-installable)
    local bundle_servers = { 'ruby_lsp', 'sorbet', 'rubocop' } -- ruby_lsp self-bootstraps but still needs manual enable

    -- Mason: auto-install servers and tools (run :Mason to manage)
    local ensure_installed = vim.tbl_filter(function(name)
      return not vim.tbl_contains(bundle_servers, name)
    end, vim.tbl_keys(servers or {}))
    vim.list_extend(ensure_installed, { 'stylua' }) -- add non-LSP tools
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    -- Mason-lspconfig: auto-enable installed LSPs
    -- Don't auto-install/enable Ruby servers — they run via bundle exec
    require('mason-lspconfig').setup {
      automatic_enable = {
        exclude = { 'ruby_lsp', 'sorbet', 'rubocop' },
      },
      automatic_installation = {
        exclude = { 'ruby_lsp', 'sorbet', 'rubocop' },
      },
      ensure_installed = {},
    }

    -- Apply capabilities globally so all servers get blink.cmp enhancements
    vim.lsp.config('*', { capabilities = capabilities })

    -- Apply server configs from the servers table
    for server_name, config in pairs(servers) do
      vim.lsp.config(server_name, config)
    end

    -- Manually enable bundle-managed servers (Mason can't install these)
    vim.lsp.enable(bundle_servers)

    -- Restart sorbet on git branch change. Sorbet LSP indexes files once at startup
    -- and does not re-scan after `git switch`, producing -32602 "Unrecognized URI"
    -- errors for files added on the new branch. Watch .git/HEAD and auto-restart.
    do
      local last_head = nil
      local function current_head()
        local f = io.open((vim.fn.getcwd() or '.') .. '/.git/HEAD', 'r')
        if not f then return nil end
        local head = f:read('*l')
        f:close()
        return head
      end
      last_head = current_head()
      vim.api.nvim_create_autocmd({ 'FocusGained', 'DirChanged' }, {
        callback = function()
          local head = current_head()
          if head and last_head and head ~= last_head then
            vim.cmd('LspRestart sorbet')
          end
          last_head = head
        end,
      })
      vim.api.nvim_create_user_command('SorbetRestart', function()
        vim.cmd('LspRestart sorbet')
      end, {})
    end
  end,
}
