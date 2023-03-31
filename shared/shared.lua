function CapitalFirstLetter(str)
    if not str then return nil end
    return (str):gsub("^%l", string.upper)
end

function TrimString(str)
    if not str then return "" end
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end