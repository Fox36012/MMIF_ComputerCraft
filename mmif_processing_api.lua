-- MMIF_processing_api.lua
-- Универсальный API для конвертации в формат MMIF

local colors = {
    colors.white, colors.orange, colors.magenta, colors.lightBlue,
    colors.yellow, colors.lime, colors.pink, colors.gray,
    colors.lightGray, colors.cyan, colors.purple, colors.blue,
    colors.brown, colors.green, colors.red, colors.black
}

-- Палитра в RGB
local paletteRGB = {
    {0xF0, 0xF0, 0xF0}, {0xF2, 0xB2, 0x33}, {0xE5, 0x7F, 0xD8}, {0x99, 0xB2, 0xF2},
    {0xDE, 0xDE, 0x6C}, {0x7F, 0xCC, 0x19}, {0xF2, 0xB2, 0xCC}, {0x4C, 0x4C, 0x4C},
    {0x99, 0x99, 0x99}, {0x4C, 0x99, 0xB2}, {0xB2, 0x66, 0xE5}, {0x33, 0x66, 0xCC},
    {0x7F, 0x66, 0x4C}, {0x57, 0xA6, 0x4E}, {0xCC, 0x4C, 0x4C}, {0x11, 0x11, 0x11}
}

-- Таблица для преобразования имен символов в цвета
local charToColor = {
    ["0"] = colors.white, ["1"] = colors.orange, ["2"] = colors.magenta,
    ["3"] = colors.lightBlue, ["4"] = colors.yellow, ["5"] = colors.lime,
    ["6"] = colors.pink, ["7"] = colors.gray, ["8"] = colors.lightGray,
    ["9"] = colors.cyan, ["a"] = colors.purple, ["b"] = colors.blue,
    ["c"] = colors.brown, ["d"] = colors.green, ["e"] = colors.red,
    ["f"] = colors.black, [" "] = colors.black, ["."] = colors.black,
    ["@"] = colors.black, ["#"] = colors.gray, ["*"] = colors.white,
    ["-"] = colors.lightGray, ["_"] = colors.lightGray
}

-- Функция для вычисления расстояния между цветами
local function colorDistance(r1, g1, b1, r2, g2, b2)
    return math.sqrt((r1 - r2)^2 + (g1 - g2)^2 + (b1 - b2)^2)
end

-- Функция квантования - нахождение ближайшего цвета в палитре
local function quantizeColor(r, g, b)
    local bestIndex = 1
    local bestDistance = colorDistance(r, g, b, paletteRGB[1][1], paletteRGB[1][2], paletteRGB[1][3])
    
    for i = 2, #paletteRGB do
        local dist = colorDistance(r, g, b, paletteRGB[i][1], paletteRGB[i][2], paletteRGB[i][3])
        if dist < bestDistance then
            bestDistance = dist
            bestIndex = i
        end
    end
    
    return bestIndex - 1 -- возвращаем индекс от 0 до 15
end

-- Функция дизеринга по Флойду-Стейнбергу
local function floydSteinbergDither(bmpData, width, height)
    local result = {}
    
    -- Создаем копию данных для обработки
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            result[y][x] = {bmpData[y][x][1], bmpData[y][x][2], bmpData[y][x][3]}
        end
    end
    
    -- Применяем дизеринг
    for y = 1, height do
        for x = 1, width do
            local oldR, oldG, oldB = result[y][x][1], result[y][x][2], result[y][x][3]
            
            -- Находим ближайший цвет
            local newColorIndex = quantizeColor(oldR, oldG, oldB)
            local newR, newG, newB = paletteRGB[newColorIndex + 1][1], paletteRGB[newColorIndex + 1][2], paletteRGB[newColorIndex + 1][3]
            
            -- Записываем результат (только индекс цвета)
            result[y][x] = newColorIndex
            
            -- Вычисляем ошибку
            local errR = oldR - newR
            local errG = oldG - newG
            local errB = oldB - newB
            
            -- Распространяем ошибку на соседние пиксели
            if x < width then
                -- Пиксель справа
                if type(result[y][x+1]) == "table" then
                    local rightR, rightG, rightB = result[y][x+1][1], result[y][x+1][2], result[y][x+1][3]
                    result[y][x+1] = {
                        math.max(0, math.min(255, rightR + errR * 7/16)),
                        math.max(0, math.min(255, rightG + errG * 7/16)),
                        math.max(0, math.min(255, rightB + errB * 7/16))
                    }
                end
            end
            
            if y < height then
                if x > 1 then
                    -- Пиксель слева снизу
                    if type(result[y+1][x-1]) == "table" then
                        local leftDownR, leftDownG, leftDownB = result[y+1][x-1][1], result[y+1][x-1][2], result[y+1][x-1][3]
                        result[y+1][x-1] = {
                            math.max(0, math.min(255, leftDownR + errR * 3/16)),
                            math.max(0, math.min(255, leftDownG + errG * 3/16)),
                            math.max(0, math.min(255, leftDownB + errB * 3/16))
                        }
                    end
                end
                
                -- Пиксель снизу
                if type(result[y+1][x]) == "table" then
                    local downR, downG, downB = result[y+1][x][1], result[y+1][x][2], result[y+1][x][3]
                    result[y+1][x] = {
                        math.max(0, math.min(255, downR + errR * 5/16)),
                        math.max(0, math.min(255, downG + errG * 5/16)),
                        math.max(0, math.min(255, downB + errB * 5/16))
                    }
                end
                
                if x < width then
                    -- Пиксель справа снизу
                    if type(result[y+1][x+1]) == "table" then
                        local rightDownR, rightDownG, rightDownB = result[y+1][x+1][1], result[y+1][x+1][2], result[y+1][x+1][3]
                        result[y+1][x+1] = {
                            math.max(0, math.min(255, rightDownR + errR * 1/16)),
                            math.max(0, math.min(255, rightDownG + errG * 1/16)),
                            math.max(0, math.min(255, rightDownB + errB * 1/16))
                        }
                    end
                end
            end
        end
    end
    
    return result
end

-- =================== ЧТЕНИЕ BMP ===================
local function readBMP(filename)
    local file = fs.open(filename, "rb")
    if not file then
        error("Cannot open BMP file: " .. filename)
    end
    
    -- Проверка сигнатуры
    local signature = file.read(2)
    if signature ~= "BM" then
        file.close()
        error("Not a valid BMP file")
    end
    
    -- Переходим к информации о размере
    file.seek("set", 18)
    
    -- Читаем ширину (4 байта little-endian)
    local w1, w2, w3, w4 = string.byte(file.read(1)), string.byte(file.read(1)), 
                           string.byte(file.read(1)), string.byte(file.read(1))
    local width = w1 + w2 * 256 + w3 * 65536 + w4 * 16777216
    
    -- Читаем высоту
    local h1, h2, h3, h4 = string.byte(file.read(1)), string.byte(file.read(1)),
                           string.byte(file.read(1)), string.byte(file.read(1))
    local height = h1 + h2 * 256 + h3 * 65536 + h4 * 16777216
    
    -- Переходим к пиксельным данным (54 байт для 24-bit BMP)
    file.seek("set", 54)
    
    local bmpData = {}
    local rowSize = math.ceil((width * 3) / 4) * 4
    local padding = rowSize - width * 3
    
    -- BMP хранится снизу вверх
    for y = height, 1, -1 do
        bmpData[y] = {}
        for x = 1, width do
            local b = string.byte(file.read(1))
            local g = string.byte(file.read(1))
            local r = string.byte(file.read(1))
            bmpData[y][x] = {r, g, b}
        end
        
        -- Пропускаем padding
        if padding > 0 then
            for i = 1, padding do
                file.read(1)
            end
        end
    end
    
    file.close()
    return bmpData, width, height
end

-- =================== ЧТЕНИЕ NFP (Paint) ===================
local function readNFP(filename)
    local file = fs.open(filename, "rb")
    if not file then
        error("Cannot open NFP file: " .. filename)
    end
    
    -- Читаем размеры
    local width = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    local height = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    
    -- Создаем RGB данные
    local pixelData = {}
    for y = 1, height do
        pixelData[y] = {}
        for x = 1, width do
            local colorIndex = string.byte(file.read(1))
            local rgb = paletteRGB[colorIndex + 1]
            pixelData[y][x] = {rgb[1], rgb[2], rgb[3]}
        end
    end
    
    file.close()
    return pixelData, width, height
end

-- =================== ЧТЕНИЕ TXT ===================
local function readTXT(filename, customCharMap)
    local file = fs.open(filename, "r")
    if not file then
        error("Cannot open TXT file: " .. filename)
    end
    
    local lines = {}
    local lineCount = 0
    local maxWidth = 0
    
    -- Читаем все строки
    while true do
        local line = file.readLine()
        if not line then break end
        lineCount = lineCount + 1
        lines[lineCount] = line
        if #line > maxWidth then
            maxWidth = #line
        end
    end
    
    file.close()
    
    local width = maxWidth
    local height = lineCount
    
    -- Объединяем стандартную и пользовательскую карту символов
    local charMap = {}
    for k, v in pairs(charToColor) do charMap[k] = v end
    if customCharMap then
        for k, v in pairs(customCharMap) do charMap[k] = v end
    end
    
    -- Таблица для преобразования цвета в индекс
    local colorToIndex = {}
    for i, color in ipairs(colors) do
        colorToIndex[color] = i - 1
    end
    
    -- Конвертируем текст в RGB
    local pixelData = {}
    for y = 1, height do
        pixelData[y] = {}
        local line = lines[y] or ""
        for x = 1, width do
            local char = line:sub(x, x) or " "
            local colorName = charMap[char] or colors.black
            local colorIndex = colorToIndex[colorName] or 15
            local rgb = paletteRGB[colorIndex + 1]
            pixelData[y][x] = {rgb[1], rgb[2], rgb[3]}
        end
    end
    
    return pixelData, width, height
end

-- =================== ЧТЕНИЕ MMIF (статического) ===================
local function readMMIFImage(filename)
    local file = fs.open(filename, "rb")
    if not file then
        error("Cannot open MMIF file: " .. filename)
    end
    
    -- Проверяем сигнатуру
    local signature = file.read(4)
    if signature ~= "MMIF" then
        file.close()
        error("Not a valid MMIF file")
    end
    
    -- Читаем размеры
    local width = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    local height = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    
    -- Пропускаем флаги
    file.read(2)
    
    -- Читаем пиксельные данные
    local pixelData = {}
    for y = 1, height do
        pixelData[y] = {}
        for x = 1, width do
            local colorIndex = string.byte(file.read(1))
            local rgb = paletteRGB[colorIndex + 1]
            pixelData[y][x] = {rgb[1], rgb[2], rgb[3]}
        end
    end
    
    file.close()
    return pixelData, width, height
end

-- =================== ЗАПИСЬ MMIF ===================
local function saveMMIFImage(filename, pixelData, width, height, isVideo, isLooped, fps)
    local file = fs.open(filename, "wb")
    
    -- Заголовок
    file.write("MMIF")
    file.write(string.char(math.floor(width / 256), width % 256))
    file.write(string.char(math.floor(height / 256), height % 256))
    
    -- Флаги
    local flags = 0
    if isVideo then flags = bit.bor(flags, 0x01) end
    if isLooped then flags = bit.bor(flags, 0x02) end
    file.write(string.char(flags, fps or 0))
    
    -- Данные пикселей
    for y = 1, height do
        for x = 1, width do
            file.write(string.char(pixelData[y][x]))
        end
    end
    
    file.close()
end

-- =================== СОЗДАНИЕ ВИДЕО MMIF ===================
local function createMMIFVideo(outputFile, frames, width, height, isLooped, fps)
    local file = fs.open(outputFile, "wb")
    
    -- Заголовок
    file.write("MMIF")
    file.write(string.char(math.floor(width / 256), width % 256))
    file.write(string.char(math.floor(height / 256), height % 256))
    
    -- Флаги: видео + зацикленное (если указано)
    local flags = 0x01  -- Видео
    if isLooped then flags = bit.bor(flags, 0x02) end
    file.write(string.char(flags, fps or 10))
    
    -- Записываем каждый кадр
    for frameIndex, frameData in ipairs(frames) do
        -- Маркер начала кадра
        file.write(string.char(0xAD))
        
        -- Данные кадра
        for y = 1, height do
            for x = 1, width do
                file.write(string.char(frameData[y][x]))
            end
        end
    end
    
    -- Маркер конца файла
    file.write(string.char(0xFF))
    file.close()
    
    return #frames
end

-- =================== КОНВЕРТАЦИЯ ИЗОБРАЖЕНИЯ ===================
local function convertImage(inputFile, outputFile, format, useDithering, customCharMap)
    local pixelData, width, height
    
    -- Чтение в зависимости от формата
    if format == "bmp" then
        pixelData, width, height = readBMP(inputFile)
    elseif format == "nfp" then
        pixelData, width, height = readNFP(inputFile)
    elseif format == "txt" then
        pixelData, width, height = readTXT(inputFile, customCharMap)
    elseif format == "mmif" then
        pixelData, width, height = readMMIFImage(inputFile)
    else
        error("Unsupported format: " .. format)
    end
    
    -- Обработка изображения
    local processedData
    if useDithering then
        processedData = floydSteinbergDither(pixelData, width, height)
    else
        processedData = {}
        for y = 1, height do
            processedData[y] = {}
            for x = 1, width do
                local r, g, b = pixelData[y][x][1], pixelData[y][x][2], pixelData[y][x][3]
                processedData[y][x] = quantizeColor(r, g, b)
            end
        end
    end
    
    -- Сохранение
    saveMMIFImage(outputFile, processedData, width, height, false, false, 0)
    
    return width, height
end

-- =================== КОНВЕРТАЦИЯ ВИДЕО ===================
local function convertVideo(inputFiles, outputFile, formats, useDithering, isLooped, fps, customCharMap)
    if #inputFiles == 0 then
        error("No input files specified")
    end
    
    local frames = {}
    local width, height
    
    -- Обрабатываем каждый кадр
    for i, inputFile in ipairs(inputFiles) do
        local format = formats[i] or formats[1] or "bmp"
        local pixelData, frameWidth, frameHeight
        
        -- Чтение кадра
        if format == "bmp" then
            pixelData, frameWidth, frameHeight = readBMP(inputFile)
        elseif format == "nfp" then
            pixelData, frameWidth, frameHeight = readNFP(inputFile)
        elseif format == "txt" then
            pixelData, frameWidth, frameHeight = readTXT(inputFile, customCharMap)
        elseif format == "mmif" then
            pixelData, frameWidth, frameHeight = readMMIFImage(inputFile)
        else
            error("Unsupported format for frame " .. i .. ": " .. format)
        end
        
        -- Проверка размера
        if i == 1 then
            width, height = frameWidth, frameHeight
        elseif frameWidth ~= width or frameHeight ~= height then
            error(string.format("Frame %d has different size: %dx%d (expected: %dx%d)", 
                  i, frameWidth, frameHeight, width, height))
        end
        
        -- Обработка кадра
        local processedFrame
        if useDithering then
            processedFrame = floydSteinbergDither(pixelData, width, height)
        else
            processedFrame = {}
            for y = 1, height do
                processedFrame[y] = {}
                for x = 1, width do
                    local r, g, b = pixelData[y][x][1], pixelData[y][x][2], pixelData[y][x][3]
                    processedFrame[y][x] = quantizeColor(r, g, b)
                end
            end
        end
        
        table.insert(frames, processedFrame)
        print("Processed frame " .. i .. ": " .. inputFile)
    end
    
    -- Создание видео
    local frameCount = createMMIFVideo(outputFile, frames, width, height, isLooped, fps)
    
    print(string.format("\nVideo created successfully!"))
    print(string.format("Output: %s", outputFile))
    print(string.format("Frames: %d", frameCount))
    print(string.format("Size: %dx%d", width, height))
    print(string.format("FPS: %d", fps or 10))
    print(string.format("Looped: %s", tostring(isLooped)))
    
    return width, height, frameCount
end

-- =================== ПРЕДПРОСМОТР ===================
local function previewImage(filename, format, useDithering, customCharMap)
    term.setGraphicsMode(1)
    term.clear()
    
    local pixelData, width, height
    
    -- Чтение изображения
    if format == "bmp" then
        pixelData, width, height = readBMP(filename)
    elseif format == "nfp" then
        pixelData, width, height = readNFP(filename)
    elseif format == "txt" then
        pixelData, width, height = readTXT(filename, customCharMap)
    elseif format == "MMIF" then
        pixelData, width, height = readMMIFImage(filename)
    else
        term.setGraphicsMode(0)
        error("Unsupported format: " .. format)
    end
    
    -- Обработка
    local processedData
    if useDithering then
        processedData = floydSteinbergDither(pixelData, width, height)
    else
        processedData = {}
        for y = 1, height do
            processedData[y] = {}
            for x = 1, width do
                local r, g, b = pixelData[y][x][1], pixelData[y][x][2], pixelData[y][x][3]
                processedData[y][x] = quantizeColor(r, g, b)
            end
        end
    end
    
    -- Отображение
    for y = 1, height do
        for x = 1, width do
            local colorIndex = processedData[y][x]
            local colorValue = colors[colorIndex + 1]
            term.setPixel(x, y, colorValue)
        end
    end
    
    -- Ждем нажатия любой клавиши
    print("Press any key to continue...")
    os.pullEvent("key")
    
    term.setGraphicsMode(0)
    return width, height
end

return {
    -- Основные функции
    convertImage = convertImage,
    convertVideo = convertVideo,
    previewImage = previewImage,
    
    -- Функции чтения
    readBMP = readBMP,
    readNFP = readNFP,
    readTXT = readTXT,
    readMMIFImage = readMMIFImage,
    
    -- Функции записи
    saveMMIFImage = saveMMIFImage,
    createMMIFVideo = createMMIFVideo,
    
    -- Утилиты обработки
    quantizeColor = quantizeColor,
    floydSteinbergDither = floydSteinbergDither,
    
    -- Константы
    colors = colors,
    paletteRGB = paletteRGB,
    charToColor = charToColor
}
