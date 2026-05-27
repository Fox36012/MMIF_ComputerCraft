-- brgb_convert.lua
local api = require("mmif_processing_api")

local function printHelp()
    print("MMIF Converter - Multi-Media Image Format Converter")
    print("================================================")
    print()
    print("Convert single image:")
    print("  MMIF_convert image <input> <output.mmif> [options]")
    print()
    print("Convert video from multiple frames:")
    print("  MMIF_convert video <frame1> <frame2> ... <output.mmif> [options]")
    print()
    print("Preview image:")
    print("  MMIF_convert preview <input> [options]")
    print()
    print("Options:")
    print("  --format <bmp|nfp|txt|brgb> : Input format (auto-detected)")
    print("  --dither                    : Use Floyd-Steinberg dithering")
    print("  --fps <number>              : FPS for video (default: 10)")
    print("  --looped                    : Create looped video")
    print("  --charmap <file.lua>        : Custom character mapping for TXT")
    print("  --batch <pattern>           : Batch convert matching files")
    print("  --output-dir <dir>          : Output directory for batch")
    print()
    print("Examples:")
    print("  MMIF_convert image photo.bmp image.mmif --dither")
    print("  MMIF_convert image drawing.nfp drawing.mmif")
    print("  MMIF_convert image text.txt text.mmif")
    print("  MMIF_convert video frame*.bmp animation.mmif --fps 15 --looped")
    print("  MMIF_convert preview test.bmp --dither")
    print("  MMIF_convert image *.bmp --batch")
end

-- Автоматическое определение формата по расширению
local function detectFormat(filename)
    if filename:match("%.bmp$") then return "bmp" end
    if filename:match("%.nfp$") then return "nfp" end
    if filename:match("%.txt$") then return "txt" end
    if filename:match("%.miff$") then return "miff" end
    return nil
end

-- Загрузка пользовательской карты символов
local function loadCharMap(filename)
    if not fs.exists(filename) then
        error("Char map file not found: " .. filename)
    end
    
    -- Запускаем файл в изолированной среде
    local env = {colors = colors}
    local func, err = loadfile(filename, nil, env)
    if not func then
        error("Failed to load char map: " .. err)
    end
    
    local success, result = pcall(func)
    if not success then
        error("Error executing char map: " .. result)
    end
    
    -- Возвращаем таблицу charToColor из загруженного файла
    return env.charToColor or {}
end

-- Пакетная конвертация
local function batchConvert(pattern, outputDir, format, useDithering, customCharMap)
    local files = fs.list("")
    local converted = 0
    
    for _, filename in ipairs(files) do
        if filename:match(pattern) then
            local fileFormat = format or detectFormat(filename)
            if fileFormat then
                local outputFile = outputDir .. "/" .. filename:gsub("%.[^%.]+$", "") .. ".mmif"
                
                print("Converting: " .. filename .. " -> " .. outputFile)
                
                local success, err = pcall(function()
                    api.convertImage(filename, outputFile, fileFormat, useDithering, customCharMap)
                end)
                
                if success then
                    print("  ✓ Success")
                    converted = converted + 1
                else
                    print("  ✗ Error: " .. err)
                end
            end
        end
    end
    
    print("\nBatch conversion complete!")
    print("Converted: " .. converted .. " files")
end

-- Основная функция
local function main(args)
    if #args == 0 then
        printHelp()
        return
    end
    
    local mode = args[1]
    local options = {
        format = nil,
        useDithering = false,
        fps = 10,
        isLooped = false,
        customCharMap = nil,
        batchPattern = nil
    }
    
    local inputFiles = {}
    local outputFile = nil
    local outputDir = "converted"
    
    -- Парсинг аргументов
    local i = 2
    while i <= #args do
        local arg = args[i]
        
        if arg == "--format" and i + 1 <= #args then
            options.format = args[i + 1]
            i = i + 2
        elseif arg == "--dither" then
            options.useDithering = true
            i = i + 1
        elseif arg == "--fps" and i + 1 <= #args then
            options.fps = tonumber(args[i + 1])
            i = i + 2
        elseif arg == "--looped" then
            options.isLooped = true
            i = i + 1
        elseif arg == "--charmap" and i + 1 <= #args then
            options.customCharMap = loadCharMap(args[i + 1])
            i = i + 2
        elseif arg == "--batch" and i + 1 <= #args then
            options.batchPattern = args[i + 1]
            i = i + 2
        elseif arg == "--output-dir" and i + 1 <= #args then
            outputDir = args[i + 1]
            i = i + 2
        elseif not outputFile and (arg:match("%.mmif$") or i == #args) then
            outputFile = arg
            i = i + 1
        else
            table.insert(inputFiles, arg)
            i = i + 1
        end
    end
    
    if mode == "image" then
        if options.batchPattern then
            -- Пакетная конвертация
            if not fs.exists(outputDir) then
                fs.makeDir(outputDir)
            end
            batchConvert(options.batchPattern, outputDir, options.format, options.useDithering, options.customCharMap)
        else
            -- Одиночное изображение
            if #inputFiles ~= 1 then
                error("Single image mode requires exactly 1 input file")
            end
            
            if not outputFile then
                outputFile = inputFiles[1]:gsub("%.[^%.]+$", "") .. ".mmif"
            end
            
            local format = options.format or detectFormat(inputFiles[1])
            if not format then
                error("Cannot detect format for: " .. inputFiles[1])
            end
            
            print("Converting: " .. inputFiles[1] .. " -> " .. outputFile)
            local width, height = api.convertImage(inputFiles[1], outputFile, format, 
                                                   options.useDithering, options.customCharMap)
            print(string.format("Success! Size: %dx%d", width, height))
        end
        
    elseif mode == "video" then
        if #inputFiles < 2 then
            error("Video mode requires at least 2 input files")
        end
        
        if not outputFile then
            outputFile = "animation.mmif"
        end
        
        -- Определяем форматы для каждого кадра
        local formats = {}
        for _, file in ipairs(inputFiles) do
            table.insert(formats, options.format or detectFormat(file))
        end
        
        -- Конвертируем видео
        local success, err = pcall(function()
            api.convertVideo(inputFiles, outputFile, formats, options.useDithering, 
                           options.isLooped, options.fps, options.customCharMap)
        end)
        
        if not success then
            error("Video conversion failed: " .. err)
        end
        
    elseif mode == "preview" then
        if #inputFiles ~= 1 then
            error("Preview mode requires exactly 1 input file")
        end
        
        local format = options.format or detectFormat(inputFiles[1])
        if not format then
            error("Cannot detect format for: " .. inputFiles[1])
        end
        
        print("Previewing: " .. inputFiles[1])
        local width, height = api.previewImage(inputFiles[1], format, 
                                              options.useDithering, options.customCharMap)
        print(string.format("Preview complete. Size: %dx%d", width, height))
        
    else
        error("Unknown mode: " .. mode .. ". Use 'image', 'anim', or 'text'")
    end
end

-- Запуск
local args = {...}
local success, err = pcall(function() main(args) end)
if not success then
    print("Error: " .. err)
    print()
    printHelp()
end
