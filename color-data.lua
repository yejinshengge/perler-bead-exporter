-- 颜色数据公共模块
-- 用于在多个脚本之间共享颜色名称数据

-- 全局颜色名称存储
if ShowColorName == nil then
    ShowColorName = {}
end

ShowColorName.colorNames = ShowColorName.colorNames or {}

-- 辅助函数：去除字符串首尾空格
local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 解析GPL文件
function ShowColorName.parseGPLFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return {}
    end
    
    local names = {}
    local lineNum = 0
    
    for line in file:lines() do
        lineNum = lineNum + 1
        
        -- 跳过头部和注释
        if lineNum > 3 and not line:match("^#") and trim(line) ~= "" then
            -- GPL格式: R G B ColorName
            local r, g, b, name = line:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s+(.+)$")
            if r and g and b and name then
                r = tonumber(r)
                g = tonumber(g)
                b = tonumber(b)
                name = trim(name)
                
                -- 创建颜色键
                local colorKey = string.format("%d_%d_%d", r, g, b)
                names[colorKey] = name
            end
        end
    end
    
    file:close()
    return names
end

-- 获取当前调色板对应的GPL文件路径
function ShowColorName.getGPLFilePath()
    local sprite = app.activeSprite
    if not sprite then
        return nil
    end
    
    -- 尝试查找同名的.gpl文件
    local spritePath = sprite.filename
    if spritePath == "" then
        return nil
    end
    
    -- 替换扩展名为.gpl
    local gplPath = spritePath:gsub("%.[^%.]+$", ".gpl")
    
    -- 检查文件是否存在
    local file = io.open(gplPath, "r")
    if file then
        file:close()
        return gplPath
    end
    
    -- 尝试在同目录查找palette.gpl
    local dir = spritePath:match("(.*/)")
    if dir then
        gplPath = dir .. "palette.gpl"
        file = io.open(gplPath, "r")
        if file then
            file:close()
            return gplPath
        end
    end
    
    return nil
end

-- 加载GPL文件到全局颜色数据
function ShowColorName.loadGPLFile(gplPath)
    ShowColorName.colorNames = ShowColorName.parseGPLFile(gplPath)
    local count = 0
    for _ in pairs(ShowColorName.colorNames) do count = count + 1 end
    return count
end

-- 获取颜色名称
function ShowColorName.getColorName(r, g, b)
    -- 确保参数都是整数
    r = math.floor(tonumber(r) or 0)
    g = math.floor(tonumber(g) or 0)
    b = math.floor(tonumber(b) or 0)
    local colorKey = string.format("%d_%d_%d", r, g, b)
    return ShowColorName.colorNames[colorKey]
end

-- 从Color对象获取颜色名称
function ShowColorName.getColorNameFromColor(color)
    if not color then
        return nil
    end
    
    -- 确保RGB值是整数
    local r = math.floor(tonumber(color.red) or 0)
    local g = math.floor(tonumber(color.green) or 0)
    local b = math.floor(tonumber(color.blue) or 0)
    
    return ShowColorName.getColorName(r, g, b)
end

-- 获取已加载的颜色数量
function ShowColorName.getLoadedColorCount()
    local count = 0
    for _ in pairs(ShowColorName.colorNames) do count = count + 1 end
    return count
end

-- 清空颜色数据
function ShowColorName.clearColorData()
    ShowColorName.colorNames = {}
end

