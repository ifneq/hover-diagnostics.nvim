local M = {}

-- Time delay before showing hover diagnostics (in milliseconds)
local debounce_time = 1000 -- Change this to your desired delay (1000ms = 1 second)
local debounce_timer = nil
local last_diagnostics_list = "" -- Store the last formatted diagnostic messages

-- Severity mappings
local severity_map = {
    [vim.diagnostic.severity.ERROR] = "err",
    [vim.diagnostic.severity.WARN] = "warn",
    [vim.diagnostic.severity.INFO] = "info",
    [vim.diagnostic.severity.HINT] = "hint",
}

function M.setup()
    -- Disable virtual text and configure diagnostics
    vim.diagnostic.config({
        underline = true,        -- Keep underlines for errors
        virtual_text = false,    -- Ensure inline virtual text is disabled
        signs = true,            -- Show signs in the gutter
        update_in_insert = false, -- Prevent updates while typing
        severity_sort = true,     -- Sort diagnostics by severity
        float = {
            border = "rounded",  -- Rounded border for floating window
            source = "always",   -- Show source of diagnostics
        },
    })

    -- Ensure LSPs respect this setting
    vim.lsp.handlers["textDocument/publishDiagnostics"] = function(_, result, ctx, config)
        config = config or {}
        config.virtual_text = false -- Enforce disabling virtual text
        vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
    end

    -- Set a global keybinding for <Leader>y to copy the last diagnostics list
    vim.keymap.set("n", "<Leader>yy", function()
        if last_diagnostics_list ~= "" then
            vim.fn.setreg("+", last_diagnostics_list) -- Copy to system clipboard
            print("Diagnostics copied to clipboard!")
        else
            print("No diagnostics available.")
        end
    end, { silent = true, desc = "copy diagnostic" })

    vim.keymap.set("n", "<Leader>ya", function()
        local all_diagnostics = vim.diagnostic.get(0) -- Get all diagnostics in the current buffer
        if #all_diagnostics > 0 then
            local formatted_messages = {}
            for _, diag in ipairs(all_diagnostics) do
                local severity = severity_map[diag.severity] or "Unknown"
                local source = diag.source and (diag.source .. ": ") or "" -- Include source if available
                local lnum = diag.lnum + 1 -- Convert 0-based line number to 1-based
                table.insert(formatted_messages, string.format("[%s] %s%s (Line %d)", severity, source, diag.message, lnum))
            end
            last_file_diagnostics_list = table.concat(formatted_messages, "\n")
            vim.fn.setreg("+", last_file_diagnostics_list) -- Copy to system clipboard
            print("All file diagnostics copied to clipboard!")
        else
            print("No diagnostics found in file.")
        end
    end, { silent = true, desc = "copy all diagnostics" })


    -- Show floating diagnostics with debounce
    vim.api.nvim_create_autocmd("CursorHold", {
        pattern = "*",
        callback = function()
            -- Cancel the previous timer if it exists
            if debounce_timer then
                debounce_timer:stop()
            end

            -- Start a new timer
            debounce_timer = vim.defer_fn(function()
                -- Get diagnostics under the cursor
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                local diagnostics = vim.diagnostic.get(0, { lnum = line - 1 })

                if #diagnostics > 0 then
                    -- Format diagnostics as a list
                    local formatted_messages = {}
                    for _, diag in ipairs(diagnostics) do
                        local severity = severity_map[diag.severity] or "Unknown"
                        local source = diag.source and (diag.source .. ": ") or "" -- Include source if available
                        table.insert(formatted_messages, string.format("[%s] %s%s", severity, source, diag.message))
                    end
                    last_diagnostics_list = table.concat(formatted_messages, "\n") -- Store list as new lines

                    -- Open floating window with diagnostic
                    vim.diagnostic.open_float(nil, {
                        focusable = true,
                        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
                        border = "rounded",
                        source = "always",
                        prefix = " ",
                    })
                end
            end, debounce_time)
        end
    })
end

return M