-- ============================================================================
-- Addon: RaidBuffChecker
-- Cliente: World of Warcraft: Wrath of the Lich King (v3.3.5a - Parche 12340)
-- Descripción: Escanea los beneficios de banda en entornos de 25 jugadores
--              (Subgrupos 1 al 5) a demanda mediante un botón o comando.
-- ============================================================================

-- CAPA 1: BASE DE DATOS DE ASIGNACIÓN Y MAPEO DE SPELLS

-- Declaración local de la base de datos de asignaciones.
-- Se inicializa con valores por defecto y se sincroniza con SavedVariables en la carga.
local Assignments = {
    PALADIN_REYES = "",
    PALADIN_SABIDURIA = "",
    PALADIN_PODER = "",
    PALADIN_SALVAGUARDA = "",
    PRIEST = "",
    DRUID_MARCA = "",
    MAGE_INTELECTO = "",
    WARRIOR_GRITO = "",
    TAMBORES = "",
    PERGAMINOS = "",
    MAGE_IGNORE_LIST = ""
}

-- IDs de hechizos de la base de datos de WotLK (Wrath of the Lich King)
local SPELL_IDS = {
    Reyes = 25898,         -- Bendición de reyes superior (Greater Blessing of Kings)
    Sabiduria = 48938,     -- Bendición de sabiduría superior (Greater Blessing of Wisdom)
    Poder = 48934,         -- Bendición de poderío superior (Greater Blessing of Might)
    Salvaguarda = 25899,   -- Bendición de salvaguarda superior (Greater Blessing of Sanctuary)
    Entereza = 48162,      -- Rezo de entereza (Prayer of Fortitude)
    Sombra = 48170,        -- Rezo de protección contra las Sombras (Prayer of Shadow Protection)
    Espiritu = 48074,      -- Rezo de espíritu (Prayer of Spirit)
    Marca = 48470,         -- Don de lo Salvaje (Gift of the Wild)
    Intelecto = 43002,     -- Luminosidad arcana (Arcane Brilliance)
    Grito = 47436,         -- Grito de batalla (Battle Shout)
    EnfoqueDeMagia = 54646 -- Enfoque de magia (Focus Magic)
}

-- Tabla local para almacenar los nombres localizados de los hechizos indicados
local LOCALIZED_SPELLS = {}

-- Diccionario de nombres de auras a comprobar en UnitAura (permite soportar buffs base y alternativos)
local SPELL_NAMES_CHECK = {}

-- Inicializa y resuelve los nombres localizados de los hechizos usando GetSpellInfo
local function InitializeSpellNames()
    -- Resolver nombres localizados para los IDs primarios especificados
    for key, id in pairs(SPELL_IDS) do
        local name = GetSpellInfo(id)
        LOCALIZED_SPELLS[key] = name or "UNKNOWN_SPELL_" .. id
    end

    -- Mapear claves a un conjunto de IDs válidos para el escaneo de auras.
    -- En WotLK, los hechizos de grupo (Greater/Prayer/Gift) aplican auras con el mismo
    -- nombre localized que sus versiones individuales o viceversa, y pueden variar según el rango.
    local scanMappings = {
        Reyes = { 25898, 20217 },                                          -- Greater Blessing of Kings, Blessing of Kings
        Sabiduria = { 48938, 25894, 48936, 19742 },                        -- Greater Blessing of Wisdom max ranks
        Poder = { 48934, 25890, 48932, 19740 },                            -- Greater Blessing of Might max ranks
        Salvaguarda = { 25899, 20911 },                                    -- Greater Blessing of Sanctuary, Blessing of Sanctuary
        Entereza = { 48162, 48161, 48066, 1243 },                          -- Prayer of Fortitude, Power Word: Fortitude
        Sombra = { 48170, 48169, 25433 },                                  -- Prayer of Shadow Protection, Shadow Protection
        Espiritu = { 48074, 48073, 14752 },                                -- Prayer of Spirit, Divine Spirit
        Marca = { 48470, 48469, 48870, 1126 },                             -- Gift of the Wild, Mark of the Wild
        Intelecto = { 43002, 43008, 27127, 1459, 61316, 61024 },           -- Arcane Brilliance, Arcane Intellect, Dalaran Brilliance, Dalaran Intellect
        Grito = { 47436, 25289, 25290, 11549, 11550, 11551, 11552, 2048 }, -- Battle Shout (Grito de batalla)
        EnfoqueDeMagia = { 54646 }                                         -- Focus Magic
    }

    for key, ids in pairs(scanMappings) do
        SPELL_NAMES_CHECK[key] = {}
        for _, id in ipairs(ids) do
            local name = GetSpellInfo(id)
            if name and name ~= "" then
                -- Asegurar inserción única
                local exists = false
                for _, existingName in ipairs(SPELL_NAMES_CHECK[key]) do
                    if existingName == name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(SPELL_NAMES_CHECK[key], name)
                end
            end
        end
    end
end


-- CAPA 2: FUNCIONES AUXILIARES DE ESCANEO (HELPERS)

-- Comprueba si una unidad tiene un beneficio específico mediante su nombre localizado.
-- Utiliza un bucle indexado con UnitAura ("HELPFUL") hasta que retorne nil, de forma
-- limpia y optimizada según las restricciones clásicas de 2010.
local function UnitHasBuff(unit, buffName)
    if not buffName or buffName == "" then return false end
    local index = 1
    while true do
        -- API Clásica de WotLK: retorna name, rank, icon, count, debuffType, etc.
        local name = UnitAura(unit, index, "HELPFUL")
        if not name then
            break
        end
        if name == buffName then
            return true
        end
        index = index + 1
    end
    return false
end

-- Comprueba si una unidad tiene cualquiera de las auras localized resueltas para una clave específica.
local function UnitHasSpellKeyBuff(unit, key)
    local names = SPELL_NAMES_CHECK[key]
    if not names then return false end
    for i = 1, #names do
        if UnitHasBuff(unit, names[i]) then
            return true
        end
    end
    return false
end

-- Envía un reporte del escaneo respetando la jerarquía del emisor y el estado del grupo
local function SendRaidReport(message)
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        -- Si está en banda y es Líder o Ayudante (Officer), envía por RAID_WARNING.
        -- De lo contrario, deriva a chat de banda (RAID).
        if IsRaidLeader() or IsRaidOfficer() then
            SendChatMessage(message, "RAID_WARNING")
        else
            SendChatMessage(message, "RAID")
        end
    else
        -- Si no está en banda, lo muestra localmente en su ventana de chat predeterminada
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RBC]|r " .. message)
        end
    end
end

-- Helpers de clasificación de clases para determinar la necesidad de beneficios específicos
local function IsManaClass(class)
    if not class then return false end
    -- Clases con maná en WotLK (se benefician de Sabiduría e Intelecto)
    return (class == "MAGE" or class == "PRIEST" or class == "WARLOCK" or class == "DRUID" or class == "SHAMAN" or class == "PALADIN" or class == "HUNTER")
end

local function IsPhysicalClass(class)
    if not class then return false end
    -- Clases de daño físico/tanqueo en WotLK (se benefician de Poder)
    return (class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or class == "HUNTER" or class == "PALADIN" or class == "SHAMAN" or class == "DRUID")
end

local function IsSpiritClass(class)
    if not class then return false end
    -- Clases que aprovechan el Espíritu activamente para regeneración o stats en WotLK
    return (class == "PRIEST" or class == "MAGE" or class == "WARLOCK" or class == "DRUID")
end


-- CAPA 3: MOTOR DE ANÁLISIS ESTRUCTURAL (CORE SCANNER)

-- Tablas estáticas persistentes a nivel local para optimizar el uso de memoria
-- y evitar picos de Garbage Collection (GC) en ejecuciones frecuentes.
local temp_missingReyesClasses = {}
local temp_missingSabiduriaClasses = {}
local temp_missingPoderClasses = {}
local temp_missingSalvaguardaClasses = {}
local temp_missingGrito = {}
local temp_missingMarca = {}
local temp_missingIntelecto = {}

local temp_priestMissing = { Entereza = 0, Sombra = 0, Espiritu = 0 }

local temp_mageReports = {}

-- Limpia de forma eficiente el contenido de las tablas de almacenamiento temporal
local function WipeTempTables()
    for k in pairs(temp_missingReyesClasses) do temp_missingReyesClasses[k] = nil end
    for k in pairs(temp_missingSabiduriaClasses) do temp_missingSabiduriaClasses[k] = nil end
    for k in pairs(temp_missingPoderClasses) do temp_missingPoderClasses[k] = nil end
    for k in pairs(temp_missingSalvaguardaClasses) do temp_missingSalvaguardaClasses[k] = nil end
    for i = 1, #temp_missingGrito do temp_missingGrito[i] = nil end
    for i = 1, #temp_missingMarca do temp_missingMarca[i] = nil end
    for i = 1, #temp_missingIntelecto do temp_missingIntelecto[i] = nil end
    for i = 1, #temp_mageReports do temp_mageReports[i] = nil end

    temp_priestMissing.Entereza = 0
    temp_priestMissing.Sombra = 0
    temp_priestMissing.Espiritu = 0
end

-- Función central para realizar el escaneo estructural
local function ExecuteAdvancedRaidCheck(isSilent)
    -- Garantizar que los nombres de los hechizos estén resueltos si el cache demoró al cargar
    if not SPELL_NAMES_CHECK.Reyes or #SPELL_NAMES_CHECK.Reyes == 0 then
        InitializeSpellNames()
    end

    -- Limpiar tablas de descarte temporal antes de comenzar
    WipeTempTables()

    -- Estructura para almacenar resultados del rastreo silencioso
    local trackResults = {
        Reyes = {},
        Sabiduria = {},
        Poder = {},
        Salvaguarda = {},
        Grito = {},
        Marca = {},
        Intelecto = {},
        Entereza = {},
        Sombra = {},
        Espiritu = {},
        Eligible = {
            Mana = 0,
            Physical = 0,
            Spirit = 0
        }
    }

    -- En modo silencioso (Rastrear) siempre comprobar TODOS los bufos posibles,
    -- independientemente de si hay asignaciones configuradas o no.
    -- En modo de alerta (Escanear Banda) solo comprobar los bufos con asignación configurada.
    local checkKings, checkWisdom, checkMight, checkSalvation, checkPriest, checkDruid, checkMage, checkWarrior
    if isSilent then
        -- Modo rastreo universal: rastrear todo siempre, funciona solo/grupo/banda
        checkKings     = true
        checkWisdom    = true
        checkMight     = true
        checkSalvation = true
        checkPriest    = true
        checkDruid     = true
        checkMage      = true
        checkWarrior   = true
    else
        -- Modo alerta: solo lo que está asignado en la UI
        checkKings     = (Assignments.PALADIN_REYES and Assignments.PALADIN_REYES ~= "") or
            (Assignments.TAMBORES and Assignments.TAMBORES ~= "")
        checkWisdom    = (Assignments.PALADIN_SABIDURIA and Assignments.PALADIN_SABIDURIA ~= "")
        checkMight     = (Assignments.PALADIN_PODER and Assignments.PALADIN_PODER ~= "")
        checkSalvation = (Assignments.PALADIN_SALVAGUARDA and Assignments.PALADIN_SALVAGUARDA ~= "")
        checkPriest    = (Assignments.PRIEST and Assignments.PRIEST ~= "") or
            (Assignments.PERGAMINOS and Assignments.PERGAMINOS ~= "")
        checkDruid     = (Assignments.DRUID_MARCA and Assignments.DRUID_MARCA ~= "")
        checkMage      = (Assignments.MAGE_INTELECTO and Assignments.MAGE_INTELECTO ~= "")
        checkWarrior   = (Assignments.WARRIOR_GRITO and Assignments.WARRIOR_GRITO ~= "")

        -- En modo alerta, abortar si no hay ninguna asignación configurada
        if not checkKings and not checkWisdom and not checkMight and not checkSalvation and not checkPriest and not checkDruid and not checkMage and not checkWarrior then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffffd700[RBC] No hay asignaciones otorgadas para bufos.|r")
            end
            return nil
        end
    end

    -- PASO 1: RECOPILAR MIEMBROS A ESCANEAR (Soporta Solo, Grupo y Banda Subgrupos 1-5)
    local unitsToScan = {}
    local numRaid = GetNumRaidMembers()

    if numRaid > 0 then
        -- En Banda: Escanear subgrupos 1 a 5
        for i = 1, numRaid do
            local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
            if name and subgroup <= 5 then
                table.insert(unitsToScan, {
                    unit = "raid" .. i,
                    name = name,
                    class = class,
                    fileName = fileName,
                    online = online,
                    isDead = isDead
                })
            end
        end
    else
        -- Fuera de Banda: Solo o en Grupo de 5 personas (para pruebas y mazmorras)
        local numParty = GetNumPartyMembers()

        -- Añadir al propio jugador
        local pName = UnitName("player")
        local _, pClass = UnitClass("player")
        table.insert(unitsToScan, {
            unit = "player",
            name = pName,
            class = UnitClass("player"), -- Localized name
            fileName = pClass,           -- Upper English token
            online = true,
            isDead = UnitIsDeadOrGhost("player")
        })

        -- Añadir miembros del grupo si existen
        if numParty > 0 then
            for i = 1, numParty do
                local partyUnit = "party" .. i
                local localizedClass, fileNameClass = UnitClass(partyUnit)
                table.insert(unitsToScan, {
                    unit = partyUnit,
                    name = UnitName(partyUnit),
                    class = localizedClass,   -- Nombre localizado (para display)
                    fileName = fileNameClass, -- Token inglés en mayúsculas (para IsManaClass/IsPhysicalClass)
                    online = UnitIsConnected(partyUnit),
                    isDead = UnitIsDeadOrGhost(partyUnit)
                })
            end
        end
    end

    -- PASO 2: DETECTAR MAGOS IGNORADOS PARA CADENA DE ENFOQUE
    local ignoredMages = {}
    local ignoreStr = Assignments.MAGE_IGNORE_LIST or ""
    ignoreStr = string.gsub(ignoreStr, ",", " ") -- Reemplazar comas por espacios
    for word in string.gmatch(ignoreStr, "%S+") do
        local cleanName = string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2))
        ignoredMages[cleanName] = true
    end

    local activeMageNames = {}

    -- PASO 3: REALIZAR COMPROBACIONES DE BUFOS EN CADA MIEMBRO
    local activePaladins = 0
    local activePriests = 0
    local activeDruids = 0
    local activeMages = 0

    for _, member in ipairs(unitsToScan) do
        local unit = member.unit
        local name = member.name
        local class = member.class
        local fileName = member.fileName

        -- Módulo Magos: Registrar magos para enfoque
        if member.fileName == "MAGE" and member.online and not member.isDead then
            if not ignoredMages[name] then
                table.insert(activeMageNames, name)
            end
        end

        -- Comprobar beneficios
        if member.online and not member.isDead then
            if fileName == "PALADIN" then
                activePaladins = activePaladins + 1
            elseif fileName == "PRIEST" then
                activePriests = activePriests + 1
            elseif fileName == "DRUID" then
                activeDruids = activeDruids + 1
            elseif fileName == "MAGE" then
                activeMages = activeMages + 1
            end

            -- 1. Reyes/Tambores
            if checkKings then
                if not UnitHasSpellKeyBuff(unit, "Reyes") then
                    temp_missingReyesClasses[class] = true
                    table.insert(trackResults.Reyes, name)
                end
            end

            -- 2. Sabiduría (mana)
            if checkWisdom and IsManaClass(fileName) then
                trackResults.Eligible.Mana = trackResults.Eligible.Mana + 1
                if not UnitHasSpellKeyBuff(unit, "Sabiduria") then
                    temp_missingSabiduriaClasses[class] = true
                    table.insert(trackResults.Sabiduria, name)
                end
            end

            -- 3. Poder (fisicos)
            if checkMight and IsPhysicalClass(fileName) then
                trackResults.Eligible.Physical = trackResults.Eligible.Physical + 1
                if not UnitHasSpellKeyBuff(unit, "Poder") then
                    temp_missingPoderClasses[class] = true
                    table.insert(trackResults.Poder, name)
                end
            end

            -- 3b. Salvaguarda (tanques: Warrior, DK, Paladin, Bear Druid)
            if checkSalvation and IsPhysicalClass(fileName) then
                if not UnitHasSpellKeyBuff(unit, "Salvaguarda") then
                    temp_missingSalvaguardaClasses[class] = true
                    table.insert(trackResults.Salvaguarda, name)
                end
            end

            -- 3c. Grito de batalla (fisicos)
            if checkWarrior and IsPhysicalClass(fileName) then
                if not UnitHasSpellKeyBuff(unit, "Grito") then
                    table.insert(temp_missingGrito, name)
                    table.insert(trackResults.Grito, name)
                end
            end

            -- 4. Marca (druida)
            if checkDruid then
                if not UnitHasSpellKeyBuff(unit, "Marca") then
                    table.insert(temp_missingMarca, name)
                    table.insert(trackResults.Marca, name)
                end
            end

            -- 5. Intelecto (mago)
            if checkMage and IsManaClass(fileName) then
                if not UnitHasSpellKeyBuff(unit, "Intelecto") then
                    table.insert(temp_missingIntelecto, name)
                    table.insert(trackResults.Intelecto, name)
                end
            end

            -- 6. Sacerdote (Entereza, Sombra, Espíritu)
            if checkPriest then
                -- Entereza
                if not UnitHasSpellKeyBuff(unit, "Entereza") then
                    temp_priestMissing.Entereza = temp_priestMissing.Entereza + 1
                    table.insert(trackResults.Entereza, name)
                end
                -- Sombra
                if not UnitHasSpellKeyBuff(unit, "Sombra") then
                    temp_priestMissing.Sombra = temp_priestMissing.Sombra + 1
                    table.insert(trackResults.Sombra, name)
                end
                -- Espíritu
                if IsSpiritClass(fileName) then
                    if not UnitHasSpellKeyBuff(unit, "Espiritu") then
                        temp_priestMissing.Espiritu = temp_priestMissing.Espiritu + 1
                        table.insert(trackResults.Espiritu, name)
                    end
                end
            end
        end
    end

    -- 7. Módulo Magos (Enfoque de Magia / Focus Magic)
    -- Si hay magos asignados y conectados, se genera su cadena circular o intercambio cruzado
    if #activeMageNames >= 2 then
        -- Ordenar alfabéticamente los nombres para consistencia
        table.sort(activeMageNames)

        if #activeMageNames == 2 then
            table.insert(temp_mageReports,
                string.format("[MAGOS] %s y %s deben intercambiar Enfoque de Magia.", activeMageNames[1],
                    activeMageNames[2]))
        else
            -- Construir dinámicamente la cadena para 3, 4 o 5 magos (ej: A > B > C > D > A)
            local chainParts = {}
            for k = 1, #activeMageNames do
                table.insert(chainParts, activeMageNames[k])
            end
            table.insert(chainParts, activeMageNames[1]) -- Cierra el círculo
            table.insert(temp_mageReports, "[MAGOS] Enfoques: " .. table.concat(chainParts, " > ") .. ".")
        end
    end

    -- Si es un rastreo silencioso para la UI, retornar los resultados y no emitir nada al chat
    if isSilent then
        trackResults.MagesFocusReport = temp_mageReports
        return trackResults
    end

    -- CAPA 4: EMISIÓN DE ALERTAS

    -- Contador de alertas emitidas para reporte local de conformidad
    local alertCount = 0

    -- Reportar faltas de Paladines o Tambores
    if checkKings then
        local reyesCount = 0
        local reyesClasses = {}
        for className in pairs(temp_missingReyesClasses) do
            table.insert(reyesClasses, className)
            reyesCount = reyesCount + 1
        end
        if reyesCount > 0 then
            local header = "Reyes"
            local isDrums = false
            if Assignments.PALADIN_REYES and Assignments.PALADIN_REYES ~= "" then
                header = Assignments.PALADIN_REYES
            elseif Assignments.TAMBORES and Assignments.TAMBORES ~= "" then
                header = Assignments.TAMBORES
                isDrums = true
            end
            if isDrums then
                SendRaidReport(string.format("[%s] Falta TAMBORES.", header))
            else
                SendRaidReport(string.format("[%s] Falta REYES a: %s.", header, table.concat(reyesClasses, ", ")))
            end
            alertCount = alertCount + 1
        end
    end

    if checkWisdom then
        local sabiCount = 0
        local sabiClasses = {}
        for className in pairs(temp_missingSabiduriaClasses) do
            table.insert(sabiClasses, className)
            sabiCount = sabiCount + 1
        end
        if sabiCount > 0 then
            local header = (Assignments.PALADIN_SABIDURIA and Assignments.PALADIN_SABIDURIA ~= "") and
                Assignments.PALADIN_SABIDURIA or "Sabiduría"
            SendRaidReport(string.format("[%s] Falta SABIDURÍA a: %s.", header, table.concat(sabiClasses, ", ")))
            alertCount = alertCount + 1
        end
    end

    if checkMight then
        local poderCount = 0
        local poderClasses = {}
        for className in pairs(temp_missingPoderClasses) do
            table.insert(poderClasses, className)
            poderCount = poderCount + 1
        end
        if poderCount > 0 then
            local header = (Assignments.PALADIN_PODER and Assignments.PALADIN_PODER ~= "") and Assignments.PALADIN_PODER or
                "Poderío"
            SendRaidReport(string.format("[%s] Falta PODERÍO a: %s.", header, table.concat(poderClasses, ", ")))
            alertCount = alertCount + 1
        end
    end

    -- Reportar faltas de Salvaguarda (2 tanques)
    if checkSalvation then
        local salvCount = 0
        local salvClasses = {}
        for className in pairs(temp_missingSalvaguardaClasses) do
            table.insert(salvClasses, className)
            salvCount = salvCount + 1
        end
        if salvCount > 0 then
            local header = (Assignments.PALADIN_SALVAGUARDA and Assignments.PALADIN_SALVAGUARDA ~= "") and
                Assignments.PALADIN_SALVAGUARDA or "Salvaguarda"
            SendRaidReport(string.format("[%s] Falta SALVAGUARDA a: %s.", header, table.concat(salvClasses, ", ")))
            alertCount = alertCount + 1
        end
    end

    -- Reportar faltas de Guerrero (Grito)
    if checkWarrior then
        if #temp_missingGrito > 0 then
            local header = (Assignments.WARRIOR_GRITO and Assignments.WARRIOR_GRITO ~= "") and Assignments.WARRIOR_GRITO or
                "Grito"
            SendRaidReport(string.format("[%s] Falta GRITO DE BATALLA.", header))
            alertCount = alertCount + 1
        end
    end

    -- Reportar faltas de Druida
    if checkDruid then
        if #temp_missingMarca > 0 then
            local header = (Assignments.DRUID_MARCA and Assignments.DRUID_MARCA ~= "") and Assignments.DRUID_MARCA or
                "DruidaMarca"
            SendRaidReport(string.format("[%s] Falta DON DE LO SALVAJE.", header))
            alertCount = alertCount + 1
        end
    end

    -- Reportar faltas de Intelecto de Magos
    if checkMage then
        if #temp_missingIntelecto > 0 then
            local header = (Assignments.MAGE_INTELECTO and Assignments.MAGE_INTELECTO ~= "") and
                Assignments.MAGE_INTELECTO or "MagoIntelecto"
            SendRaidReport(string.format("[%s] Falta INTELECTO.", header))
            alertCount = alertCount + 1
        end
    end

    -- Reportar faltas de Sacerdotes o Pergaminos (Rezados de Entereza, Sombra y Espíritu a nivel global)
    if checkPriest then
        local isScrollMode = (Assignments.PERGAMINOS and Assignments.PERGAMINOS ~= "")
        local header = "Sacerdote"
        if Assignments.PRIEST and Assignments.PRIEST ~= "" then
            header = Assignments.PRIEST
        elseif isScrollMode then
            header = Assignments.PERGAMINOS
        end

        if isScrollMode then
            -- Modo Pergaminos: UN SOLO mensaje como Tambores (bufo de banda completo de una vez)
            if temp_priestMissing.Entereza > 0 or temp_priestMissing.Sombra > 0 or temp_priestMissing.Espiritu > 0 then
                SendRaidReport(string.format("[%s] Falta Pergamino.", header))
                alertCount = alertCount + 1
            end
        else
            -- Modo Sacerdote: avisar qué bufo falta
            if temp_priestMissing.Entereza > 0 then
                SendRaidReport(string.format("[%s] Falta ENTEREZA.", header))
                alertCount = alertCount + 1
            end
            if temp_priestMissing.Sombra > 0 then
                SendRaidReport(string.format("[%s] Falta SOMBRA.", header))
                alertCount = alertCount + 1
            end
            if temp_priestMissing.Espiritu > 0 then
                SendRaidReport(string.format("[%s] Falta ESPÍRITU.", header))
                alertCount = alertCount + 1
            end
        end
    end

    -- Reportar faltas de Magos
    if #temp_mageReports > 0 then
        for j = 1, #temp_mageReports do
            SendRaidReport(temp_mageReports[j])
            alertCount = alertCount + 1
        end
    end

    -- Si todos los beneficios requeridos están correctos, imprimir reporte de conformidad local y emitir reporte a la banda
    if alertCount == 0 then
        local broadcastMsg = "¡Todos los beneficios de banda están al día!"
        if activePaladins == 0 or activePriests == 0 or activeDruids == 0 or activeMages == 0 then
            local missingClasses = {}
            if activePaladins == 0 then table.insert(missingClasses, "Paladín") end
            if activePriests == 0 then table.insert(missingClasses, "Sacerdote") end
            if activeDruids == 0 then table.insert(missingClasses, "Druida") end
            if activeMages == 0 then table.insert(missingClasses, "Mago") end
            broadcastMsg = "¡Todos los beneficios de las clases presentes están al día! (Sin: " ..
                table.concat(missingClasses, ", ") .. ")"
        end

        -- Informar a toda la banda del estado exitoso de los bufos
        SendRaidReport(broadcastMsg)
    end
end


-- CAPA 5: INTERFAZ DE USUARIO Y CONFIGURACIÓN (FRAME XML/API)

-- Frame de configuración de opciones de asignación en juego (RBCConfigFrame)
local configFrame = nil
local resultsFrame = nil
local editBoxes = {}
local resultsReportText = nil
local resultsScrollChild = nil

-- Frame contenedor reutilizable para el menú desplegable (EasyMenu)
local menuFrame = CreateFrame("Frame", "RBC_EasyMenuFrame", UIParent, "UIDropDownMenuTemplate")

-- Función para formatear los resultados del escaneo silencioso y colorearlos según la clase
local function FormatTrackingReport(results)
    local lines = {}

    -- Función auxiliar para dar formato
    local function AddSection(title, list, titleColorHex, emptyMsg)
        table.insert(lines, string.format("|cff%s%s|r", titleColorHex, title))
        if #list == 0 then
            table.insert(lines, "  " .. (emptyMsg or "|cff00ff00¡Todos con bufo!|r") .. "\n")
        else
            -- Mostrar lista de nombres ordenados alfabéticamente
            table.sort(list)
            table.insert(lines, "  |cffff3333Faltan:|r " .. table.concat(list, ", ") .. "\n")
        end
    end

    -- 1. Reyes / Tambores (siempre se muestra)
    local reyesLabel
    if Assignments.TAMBORES and Assignments.TAMBORES ~= "" then
        reyesLabel = "Tambores / Reyes"
    elseif Assignments.PALADIN_REYES and Assignments.PALADIN_REYES ~= "" then
        reyesLabel = "Bendición de Reyes"
    else
        reyesLabel = "Reyes / Tambores"
    end
    AddSection(reyesLabel, results.Reyes, "f48cba")

    -- 2. Sabiduría
    local sabiEmptyMsg = (results.Eligible.Mana == 0) and "|cff999999(Sin clases de maná)|r" or nil
    AddSection("Bendición de Sabiduría", results.Sabiduria, "f48cba", sabiEmptyMsg)

    -- 3. Poderío
    local poderEmptyMsg = (results.Eligible.Physical == 0) and "|cff999999(Sin clases físicas)|r" or nil
    AddSection("Bendición de Poderío", results.Poder, "f48cba", poderEmptyMsg)

    -- 3b. Salvaguarda
    local salvEmptyMsg = (results.Eligible.Physical == 0) and "|cff999999(Sin clases físicas)|r" or nil
    AddSection("Bendición de Salvaguarda", results.Salvaguarda, "f48cba", salvEmptyMsg)

    -- 3c. Grito de batalla
    local gritoEmptyMsg = (results.Eligible.Physical == 0) and "|cff999999(Sin clases físicas)|r" or nil
    AddSection("Grito de Batalla", results.Grito, "c79c6e", gritoEmptyMsg)

    -- 4. Don de lo Salvaje
    AddSection("Don de lo Salvaje", results.Marca, "ff7d0a")

    -- 5. Luminosidad Arcana / Intelecto
    local intEmptyMsg = (results.Eligible.Mana == 0) and "|cff999999(Sin clases de maná)|r" or nil
    AddSection("Luminosidad Arcana", results.Intelecto, "69ccf0", intEmptyMsg)

    -- 6. Sacerdote (Entereza, Sombra, Espíritu)
    table.insert(lines, "|cffffff78Bufos de Sacerdote|r")

    if #results.Entereza == 0 then
        table.insert(lines, "  Entereza: |cff00ff00¡Al día!|r")
    else
        table.sort(results.Entereza)
        table.insert(lines, "  Entereza: |cffff3333Faltan:|r " .. table.concat(results.Entereza, ", "))
    end

    if #results.Sombra == 0 then
        table.insert(lines, "  Sombra: |cff00ff00¡Al día!|r")
    else
        table.sort(results.Sombra)
        table.insert(lines, "  Sombra: |cffff3333Faltan:|r " .. table.concat(results.Sombra, ", "))
    end

    if #results.Espiritu == 0 then
        table.insert(lines, "  Espíritu: |cff00ff00¡Al día!|r\n")
    else
        table.sort(results.Espiritu)
        table.insert(lines, "  Espíritu: |cffff3333Faltan:|r " .. table.concat(results.Espiritu, ", ") .. "\n")
    end

    -- 7. Enfoques de Magia (solo si hay 2+ magos activos)
    if results.MagesFocusReport and #results.MagesFocusReport > 0 then
        table.insert(lines, "|cff69ccf0Enfoques de Magia (Magos)|r")
        for _, msg in ipairs(results.MagesFocusReport) do
            local cleanMsg = msg:gsub("^%[MAGOS%]%s*", "")
            table.insert(lines, "  " .. cleanMsg)
        end
    end

    return table.concat(lines, "\n")
end

-- Función para crear la interfaz de menú de configuración de manera dinámica e interactiva
local function CreateRBCConfigMenu()
    if configFrame then return end

    -- Panel principal del menú
    configFrame = CreateFrame("Frame", "RBCConfigFrame", UIParent)
    configFrame:SetSize(360, 640)

    -- Permitir cerrar la ventana presionando la tecla Escape (Escape exit)
    tinsert(UISpecialFrames, "RBCConfigFrame")
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    configFrame:SetClampedToScreen(true)
    configFrame:EnableMouse(true)
    configFrame:SetMovable(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)

    -- Diseño estético Premium del fondo y bordes de la ventana (Estilo cristal/oscuro premium)
    configFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    configFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)      -- Gris oscuro azulado semitransparente
    configFrame:SetBackdropBorderColor(0.85, 0.65, 0.15, 0.9) -- Borde dorado elegante

    -- Título de la ventana
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -18)
    title:SetText("RaidBuffChecker - Asignaciones")
    title:SetTextColor(0.95, 0.75, 0.1, 1) -- Dorado brillante

    -- Subtítulo explicativo
    local subtitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText("Escribe o selecciona los jugadores de la banda:")
    subtitle:SetTextColor(0.8, 0.8, 0.8, 0.9)

    -- Tabla de campos a configurar (9 campos en total)
    local fields = {
        { key = "PALADIN_REYES",       label = "Paladín (Reyes):",       color = { 0.96, 0.55, 0.73 } },
        { key = "PALADIN_SABIDURIA",   label = "Paladín (Sabiduría):",   color = { 0.96, 0.55, 0.73 } },
        { key = "PALADIN_PODER",       label = "Paladín (Poderío):",     color = { 0.96, 0.55, 0.73 } },
        { key = "PALADIN_SALVAGUARDA", label = "Paladín (Salvaguarda):", color = { 0.96, 0.55, 0.73 } },
        { key = "PRIEST",              label = "Sacerdote:",             color = { 1.0, 1.0, 1.0 } },
        { key = "DRUID_MARCA",         label = "Druida (Marca):",        color = { 1.0, 0.49, 0.04 } },
        { key = "MAGE_INTELECTO",      label = "Mago (Intelecto):",      color = { 0.25, 0.78, 0.92 } },
        { key = "WARRIOR_GRITO",       label = "Guerrero (Grito):",      color = { 0.78, 0.61, 0.43 } },
        { key = "MAGE_IGNORE_LIST",    label = "Ignorar Magos:",         color = { 0.25, 0.78, 0.92 } },
        { key = "TAMBORES",            label = "Tambores:",              color = { 0.2, 0.8, 0.2 } },
        { key = "PERGAMINOS",          label = "Pergaminos:",            color = { 0.2, 0.8, 0.2 } }
    }

    local yOffset = -70
    for i, field in ipairs(fields) do
        -- Crear etiqueta de texto para el beneficio con color temático de clase
        local label = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 24, yOffset - 4)
        label:SetText(field.label)
        label:SetTextColor(field.color[1], field.color[2], field.color[3], 0.9)

        -- Crear caja de entrada de texto (EditBox) personalizada sin plantillas problemáticas
        local editBox = CreateFrame("EditBox", nil, configFrame)
        editBox:SetSize(112, 24)
        editBox:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -84, yOffset)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetText(Assignments[field.key] or "")
        editBox:SetTextInsets(6, 6, 0, 0) -- Padding interno para que el texto no choque con los bordes

        -- Fondo y contorno minimalista moderno para la caja de texto (Evita solapamientos)
        editBox:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        editBox:SetBackdropColor(0, 0, 0, 0.6)
        editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

        -- Quitar el foco de la caja de texto al presionar Escape o Enter para liberar los controles del juego
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)

        -- Guardar automáticamente en tiempo real las asignaciones ante cualquier cambio de texto (escrito o seleccionado)
        editBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            text = text:gsub("^%s*(.-)%s*$", "%1") -- trim spaces
            Assignments[field.key] = text
            if not RBC_SavedAssignments then RBC_SavedAssignments = {} end
            RBC_SavedAssignments[field.key] = text
        end)

        -- Guardar referencia al EditBox
        editBoxes[field.key] = editBox

        -- 1. Botón Dropdown de Flecha
        local dropBtn = CreateFrame("Button", nil, configFrame)
        dropBtn:SetSize(18, 18)
        dropBtn:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
        dropBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        dropBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
        dropBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        if field.key == "MAGE_IGNORE_LIST" then
            dropBtn:SetScript("OnClick", function(self)
                local menuList = {
                    { text = "Añadir magos a ignorar", isTitle = true, notCheckable = true }
                }

                local numRaid = GetNumRaidMembers()
                if numRaid > 0 then
                    for r = 1, numRaid do
                        local name, _, _, _, _, fileName, _, online = GetRaidRosterInfo(r)
                        if name and fileName == "MAGE" and online then
                            table.insert(menuList, {
                                text = name,
                                notCheckable = true,
                                func = function()
                                    local currentText = editBox:GetText() or ""
                                    currentText = currentText:gsub("^%s*(.-)%s*$", "%1") -- Trim

                                    if currentText == "" then
                                        editBox:SetText(name)
                                    else
                                        -- Normalizar para evitar duplicar nombres en la lista
                                        local cleanName = string.upper(string.sub(name, 1, 1)) ..
                                            string.lower(string.sub(name, 2))
                                        local isAlreadyAdded = false

                                        local tempStr = string.gsub(currentText, ",", " ")
                                        for word in string.gmatch(tempStr, "%S+") do
                                            local existingName = string.upper(string.sub(word, 1, 1)) ..
                                                string.lower(string.sub(word, 2))
                                            if existingName == cleanName then
                                                isAlreadyAdded = true
                                                break
                                            end
                                        end

                                        if not isAlreadyAdded then
                                            editBox:SetText(currentText .. ", " .. name)
                                        end
                                    end
                                end
                            })
                        end
                    end
                end

                if #menuList == 1 then
                    table.insert(menuList, { text = "No hay magos en la banda", disabled = true, notCheckable = true })
                end

                EasyMenu(menuList, menuFrame, self, 0, 0, "MENU")
            end)
        else
            dropBtn:SetScript("OnClick", function(self)
                -- Construir dinámicamente la lista de opciones para EasyMenu
                local menuList = {
                    { text = "Seleccionar de la banda", isTitle = true, notCheckable = true }
                }

                -- Agregar opción para vaciar el campo (Útil para desasignar)
                table.insert(menuList, {
                    text = "|cff999999Desasignar|r",
                    notCheckable = true,
                    func = function()
                        editBox:SetText("")
                    end
                })

                local hasPlayers = false
                local key = field.key

                -- Función auxiliar para añadir un jugador al menú si cumple la clase requerida
                local function TryAddPlayer(name, fileName)
                    if not name or name == "" then return end
                    local isMatch = false

                    -- TAMBORES y PERGAMINOS: sin restricción de clase (cualquier jugador puede usarlos)
                    if key == "TAMBORES" or key == "PERGAMINOS" then
                        isMatch = true
                    elseif key:find("PALADIN") and fileName == "PALADIN" then
                        -- Si es un Paladín, comprobar que no esté ya asignado en otro campo de Paladín
                        local cleanName = string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
                        for otherKey, otherEditBox in pairs(editBoxes) do
                            if otherKey:find("PALADIN") and otherKey ~= key then
                                local otherText = otherEditBox:GetText() or ""
                                -- Trim
                                otherText = otherText:gsub("^%s*(.-)%s*$", "%1")
                                if otherText ~= "" then
                                    local otherClean = string.upper(string.sub(otherText, 1, 1)) ..
                                        string.lower(string.sub(otherText, 2))
                                    if otherClean == cleanName then
                                        -- Ya está asignado a otra bendición, no agregarlo a la lista
                                        return
                                    end
                                end
                            end
                        end
                        isMatch = true
                    elseif key:find("PRIEST") and fileName == "PRIEST" then
                        isMatch = true
                    elseif key:find("DRUID") and fileName == "DRUID" then
                        isMatch = true
                    elseif key:find("MAGE") and fileName == "MAGE" then
                        isMatch = true
                    elseif key:find("WARRIOR") and fileName == "WARRIOR" then
                        isMatch = true
                    end

                    if isMatch then
                        hasPlayers = true
                        table.insert(menuList, {
                            text = name,
                            notCheckable = true,
                            func = function()
                                editBox:SetText(name)
                            end
                        })
                    end
                end

                -- Escanear banda primero, luego grupo/solo
                local numRaid = GetNumRaidMembers()
                if numRaid > 0 then
                    for r = 1, numRaid do
                        local name, _, _, _, _, fileName, _, online = GetRaidRosterInfo(r)
                        if name and online then
                            TryAddPlayer(name, fileName)
                        end
                    end
                else
                    -- Fuera de banda: añadir al propio jugador
                    local _, playerClass = UnitClass("player")
                    TryAddPlayer(UnitName("player"), playerClass)

                    -- Añadir miembros del grupo si existen
                    local numParty = GetNumPartyMembers()
                    for p = 1, numParty do
                        local partyUnit = "party" .. p
                        if UnitIsConnected(partyUnit) then
                            local _, partyClass = UnitClass(partyUnit)
                            TryAddPlayer(UnitName(partyUnit), partyClass)
                        end
                    end
                end

                -- Si no se encontró ningún jugador elegible
                if not hasPlayers then
                    local className = "jugadores de esta clase"
                    if key:find("PALADIN") then
                        className = "Paladines"
                    elseif key:find("PRIEST") then
                        className = "Sacerdotes"
                    elseif key:find("DRUID") then
                        className = "Druidas"
                    elseif key:find("MAGE") then
                        className = "Magos"
                    elseif key:find("WARRIOR") then
                        className = "Guerreros"
                    else
                        className = "jugadores conectados"
                    end
                    table.insert(menuList,
                        { text = "No hay " .. className .. " en banda", disabled = true, notCheckable = true })
                end

                -- Abrir el menú emergente nativo
                EasyMenu(menuList, menuFrame, self, 0, 0, "MENU")
            end)
        end

        -- 2. Botón de Prohibición (Círculo rojo 🚫 para vaciar el campo)
        local resetBtn = CreateFrame("Button", nil, configFrame)
        resetBtn:SetSize(18, 18)
        resetBtn:SetPoint("LEFT", dropBtn, "RIGHT", 4, 0)

        local tex = resetBtn:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        tex:SetAllPoints()
        resetBtn:SetNormalTexture(tex)

        local hl = resetBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        hl:SetAllPoints()
        resetBtn:SetHighlightTexture(hl)

        resetBtn:SetScript("OnClick", function()
            editBox:SetText("")
        end)

        yOffset = yOffset - 40
    end

    -- Botón de Acción: Guardar
    local saveBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    saveBtn:SetSize(90, 32)
    saveBtn:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 20, 24)
    saveBtn:SetText("Guardar")
    saveBtn:SetScript("OnClick", function()
        -- Garantizar la existencia del objeto de persistencia global de Blizzard
        if not RBC_SavedAssignments then RBC_SavedAssignments = {} end

        for key, editBox in pairs(editBoxes) do
            local value = editBox:GetText()
            -- Quitar espacios al inicio y final
            value = value:gsub("^%s*(.-)%s*$", "%1")
            RBC_SavedAssignments[key] = value
            Assignments[key] = value
        end

        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RBC] ¡Asignaciones guardadas con éxito en memoria!|r")
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffffd700[RBC Nota] Para asegurar el guardado físico en disco ante una desconexión o caída del servidor, escribe /reload o sal del juego normalmente.|r")
        end
        configFrame:Hide()
    end)

    -- Botón de Acción: Limpiar (Reset)
    local clearBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(90, 32)
    clearBtn:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 24)
    clearBtn:SetText("Limpiar")
    clearBtn:SetScript("OnClick", function()
        for key, editBox in pairs(editBoxes) do
            editBox:SetText("")
        end
    end)

    -- Botón de Acción: Cancelar
    local cancelBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 32)
    cancelBtn:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -20, 24)
    cancelBtn:SetText("Cancelar")
    cancelBtn:SetScript("OnClick", function()
        configFrame:Hide()
    end)

    -- Botón de Acción: Rastrear (encima de Cancelar)
    local trackBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    trackBtn:SetSize(90, 28)
    trackBtn:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -20, 60)
    trackBtn:SetText("Rastrear >>")

    -- ==========================================
    -- CREACIÓN DEL PANEL LATERAL DE RASTREO INDEPENDIENTE (NUEVO & MOVIBLE)
    -- ==========================================
    resultsFrame = CreateFrame("Frame", "RBCResultsFrame", UIParent)
    resultsFrame:SetSize(250, 520)
    resultsFrame:SetPoint("LEFT", configFrame, "RIGHT", 8, 0)
    resultsFrame:Hide() -- Oculto por defecto

    -- Hacer el panel completamente independiente y arrastrable
    tinsert(UISpecialFrames, "RBCResultsFrame")
    resultsFrame:EnableMouse(true)
    resultsFrame:SetMovable(true)
    resultsFrame:RegisterForDrag("LeftButton")
    resultsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    resultsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    resultsFrame:SetClampedToScreen(true)

    -- Sincronizar el texto del botón Rastrear con el estado del panel
    resultsFrame:SetScript("OnShow", function()
        if trackBtn then
            trackBtn:SetText("<< Rastrear")
        end
    end)
    resultsFrame:SetScript("OnHide", function()
        if trackBtn then
            trackBtn:SetText("Rastrear >>")
        end
    end)

    -- Diseño estético Premium del fondo y bordes de la ventana lateral (Estilo cristal/oscuro premium)
    resultsFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    resultsFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    resultsFrame:SetBackdropBorderColor(0.85, 0.65, 0.15, 0.9)

    -- Título del panel lateral
    local resTitle = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resTitle:SetPoint("TOP", resultsFrame, "TOP", 0, -18)
    resTitle:SetText("Rastreo de Bufos")
    resTitle:SetTextColor(0.95, 0.75, 0.1, 1)

    -- Subtítulo descriptivo
    local resSubtitle = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resSubtitle:SetPoint("TOP", resTitle, "BOTTOM", 0, -4)
    resSubtitle:SetText("Escaneo silencioso de la banda")
    resSubtitle:SetTextColor(0.6, 0.6, 0.6, 0.9)

    -- ScrollFrame usando plantilla estándar de Blizzard
    local scrollFrame = CreateFrame("ScrollFrame", "RBCResultsScrollFrame", resultsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 16, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -32, 20)

    -- Contenedor del contenido (ScrollChild)
    resultsScrollChild = CreateFrame("Frame", "RBCResultsScrollChild", scrollFrame)
    resultsScrollChild:SetSize(200, 430)
    scrollFrame:SetScrollChild(resultsScrollChild)

    -- FontString principal de reporte
    resultsReportText = resultsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultsReportText:SetPoint("TOPLEFT", resultsScrollChild, "TOPLEFT", 0, 0)
    resultsReportText:SetWidth(190)
    resultsReportText:SetJustifyH("LEFT")
    resultsReportText:SetJustifyV("TOP")
    resultsReportText:SetWordWrap(true)
    resultsReportText:SetText("Haz clic en 'Rastrear' para iniciar el escaneo de la banda.")

    -- Acción del botón Rastrear (palanca: abre o cierra el panel)
    trackBtn:SetScript("OnClick", function()
        -- Si el panel ya está abierto, cerrarlo (toggle)
        if resultsFrame:IsShown() then
            resultsFrame:Hide()
            return
        end

        PlaySound("igQuestLogOpen")

        -- Ejecutar el escaneo en modo silencioso
        local results = ExecuteAdvancedRaidCheck(true)
        if results then
            local formattedText = FormatTrackingReport(results)
            resultsReportText:SetText(formattedText)
            resultsScrollChild:SetHeight(resultsReportText:GetHeight() + 20)
            resultsFrame:ClearAllPoints()
            resultsFrame:SetPoint("LEFT", configFrame, "RIGHT", 8, 0)
            resultsFrame:Show()
        end
    end)

    -- Sincronizar campos al mostrar la ventana principal
    configFrame:SetScript("OnShow", function()
        for key, editBox in pairs(editBoxes) do
            editBox:SetText(Assignments[key] or "")
            editBox:SetCursorPosition(0)
        end
    end)

    -- Cerrar el panel de rastreo al cerrar el menú de asignaciones
    configFrame:SetScript("OnHide", function()
        if resultsFrame and resultsFrame:IsShown() then
            resultsFrame:Hide()
        end
    end)

    -- CRÍTICO: Iniciar oculta para resolver el bug de doble clic del primer toggle
    configFrame:Hide()
end

-- Función para alternar el estado visible de la ventana de configuración
local function ToggleRBCConfigMenu()
    CreateRBCConfigMenu()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end

-- Función unificada e idempotente para cargar las variables guardadas
local function LoadSavedVariables()
    -- 1. Inicializar variables guardadas (SavedVariables) de Blizzard de manera defensiva
    if not RBC_SavedAssignments then
        RBC_SavedAssignments = {}
        for k, v in pairs(Assignments) do
            RBC_SavedAssignments[k] = v
        end
    else
        -- Inicializar campos ausentes si existiese una base de datos antigua
        for k, v in pairs(Assignments) do
            if RBC_SavedAssignments[k] == nil then
                RBC_SavedAssignments[k] = v
            end
        end
    end
    -- Copiar explícitamente todos los valores a la tabla local Assignments para sincronización perfecta de referencias
    for k, v in pairs(RBC_SavedAssignments) do
        Assignments[k] = v
    end

    -- 2. Inicializar posición guardada del botón
    if not RBC_ButtonPosition then
        RBC_ButtonPosition = { relX = nil, relY = nil }
    end

    -- 3. Resolver nombres localizados de hechizos
    InitializeSpellNames()
end

-- CARGA INMEDIATA: Como las SavedVariables ya están cargadas en el entorno global de WoW antes de ejecutar
-- este archivo Lua, llamamos al cargador inmediatamente para garantizar que estén listas sin depender de eventos.
LoadSavedVariables()

-- Registro y manejo de eventos del cargador para persistencia y seguridad adicional
local eventLoader = CreateFrame("Frame")
eventLoader:RegisterEvent("ADDON_LOADED")
eventLoader:RegisterEvent("PLAYER_LOGOUT")
eventLoader:RegisterEvent("PLAYER_REGEN_DISABLED")
eventLoader:RegisterEvent("RAID_ROSTER_UPDATE")
eventLoader:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        -- Soporta que la carpeta se llame 'bufos' o 'RaidBuffChecker' (sensible a mayúsculas/minúsculas)
        local lowerName = string.lower(addonName)
        if lowerName == "bufos" or lowerName == "raidbuffchecker" then
            LoadSavedVariables()
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Garantizar el guardado físico de la configuración al salir/reloguear de forma ultra segura
        if not RBC_SavedAssignments then RBC_SavedAssignments = {} end
        for k, v in pairs(Assignments) do
            RBC_SavedAssignments[k] = v
        end
        -- Guardar posición del botón
        if rbcButton then
            local cx, cy = rbcButton:GetCenter()
            local parentW = rbcButton:GetParent():GetWidth()
            local parentH = rbcButton:GetParent():GetHeight()
            if cx and cy and parentW > 0 and parentH > 0 then
                if not RBC_ButtonPosition then RBC_ButtonPosition = {} end
                RBC_ButtonPosition.relX = cx / parentW
                RBC_ButtonPosition.relY = cy / parentH
            end
        end
        -- Guardar posición del botón de minimapa
        if minimapButton then
            local cx, cy = minimapButton:GetCenter()
            if cx and cy then
                local mx, my = Minimap:GetCenter()
                if mx and my then
                    local dx = cx - mx
                    local dy = cy - my
                    if not RBC_ButtonPosition then RBC_ButtonPosition = {} end
                    RBC_ButtonPosition.minimapAngle = math.atan2(dy, dx)
                end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Auto-cierre de la ventana al entrar en combate para seguridad y rendimiento
        if configFrame and configFrame:IsShown() then
            configFrame:Hide()
        end
        if resultsFrame and resultsFrame:IsShown() then
            resultsFrame:Hide()
        end
    elseif event == "RAID_ROSTER_UPDATE" then
        -- Auto-actualizar el panel de rastreo si está visible
        if resultsFrame and resultsFrame:IsShown() then
            local results = ExecuteAdvancedRaidCheck(true)
            if results and resultsReportText then
                local formattedText = FormatTrackingReport(results)
                resultsReportText:SetText(formattedText)
                if resultsScrollChild then
                    resultsScrollChild:SetHeight(resultsReportText:GetHeight() + 20)
                end
            end
        end
    end
end)

-- Crear el botón físico como icono 60x60 (sin texto, usa raidbuf.tga)
local rbcButton = CreateFrame("Button", "AdvancedBuffCheckerButton", UIParent)
rbcButton:SetSize(60, 60)
-- Restaurar posición guardada (como porcentaje del parent) o usar predeterminada
if RBC_ButtonPosition and RBC_ButtonPosition.relX and RBC_ButtonPosition.relY then
    local parentW = rbcButton:GetParent():GetWidth()
    local parentH = rbcButton:GetParent():GetHeight()
    rbcButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", RBC_ButtonPosition.relX * parentW,
        RBC_ButtonPosition.relY * parentH)
else
    rbcButton:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
end

-- Textura normal (icono del addon)
local rbcIconNormal = rbcButton:CreateTexture(nil, "ARTWORK")
rbcIconNormal:SetAllPoints(rbcButton)
rbcIconNormal:SetTexture("Interface\\Addons\\bufos\\raidbuf.tga")
rbcButton:SetNormalTexture(rbcIconNormal)

-- Textura de highlight (brillo al pasar el mouse)
local rbcIconHighlight = rbcButton:CreateTexture(nil, "HIGHLIGHT")
rbcIconHighlight:SetAllPoints(rbcButton)
rbcIconHighlight:SetTexture("Interface\\Addons\\bufos\\raidbuf.tga")
rbcIconHighlight:SetVertexColor(1.3, 1.3, 1.3, 1)
rbcButton:SetHighlightTexture(rbcIconHighlight)

-- Textura pushed (al hacer clic)
local rbcIconPushed = rbcButton:CreateTexture(nil, "ARTWORK")
rbcIconPushed:SetAllPoints(rbcButton)
rbcIconPushed:SetTexture("Interface\\Addons\\bufos\\raidbuf.tga")
rbcIconPushed:SetVertexColor(0.7, 0.7, 0.7, 1)
rbcButton:SetPushedTexture(rbcIconPushed)

rbcButton:SetClampedToScreen(true) -- Evita arrastrar el botón fuera del área de renderizado visible

-- Habilitar arrastre y posicionamiento (Drag & Drop) seguro
rbcButton:SetMovable(true)
rbcButton:EnableMouse(true)
rbcButton:RegisterForDrag("LeftButton")

-- Comportamiento de arrastre seguro, condicionado estrictamente a pulsar Shift para evitar moverlo en combate accidentalmente
rbcButton:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)

rbcButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local parentW = self:GetParent():GetWidth()
    local parentH = self:GetParent():GetHeight()
    if cx and cy and parentW > 0 and parentH > 0 then
        RBC_ButtonPosition = RBC_ButtonPosition or {}
        RBC_ButtonPosition.relX = cx / parentW
        RBC_ButtonPosition.relY = cy / parentH
    end
end)

-- Habilitar clics izquierdos y derechos en el botón físico
rbcButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Vincular clics: izquierdo para escanear y derecho/Alt-Clic para abrir la ventana de configuración
rbcButton:SetScript("OnClick", function(self, buttonPressed)
    if IsAltKeyDown() then
        ToggleRBCConfigMenu()
    elseif buttonPressed == "LeftButton" then
        ExecuteAdvancedRaidCheck()
    elseif buttonPressed == "RightButton" then
        ToggleRBCConfigMenu()
    end
end)

-- Agregar Tooltip informativo de alta calidad (UX excelente)
rbcButton:SetScript("OnEnter", function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("RaidBuffChecker (v3.3.5a)", 1, 0.82, 0)
        GameTooltip:AddLine("Clic izquierdo: Escanear beneficios de banda (G1-G5).", 1, 1, 1)
        GameTooltip:AddLine("Clic derecho o Alt + Clic: Configurar asignaciones.", 0, 1, 0.5)
        GameTooltip:AddLine("Shift + Arrastrar: Reposicionar el botón.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end
end)

rbcButton:SetScript("OnLeave", function(self)
    if GameTooltip then
        GameTooltip:Hide()
    end
end)

-- ==========================================
-- BOTÓN DE MINIMAPA (acceso rápido alternativo)
-- ==========================================
local minimapButton = CreateFrame("Button", "raidbuffcheckerMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")

-- Icono del botón
local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexture("Interface\\Addons\\bufos\\raidbuf.tga")
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

-- Borde redondo tipo minimapa
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Posicionar alrededor del minimapa según ángulo guardado
local function SetMinimapButtonPosition()
    local angle = (RBC_ButtonPosition and RBC_ButtonPosition.minimapAngle) or 0
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Arrastre para re-posicionar alrededor del minimapa
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local cx, cy = Minimap:GetCenter()
        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        mx, my = mx / scale, my / scale
        local currentAngle = math.atan2(my - cy, mx - cx)
        if not RBC_ButtonPosition then RBC_ButtonPosition = {} end
        RBC_ButtonPosition.minimapAngle = currentAngle
        SetMinimapButtonPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- Clics: izquierdo/derecho alternan visibilidad del botón flotante
minimapButton:SetScript("OnClick", function()
    if rbcButton then
        if rbcButton:IsShown() then
            rbcButton:Hide()
        else
            rbcButton:Show()
        end
    end
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function(self)
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("RaidBuffChecker", 1, 0.82, 0)
        GameTooltip:AddLine("Clic: Mostrar/ocultar botón Escanear Banda.", 1, 1, 1)
        GameTooltip:AddLine("Arrastrar: Re-posicionar alrededor del minimapa.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end
end)
minimapButton:SetScript("OnLeave", function(self)
    if GameTooltip then
        GameTooltip:Hide()
    end
end)

SetMinimapButtonPosition()

-- Registrar comando de barra /rbc mediante arrays globales clásicos de Blizzard
SLASH_ADVANCEDBUFFCHECKER1 = "/rbc"
SlashCmdList["ADVANCEDBUFFCHECKER"] = function(msg)
    msg = msg:lower():gsub("^%s*(.-)%s*$", "%1")
    if msg == "config" or msg == "menu" or msg == "opciones" then
        ToggleRBCConfigMenu()
    elseif msg == "ver" or msg == "version" then
        local version = GetAddOnMetadata("bufos", "Version") or "1.0"
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RBC]|r Versión: " .. version)
        end
    else
        ExecuteAdvancedRaidCheck()
    end
end

-- Registrar comando /kamin como alias directo para abrir la ventana de configuración
SLASH_RBCKAMIN1 = "/kmin"
SlashCmdList["RBCKAMIN"] = function()
    ToggleRBCConfigMenu()
end

-- Registrar comando /ver como alias directo para mostrar la versión
SLASH_RBCVERSION1 = "/ver"
SlashCmdList["RBCVERSION"] = function()
    local version = GetAddOnMetadata("bufos", "Version") or GetAddOnMetadata("RaidBuffChecker", "Version") or "1.0"
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RBC]|r Versión: " .. version)
    end
end
