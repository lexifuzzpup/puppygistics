---@param filename string path to the file to read
return function(filename)
    local file = fs.open(filename, "r")
    local success, contents, read_error = pcall(file.readAll)
    file.close()

    if not success then
        error(read_error)
    else
        return textutils.unserializeJSON(contents)
    end
end