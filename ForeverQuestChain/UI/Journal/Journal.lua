local _, ns = ...

local Journal = {}
Journal.__index = Journal
ns.Journal = Journal

function Journal.New(playerClass)
    local search = { tab = "search", page = "search" }
    return setmetatable({ route = search, tabs = {
        search = search,
        zones = { tab = "zones", page = "locations", kind = "zones" },
        dungeons = { tab = "dungeons", page = "locations", kind = "dungeons" },
        classes = { tab = "classes", page = "quests", kind = "classes", key = playerClass },
        activeChains = { tab = "activeChains", page = "activeChains" },
    } }, Journal)
end

function Journal:Visit(route)
    self.route = route
    self.tabs[route.tab] = route
end

function Journal:SelectTab(tab)
    self:Visit(self.tabs[tab])
end

function Journal:OpenSearch()
    self:Visit({ tab = "search", page = "search" })
end

function Journal:OpenLocations(kind)
    if kind == "classes" then return self:SelectTab(kind) end
    self:Visit({ tab = kind, page = "locations", kind = kind })
end

function Journal:OpenCategory(kind, key, section)
    self:Visit({ tab = kind, page = section or "quests", kind = kind, key = key })
end

function Journal:OpenQuest()
    if self.route.page == "chain" then return end
    self.returnRoute = self.route
    self.route = { tab = self.route.tab, page = "chain" }
end

function Journal:Back()
    self:Visit(self.returnRoute or self.tabs[self.route.tab])
end
