local _, ns = ...

local Timeline = {}
ns.Timeline = Timeline

local margin, gap, minCardWidth, maxCardWidth = 16, 14, 112, 236
local baseCardHeight, rowGap = 67, 27
local optionalLabels = {
    breadcrumb = "Optional lead-in",
    substitute = "Prerequisite alternative",
}

local function reaches(from, target, visited)
    if from == target then
        return true
    end
    if not visited[from] then
        visited[from] = true
        for _, nextNode in ipairs(from.children) do
            if reaches(nextNode, target, visited) then
                return true
            end
        end
    end
    return false
end

function Timeline.Layout(view, viewportWidth, extraCardHeight)
    local cardHeight = baseCardHeight + (extraCardHeight or 0)
    local layout = { cards = {}, segments = {}, notes = {}, incoming = {}, width = viewportWidth, height = 0 }
    local nodes, ordered, links = {}, {}, {}
    for index, quest in ipairs(view.quests) do
        local node = { id = quest.id, order = index, rank = 1, parents = {}, children = {} }
        nodes[quest.id], ordered[index] = node, node
    end

    local function connect(edge, from, to)
        links[#links + 1] = edge
        local incoming = layout.incoming[to.id] or {}
        layout.incoming[to.id] = incoming
        incoming[#incoming + 1] = edge
        from.children[#from.children + 1] = to
        to.parents[#to.parents + 1] = from
    end

    -- The chain is already topologically ordered by its required links. Keep
    -- those links first, so an optional route cannot displace a prerequisite.
    local optional = {}
    for _, edge in ipairs(view.edges) do
        local from, to = nodes[edge.fromId], nodes[edge.toId]
        if optionalLabels[edge.kind] then
            optional[#optional + 1] = edge
        elseif from and to and from.order < to.order then
            connect(edge, from, to)
        else
            layout.hasUnorderedLinks = true
        end
    end
    for _, edge in ipairs(optional) do
        local from, to = nodes[edge.fromId], nodes[edge.toId]
        if from and to and not reaches(to, from, {}) then
            connect(edge, from, to)
            if edge.kind == "substitute" or not layout.notes[from.id] then
                layout.notes[from.id] = optionalLabels[edge.kind]
            end
        else
            layout.hasUnorderedLinks = true
        end
    end

    local queue, rows, widest = {}, {}, 0
    for _, node in ipairs(ordered) do
        node.remaining = #node.parents
        if node.remaining == 0 then
            queue[#queue + 1] = node
        end
    end
    local index = 1
    while queue[index] do
        local node = queue[index]
        index = index + 1
        local row = rows[node.rank] or {}
        rows[node.rank] = row
        row[#row + 1] = node
        widest = math.max(widest, #row)
        for _, child in ipairs(node.children) do
            child.rank = math.max(child.rank, node.rank + 1)
            child.remaining = child.remaining - 1
            if child.remaining == 0 then
                queue[#queue + 1] = child
            end
        end
    end

    layout.width = math.max(viewportWidth, 2 * margin + widest * (minCardWidth + gap) - gap)
    for rank, row in ipairs(rows) do
        for _, node in ipairs(row) do
            local total = 0
            for _, parent in ipairs(node.parents) do
                total = total + layout.cards[parent.id].center
            end
            node.preferredX = #node.parents > 0 and total / #node.parents or layout.width / 2
        end
        table.sort(row, function(a, b)
            if a.preferredX == b.preferredX then
                return a.order < b.order
            end
            return a.preferredX < b.preferredX
        end)
        local width = math.min(maxCardWidth, math.floor((layout.width - 2 * margin - gap * (#row - 1)) / #row))
        local left = math.floor((layout.width - #row * width - (#row - 1) * gap) / 2)
        local y = (rank - 1) * (cardHeight + rowGap)
        for column, node in ipairs(row) do
            local x = left + (column - 1) * (width + gap)
            layout.cards[node.id] = { x = x, y = y, width = width, height = cardHeight, center = x + width / 2 }
        end
        layout.height = y + cardHeight
    end

    local function segment(x1, y1, x2, y2, isOptional)
        if x1 ~= x2 or y1 ~= y2 then
            layout.segments[#layout.segments + 1] = {
                x1 = math.min(x1, x2), y1 = math.min(y1, y2),
                x2 = math.max(x1, x2), y2 = math.max(y1, y2),
                optional = isOptional,
            }
        end
    end
    for linkIndex, edge in ipairs(links) do
        local from, to = layout.cards[edge.fromId], layout.cards[edge.toId]
        local startY, endY = from.y + from.height, to.y
        local isOptional = optionalLabels[edge.kind] ~= nil
        if endY - startY > rowGap then
            -- Use the margin for edges that cross several levels so they do
            -- not look like they attach to the cards in between.
            local gutter = 5 + 3 * (linkIndex % 3)
            if from.center + to.center > layout.width then
                gutter = layout.width - gutter
            end
            segment(from.center, startY, from.center, startY + 8, isOptional)
            segment(from.center, startY + 8, gutter, startY + 8, isOptional)
            segment(gutter, startY + 8, gutter, endY - 8, isOptional)
            segment(gutter, endY - 8, to.center, endY - 8, isOptional)
            segment(to.center, endY - 8, to.center, endY, isOptional)
        elseif from.center == to.center then
            segment(from.center, startY, to.center, endY, isOptional)
        else
            local midY = math.floor((startY + endY) / 2)
            segment(from.center, startY, from.center, midY, isOptional)
            segment(from.center, midY, to.center, midY, isOptional)
            segment(to.center, midY, to.center, endY, isOptional)
        end
    end
    return layout
end

function Timeline.EarlierSteps(layout, selectedId)
    if not selectedId then return {} end
    local earlier, queue, seen = {}, { selectedId }, { [selectedId] = true }
    local index = 1
    while queue[index] do
        for _, edge in ipairs(layout.incoming[queue[index]] or {}) do
            if not seen[edge.fromId] then
                seen[edge.fromId] = true
                earlier[#earlier + 1] = edge
                queue[#queue + 1] = edge.fromId
            end
        end
        index = index + 1
    end
    return earlier
end
