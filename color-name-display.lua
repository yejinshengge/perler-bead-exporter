-- 显示颜色名称插件
-- 从.gpl文件读取颜色名称并在浮动窗口中实时显示

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

local colorDialog = nil
local lastFgColor = nil
local currentDisplayColor = Color{r=128, g=128, b=128}
local isMonitoring = false
local updateTimer = nil

-- 颜色是否相同
local function isSameColor(c1, c2)
    if not c1 or not c2 then
        return false
    end
    return c1.red == c2.red and c1.green == c2.green and c1.blue == c2.blue
end

-- 更新颜色显示窗口
local function updateColorDisplay()
    if not colorDialog then
        return
    end
    
    local fgColor = app.fgColor
    
    -- 如果颜色没变化，不更新
    if lastFgColor and isSameColor(fgColor, lastFgColor) then
        return
    end
    
    lastFgColor = Color{r = fgColor.red, g = fgColor.green, b = fgColor.blue}
    
    -- 获取颜色名称（使用公共模块）
    local colorName = nil
    if ShowColorName.getColorNameFromColor then
        colorName = ShowColorName.getColorNameFromColor(fgColor)
    end
    
    -- 构建显示文本
    local displayText = ""
    if colorName then
        displayText = colorName
    else
        displayText = "未命名颜色"
    end
    
    -- 更新对话框内容
    currentDisplayColor = Color{r=fgColor.red, g=fgColor.green, b=fgColor.blue}
    colorDialog:modify{
        id="color_swatch",
        visible=true  -- 触发重绘
    }
    colorDialog:repaint()
    colorDialog:modify{
        id="color_name",
        text=displayText
    }
end

-- 加载GPL文件
local function loadGPLFile()
    -- 确保函数存在
    if not ShowColorName.getGPLFilePath then
        app.alert("错误：颜色数据模块未正确加载，请重新加载插件")
        return
    end
    
    local gplPath = ShowColorName.getGPLFilePath()
    
    if not gplPath then
        -- 让用户选择GPL文件
        local dlg = Dialog("选择GPL调色板文件")
        dlg:file{
            id="gpl_file",
            label="GPL文件:",
            open=true,
            filetypes={"gpl"}
        }
        dlg:button{
            id="ok",
            text="确定",
            onclick=function()
                local data = dlg.data
                if data.gpl_file and data.gpl_file ~= "" then
                    local count = 0
                    if ShowColorName.loadGPLFile then
                        count = ShowColorName.loadGPLFile(data.gpl_file)
                    end
                    if count > 0 then
                        app.alert(string.format("✓ 成功加载 %d 个颜色名称", count))
                    else
                        app.alert("⚠ 未能解析颜色名称，请检查GPL文件格式")
                    end
                end
                dlg:close()
            end
        }
        dlg:button{
            id="cancel",
            text="取消"
        }
        dlg:show()
    else
        local count = 0
        if ShowColorName.loadGPLFile then
            count = ShowColorName.loadGPLFile(gplPath)
        end
        if count > 0 then
            app.alert(string.format("✓ 成功自动加载 %d 个颜色名称\n文件: %s", count, gplPath))
        end
    end
end

-- 启动颜色名称监控窗口
local function startColorMonitor()
    if isMonitoring and colorDialog then
        colorDialog:close()
        isMonitoring = false
        return
    end
    
    -- 确保已加载颜色数据
    local count = 0
    if ShowColorName.getLoadedColorCount then
        count = ShowColorName.getLoadedColorCount()
    end
    if count == 0 then
        loadGPLFile()
        if ShowColorName.getLoadedColorCount then
            count = ShowColorName.getLoadedColorCount()
        end
        if count == 0 then
            return
        end
    end
    
    -- 创建浮动窗口
    colorDialog = Dialog{
        title="",
        onclose=function()
            isMonitoring = false
            colorDialog = nil
        end
    }:canvas{
        id="color_swatch",
        width=16,
        height=16,
        onpaint=function(ev)
            local gc = ev.context
            gc.color = currentDisplayColor
            gc:fillRect(Rectangle(0, 0, 16, 16))
        end
    }:label{
        id="color_name",
        text="选择一个颜色"
    }:newrow()
    :button{
        id="export_btn",
        text="导出图纸",
        onclick=function()
            if ShowColorName_ExportPerlerBead then
                ShowColorName_ExportPerlerBead()
            else
                app.alert("导出功能未加载，请重新加载插件")
            end
        end
    }:newrow()
    :button{
        id="reload_btn",
        text="重新加载",
        onclick=function()
            -- 让用户选择新的GPL文件
            local dlg = Dialog("选择GPL调色板文件")
            dlg:file{
                id="gpl_file",
                label="GPL文件:",
                open=true,
                filetypes={"gpl"}
            }
            dlg:button{
                id="ok",
                text="确定",
                onclick=function()
                    local data = dlg.data
                    if data.gpl_file and data.gpl_file ~= "" then
                        local count = 0
                        if ShowColorName.loadGPLFile then
                            count = ShowColorName.loadGPLFile(data.gpl_file)
                        end
                        if count > 0 then
                            app.alert(string.format("✓ 成功加载 %d 个颜色名称", count))
                            -- 立即更新颜色显示
                            updateColorDisplay()
                        else
                            app.alert("⚠ 未能解析颜色名称，请检查GPL文件格式")
                        end
                    end
                    dlg:close()
                end
            }
            dlg:button{
                id="cancel",
                text="取消"
            }
            dlg:show()
        end
    }
    
    -- 显示窗口（非模态）
    colorDialog:show{wait=false}
    
    isMonitoring = true
    lastFgColor = nil
    
    -- 立即更新一次
    updateColorDisplay()
    
    -- 启动定时器持续监控
    if updateTimer then
        updateTimer:stop()
    end
    
    updateTimer = Timer{
        interval=0.1,  -- 每100毫秒检查一次
        ontick=function()
            if isMonitoring and colorDialog then
                updateColorDisplay()
            else
                if updateTimer then
                    updateTimer:stop()
                end
            end
        end
    }
    updateTimer:start()
end

-- 显示调色板颜色名称对照表
local function showPaletteNames()
    local sprite = app.activeSprite
    if not sprite then
        app.alert("请先打开一个文件")
        return
    end
    
    local count = 0
    if ShowColorName.getLoadedColorCount then
        count = ShowColorName.getLoadedColorCount()
    end
    if count == 0 then
        loadGPLFile()
        if ShowColorName.getLoadedColorCount then
            count = ShowColorName.getLoadedColorCount()
        end
        if count == 0 then
            return
        end
    end
    
    local palette = sprite.palettes[1]
    local nameList = ""
    local foundCount = 0
    
    for i = 0, #palette - 1 do
        local color = palette:getColor(i)
        local name = nil
        if ShowColorName.getColorNameFromColor then
            name = ShowColorName.getColorNameFromColor(color)
        end
        if name then
            nameList = nameList .. string.format("Index %d: %s\n  RGB(%d, %d, %d) #%02X%02X%02X\n\n", 
                i, name, color.red, color.green, color.blue,
                color.red, color.green, color.blue)
            foundCount = foundCount + 1
        end
    end
    
    if foundCount == 0 then
        app.alert("调色板中没有找到匹配的颜色名称")
    else
        -- 创建对话框显示列表
        local dlg = Dialog("调色板颜色名称对照表")
        dlg:label{
            id="info",
            text=string.format("共找到 %d 个已命名颜色", foundCount)
        }
        dlg:separator()
        dlg:label{
            id="list",
            text=nameList
        }
        dlg:button{
            id="close",
            text="关闭"
        }
        dlg:show()
    end
end

-- 注册菜单命令
function init(plugin)
    -- 启动/关闭颜色名称监控
    plugin:newCommand{
        id="ToggleColorMonitor",
        title="拼豆图纸导出工具",
        group="view_controls",
        onclick=function()
            startColorMonitor()
        end
    }
    
    -- 加载GPL文件
    plugin:newCommand{
        id="LoadGPLFile",
        title="加载GPL调色板文件",
        group="palette_popup_edit",
        onclick=function()
            loadGPLFile()
        end
    }
    
    -- 显示调色板名称列表
    plugin:newCommand{
        id="ShowPaletteNames",
        title="查看调色板颜色名称",
        group="palette_popup_edit",
        onclick=function()
            showPaletteNames()
        end
    }
end

function exit(plugin)
    if updateTimer then
        updateTimer:stop()
    end
    if colorDialog then
        colorDialog:close()
    end
end

