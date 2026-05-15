local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local selectedMapID = nil;
local selectedContinentName = nil;

local function FormatDuration(seconds)
	if not seconds or seconds < 0 then
		return "0s";
	end
	local days = math.floor(seconds / 86400);
	local hours = math.floor((seconds % 86400) / 3600);
	local minutes = math.floor((seconds % 3600) / 60);
	
	if days > 0 then
		return string.format("%dd %dh", days, hours);
	end
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes);
	end
	if minutes > 0 then
		return string.format("%dm", minutes);
	end
	return string.format("%ds", math.floor(seconds));
end

function WeatherAddon:CreateDataUI(parentFrame)
	local view = CreateFrame("Frame", nil, parentFrame);
	view:SetAllPoints();

	local collapsedNodes = {};
	local mapTree = nil;

	local leftPanel = CreateFrame("Frame", nil, view);
	leftPanel:SetWidth(150);
	leftPanel:SetPoint("TOPLEFT", 5, -20);
	leftPanel:SetPoint("BOTTOMLEFT", 5, 0);

	local leftBg = leftPanel:CreateTexture(nil, "BACKGROUND");
	leftBg:SetAllPoints();
	leftBg:SetColorTexture(0, 0, 0, 0.25);

	leftBg.mask = leftPanel:CreateMaskTexture();
	leftBg.mask:SetAllPoints(leftBg);
	leftBg.mask:SetTexture(2922105); --Interface/COMMON/common-iconmask.blp 
	leftBg:AddMaskTexture(leftBg.mask);

	--[[-- nineslice
	local leftBorder = leftPanel:CreateTexture(nil, "BORDER", nil, 7);
	leftBorder:SetPoint("TOPLEFT", -8, 8);
	leftBorder:SetPoint("BOTTOMRIGHT", 8, -8);
	leftBorder:SetAtlas("QuestLog-frame");
	leftBorder:SetTextureSliceMargins(20, 20, 20, 20);
	leftBorder:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched);
	--]]

	local searchBox = CreateFrame("EditBox", nil, leftPanel, "SearchBoxTemplate");
	searchBox:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 10, -10);
	searchBox:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -10);
	searchBox:SetHeight(20);
	searchBox:SetAutoFocus(false);

	--QuestLog-frame-filigree

	local zoneScroll = CreateFrame("Frame", nil, leftPanel, "WowScrollBoxList");
	zoneScroll:SetPoint("TOPLEFT", 2, -35);
	zoneScroll:SetPoint("BOTTOMRIGHT", -2, 2);

	local zoneScrollBar = CreateFrame("EventFrame", nil, leftPanel, "MinimalScrollBar");
	zoneScrollBar:SetPoint("TOPLEFT", zoneScroll, "TOPRIGHT", 5, 0);
	zoneScrollBar:SetPoint("BOTTOMLEFT", zoneScroll, "BOTTOMRIGHT", 5, 0);

	-- nineslice
	local leftListBg = leftPanel:CreateTexture(nil, "BACKGROUND", nil, -2);
	leftListBg:SetPoint("TOPLEFT", zoneScroll, "TOPLEFT", -2, 1);
	leftListBg:SetPoint("BOTTOMRIGHT", zoneScroll, "BOTTOMRIGHT", 2, -1);
	leftListBg:SetAtlas("GO-bg-Group");
	leftListBg:SetTextureSliceMargins(10, 10, 10, 10);
	leftListBg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched);

	local rightPanel = CreateFrame("Frame", nil, view);
	rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 15, -3);
	rightPanel:SetPoint("BOTTOMRIGHT", -15, 2);

	local timeBar = CreateFrame("Frame", nil, view);
	timeBar:SetPoint("BOTTOM", rightPanel, "TOP", 0, 2);
	timeBar:SetSize(150, 20);

	timeBar.tex = timeBar:CreateTexture();
	timeBar.tex:SetAllPoints(timeBar);
	timeBar.tex:SetAtlas("activities-bar-background");


	local timeBarLabel = timeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	timeBarLabel:SetAllPoints();
	timeBarLabel:SetText(L["TimeObserved"]);

	local rightScroll = CreateFrame("Frame", nil, rightPanel, "WowScrollBoxList");
	rightScroll:SetPoint("TOPLEFT", 0, 0);
	rightScroll:SetPoint("BOTTOMRIGHT", 0, 0);

	local rightScrollBar = CreateFrame("EventFrame", nil, rightPanel, "MinimalScrollBar");
	rightScrollBar:SetPoint("TOPLEFT", rightScroll, "TOPRIGHT", 5, 0);
	rightScrollBar:SetPoint("BOTTOMLEFT", rightScroll, "BOTTOMRIGHT", 5, 0);

	-- nineslice
	local rightListBg = rightPanel:CreateTexture(nil, "BACKGROUND", nil, -2);
	rightListBg:SetPoint("TOPLEFT", rightScroll, "TOPLEFT", 0, 2);
	rightListBg:SetPoint("BOTTOMRIGHT", rightScroll, "BOTTOMRIGHT", 0, -1);
	rightListBg:SetAtlas("GO-bg-Group");
	rightListBg:SetTextureSliceMargins(10, 10, 10, 10);
	rightListBg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched);

	local rightDP = CreateDataProvider();
	local rightView = CreateScrollBoxListLinearView();
	rightView:SetElementExtent(20);
	rightView:SetElementInitializer("Frame", function(row, data)
		if not row.isInitialized then
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal");
			row.label:SetPoint("LEFT", 10, 0);
			
			row.timeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
			row.timeLabel:SetPoint("RIGHT", -10, 0);
			
			row.isInitialized = true;
		end

		if data.isHeader then
			row.label:SetText(data.text);
			row.label:SetFontObject("GameFontHighlight");
			row.label:SetTextColor(1, 0.82, 0);
			row.timeLabel:SetText("");

			row:SetScript("OnEnter", function()
				GameTooltip:SetOwner(row, "ANCHOR_RIGHT");
				GameTooltip:SetText(data.text, 1, 0.82, 0);
				GameTooltip:AddLine(string.format(L["TimeObserved"], FormatDuration(data.subzoneTotal)), 1, 1, 1);
				GameTooltip:Show();
			end)
			row:SetScript("OnLeave", function()
				GameTooltip:Hide();
			end)
		else
			row.label:SetText("  " .. data.weatherType);
			row.label:SetFontObject("GameFontHighlight");
			row.label:SetTextColor(0.8, 0.8, 0.8);
			row.timeLabel:SetText(data.pct .. "%");
			
			row:SetScript("OnEnter", nil);
			row:SetScript("OnLeave", nil);
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(rightScroll, rightScrollBar, rightView);
	rightScroll:SetDataProvider(rightDP);

	local function CollectLeafMapIDs(node, result)
		if node.hasData then
			result[#result + 1] = node.mapID;
		end
		for _, child in ipairs(node.children) do
			CollectLeafMapIDs(child, result);
		end
	end

	local function FindNode(mapID, children)
		for _, child in ipairs(children) do
			if child.mapID == mapID then return child; end
			local found = FindNode(mapID, child.children);
			if found then return found; end
		end
	end

	local function AggregateMapIDs(mapIDs)
		local result = {};
		for _, mapID in ipairs(mapIDs) do
			local mapData = Weather_Collector_DB and Weather_Collector_DB[mapID];
			if mapData then
				for subzone, weathers in pairs(mapData) do
					if not result[subzone] then result[subzone] = {}; end
					for wType, duration in pairs(weathers) do
						result[subzone][wType] = (result[subzone][wType] or 0) + duration;
					end
				end
			end
		end
		return result;
	end

	local function RefreshRightPanel()
		local subzonesToShow = nil;

		if selectedContinentName and mapTree and mapTree[selectedContinentName] then
			local mapIDs = {};
			for _, child in ipairs(mapTree[selectedContinentName].children) do
				CollectLeafMapIDs(child, mapIDs);
			end
			subzonesToShow = AggregateMapIDs(mapIDs);

		elseif selectedMapID then
			local selectedNode = nil;
			if mapTree then
				for _, cont in pairs(mapTree) do
					selectedNode = FindNode(selectedMapID, cont.children);
					if selectedNode then break; end
				end
			end

			if selectedNode and #selectedNode.children > 0 then
				local mapIDs = {};
				CollectLeafMapIDs(selectedNode, mapIDs);
				subzonesToShow = AggregateMapIDs(mapIDs);
			elseif Weather_Collector_DB and Weather_Collector_DB[selectedMapID] then
				subzonesToShow = Weather_Collector_DB[selectedMapID];
			end
		end

		local rows = {};

		if not subzonesToShow or not next(subzonesToShow) then
			timeBarLabel:SetText(L["TimeObserved"]);
			--rows[1] = { isHeader = true, text = L["SelectZone"] };
			rightDP:Flush();
			rightDP:InsertTable(rows);
			return;
		end

		local grandTotal = 0;
		for _, weathers in pairs(subzonesToShow) do
			for _, duration in pairs(weathers) do
				grandTotal = grandTotal + duration;
			end
		end

		timeBarLabel:SetText(string.format(L["TimeObserved"], FormatDuration(grandTotal)));

		local sortedSubzones = {};
		for subzone in pairs(subzonesToShow) do
			sortedSubzones[#sortedSubzones + 1] = subzone;
		end
		table.sort(sortedSubzones);

		for _, subzone in ipairs(sortedSubzones) do
			local weathers = subzonesToShow[subzone];
			local subzoneTotal = 0;
			for _, duration in pairs(weathers) do
				subzoneTotal = subzoneTotal + duration;
			end

			rows[#rows + 1] = { isHeader = true, text = subzone, subzoneTotal = subzoneTotal };

			local sortedWeathers = {};
			for wType in pairs(weathers) do
				sortedWeathers[#sortedWeathers + 1] = wType;
			end
			table.sort(sortedWeathers);

			for _, wType in ipairs(sortedWeathers) do
				local pct = subzoneTotal > 0 and math.floor((weathers[wType] / subzoneTotal) * 100 + 0.5) or 0;
				rows[#rows + 1] = { isHeader = false, weatherType = wType, pct = pct };
			end
		end

		rightDP:Flush();
		rightDP:InsertTable(rows);
	end

	local function UpdateLeftPanelSelection()
		zoneScroll:ForEachFrame(function(row)
			local d = row:GetElementData();
			if not d then return; end

			if d.isContinentHeader then
				if selectedContinentName == d.name then
					row.selected:Show();
				else
					row.selected:Hide();
				end
			else
				if selectedMapID == d.mapID then
					row.label:SetTextColor(1, 0.82, 0);
					row.selected:Show();
				else
					if d.isSubHeader then
						row.label:SetTextColor(1, 0.9, 0.6);
					else
						row.label:SetTextColor(0.8, 0.75, 0.6);
					end
					row.selected:Hide();
				end
			end
		end)
	end

	local INDENT = 12;

	local zoneDP = CreateDataProvider();
	local zoneView = CreateScrollBoxListLinearView();
	zoneView:SetElementExtent(25);
	zoneView:SetElementInitializer("Button", function(row, data)
		if not row.isInitialized then
			row.hl = row:CreateTexture(nil, "HIGHLIGHT");
			row.hl:SetAllPoints();
			row.hl:SetColorTexture(1, 1, 1, 0.1);
			row:SetScript("OnEnter", function()
				PlaySound(317793);
			end)

			row.selected = row:CreateTexture(nil, "BACKGROUND");
			row.selected:SetAllPoints();
			row.selected:SetColorTexture(0.4, 0.35, 0.2, 0.35);

			row.collapseBtn = CreateFrame("Button", nil, row);
			row.collapseBtn:SetSize(18, 18);
			--row.collapseBtn:SetNormalAtlas("UI-QuestTrackerButton-Expand-All");
			--row.collapseBtn:SetPushedAtlas("UI-QuestTrackerButton-Expand-All-Pressed");

			row.headerBg = row:CreateTexture(nil, "BACKGROUND", nil, -1);
			row.headerBg:SetAtlas("QuestLog-tab", true);
			row.headerBg:SetAllPoints();

			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
			row.label:SetPoint("RIGHT", -5, 0);
			row.label:SetJustifyH("LEFT");
			row.label:SetWordWrap(false);

			row.isInitialized = true;
		end

		local depth = data.depth or 0;
		local indent = depth * INDENT;

		local query = searchBox:GetText():lower();
		local isCollapsed = false;
		if query == "" then
			if collapsedNodes[data.key] ~= nil then
				isCollapsed = collapsedNodes[data.key];
			else
				isCollapsed = data.isSubHeader;
			end
		end

		if data.isContinentHeader then
			row.headerBg:Show();
			row.collapseBtn:Show();
			row.collapseBtn:ClearAllPoints();
			row.collapseBtn:SetPoint("LEFT", 2, 0);

			--local isCollapsed = collapsedNodes[data.key];
			if isCollapsed then
				row.collapseBtn:SetNormalAtlas("UI-QuestTrackerButton-Expand-All");
				row.collapseBtn:SetPushedAtlas("UI-QuestTrackerButton-Expand-All-Pressed");
			else
				row.collapseBtn:SetNormalAtlas("UI-QuestTrackerButton-Collapse-All");
				row.collapseBtn:SetPushedAtlas("UI-QuestTrackerButton-Collapse-All-Pressed");
			end

			row.collapseBtn:SetScript("OnClick", function()
				local currentState = collapsedNodes[data.key];
				if currentState == nil then currentState = data.isSubHeader; end
				collapsedNodes[data.key] = not currentState;
				view:RefreshMapList();
				PlaySound(273125);
			end)

			row.label:ClearAllPoints();
			row.label:SetPoint("LEFT", 22, 0);
			row.label:SetPoint("RIGHT", -5, 0);
			row.label:SetText(data.name);
			row.label:SetFontObject("GameFontNormal");
			row.label:SetTextColor(1, 0.82, 0);

			row.hl:Show();

			if selectedContinentName == data.name then
				row.selected:Show();
			else
				row.selected:Hide();
			end

			row:SetScript("OnClick", function()
				selectedMapID = nil;
				selectedContinentName = data.name;
				UpdateLeftPanelSelection();
				RefreshRightPanel();
				PlaySound(305111);
			end)

		elseif data.isSubHeader then
			row.headerBg:Hide();
			row.collapseBtn:Show();
			row.collapseBtn:ClearAllPoints();
			row.collapseBtn:SetPoint("LEFT", 2 + indent, 0);

			--local isCollapsed = collapsedNodes[data.key];
			if isCollapsed then
				row.collapseBtn:SetNormalAtlas("UI-QuestTrackerButton-Expand-All");
				row.collapseBtn:SetPushedAtlas("UI-QuestTrackerButton-Expand-All-Pressed");
			else
				row.collapseBtn:SetNormalAtlas("UI-QuestTrackerButton-Collapse-All");
				row.collapseBtn:SetPushedAtlas("UI-QuestTrackerButton-Collapse-All-Pressed");
			end

			row.collapseBtn:SetScript("OnClick", function()
				local currentState = collapsedNodes[data.key];
				if currentState == nil then currentState = data.isSubHeader; end
				collapsedNodes[data.key] = not currentState;
				view:RefreshMapList();
				PlaySound(273125);
			end)

			row.label:ClearAllPoints();
			row.label:SetPoint("LEFT", 2 + indent + 20, 0);
			row.label:SetPoint("RIGHT", -5, 0);
			row.label:SetText(data.name);
			row.label:SetFontObject("GameFontNormalSmall");

			row.hl:Show();

			if selectedMapID == data.mapID then
				row.label:SetTextColor(1, 0.82, 0);
				row.selected:Show();
			else
				row.label:SetTextColor(1, 0.9, 0.6);
				row.selected:Hide();
			end

			row:SetScript("OnClick", function()
				selectedMapID = data.mapID;
				selectedContinentName = nil;
				UpdateLeftPanelSelection();
				RefreshRightPanel();
				PlaySound(305111);
			end)

		else
			row.headerBg:Hide();
			row.collapseBtn:Hide();

			row.label:ClearAllPoints();
			row.label:SetPoint("LEFT", 5 + indent, 0);
			row.label:SetPoint("RIGHT", -5, 0);
			row.label:SetText("  " .. data.name);
			row.label:SetFontObject("GameFontNormalSmall");

			row.hl:Show();

			if selectedMapID == data.mapID then
				row.label:SetTextColor(1, 0.82, 0);
				row.selected:Show();
			else
				row.label:SetTextColor(0.8, 0.75, 0.6);
				row.selected:Hide();
			end

			row:SetScript("OnClick", function()
				selectedMapID = data.mapID;
				selectedContinentName = nil;
				UpdateLeftPanelSelection();
				RefreshRightPanel();
				PlaySound(305111);
			end)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(zoneScroll, zoneScrollBar, zoneView);
	zoneScroll:SetDataProvider(zoneDP);

	function view:SelectCurrentZone()
		local mapID = C_Map.GetBestMapForUnit("player");
		if not mapID or not (Weather_Collector_DB and Weather_Collector_DB[mapID]) then
			view:RefreshMapList();
			RefreshRightPanel();
			return;
		end

		local currentID = mapID;
		local visited = {};
		while currentID and currentID > 0 do
			if visited[currentID] then break; end
			visited[currentID] = true;
			local info = C_Map.GetMapInfo(currentID);
			if not info then break; end
			if info.mapType <= 2 then
				collapsedNodes["c:" .. (info.name or string.format(L["UnknownMap"], currentID))] = false;
				break;
			end
			collapsedNodes["m:" .. currentID] = false;
			currentID = info.parentMapID;
		end

		selectedMapID = mapID;
		selectedContinentName = nil;

		view:RefreshMapList();
		UpdateLeftPanelSelection();
		RefreshRightPanel();
	end

	function view:RefreshMapList()
		local currentScroll = zoneScroll:GetScrollPercentage() or 0;
		zoneDP:Flush();
		mapTree = {};

		if not Weather_Collector_DB then
			zoneScroll:SetScrollPercentage(currentScroll);
			return;
		end

		local allNodes = {};

		local function GetOrCreateNode(mapID)
			if allNodes[mapID] then return allNodes[mapID]; end
			local info = C_Map.GetMapInfo(mapID);
			local name = info and info.name or string.format(L["UnknownMap"], mapID);
			allNodes[mapID] = { mapID = mapID, name = name, hasData = false, children = {}, childrenByID = {} };
			return allNodes[mapID];
		end

		local function GetOrCreateContinent(name)
			if not mapTree[name] then
				mapTree[name] = { name = name, children = {}, childrenByID = {} };
			end
			return mapTree[name];
		end

		local function AddChild(parent, child)
			if not parent.childrenByID[child.mapID] then
				parent.childrenByID[child.mapID] = true;
				table.insert(parent.children, child);
			end
		end

		for mapID in pairs(Weather_Collector_DB) do
			local chain = {};
			local continentName = L["OtherUnknown"];
			local currentID = mapID;
			local visited = {};

			while currentID and currentID > 0 do
				if visited[currentID] then break; end
				visited[currentID] = true;
				local info = C_Map.GetMapInfo(currentID);
				if not info then break; end
				if info.mapType <= 2 then
					continentName = info.name or string.format(L["UnknownMap"], currentID);
					break;
				end
				table.insert(chain, 1, currentID);
				currentID = info.parentMapID;
			end

			local parent = GetOrCreateContinent(continentName);

			for i, cID in ipairs(chain) do
				local node = GetOrCreateNode(cID);
				if i == #chain then
					node.hasData = true;
				end
				AddChild(parent, node);
				parent = node;
			end
		end

		local function SortChildren(children)
			table.sort(children, function(a, b) return a.name < b.name; end);
		end

		local query = searchBox:GetText():lower();
		local function NodeMatches(node)
			if query == "" then return true; end
			if node.name:lower():find(query, 1, true) then return true; end
			-- check subzones
			if node.mapID and Weather_Collector_DB[node.mapID] then
				for subzoneName, weathers in pairs(Weather_Collector_DB[node.mapID]) do
					if subzoneName:lower():find(query, 1, true) then
						return true;
					end
					if type(weathers) == "table" then
						for wType, _ in pairs(weathers) do
							if wType:lower():find(query, 1, true) then
								return true;
							end
						end
					end
				end
			end
			for _, child in ipairs(node.children) do
				if NodeMatches(child) then return true; end
			end
			return false;
		end

		local function FlattenNode(node, depth, forceKeep)
			local selfMatches = query == "" or forceKeep or node.name:lower():find(query, 1, true) ~= nil;
			-- check subzones
			if not selfMatches and node.mapID and Weather_Collector_DB[node.mapID] then
				for subzoneName, weathers in pairs(Weather_Collector_DB[node.mapID]) do
					if subzoneName:lower():find(query, 1, true) then
						selfMatches = true;
						break;
					end
					if type(weathers) == "table" then
						for wType, _ in pairs(weathers) do
							if wType:lower():find(query, 1, true) then
								selfMatches = true;
								break;
							end
						end
					end
					
					if selfMatches then break; end
				end
			end
			local childMatches = false;
			for _, child in ipairs(node.children) do
				if NodeMatches(child) then childMatches = true; break; end
			end
			
			local keep = selfMatches or childMatches;
			if not keep then return; end
			local hasChildren = #node.children > 0;
			local key = "m:" .. node.mapID;

			zoneDP:Insert({
				isContinentHeader = false,
				isSubHeader = hasChildren,
				name = node.name,
				mapID = node.mapID,
				key = key,
				depth = depth,
			});

			local isCollapsed = false;
			if query == "" then
				if collapsedNodes[key] ~= nil then
					isCollapsed = collapsedNodes[key];
				else
					isCollapsed = hasChildren;
				end
			end

			if hasChildren and not isCollapsed then
				SortChildren(node.children);
				for _, child in ipairs(node.children) do
					FlattenNode(child, depth + 1, selfMatches);
				end
			end
		end

		local sortedContinents = {};
		for name in pairs(mapTree) do
			sortedContinents[#sortedContinents + 1] = name;
		end
		table.sort(sortedContinents);

		for _, continentName in ipairs(sortedContinents) do
			local continent = mapTree[continentName];
			local key = "c:" .. continentName;

			local selfMatches = query == "" or continentName:lower():find(query, 1, true) ~= nil;
			local childMatches = false;
			for _, child in ipairs(continent.children) do
				if NodeMatches(child) then childMatches = true; break; end
			end

			if selfMatches or childMatches then
				zoneDP:Insert({
					isContinentHeader = true,
					isSubHeader = false,
					name = continentName,
					key = key,
					depth = 0,
				});

				local isCollapsed = false;
				if query == "" then
					if collapsedNodes[key] ~= nil then
						isCollapsed = collapsedNodes[key];
					end
				end

				if not isCollapsed then
					SortChildren(continent.children);
					for _, child in ipairs(continent.children) do
						FlattenNode(child, 1, selfMatches);
					end
				end
			end
		end

		zoneScroll:SetScrollPercentage(currentScroll);
	end

	searchBox:HookScript("OnTextChanged", function(self)
		self.t = 0;
		self:SetScript("OnUpdate", function(self, elapsed)
			self.t = self.t + elapsed;
			if self.t >= 0.2 then
				self.t = 0;
				self:SetScript("OnUpdate", nil);
				view:RefreshMapList();
			end
		end)
	end)

	view:SetScript("OnShow", function()
		if view.selectCurrentOnShow then
			view.selectCurrentOnShow = nil;
			view:SelectCurrentZone();
		else
			view:RefreshMapList();
			RefreshRightPanel();
		end
	end)

	return view;
end