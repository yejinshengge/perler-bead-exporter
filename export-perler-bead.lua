-- 导出拼豆图纸插件（HTML版本）
-- 将像素画导出为带网格和颜色标注的HTML图纸

-- 确保全局模块已初始化
if ShowColorName == nil then
    ShowColorName = {}
end
if ShowColorName.colorNames == nil then
    ShowColorName.colorNames = {}
end

-- 如果函数未定义，尝试手动加载color-data.lua
if not ShowColorName.getColorName then
    -- 尝试查找并加载color-data.lua
    local scriptPath = debug.getinfo(1, "S").source:sub(2)
    local scriptDir = scriptPath:match("(.*/)")
    if scriptDir then
        local colorDataPath = scriptDir .. "color-data.lua"
        local success, err = pcall(function()
            dofile(colorDataPath)
        end)
        if not success then
            print("警告: 无法加载color-data.lua: " .. tostring(err))
        end
    end
end

-- 前向声明（在调用前必须先声明）
local performExport

-- 统计颜色使用次数
local function countColors(sprite)
    -- 确保 getColorName 函数存在
    local getColorName = ShowColorName.getColorName or function(r, g, b) return nil end
    
    local colorCount = {}
    local layer = sprite.layers[1]
    
    for _, cel in ipairs(sprite.cels) do
        if cel.layer == layer or not layer then
            local image = cel.image
            for pixel in image:pixels() do
                local pixelValue = pixel()
                if pixelValue ~= 0 or not sprite.spec.transparentColor then
                    local r, g, b
                    
                    if sprite.colorMode == ColorMode.RGB then
                        r = app.pixelColor.rgbaR(pixelValue)
                        g = app.pixelColor.rgbaG(pixelValue)
                        b = app.pixelColor.rgbaB(pixelValue)
                    elseif sprite.colorMode == ColorMode.INDEXED then
                        local paletteColor = sprite.palettes[1]:getColor(pixelValue)
                        -- Color对象的属性已经是数字，直接使用
                        r = paletteColor.red
                        g = paletteColor.green
                        b = paletteColor.blue
                    else
                        r = app.pixelColor.rgbaR(pixelValue)
                        g = app.pixelColor.rgbaG(pixelValue)
                        b = app.pixelColor.rgbaB(pixelValue)
                    end
                    
                    local colorKey = string.format("%d_%d_%d", r, g, b)
                    
                    if not colorCount[colorKey] then
                        colorCount[colorKey] = {
                            r = r,
                            g = g,
                            b = b,
                            count = 0,
                            name = getColorName(r, g, b) or "未命名"
                        }
                    end
                    
                    colorCount[colorKey].count = colorCount[colorKey].count + 1
                end
            end
        end
    end
    
    return colorCount
end

-- 将颜色计数转换为排序列表
local function getSortedColorList(colorCount)
    local colorList = {}
    for colorKey, data in pairs(colorCount) do
        table.insert(colorList, data)
    end
    
    -- 按使用次数排序
    table.sort(colorList, function(a, b)
        return a.count > b.count
    end)
    
    return colorList
end

-- 计算亮度（用于确定文字颜色）
local function getBrightness(r, g, b)
    return (r * 299 + g * 587 + b * 114) / 1000
end

-- RGB转十六进制
local function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- 导出拼豆图纸
local function exportPerlerBead()
    local sprite = app.activeSprite
    if not sprite then
        app.alert("请先打开一个文件")
        return
    end
    
    -- 统计已加载的颜色数量
    local colorCount = 0
    if ShowColorName.getLoadedColorCount then
        colorCount = ShowColorName.getLoadedColorCount()
    end
    
    -- 设置对话框
    local dlg = Dialog("导出拼豆图纸（HTML）")
    
    if colorCount > 0 then
        dlg:label{
            id="color_info",
            text=string.format("✓ 已加载 %d 个颜色名称", colorCount)
        }
        dlg:separator()
    else
        dlg:label{
            id="color_warning",
            text="⚠ 未加载颜色名称（将显示为\"未命名\"）"
        }
        dlg:separator()
    end
    
    dlg:number{
        id="cell_size",
        label="网格大小（像素）:",
        text="40",
        decimals=0
    }
    
    dlg:check{
        id="show_color_name",
        label="显示颜色名称",
        selected=true
    }
    
    dlg:check{
        id="show_color_code",
        label="显示颜色代码",
        selected=true
    }
    
    dlg:check{
        id="show_coordinates",
        label="显示坐标",
        selected=true
    }
    
    dlg:number{
        id="font_size",
        label="字体大小:",
        text="10",
        decimals=0
    }
    
    dlg:file{
        id="save_path",
        label="保存路径:",
        save=true,
        filename="perler-bead.html",
        filetypes={"html"}
    }
    
    dlg:button{
        id="ok",
        text="导出",
        onclick=function()
            local data = dlg.data
            dlg:close()
            
            -- 执行导出
            performExport(sprite, data)
        end
    }
    
    dlg:button{
        id="cancel",
        text="取消"
    }
    
    dlg:show()
end

-- 执行导出
performExport = function(sprite, options)
    -- 确保 getColorName 函数存在
    local getColorName = ShowColorName.getColorName or function(r, g, b) return nil end
    
    local cellSize = options.cell_size or 40
    local showColorName = options.show_color_name
    local showColorCode = options.show_color_code
    local showCoordinates = options.show_coordinates
    local fontSize = options.font_size or 10
    local savePath = options.save_path
    
    if not savePath or savePath == "" then
        app.alert("请选择保存路径")
        return
    end
    
    -- 统计颜色
    local colorCount = countColors(sprite)
    local colorList = getSortedColorList(colorCount)
    
    -- 计算总像素数
    local totalPixels = 0
    for _, item in ipairs(colorList) do
        totalPixels = totalPixels + item.count
    end
    
    -- 获取原始图像
    local cel = sprite.cels[1]
    if not cel then
        app.alert("找不到图层内容")
        return
    end
    
    local sourceImage = cel.image
    local celX = cel.position.x
    local celY = cel.position.y
    local spriteWidth = sprite.width
    local spriteHeight = sprite.height
    
    -- 生成HTML
    local html = [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>拼豆图纸</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            display: inline-block;
        }
        h1 {
            margin-top: 0;
            color: #333;
        }
        .grid-container {
            margin: 20px 0;
            overflow-x: auto;
        }
        table.pixel-grid {
            border-collapse: collapse;
            margin: 0 auto;
        }
        table.pixel-grid td {
            border: 1px solid #999;
            text-align: center;
            vertical-align: middle;
            padding: 2px;
            font-size: ]] .. fontSize .. [[px;
            width: ]] .. cellSize .. [[px;
            height: ]] .. cellSize .. [[px;
            position: relative;
        }
        table.pixel-grid td.empty {
            background-color: #fff;
            background-image: 
                linear-gradient(45deg, #eee 25%, transparent 25%),
                linear-gradient(-45deg, #eee 25%, transparent 25%),
                linear-gradient(45deg, transparent 75%, #eee 75%),
                linear-gradient(-45deg, transparent 75%, #eee 75%);
            background-size: 10px 10px;
            background-position: 0 0, 0 5px, 5px -5px, -5px 0px;
        }
        table.pixel-grid th {
            background-color: #f0f0f0;
            border: 1px solid #999;
            padding: 5px;
            font-size: ]] .. (fontSize - 1) .. [[px;
            font-weight: bold;
        }
        .color-name {
            display: block;
            font-weight: bold;
            text-shadow: 0 0 3px rgba(255,255,255,0.8);
        }
        .color-code {
            display: block;
            font-size: ]] .. (fontSize - 2) .. [[px;
            text-shadow: 0 0 3px rgba(255,255,255,0.8);
        }
        .stats {
            margin-top: 30px;
        }
        table.stats-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        table.stats-table th,
        table.stats-table td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        table.stats-table th {
            background-color: #f0f0f0;
            font-weight: bold;
        }
        .color-swatch {
            display: inline-block;
            width: 30px;
            height: 20px;
            border: 1px solid #999;
            vertical-align: middle;
            margin-right: 10px;
        }
        .summary {
            background-color: #e8f4f8;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary h2 {
            margin-top: 0;
            color: #0066cc;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>拼豆图纸</h1>
        
        <div class="summary">
            <h2>摘要信息</h2>
            <p><strong>尺寸:</strong> ]] .. spriteWidth .. [[ × ]] .. spriteHeight .. [[ 像素</p>
            <p><strong>总像素数:</strong> ]] .. totalPixels .. [[</p>
            <p><strong>颜色种类:</strong> ]] .. #colorList .. [[</p>
        </div>
        
        <div class="grid-container">
            <table class="pixel-grid">
]]
    
    -- 添加坐标行
    if showCoordinates then
        html = html .. "                <tr>\n"
        html = html .. "                    <th></th>\n"
        for x = 0, spriteWidth - 1 do
            html = html .. "                    <th>" .. x .. "</th>\n"
        end
        html = html .. "                </tr>\n"
    end
    
    -- 生成网格
    for y = 0, spriteHeight - 1 do
        html = html .. "                <tr>\n"
        
        -- 添加行坐标
        if showCoordinates then
            html = html .. "                    <th>" .. y .. "</th>\n"
        end
        
        for x = 0, spriteWidth - 1 do
            -- 计算相对于cel的坐标
            local celLocalX = x - celX
            local celLocalY = y - celY
            
            -- 检查是否在cel范围内
            local isInCel = celLocalX >= 0 and celLocalX < sourceImage.width and
                           celLocalY >= 0 and celLocalY < sourceImage.height
            
            if not isInCel then
                -- 超出cel范围，显示为空
                html = html .. '                    <td class="empty"></td>\n'
            else
                local pixelValue = sourceImage:getPixel(celLocalX, celLocalY)
                
                -- 检查透明像素
                local isTransparent = false
                if sprite.colorMode == ColorMode.RGB then
                    -- RGB模式：检查alpha通道
                    local alpha = app.pixelColor.rgbaA(pixelValue)
                    isTransparent = (alpha == 0)
                elseif sprite.colorMode == ColorMode.INDEXED then
                    -- 索引模式：检查是否是透明色索引或mask color
                    isTransparent = (pixelValue == sprite.transparentColor)
                end
                
                if isTransparent then
                    html = html .. '                    <td class="empty"></td>\n'
                else
                    local r, g, b
                    
                    if sprite.colorMode == ColorMode.RGB then
                        r = app.pixelColor.rgbaR(pixelValue)
                        g = app.pixelColor.rgbaG(pixelValue)
                        b = app.pixelColor.rgbaB(pixelValue)
                    elseif sprite.colorMode == ColorMode.INDEXED then
                        local paletteColor = sprite.palettes[1]:getColor(pixelValue)
                        -- Color对象的属性已经是数字，直接使用
                        r = paletteColor.red
                        g = paletteColor.green
                        b = paletteColor.blue
                    else
                        r = app.pixelColor.rgbaR(pixelValue)
                        g = app.pixelColor.rgbaG(pixelValue)
                        b = app.pixelColor.rgbaB(pixelValue)
                    end
                
                    local bgColor = rgbToHex(r, g, b)
                    local brightness = getBrightness(r, g, b)
                    local textColor = brightness > 128 and "#000" or "#fff"
                    
                    local colorName = getColorName(r, g, b) or "未命名"
                    
                    html = html .. '                    <td style="background-color: ' .. bgColor .. '; color: ' .. textColor .. ';">\n'
                    
                    if showColorName then
                        html = html .. '                        <span class="color-name">' .. colorName .. '</span>\n'
                    end
                    
                    if showColorCode then
                        html = html .. '                        <span class="color-code">' .. bgColor .. '</span>\n'
                    end
                    
                    html = html .. '                    </td>\n'
                end
            end
        end
        
        html = html .. "                </tr>\n"
    end
    
    html = html .. [[
            </table>
        </div>
        
        <div class="stats">
            <h2>颜色统计</h2>
            <table class="stats-table">
                <thead>
                    <tr>
                        <th>序号</th>
                        <th>颜色</th>
                        <th>名称</th>
                        <th>RGB</th>
                        <th>HEX</th>
                        <th>数量</th>
                        <th>占比</th>
                    </tr>
                </thead>
                <tbody>
]]
    
    -- 添加颜色统计行
    for i, item in ipairs(colorList) do
        local percentage = (item.count / totalPixels) * 100
        local hexColor = rgbToHex(item.r, item.g, item.b)
        
        html = html .. "                    <tr>\n"
        html = html .. "                        <td>" .. i .. "</td>\n"
        html = html .. '                        <td><span class="color-swatch" style="background-color: ' .. hexColor .. ';"></span></td>\n'
        html = html .. "                        <td><strong>" .. item.name .. "</strong></td>\n"
        html = html .. "                        <td>RGB(" .. item.r .. ", " .. item.g .. ", " .. item.b .. ")</td>\n"
        html = html .. "                        <td>" .. hexColor .. "</td>\n"
        html = html .. "                        <td>" .. item.count .. "</td>\n"
        html = html .. "                        <td>" .. string.format("%.2f%%", percentage) .. "</td>\n"
        html = html .. "                    </tr>\n"
    end
    
    html = html .. [[
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
]]
    
    -- 保存HTML文件
    local file = io.open(savePath, "w")
    if file then
        file:write(html)
        file:close()
        
        -- 显示结果
        app.alert{
            title="导出完成",
            text=string.format("拼豆图纸已导出为HTML！\n\n文件: %s\n\n共 %d 种颜色, %d 个像素",
                savePath, #colorList, totalPixels),
            buttons="确定"
        }
    else
        app.alert("无法保存文件: " .. savePath)
    end
end

-- 全局导出函数，供其他脚本调用
function ShowColorName_ExportPerlerBead()
    exportPerlerBead()
end

-- 不再注册菜单命令，仅通过颜色监控窗口的按钮调用
function init(plugin)
end

function exit(plugin)
end

