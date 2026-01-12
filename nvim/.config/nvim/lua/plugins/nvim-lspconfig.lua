return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    -- Mason must be loaded before its dependents so we need to set it up here.
    -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
    { 'williamboman/mason.nvim', opts = {} },
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },
    { 'saghen/blink.cmp' },
  },
  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
      callback = function(event)
        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        --  Most Language Servers support renaming across files, etc.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
        ---@param client vim.lsp.Client
        ---@param method vim.lsp.protocol.Method
        ---@param bufnr? integer some lsp support methods only in specific files
        ---@return boolean
        local function client_supports_method(client, method, bufnr)
          if vim.fn.has 'nvim-0.11' == 1 then
            return client:supports_method(method, bufnr)
          else
            return client:supports_method(method, { bufnr = bufnr })
          end
        end

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
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

    -- Diagnostic Config
    -- See :help vim.diagnostic.Opts
    vim.diagnostic.config {
      severity_sort = true,
      float = { border = 'rounded', source = 'if_many' },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = vim.g.have_nerd_font and {
        text = {
          [vim.diagnostic.severity.ERROR] = '󰅚 ',
          [vim.diagnostic.severity.WARN] = '󰀪 ',
          [vim.diagnostic.severity.INFO] = '󰋽 ',
          [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
      } or {},
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

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend(
      'force',
      capabilities,
      require('blink-cmp').get_lsp_capabilities({ textDocument = { completion = { completionItem = { snippetSupport = false } } } }, false)
    )

    -- Enable the following language servers
    --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
    --
    --  Add any additional override configuration in the following tables. Available keys are:
    --  - cmd (table): Override the default command used to start the server
    --  - filetypes (table): Override the default list of associated filetypes for the server
    --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    --  - settings (table): Override the default settings passed when initializing the server.
    --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
    local servers = {
      -- clangd = {},
      -- pyright = {},
      -- rust_analyzer = {},
      -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
      --
      -- Some languages (like typescript) have entire language plugins that can be useful:
      --    https://github.com/pmizio/typescript-tools.nvim
      --
      -- But for many setups, the LSP (`ts_ls`) will work just fine
      -- ts_ls = {},
      --
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

      bashls = {
        filetypes = { 'sh', 'zsh' },
      },

      graphql = {},

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

      eslint = {
        enable = true,
        format = { enable = true }, -- this will enable formatting
        packageManager = 'yarn',
        autoFixOnSave = true,
        codeActionsOnSave = {
          mode = 'all',
          rules = { '!debugger', '!no-only-tests/*' },
        },
        lintTask = {
          enable = true,
        },
      },

      sorbet = {
        cmd = { 'bundle', 'exec', 'srb', 'tc', '--lsp' },
        filetypes = { 'ruby' },
        --root_dir = lspconfig.util.root_pattern('Gemfile', '.git'),
        capabilities = capabilities,
      },

      rubocop = {
        cmd = { 'bundle', 'exec', 'rubocop', '--lsp', '--no-server' },
        filetypes = { 'ruby' },
        --root_dir = lspconfig.util.root_pattern('Gemfile', '.git'),
        capabilities = capabilities,
      },

      basedpyright = {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = 'basic',
              inlayHints = {
                callArgumentNames = true,
              },
            },
          },
        },
      },

      ruff = {
        settings = {},
      },

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

    -- Ensure the servers and tools above are installed
    --
    -- To check the current status of installed tools and/or manually install
    -- other tools, you can run
    --    :Mason
    --
    -- You can press `g?` for help in this menu.
    --
    -- `mason` had to be setup earlier: to configure its options see the
    -- `dependencies` table for `nvim-lspconfig` above.
    --
    -- You can add other tools here that you want Mason to install
    -- for you, so that they are available from within Neovim.
    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua', -- Used to format Lua code
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    --@type MasonLspconfigSettings
    require('mason-lspconfig').setup {
      dependencies = {
        'neovim/nvim-lspconfig',
        'mason-org/mason.nvim',
      },
      automatic_enable = true,
      ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
      automatic_installation = true,
      --handlers = {
      -- function(server_name)
      -- local server = servers[server_name] or {}
      -- This handles overriding only values explicitly passed
      -- by the server configuration above. Useful when disabling
      -- certain features of an LSP (for example, turning off formatting for ts_ls)
      -- server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
      -- require('lspconfig')[server_name].setup(server)
      --end,
      -- },
    }
    -- Installed LSPs are configured and enabled automatically with mason-lspconfig
    -- The loop below is for overriding the default configuration of LSPs with the ones in the servers table
    for server_name, config in pairs(servers) do
      vim.lsp.config(server_name, config)
    end
  end,
}
