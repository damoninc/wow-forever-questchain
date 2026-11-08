local _, ns = ...

local Rewards = {}
Rewards.__index = Rewards
ns.Rewards = Rewards

local function emptyView(state)
    return {
        xp = { state = state },
        copper = { state = state },
        guaranteed = { state = state },
        choices = { state = state },
    }
end

function Rewards.New(api, onUpdate)
    return setmetatable({
        api = api,
        onUpdate = onUpdate,
        cache = {},
        pending = {},
    }, Rewards)
end

function Rewards:Get(id)
    local entry = self.cache[id]
    return entry and entry.view or emptyView("unavailable")
end

function Rewards:Finish(id, view, retry)
    self.pending[id] = nil
    self.cache[id] = { view = view, retry = retry }
    if self.selected == id then
        self.onUpdate(id, view)
    end
end

function Rewards:Select(id)
    self.selected = id
    local cached = self.cache[id]
    if cached and not cached.retry then
        return cached.view
    end

    local ready = self.api.read(id, false)
    if ready then
        self.cache[id] = { view = ready }
        return ready
    end

    local request = {}
    self.pending[id] = request
    self.cache[id] = { view = emptyView("loading") }
    self.api.after(3, function()
        if self.pending[id] == request then
            local result = self.api.read(id, false)
            self:Finish(id, result or emptyView("unavailable"), not result)
        end
    end)
    self.api.request(id)
    return self:Get(id)
end

function Rewards:OnQuestDataLoaded(id, success)
    if not self.pending[id] then
        return
    end
    local result = success and self.api.read(id, true)
    self:Finish(id, result or emptyView("unavailable"), not result)
end

function Rewards:Invalidate(id)
    if id then
        self.cache[id], self.pending[id] = nil, nil
    else
        self.cache, self.pending = {}, {}
    end
    if self.selected and (not id or self.selected == id) then
        local selected = self.selected
        local result = self:Select(selected)
        self.onUpdate(selected, result)
    end
end
