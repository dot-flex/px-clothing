ClothingProtection = { ready = false }
local resource = GetCurrentResourceName()

local function reject(reason)
    print(('^1[px-clothing] Startup blocked: %s^7'):format(reason))
    SetTimeout(0, function() StopResource(resource) end)
end

if resource ~= 'px-clothing' then
    reject('The resource folder must be named exactly px-clothing. Rename it, refresh resources and ensure px-clothing.')
    return
end

local constants = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function rotate(value, bits)
    return ((value >> bits) | (value << (32 - bits))) & 0xffffffff
end

local function sha256(value)
    local length = #value
    value = value .. string.char(128) .. string.rep(string.char(0), (55 - length) % 64) .. string.pack('>I8', length * 8)
    local hash = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    local words = {}
    for offset = 1, #value, 64 do
        for index = 1, 16 do words[index] = string.unpack('>I4', value, offset + (index - 1) * 4) end
        for index = 17, 64 do
            local a, b = words[index - 15], words[index - 2]
            local s0 = rotate(a, 7) ~ rotate(a, 18) ~ (a >> 3)
            local s1 = rotate(b, 17) ~ rotate(b, 19) ~ (b >> 10)
            words[index] = (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff
        end
        local a, b, c, d, e, f, g, h = table.unpack(hash)
        for index = 1, 64 do
            local s1 = rotate(e, 6) ~ rotate(e, 11) ~ rotate(e, 25)
            local choice = (e & f) ~ ((~e) & g)
            local t1 = (h + s1 + choice + constants[index] + words[index]) & 0xffffffff
            local s0 = rotate(a, 2) ~ rotate(a, 13) ~ rotate(a, 22)
            local majority = (a & b) ~ (a & c) ~ (b & c)
            h, g, f, e, d, c, b, a = g, f, e, (d + t1) & 0xffffffff, c, b, a, (t1 + s0 + majority) & 0xffffffff
        end
        local block = { a, b, c, d, e, f, g, h }
        for index = 1, 8 do hash[index] = (hash[index] + block[index]) & 0xffffffff end
    end
    for index = 1, 8 do hash[index] = ('%08x'):format(hash[index]) end
    return table.concat(hash)
end

local function verify()
    local raw = LoadResourceFile(resource, 'data/integrity.json')
    if not raw or #raw > 1048576 then return false, 'Missing or invalid data/integrity.json. Reinstall the complete release.' end
    local valid, catalog = pcall(json.decode, raw)
    if not valid or type(catalog) ~= 'table' or catalog.schema ~= 1 or type(catalog.files) ~= 'table' or #catalog.files == 0 then
        return false, 'Invalid integrity catalog. Reinstall the complete release.'
    end
    local seen = {}
    for _, file in ipairs(catalog.files) do
        if type(file) ~= 'table' or type(file.path) ~= 'string' or not file.path:match('^[%w_./%-]+$') or file.path:sub(1, 1) == '/' or file.path:find('..', 1, true) or seen[file.path] then
            return false, 'Invalid integrity catalog entry. Reinstall the complete release.'
        end
        seen[file.path] = true
        local contents = LoadResourceFile(resource, file.path)
        if not contents or #contents == 0 then return false, ('Missing or empty file: %s. Reinstall the complete release.'):format(file.path) end
        if file.mode == 'text' or file.mode == 'binary' then
            if type(file.sha256) ~= 'string' or #file.sha256 ~= 64 or not file.sha256:match('^[a-f0-9]+$') then return false, 'Invalid integrity checksum.' end
            if file.mode == 'text' then contents = contents:gsub('^' .. string.char(239, 187, 191), ''):gsub('\r\n', '\n') end
            if sha256(contents) ~= file.sha256 then return false, ('Changed or damaged file: %s. Restore it from the same release.'):format(file.path) end
        elseif file.mode == 'size' then
            if type(file.bytes) ~= 'number' or #contents ~= file.bytes then return false, ('Incomplete asset: %s. Reinstall the complete release.'):format(file.path) end
        else
            return false, 'Unsupported integrity catalog entry.'
        end
    end
    for _, file in ipairs({ 'fxmanifest.lua', 'server/protection.lua', 'server/version.lua', 'server/main.lua', 'client/main.lua', 'web/app.js', 'web/index.html', 'data/tattoos.json' }) do
        if not seen[file] then return false, 'Incomplete integrity catalog. Reinstall the complete release.' end
    end
    if type(Config) ~= 'table' or type(Appearance) ~= 'table' or type(ClothingLocale) ~= 'table' or type(ClothingFramework) ~= 'table' or type(ClothingIllenium) ~= 'table' or type(ClothingTattoos) ~= 'table' then
        return false, 'A required shared module failed to load. Check earlier startup errors.'
    end
    if Config.Framework ~= 'auto' and Config.Framework ~= 'esx' and Config.Framework ~= 'qb' and Config.Framework ~= 'qbox' then
        return false, 'Config.Framework must be auto, esx, qb or qbox.'
    end
    return true
end

local ok, valid, reason = pcall(verify)
if not ok then reject('Integrity verification failed. Reinstall the complete release.'); return end
if not valid then reject(reason); return end
ClothingProtection.ready = true
