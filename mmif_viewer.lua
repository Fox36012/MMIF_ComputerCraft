-- mmif_viewer.lua
local colors = {
    colors.white, colors.orange, colors.magenta, colors.lightBlue,
    colors.yellow, colors.lime, colors.pink, colors.gray,
    colors.lightGray, colors.cyan, colors.purple, colors.blue,
    colors.brown, colors.green, colors.red, colors.black
}

-- Функция для чтения видеофайла
local function loadMMIFVideo(filename)
    local file = fs.open(filename, "rb")
    if not file then
        return nil
    end
    
    -- Проверяем сигнатуру
    local signature = file.read(4)
    if signature ~= "MMIF" then
        file.close()
        return nil
    end
    
    -- Читаем размеры
    local width = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    local height = string.byte(file.read(1)) * 256 + string.byte(file.read(1))
    
    -- Читаем флаги
    local flagByte1 = string.byte(file.read(1))
    local fps = string.byte(file.read(1))  -- Второй байт - FPS
    
    -- Парсим флаги
    local isVideo = bit.band(flagByte1, 0x01) ~= 0  -- Бит 0: видео?
    local isLooped = bit.band(flagByte1, 0x02) ~= 0 -- Бит 1: цикличное?
    
    -- Для видео: читаем все кадры
    if isVideo then
        local frames = {}
        local frameCount = 0
        
        while true do
            -- Читаем маркер начала кадра
            local marker = file.read(1)
            if not marker then break end
            
            local markerByte = string.byte(marker)
            
            if markerByte == 0xAD then
                -- Начало нового кадра
                frameCount = frameCount + 1
                frames[frameCount] = {}
                
                for y = 1, height do
                    frames[frameCount][y] = {}
                    for x = 1, width do
                        local pixel = file.read(1)
                        if not pixel then break end
                        frames[frameCount][y][x] = string.byte(pixel)
                    end
                end
            elseif markerByte == 0xFF then
                -- Конец файла
                break
            else
                -- Некорректный маркер
                print("Warning: Invalid marker " .. markerByte .. " at frame " .. frameCount)
                break
            end
        end
        
        file.close()
        
        return {
            width = width,
            height = height,
            isVideo = isVideo,
            isLooped = isLooped,
            fps = fps,
            frames = frames,
            frameCount = frameCount
        }
    else
        -- Статическое изображение (обратная совместимость)
        local pixelData = {}
        for y = 1, height do
            pixelData[y] = {}
            for x = 1, width do
                pixelData[y][x] = string.byte(file.read(1))
            end
        end
        
        file.close()
        
        return {
            width = width,
            height = height,
            isVideo = false,
            isLooped = false,
            fps = 0,
            frames = {pixelData},  -- Один кадр
            frameCount = 1
        }
    end
end

-- Функция для отображения видео (без управления, только воспроизведение)
local function displayMMIFVideo(filename)
    term.setGraphicsMode(1)
    term.clear()
    
    local videoData = loadMMIFVideo(filename)
    if not videoData then
        error("Cannot load MMIF video file: " .. filename)
    end
    
    print("Loaded: " .. videoData.frameCount .. " frames")
    print("FPS: " .. videoData.fps)
    print("Size: " .. videoData.width .. "x" .. videoData.height)
    print("Press Ctrl+T to exit")
    
    if videoData.isVideo then
        -- Воспроизводим видео
        local frameDelay = 1 / videoData.fps
        local frameIndex = 1
        local running = true
        
        while running do
            local startTime = os.clock()
            
            -- Отображаем текущий кадр
            local frame = videoData.frames[frameIndex]
            if frame then
                for y = 1, videoData.height do
                    for x = 1, videoData.width do
                        local colorIndex = frame[y][x]
                        local colorValue = colors[colorIndex + 1]
                        term.setPixel(x, y, colorValue)
                    end
                end
            end
            
            -- Переход к следующему кадру
            frameIndex = frameIndex + 1
            if frameIndex > videoData.frameCount then
                if videoData.isLooped then
                    frameIndex = 1
                else
                    running = false  -- Завершаем после последнего кадра
                end
            end
            
            -- Задержка для поддержания FPS
            local elapsed = os.clock() - startTime
            if elapsed < frameDelay then
                sleep(frameDelay - elapsed)
            end
        end
    else
        -- Статическое изображение - показываем и ждем завершения программы
        local frame = videoData.frames[1]
        for y = 1, videoData.height do
            for x = 1, videoData.width do
                local colorIndex = frame[y][x]
                local colorValue = colors[colorIndex + 1]
                term.setPixel(x, y, colorValue)
            end
        end
        
        -- Бесконечное ожидание (завершить можно только Ctrl+T)
        while true do
            sleep(1)
        end
    end
    
    term.setGraphicsMode(0)
    return true
end

-- Основная программа
local args = {...}

if #args == 0 then
    print("MMIF Video Viewer")
    print("Usage: brgb_video_viewer <path_to_brgb_file>")
    print("Press Ctrl+T to exit at any time")
    return
end

local filename = args[1]

-- Проверяем существование файла
if not fs.exists(filename) then
    print("File not found: " .. filename)
    return
end

-- Проверяем расширение файла
if not filename:match("%.mmif$") then
    print("Warning: File extension is not .mmif")
end

-- Запускаем отображение
local success, err = pcall(function()
    displayMMIFVideo(filename)
end)

if not success then
    print("Error: " .. err)
end

-- Возвращаем графический режим в нормальное состояние при выходе
term.setGraphicsMode(0)
