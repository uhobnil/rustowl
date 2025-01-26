local lspconfig = require('lspconfig')
local util = require('lspconfig.util')
local configs = require('lspconfig.configs')

local hlns = vim.api.nvim_create_namespace('rustowl')
vim.api.nvim_set_hl(0, 'lifetime', { undercurl = true, sp = '#00cc00' })
vim.api.nvim_set_hl(0, 'imm_borrow', { undercurl = true, sp = '#0000cc' })
vim.api.nvim_set_hl(0, 'mut_borrow', { undercurl = true, sp = '#cc00cc' })
vim.api.nvim_set_hl(0, 'move', { undercurl = true, sp = '#cccc00' })
vim.api.nvim_set_hl(0, 'call', { undercurl = true, sp = '#cccc00' })
vim.api.nvim_set_hl(0, 'outlive', { undercurl = true, sp = '#cc0000' })

local function show_rustowl(bufnr)
    bufnr = util.validate_bufnr(bufnr)
    local clients = util.get_lsp_clients { bufnr = bufnr, name = 'rustowlsp' }
    for _, client in ipairs(clients) do
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        client.request(
            'rustowl/cursor',
            {
                position = {
                    line = line - 1,
                    character = col,
                },
                document = vim.lsp.util.make_text_document_params(),
            },
            function(err, result, ctx)
                if result ~= nil then
                    for _, deco in ipairs(result['decorations']) do
                        local start = { deco['range']['start']['line'], deco['range']['start']['character'] }
                        local finish = { deco['range']['end']['line'], deco['range']['end']['character'] }
                        vim.highlight.range(
                            bufnr,
                            hlns,
                            deco['type'],
                            start,
                            finish,
                            { regtype = "v", inclusive = true }
                        )
                    end
                end
            end,
            bufnr
        )
    end
end

local function rustowl_on_attach(client, bufnr)
    local augroup = vim.api.nvim_create_augroup('RustOwlCmd', { clear = true })

    vim.api.nvim_create_autocmd(
        { 'CursorHold', 'CursorHoldI' },
        {
            group = augroup,
            buffer = bufnr,
            callback = function()
                show_rustowl(bufnr)
            end
        }
    )

    vim.api.nvim_create_autocmd(
        'CursorMoved',
        {
            group = augroup,
            buffer = bufnr,
            callback = function()
                vim.api.nvim_buf_clear_namespace(bufnr, hlns, 0, -1)
            end
        }
    )
end

if not configs.rustowlsp then
    configs.rustowlsp = {
        default_config = {
            cmd = { 'cargo', 'owlsp' },
            root_dir = lspconfig.util.root_pattern('Cargo.toml', '.git')(fname),
            filetypes = { 'rust' },
            on_attach = function(client, bufnr)
            end,
        },
    }
end

local orig_setup = lspconfig.rustowlsp.setup
lspconfig.rustowlsp.setup = function(user_opts)
    user_opts = user_opts or {}
    local user = user_opts.on_attach
    user_opts.on_attach = function(client, bufnr)
        rustowl_on_attach(client, bufnr)

        if type(user) == 'function' then
            user(client, bufnr)
        end
    end
    orig_setup(user_opts)
end
