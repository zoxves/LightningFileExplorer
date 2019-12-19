LiFE = {
    entries = {},
    path = {},
    branch_line = '|- ',
    trunk_line = '|  ',
    filetype = 'LightningFileExplorer',
    
    clean = function()
        local buf_list = vim.api.nvim_list_bufs
        for buf,_ in pairs(LiFE.entries) do
            if not(vim.api.nvim_buf_is_loaded(buf)) or not(vim.api.nvim_buf_is_valid(buf)) or
            vim.api.nvim_buf_get_option(buf, 'filetype') ~= LiFE.filetype then
                table.remove(LiFE.entries, buf)
                table.remove(LiFE.path, buf)
            end
        end
    end,

    get_list_lines_offset = function(buf)
        return 2
    end,

    --TODO
    get_header = function(buf)
        return {
            LiFE.path[buf], 
            "../",
        }
    end,

    open = function(path)
        if path == '' then
            path = '.'
        end
        path = vim.loop.fs_realpath(path)
        path = string.gsub(path, '\\', '/')
        local dir = vim.loop.fs_opendir(path)
        if dir == nil then
            print('LiFE: incorrect path: ' .. path)
        else
            vim.loop.fs_closedir(dir)
        end

        if string.sub(path, -1) ~= '/' then
            path = path .. '/'
        end

        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'delete')
        vim.api.nvim_buf_set_option(buf, 'buflisted', false)
        vim.api.nvim_buf_set_option(buf, 'filetype', LiFE.filetype)
        
        LiFE.entries[buf] = {}
        LiFE.path[buf] = path
        
        LiFE.render_header(buf)
        LiFE.scan(buf, path, LiFE.entries[buf], 1, 0)

        vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua LiFE.click()<CR>', {['noremap']= true, ['silent']= true})
        vim.api.nvim_buf_set_keymap(buf, 'n', 'R', ':lua LiFE.render(vim.api.nvim_get_current_buf())<CR>', {['noremap']= true, ['silent']= true})
        --vim.api.nvim_buf_set_option(buf, 'ro', true)
    end,

    render_header = function(buf)
        local offset = LiFE.get_list_lines_offset(buf)
        vim.api.nvim_buf_set_lines(buf, 0, offset, false, LiFE.get_header(buf))
        vim.api.nvim_buf_add_highlight(buf, -1, "Directory", offset - 1, 0, 2)
    end,

    highlight = function(position, entry)
        if entry.type == 'directory' then
            local line_end = string.len(vim.api.nvim_buf_get_lines(buf, position, position + 1, false)[1])
            vim.api.nvim_buf_add_highlight(buf, -1, "Directory", position, line_end - string.len(entry.name) - 1, line_end - 1)
        end
    end,

    insert_line = function(buf, entries, position, entry)
        table.insert(entries, position, entry)
        local line = entry.name
        local prefix = ''
        for i=1,entry.level - 1,1 do
            prefix = prefix .. LiFE.trunk_line
        end
        if entry.level ~= 0 then prefix = prefix .. LiFE.branch_line end
        line = prefix .. line
        if entry.type == 'directory' then
            line = line .. '/'
        end
        local offset_position = LiFE.get_list_lines_offset(buf) + position - 1
        vim.api.nvim_buf_set_lines(buf, offset_position, offset_position, false, {line})
        LiFE.highlight(offset_position, entry)
    end,

    remove_line = function(buf, entries, position)
        table.remove(entries, position)
        local offset_position = LiFE.get_list_lines_offset(buf) + position - 1
        vim.api.nvim_buf_set_lines(buf, offset_position, offset_position + 1, false, {})
    end,

    level_up_line = function(buf, position, entry)
        entry.level = entry.level + 1
        local offset_position = LiFE.get_list_lines_offset(buf) + position - 1
        local line = vim.api.nvim_buf_get_lines(buf, offset_position, offset_position + 1, false)[1]
        if entry.level == 1 then
            line = LiFE.branch_line .. line
        else
            line = LiFE.trunk_line .. line
        end
        vim.api.nvim_buf_set_lines(buf, offset_position, offset_position + 1, false, {line})
        LiFE.highlight(offset_position, entry)
    end,

    
    scan = function(buf, path, entries, position, level)
        local count = 0
        local dir_count = 0
        local dir = vim.loop.fs_opendir(path)
        while true do
            local raw_entry = vim.loop.fs_readdir(dir)
            if raw_entry == nil then
                break
            else
                local entry = raw_entry[1]
                entry.path = path..entry.name
                entry.level = level
                local curr_position = position + count
                if entry.type == 'directory' then
                    entry.path = entry.path .. '/'
                    curr_position = position + dir_count
                    dir_count = dir_count + 1
                end
                LiFE.insert_line(buf, entries, curr_position, entry)
                count = count + 1
            end
        end
        vim.loop.fs_closedir(dir)
        return count
    end,

    expand = function(buf, entries, line)
        local root_entry = entries[line]
        local count = LiFE.scan(buf, root_entry.path, entries, line + 1, root_entry.level + 1)
        root_entry.expanded = true;
    end,
    
    collapse = function(buf, entries, line)
        local root_entry = entries[line]
        local root_level = root_entry.level
        local curr_line = line + 1
        while true do
            if entries[curr_line] ~= nil and entries[curr_line].level > root_level then
                LiFE.remove_line(buf, entries, curr_line)
            else break end
        end
        root_entry.expanded = false
    end,

    above = function(buf, old_path, entries)
        local sub_path_index = string.find(old_path, "/[^/]*/$")
        local path = string.sub(old_path, 0, sub_path_index)
        local old_name = string.sub(old_path, sub_path_index + 1, string.len(old_path) - 1)
        local dir = vim.loop.fs_opendir(path)
        if dir == nil then return end
        local old_count = 1
        while true do
            local old_entry = entries[old_count]
            if old_entry == nil then break end
            local curr_old_position = old_count
            LiFE.level_up_line(buf, curr_old_position, old_entry)
            old_count = old_count + 1
        end        
        local count = 1
        local dir_count = 1
        while true do
            local raw_entry = vim.loop.fs_readdir(dir)
            if raw_entry == nil then
                break
            else
                local entry = raw_entry[1]
                entry.path = path..entry.name
                entry.level = 0
                if entry.type == "directory" then
                    entry.path = entry.path .. '/'
                    
                    LiFE.insert_line(buf, entries, dir_count, entry)
                    
                    if entry.name == old_name then
                        entry.expanded = true
                        --count = count + old_count - 1
                        dir_count = dir_count + old_count - 1
                    end
                    dir_count = dir_count + 1
                else
                    LiFE.insert_line(buf, entries, count + old_count - 1, entry)
                end
                count = count + 1
            end
        end
        vim.loop.fs_closedir(dir)
        LiFE.path[buf] = path
        LiFE.render_header(buf)
    end,
    
    click = function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = vim.api.nvim_win_get_cursor(0)[1] - LiFE.get_list_lines_offset()
        local buf = vim.api.nvim_get_current_buf()
        local line_entry = LiFE.entries[buf][line]
        if line == 0 then
            LiFE.above(buf, LiFE.path[buf], LiFE.entries[buf])
            return
        end
        if line_entry.type == "directory" then
            if line_entry.expanded then
                LiFE.collapse(buf, LiFE.entries[buf], line)
            else
                LiFE.expand(buf, LiFE.entries[buf], line)
            end
            vim.api.nvim_win_set_cursor(0, cursor)
        else
            LiFE.click_on_file(line_entry)
        end
    end,

    click_on_file = function(entry)
        vim.api.nvim_command('edit ' .. entry.path)
    end,

}
