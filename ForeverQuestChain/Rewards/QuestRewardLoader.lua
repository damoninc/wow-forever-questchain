local _, ns = ...

---@class QuestRewardLoader
local QuestRewardLoader = {}
QuestRewardLoader.__index = QuestRewardLoader
ns.QuestRewardLoader = QuestRewardLoader

---@param state QuestRewardState
---@return QuestRewardView
local function emptyView(state)
    return {
        xp = { state = state },
        copper = { state = state },
        guaranteed = { state = state },
        choices = { state = state },
    }
end

---@param gateway QuestRewardGateway
---@param schedule fun(delaySeconds: number, callback: fun())
---@param onUpdate fun(questId: integer, view: QuestRewardView)
---@return QuestRewardLoader
function QuestRewardLoader.New(gateway, schedule, onUpdate)
    return setmetatable({
        gateway = gateway,
        schedule = schedule,
        onUpdate = onUpdate,
        cache = {},
        pending = {},
    }, QuestRewardLoader)
end

function QuestRewardLoader:Get(id)
    local entry = self.cache[id]
    return entry and entry.view or emptyView("unavailable")
end

---@private
function QuestRewardLoader:Finish(id, view, retry)
    self.pending[id] = nil
    self.cache[id] = { view = view, retry = retry }
    if self.selected == id then
        self.onUpdate(id, view)
    end
end

function QuestRewardLoader:Select(id)
    self.selected = id
    local cached = self.cache[id]
    if cached and not cached.retry then
        return cached.view
    end

    local ready = self.gateway:Read(id, false)
    if ready then
        self.cache[id] = { view = ready }
        return ready
    end

    local request = {}
    self.pending[id] = request
    self.cache[id] = { view = emptyView("loading") }
    self.schedule(3, function()
        if self.pending[id] == request then
            local result = self.gateway:Read(id, false)
            self:Finish(id, result or emptyView("unavailable"), not result)
        end
    end)
    self.gateway:Request(id)
    return self:Get(id)
end

function QuestRewardLoader:OnQuestDataLoaded(id, success)
    if not self.pending[id] then
        return
    end
    local result = success and self.gateway:Read(id, true)
    self:Finish(id, result or emptyView("unavailable"), not result)
end

function QuestRewardLoader:Invalidate(id)
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
