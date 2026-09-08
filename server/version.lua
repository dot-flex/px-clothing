if not ClothingProtection or not ClothingProtection.ready then return end

local settings = Config.VersionCheck
local resource = GetCurrentResourceName()

local function notice(message)
    print(('^3[px-clothing] %s^7'):format(message))
end

if type(settings) ~= 'table' or settings.enabled == false then
    notice(('Version checker disabled | Installed: %s'):format(tostring(GetResourceMetadata(resource, 'version', 0))))
    return
end
local repository = settings.repository

if type(repository) ~= 'string' or #repository > 140 or not repository:match('^[%w][%w%-]*/[%w_.%-]+$') or repository:find('..', 1, true) then
    notice('Version checker disabled: set Config.VersionCheck.repository to a GitHub owner/repository.')
    return
end

local function identifiers(value, prerelease)
    if value == '' or value:find('..', 1, true) or value:sub(1, 1) == '.' or value:sub(-1) == '.' or value:find('[^%w.%-]') then return end
    local result = {}
    for part in value:gmatch('[^.]+') do
        if prerelease and part:match('^%d+$') and #part > 1 and part:sub(1, 1) == '0' then return end
        result[#result + 1] = part
    end
    return result
end

local function version(value)
    if type(value) ~= 'string' or #value > 96 then return end
    local plain, build = value:match('^([^+]+)%+(.+)$')
    if value:find('+', 1, true) then
        if not plain or not identifiers(build, false) then return end
        value = plain
    end
    local major, minor, patch, suffix = value:match('^v?(%d+)%.(%d+)%.(%d+)(.*)$')
    if not major then return end
    local result = { major, minor, patch }
    for _, part in ipairs(result) do if #part > 1 and part:sub(1, 1) == '0' then return end end
    if suffix ~= '' then
        if suffix:sub(1, 1) ~= '-' then return end
        result.pre = identifiers(suffix:sub(2), true)
        if not result.pre then return end
    end
    return result
end

local function compareNumber(a, b)
    if #a ~= #b then return #a > #b and 1 or -1 end
    if a == b then return 0 end
    return a > b and 1 or -1
end

local function newer(remote, current)
    for index = 1, 3 do
        local comparison = compareNumber(remote[index], current[index])
        if comparison ~= 0 then return comparison > 0 end
    end
    if not remote.pre then return current.pre ~= nil end
    if not current.pre then return false end
    for index = 1, math.max(#remote.pre, #current.pre) do
        local a, b = remote.pre[index], current.pre[index]
        if not a then return false end
        if not b then return true end
        if a ~= b then
            local numericA, numericB = a:match('^%d+$'), b:match('^%d+$')
            if numericA and numericB then return compareNumber(a, b) > 0 end
            if numericA then return false end
            if numericB then return true end
            return a > b
        end
    end
    return false
end

local installed = GetResourceMetadata(resource, 'version', 0)
local current = version(installed)
if not current then notice('Version checker disabled: fxmanifest.lua needs a semantic version such as 1.0.0.'); return end
local hours = tonumber(settings.intervalHours) or 24
if hours ~= hours or hours < 0 or hours > 168 then hours = 24 end
local interval = hours == 0 and 0 or math.max(1, hours) * 3600000
local seconds = tonumber(settings.timeoutSeconds) or 10
if seconds ~= seconds or seconds < 3 or seconds > 30 then seconds = 10 end
notice(('Version checker enabled | Installed: %s | Repository: %s'):format(installed, repository))
local lastNotice, stopped = nil, false
AddEventHandler('onResourceStop', function(name) if name == resource then stopped = true end end)

local function report(key, message)
    if key == lastNotice then return end
    lastNotice = key
    notice(message)
end

local check
check = function()
    if stopped then return end
    local complete = false
    local function finish(status, body)
        if complete or stopped then return end
        complete = true
        if interval > 0 then SetTimeout(interval, check) end
        if status ~= 200 then
            local reason = status == 404 and 'repository or published stable release not found' or (status == 403 or status == 429) and 'GitHub rate limit or access denied' or status == 0 and 'request failed or timed out' or 'GitHub request failed'
            report('http:' .. tostring(status), 'Update check unavailable: ' .. reason .. '. Clothing remains available.')
            return
        end
        if type(body) ~= 'string' or #body > 1048576 then report('invalid', 'Update check ignored an invalid GitHub response.'); return end
        local decoded, release = pcall(json.decode, body)
        local remote = decoded and type(release) == 'table' and version(release.tag_name)
        if not remote or release.draft ~= false or release.prerelease ~= false then
            report('invalid', 'Update check requires a published stable release with a semantic version tag.'); return
        end
        if newer(remote, current) then
            report('update:' .. release.tag_name, ('Update available: %s -> %s | https://github.com/%s/releases/latest'):format(installed, release.tag_name, repository))
        elseif newer(current, remote) then
            report('ahead:' .. release.tag_name, ('Version check complete | Installed: %s | Latest: %s | Installed version is newer than the latest release.'):format(installed, release.tag_name))
        else
            report('current:' .. release.tag_name, ('Up to date | Installed: %s | Latest: %s'):format(installed, release.tag_name))
        end
    end
    SetTimeout(seconds * 1000, function() finish(0) end)
    local ok = pcall(PerformHttpRequest, 'https://api.github.com/repos/' .. repository .. '/releases/latest', finish, 'GET', '', {
        ['Accept'] = 'application/vnd.github+json',
        ['User-Agent'] = 'px-clothing-version-check',
        ['X-GitHub-Api-Version'] = '2022-11-28'
    }, { followLocation = false })
    if not ok then finish(0) end
end

SetTimeout(5000, check)
