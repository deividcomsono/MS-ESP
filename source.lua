--[[

         ▄▄▄▄███▄▄▄▄      ▄████████         ▄████████    ▄████████    ▄███████▄ 
        ▄██▀▀▀███▀▀▀██▄   ███    ███        ███    ███   ███    ███   ███    ███ 
        ███   ███   ███   ███    █▀         ███    █▀    ███    █▀    ███    ███ 
        ███   ███   ███   ███              ▄███▄▄▄       ███          ███    ███ 
        ███   ███   ███ ▀███████████      ▀▀███▀▀▀     ▀███████████ ▀█████████▀  
        ███   ███   ███          ███        ███    █▄           ███   ███        
        ███   ███   ███    ▄█    ███        ███    ███    ▄█    ███   ███        
        ▀█   ███   █▀   ▄████████▀         ██████████  ▄████████▀   ▄████▀      
                                                                                
                        Created by mstudio45 (Discord)
--]]

-- local getgenvFunc = typeof(getgenv) == "function" and getgenv;
local global = getgenv; -- function() return getgenvFunc and getgenvFunc() or _G; end

if global().mstudio45 and global().mstudio45.ESPLibrary then
    return global().mstudio45.ESPLibrary;
end

local __DEBUG = false;
local __LOG = true;
local __PREFIX = "mstudio45's ESP"

local Library = {
    -- // Loggin // --
    Print = function(...)
        if __LOG ~= true then return end; 
        print("[💭 INFO] " .. __PREFIX .. ":", ...);
    end,
	Warn = function(...)
        if __LOG ~= true then return end; 
        warn("[⚠ WARN] " .. __PREFIX .. ":", ...);
    end,
	Error = function(...)
        if __LOG ~= true then return end; 
        error("[🆘 ERROR] " .. __PREFIX .. ":", ...);
    end,
	Debug = function(...) 
        if __DEBUG ~= true or __LOG ~= true then return end; 
        print("[🛠 DEBUG] " .. __PREFIX .. ":", ...);
    end,

	SetDebugEnabled     = function(bool) __DEBUG = bool end,
    SetIsLoggingEnabled = function(bool) __LOG = bool end,
    SetPrefix           = function(pref) __PREFIX = tostring(pref) end,

    -- // Storage // --
    ESP = {
		Billboards = {},
		Adornments = {},
		Highlights = {},
		Outlines = {},
		Tracers = {}
	},

    Folders = {}
};
Library.Connections = { List = {} };
function Library.Connections.Add(connection, keyName, stopWhenKey)
    assert(typeof(connection) == "RBXScriptConnection", "Argument #1 must be a RBXScriptConnection.");
    local totalCount = 0; for _, v in pairs(Library.Connections.List) do totalCount = totalCount + 1; end
    local key = table.find({ "string", "number" }, typeof(keyName)) and tostring(keyName) or totalCount + 1;

    if table.find(Library.Connections.List, key) or typeof(Library.Connections.List[key]) == "RBXScriptConnection" then 
        Library.Warn(key, "already exists in Connections!")
        if stopWhenKey then return; end

        key = totalCount + 1;
    end

    Library.Debug(key, "connection added.");
    Library.Connections.List[key] = connection;
    return key;
end;
function Library.Connections.Remove(key)
    if typeof(Library.Connections.List[key]) ~= "RBXScriptConnection" then return; end;

    if Library.Connections.List[key].Connected then
        Library.Debug(key, "connection disconnected.")
        Library.Connections.List[key]:Disconnect();

        local keyIndex = table.find(Library.Connections.List, key);
        if keyIndex then table.remove(Library.Connections.List, keyIndex); end;
    end
end;

Library.Rainbow = {
    HueSetup = 0, Hue = 0, Step = 0,
    Color = Color3.new(),
    Enabled = false,

    Set = function(bool) 
        if (bool == true or bool == false) then
            Library.Rainbow.Enabled = bool;
        end; 
    end,
    Enable = function() Library.Rainbow.Enabled = true; end,
    Disable = function() Library.Rainbow.Enabled = false; end,
    Toggle = function() Library.Rainbow.Enabled = not Library.Enabled; end
};

-- // Services // --
local getService = typeof(cloneref) == "function" and (function(name) return cloneref(game:GetService(name)) end) or (function(name) return game:GetService(name) end)
local Players = getService("Players");
local CoreGui = getService("CoreGui");
--local CoreGui = typeof(gethui) == "function" and gethui() or getService("CoreGui");
local RunService = getService("RunService");
local UserInputService = getService("UserInputService");

-- // Variables // --
local DrawingLib = typeof(Drawing) == "table" and Drawing or { noDrawing = true };

local localPlayer = Players.LocalPlayer;
local character;
local rootPart;
local camera;
local worldToViewport;

local function updateVariables()
	Library.Debug("Updating variables...")
	localPlayer = Players.LocalPlayer;

	character = character or (localPlayer.Character or localPlayer.CharacterAdded:Wait());
	rootPart = rootPart or (character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")) or nil);

	camera = camera or workspace.CurrentCamera;
	worldToViewport = function(...) camera = (camera or workspace.CurrentCamera); return camera:WorldToViewportPoint(...) end;
	Library.Debug("Variables updated!")
end
updateVariables();

-- // Functions // --
local function getFolder(name, parent)
	assert(typeof(name) == "string", "Argument #1 must be a string.");
	assert(typeof(parent) == "Instance", "Argument #2 must be an Instance.");

    Library.Debug("Creating folder '" .. name .. "'.")
	local folder = parent:FindFirstChild(name);
	if folder == nil then
		folder = Instance.new("Folder", parent);
		folder.Name = name;
	end
	return folder;
end

local function hasProperty(instance, property) -- // Finds a property using a pcall call and then returns the value of it // --
	assert(typeof(instance) == "Instance", "Argument #1 must be an Instance.");
	assert(typeof(property) == "string", "Argument #2 must be a string.");

	local clone = instance;
	local success, property = pcall(function() return clone[property] end);
	return success and property or nil;
end

local function findPrimaryPart(inst)
	if inst == nil or typeof(inst) ~= "Instance" then return nil end;
    return (inst:IsA("Model") and inst.PrimaryPart or nil) or inst:FindFirstChildWhichIsA("BasePart") or inst:FindFirstChildWhichIsA("UnionOperation") or inst;
end

local function createInstance(instanceType, properties)
	assert(typeof(instanceType) == "string", "Argument #1 must be a string.");
	assert(typeof(properties) == "table", "Argument #2 must be a table.");

	local success, instance = pcall(function() return Instance.new(instanceType) end);
	assert(success, "Failed to create the instance.");

	for propertyName, propertyValue in pairs(properties) do
		local success, errorMessage = pcall(function()
			instance[propertyName] = propertyValue;
		end)

		if not success then Library.Warn("Failed to set '" .. propertyName .. "' property.", errorMessage) end;
	end

	return instance;
end

local function distanceFromCharacter(position, getPositionFromCamera) -- // mspaint.lua (line 1240) // --
    if typeof(position) == "Instance" then position = position:GetPivot().Position; end;
	if not rootPart and not camera then updateVariables(); end;

    if getPositionFromCamera == true and camera then
		return (camera.CFrame.Position - position).Magnitude;
    end

    if rootPart then
        return (rootPart.Position - position).Magnitude;
    elseif camera then
        return (camera.CFrame.Position - position).Magnitude;
    end

    return 9e9;
end

local function getTracerTable(uiTable)
    if uiTable.IsNormalTracer == true then
        return uiTable;
    end

    return uiTable.TracerInstance;
end

local function deleteTracer(tracerInstance)
    if tracerInstance ~= nil then
        tracerInstance.Visible = false;

        if typeof(tracerInstance.Destroy) == "function" then
            tracerInstance:Destroy();
        elseif typeof(tracerInstance.Remove) == "function" then
            tracerInstance:Remove();
        end

        tracerInstance = nil;
    end
end

local function createDeleteFunction(TableName, TableIndex, Table)
	return function()
		local s, e = pcall(function()
        if typeof(Library.ESP[TableName]) ~= "table" then
			Library.Warn("Table '" .. TableName .. "' doesn't exists in Library.ESP.");
            return;
		end

        local uiTable = Library.ESP[TableName][TableIndex] or Table;
        if uiTable == nil then
			Library.Warn("'???' (" .. tostring(TableName) .. ")' is nil.")
			return;
		end

        local tracerTable = getTracerTable(uiTable);
		if uiTable.Deleted == true then
            Library.Warn("'" .. tostring(uiTable.Settings.Name) .. "' (" .. tostring(TableName) .. ") was already deleted.")
            return;
		end

		Library.Debug("Deleting '" .. tostring(uiTable.Settings.Name) .. "' (" .. tostring(TableName) .. ")...");

        -- // Disconnect connections // --
        if typeof(uiTable.Connections) == "table" then
            Library.Debug("Removing connections...");
            for index, connectionKey in pairs(uiTable.Connections) do
                Library.Connections.Remove(connectionKey);
                uiTable.Connections[index] = nil;
            end
        end

        -- // Remove Elements // --
        if typeof(uiTable.UIElements) == "table" then
            Library.Debug("Removing elements...");
            for index, element in pairs(uiTable.UIElements) do
                if element == nil or typeof(element) ~= "Instance" then continue; end

                if hasProperty(element, "Adornee") then element.Adornee = nil; end
                if hasProperty(element, "Visible") then element.Visible = false; task.wait(); end
                pcall(function() element:Destroy(); end)

                uiTable.UIElements[index] = nil;
            end
        end

        -- // Remove Tracer // --
        local successTracer, errorMessageTracer = pcall(function()
            if TableName == "Tracers" then
                if typeof(uiTable.TracerInstance) == "table" then
                    Library.Debug("Removing tracer...");
                    deleteTracer(uiTable.TracerInstance)
                end
    
                local tracerTable = getTracerTable(uiTable);
                if tracerTable ~= nil then
                    Library.Debug("Removing tracer (#2)...");
                    deleteTracer(tracerTable.TracerInstance)
                end
    
                Library.Debug("Tracer deleted!");
            else
                if uiTable.TracerInstance ~= nil then
                    uiTable.TracerInstance.Destroy();
                end
            end
        end);
        if not successTracer then
			Library.Warn("Failed to delete tracer.", errorMessageTracer);
		end

        -- // Remove from Library // --
        uiTable.Deleted = true;
        -- table.remove(Library.ESP[uiTable.TableName], uiTable.TableIndex);
        Library.ESP[TableName][TableIndex] = nil;
        if uiTable.TableIndex ~= 0 then Library.ESP[uiTable.TableName][uiTable.TableIndex] = nil; end

        Library.Debug("'" .. tostring(uiTable.Settings.Name) .. "' (" .. tostring(TableName) .. ") is now deleted!");
	    end)
		if not s then Library.Warn(e) end
	end
end

-- // Setup ESP Info Table // --
Library.Folders.Main = getFolder("__ESP_FOLDER", CoreGui);
Library.Folders.Billboards = getFolder("__BILLBOARDS_FOLDER", Library.Folders.Main);
Library.Folders.Adornments = getFolder("__ADORNMENTS_FOLDER", Library.Folders.Main);
Library.Folders.Highlights = getFolder("__HIGHLIGHTS_FOLDER", Library.Folders.Main);
Library.Folders.Outlines = getFolder("__OUTLINES_FOLDER", Library.Folders.Main);

--[[if global().mstudio45 and global().mstudio45.ESPLibrary then
    local success, errorMessage = pcall(function()
        for key, con in pairs(global().mstudio45.ESPLibrary.Connections.List) do
            global().mstudio45.ESPLibrary.Connections.Remove(key)
        end
    
        global().mstudio45.ESPLibrary.ESP.Clear();
    end)

    if success == false then
        Library.Warn("Failed to deload already loaded Library.", errorMessage)
    end

    for name, uiFolder in pairs(Library.Folders) do
        if name == "Main" then continue; end

        Library.Debug("Clearing '" .. tostring(name) .. "' folder...")
        uiFolder:ClearAllChildren();
    end
end--]]

-- // ESP Templates // --
local Templates = {
	Billboard = {
		Name = "Instance", 
		Model = nil,
		Visible = true,
        MaxDistance = 5000,
        StudsOffset = Vector3.new(),

		Color = Color3.new(),
		WasCreatedWithDifferentESP = false
	},

	Tracer = {
		Model = nil,
		Visible = true,
        MaxDistance = 5000,
        StudsOffset = Vector3.new(),

		From = "Bottom", -- // Top, Center, Bottom, Mouse // --

		Color = Color3.new(),

		Thickness = 2,
		Transparency = 0.65,
	},

	Highlight = {
		Name = "Instance", 
		Model = nil,
		Visible = true,
        MaxDistance = 5000,
        StudsOffset = Vector3.new(),

		FillColor = Color3.new(),
		OutlineColor = Color3.new(),
		TextColor = Color3.new(),

		FillTransparency = 0.65,
		OutlineTransparency = 0
	},

	Adornment = {
		Name = "Instance", 
		Model = nil,
		Visible = true,
        MaxDistance = 5000,
        StudsOffset = Vector3.new(),

		Color = Color3.new(),
		TextColor = Color3.new(),

		Transparency = 0.65,
		Type = "Box" -- // Box, Cylinder, Sphere // --
	},

	Outline = {
		Name = "Instance", 
		Model = nil,
		Visible = true,
        MaxDistance = 5000,
        StudsOffset = Vector3.new(),

		SurfaceColor = Color3.new(),
		BorderColor = Color3.new(),
		TextColor = Color3.new(),

		Thickness = 0.04, -- 2
		Transparency = 0.65
	}
}

-- // Library Handler // --
function Library.Validate(args, template)
    -- // Adds missing values depending on the 'template' argument // --
	args = type(args) == "table" and args or {}

	for key, value in pairs(template) do
		local argValue = args[key]

		if argValue == nil or type(argValue) ~= type(value) then
			args[key] = value
		elseif type(value) == "table" then
			args[key] = Library.Validate(argValue, value)
		end
	end

	return args
end

function Library.ESP.Clear()
    Library.Debug("---------------------------");

	for _, uiTable in pairs(Library.ESP) do
        if typeof(uiTable) ~= "table" then continue; end

		Library.Debug("Clearing '" .. tostring(_) .. "' ESP...")
		for _, uiElement in pairs(uiTable) do 
			if not uiElement then continue; end

			if typeof(uiElement) == "table" and typeof(uiElement.Destroy) == "function" then 
				local success, errorMessage = pcall(function()
                    uiElement.Destroy()
                end);

                if success == false then Library.Warn("Failed to ESP Element.", errorMessage); end;
			elseif typeof(uiElement) == "Instance" then
				uiElement:Destroy();
			end

			task.wait();
		end
	end

    for name, uiFolder in pairs(Library.Folders) do
        if name == "Main" then continue; end

        Library.Debug("Clearing '" .. tostring(name) .. "' folder...")
        uiFolder:ClearAllChildren();
    end

    Library.Debug("---------------------------");
end

-- // ESP Handler // --
function Library.ESP.Billboard(args)
	assert(typeof(args) == "table", "args must be a table.");
	args = Library.Validate(args, Templates.Billboard);
    assert(typeof(args.Model) == "Instance", "args.Model must be an Instance.");

	Library.Debug("Creating Billboard '" .. tostring(args.Name) .. "'...")
	-- // Instances // --
	local GUI = createInstance("BillboardGui", {
		Name = "GUI_" .. args.Name,
		Parent = Library.Folders.Billboards,

		ResetOnSpawn = false,
		Enabled = true,
		AlwaysOnTop = true,

		Size = UDim2.new(0, 200, 0, 50),
		StudsOffset = args.StudsOffset,

		Adornee = args.Model
	});

	local DistanceText = createInstance("TextLabel", {
        Parent = GUI,
        Visible = true,

		Name = "Distance",
		ZIndex = 0,
		Active = true,
		ClipsDescendants = true,

		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Size = UDim2.new(0, 200, 0, 60),

		Position = UDim2.new(0, 0, 0, 10),

		Font = Enum.Font.RobotoCondensed,
		FontSize = Enum.FontSize.Size12,

		Text = "[???]",
		TextColor3 = args.Color,
		TextStrokeTransparency = 0,
		TextSize = 12,

		TextWrapped = true,
		TextWrap = true,
		RichText = true,

		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	});
	createInstance("UIStroke", { Parent = DistanceText });

	local Text = createInstance("TextLabel", {
        Parent = GUI,
        Visible = true,

		Name = "Text",
		ZIndex = 0,

		Size = UDim2.new(0, 200, 0, 50),

		FontSize = Enum.FontSize.Size18,
		Font = Enum.Font.RobotoCondensed,

		Text = args.Name,
		TextColor3 = args.Color,
		TextStrokeTransparency = 0,
		TextSize = 15,

		TextWrapped = true,
		TextWrap = true,
		RichText = true,

		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	});
	createInstance("UIStroke", { Parent = Text });

    local TableName = "Billboards";
    local TableIndex = #Library.ESP[TableName] + 1;

	local BillboardTable = {
        TableIndex = TableIndex, TableName = TableName,

		Settings = args,
		UIElements = {
			GUI, 
			Text, 
			DistanceText
		},
		TracerInstance = nil
    };

    BillboardTable.Connections = {
        Library.Connections.Add(args.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local uiTable = Library.ESP[TableName][TableIndex]
                if uiTable ~= nil and typeof(uiTable.Destroy) == "function" then --or typeof(uiTable.Delete) == "function") then
                    uiTable.Destroy()
				end
                BillboardTable.Destroy();
            end
        end))
    };

    -- // Delete Handler // --
    BillboardTable.Deleted = false;
    BillboardTable.Destroy = createDeleteFunction(TableName, TableIndex, BillboardTable);
    --BillboardTable.Delete = BillboardTable.Destroy;

    BillboardTable.GetDistance = function()
        if BillboardTable.Deleted then return 9e9 end;
        if BillboardTable.Settings.Model == nil or BillboardTable.Settings.Model.Parent == nil then return 9e9 end;
        return math.round(distanceFromCharacter(BillboardTable.Settings.Model));
    end;

    BillboardTable.Update = function(color, updateVariables)
        if BillboardTable.Deleted or (not Text and not DistanceText) then return; end

        local _Color = typeof(color) == "Color3" and color or BillboardTable.Settings.Color;
        for _, text in pairs({ Text, DistanceText }) do
            if text ~= nil and text.Parent == GUI then 
                text.TextColor3 = _Color;
            end
        end

        if updateVariables ~= false then
            BillboardTable.Settings.Color = _Color;

            BillboardTable.Settings.MaxDistance = typeof(args.MaxDistance) == "number" and args.MaxDistance or BillboardTable.Settings.MaxDistance;
        end
    end;
    BillboardTable.SetColor = BillboardTable.Update;

    BillboardTable.SetText = function(text)
        if BillboardTable.Deleted or not Text then return; end

        BillboardTable.Settings.Name = (typeof(text) == "string" and text or BillboardTable.Settings.Name);
        Text.Text = BillboardTable.Settings.Name;
    end;
    BillboardTable.SetDistanceText = function(distance)
        if BillboardTable.Deleted or not DistanceText then return; end

        if typeof(distance) ~= "number" then return end;
        DistanceText.Text = string.format("[%d]", distance);
    end;

	BillboardTable.SetVisible = function(visible)
        if BillboardTable.Deleted or not GUI then return; end

        BillboardTable.Settings.Visible = (typeof(visible) == "boolean" and visible or BillboardTable.Settings.Visible);
        GUI.Enabled = BillboardTable.Settings.Visible;
    end

    -- // Return // --
	Library.ESP[TableName][TableIndex] = BillboardTable;
	return BillboardTable;
end

function Library.ESP.Tracer(args)
	if DrawingLib.noDrawing == true then
		return {
			TableIndex = 0, TableName = "Tracers",

			Settings = {},
			UIElements = {},
            TracerInstance = nil,
            IsNormalTracer = true,
			DistancePart = nil,

			-- // Delete Handler // --
			Deleted = true,
			Destroy = function() end,

			-- // Misc Functions // --
			Update = function() end,
			SetColor = function() end,
			SetVisible = function() end
		}
	end

    assert(typeof(args) == "table", "args must be a table.");
	args = Library.Validate(args, Templates.Tracer);
	assert(typeof(args.Model) == "Instance", "args.Model must be an Instance.");
	args.From = string.lower(args.From);

	Library.Debug("Creating Tracer...")
    -- // Create Tracer // --
	local TracerInstance = DrawingLib.new("Line")
	TracerInstance.Visible = args.Visible;
	TracerInstance.Color = args.Color;
	TracerInstance.Thickness = args.Thickness;
	TracerInstance.Transparency = args.Transparency;

    local TableName = "Tracers";
	local TableIndex = #Library.ESP[TableName] + 1;

	local TracerTable = {
        TableIndex = TableIndex, TableName = TableName,

		Settings = args,
		TracerInstance = TracerInstance,
        IsNormalTracer = true
    }; 

    TracerTable.Connections = {
        Library.Connections.Add(args.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local uiTable = Library.ESP[TableName][TableIndex]
                if uiTable ~= nil and typeof(uiTable.Destroy) == "function" then -- or typeof(uiTable.Delete) == "function") then
                    uiTable.Destroy()
				end
                TracerTable.Destroy();
            end
        end))
    };

    -- // Delete Handler // --
    TracerTable.Deleted = false;
    TracerTable.Destroy = createDeleteFunction(TableName, TableIndex, TracerTable);
    --TracerTable.Delete = TracerTable.Destroy;

    TracerTable.DistancePart = findPrimaryPart(TracerTable.Settings.Model);
    TracerTable.Update = function(args, updateVariables)
        if TracerTable.Deleted or not TracerTable.TracerInstance then return; end
        args = Library.Validate(args, TracerTable.Settings);

        local _Color = typeof(args.Color) == "Color3" and args.Color or TracerTable.Settings.Color;
        local _Thickness = typeof(args.Thickness) == "number" and args.Thickness or TracerTable.Settings.Thickness;
        local _Transparency = typeof(args.Transparency) == "number" and args.Transparency or TracerTable.Settings.Transparency;
        local _From = table.find({ "top", "center", "bottom", "mouse" }, args.From) and args.From or TracerTable.Settings.From;
        local _Visible = typeof(args.Visible) == "boolean" and args.Visible or TracerTable.Settings.Visible;

        TracerTable.TracerInstance.Color = _Color;
        TracerTable.TracerInstance.Thickness = _Thickness
        TracerTable.TracerInstance.Transparency = _Transparency;
        TracerTable.TracerInstance.Visible = _Visible;
        
        if updateVariables ~= false then
            TracerTable.Settings.Color         = _Color;
            TracerTable.Settings.Thickness     = _Thickness;
            TracerTable.Settings.Transparency  = _Transparency;
            TracerTable.Settings.From          = _From;
            TracerTable.Settings.Visible       = _Visible;

            TracerTable.Settings.MaxDistance = typeof(args.MaxDistance) == "number" and args.MaxDistance or TracerTable.Settings.MaxDistance;
        end
    end;
    TracerTable.SetColor = TracerTable.Update;

	TracerTable.SetVisible = function(visible)
        if TracerTable.Deleted or not TracerTable.TracerInstance then return; end
        TracerTable.Update({ Visible = visible })
    end

    -- // Return // --
    Library.ESP[TableName][TableIndex] = TracerTable;
	return TracerTable;
end

function Library.ESP.Highlight(args)
	assert(typeof(args) == "table", "args must be a table.");
	args = Library.Validate(args, Templates.Highlight)
    
    -- // Tracer // --
    do 
        args.Tracer = Library.Validate(args.Tracer, Templates.Tracer); 
        args.Tracer.Enabled = typeof(args.Tracer.Enabled) ~= "boolean" and false or args.Tracer.Enabled; 
        args.Tracer.Model = args.Model;
    end
    assert(typeof(args.Model) == "Instance", "args.Model must be an Instance.");

	Library.Debug("Creating Highlight '" .. tostring(args.Name) .. "'...")
	local BillboardTable = Library.ESP.Billboard({
		Name = args.Name, 
		Model = args.Model,
        MaxDistance = args.MaxDistance,
        StudsOffset = args.StudsOffset,
		Color = args.TextColor,
		WasCreatedWithDifferentESP = true
	});

	local Highlight = createInstance("Highlight", {
		Parent = Library.Folders.Highlights,

		FillColor = args.FillColor,
		OutlineColor = args.OutlineColor,

		FillTransparency = args.FillTransparency,
		OutlineTransparency = args.OutlineTransparency,

		Adornee = args.Model
	});

    local TableName = "Highlights";
    local TableIndex = #Library.ESP[TableName] + 1;

	local HighlightTable = { 
        TableIndex = TableIndex, TableName = TableName,

		Settings = args,
		UIElements = { Highlight },
		TracerInstance = args.Tracer.Enabled == true and Library.ESP.Tracer(args.Tracer) or nil
    }; 
    HighlightTable.Connections = {
        Library.Connections.Add(args.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local uiTable = Library.ESP[TableName][TableIndex]
                if uiTable ~= nil and typeof(uiTable.Destroy) == "function" then -- or typeof(uiTable.Delete) == "function") then
                    uiTable.Destroy()
				end
                HighlightTable.Destroy();
            end
        end))
    };

    -- // Delete Handler // --
    HighlightTable.Deleted = false;
    HighlightTable.Destroy = createDeleteFunction(TableName, TableIndex, HighlightTable);
    --HighlightTable.Delete = HighlightTable.Destroy;

    HighlightTable.GetDistance = BillboardTable.GetDistance;

    HighlightTable.Update = function(args, updateVariables)
        if HighlightTable.Deleted or (not Highlight and not BillboardGui) then return; end
    
        if HighlightTable.TracerInstance ~= nil and typeof(args.Tracer) == "table" then 
            HighlightTable.TracerInstance.Update(Library.Validate(args.Tracer, HighlightTable.Settings.Tracer), updateVariables); 
        end;

        local settings = HighlightTable.Settings; HighlightTable.Settings.Tracer = nil;
        args = Library.Validate(args, settings);

        local _FillColor = typeof(args.FillColor) == "Color3" and args.FillColor or HighlightTable.Settings.FillColor;
        local _OutlineColor = typeof(args.OutlineColor) == "Color3" and args.OutlineColor or HighlightTable.Settings.OutlineColor;
        local _TextColor = typeof(args.TextColor) == "Color3" and args.TextColor or HighlightTable.Settings.TextColor;

        Highlight.FillColor = _FillColor;
        Highlight.OutlineColor = _OutlineColor;
        BillboardTable.Update(_TextColor, updateVariables);

        if updateVariables ~= false then
            HighlightTable.Settings.FillColor     = _FillColor;
            HighlightTable.Settings.OutlineColor  = _OutlineColor;
            HighlightTable.Settings.TextColor     = _TextColor;

            HighlightTable.Settings.MaxDistance = typeof(args.MaxDistance) == "number" and args.MaxDistance or HighlightTable.Settings.MaxDistance;
        end
    end;
    HighlightTable.SetColor = HighlightTable.Update;

    HighlightTable.SetText = function(text)
        if HighlightTable.Deleted or not BillboardGui then return; end

        HighlightTable.Settings.Name = (typeof(text) == "string" and text or HighlightTable.Settings.Name);
        BillboardTable.SetText(HighlightTable.Settings.Name);
    end;
    HighlightTable.SetDistanceText = BillboardTable.SetDistanceText;

    HighlightTable.SetVisible = function(visible)
        if HighlightTable.Deleted or not Highlight then return; end

        HighlightTable.Settings.Visible = (typeof(visible) == "boolean" and visible or HighlightTable.Settings.Visible);
        Highlight.Enabled = HighlightTable.Settings.Visible;
        if HighlightTable.TracerInstance ~= nil then HighlightTable.TracerInstance.SetVisible(HighlightTable.Settings.Visible); end;
    end;

    -- // Return // --
	Library.ESP[TableName][TableIndex] = HighlightTable;
	return HighlightTable;
end

function Library.ESP.Adornment(args)
	assert(typeof(args) == "table", "args must be a table.")
	args = Library.Validate(args, Templates.Adornment);
    
    -- // Tracer // --
    do 
        args.Tracer = Library.Validate(args.Tracer, Templates.Tracer); 
        args.Tracer.Enabled = typeof(args.Tracer.Enabled) ~= "boolean" and false or args.Tracer.Enabled; 
        args.Tracer.Model = args.Model;
    end
    assert(typeof(args.Model) == "Instance", "args.Model must be an Instance.");

	args.Type = string.lower(args.Type);

	Library.Debug("Creating Adornment '" .. tostring(args.Name) .. "'...")
	local BillboardTable = Library.ESP.Billboard({
		Name = args.Name, 
		Model = args.Model,
        MaxDistance = args.MaxDistance,
        StudsOffset = args.StudsOffset,
		Color = args.TextColor,
		WasCreatedWithDifferentESP = true
	});

	local ModelSize;
    if args.Model:IsA("Model") then
        _, ModelSize = args.Model:GetBoundingBox()
    else
        ModelSize = args.Model.Size
    end

	local Adornment; do
        if args.Type == "sphere" then 
            Adornment = createInstance("SphereHandleAdornment", {
                Radius = ModelSize.X * 1.085,
                CFrame = CFrame.new() * CFrame.Angles(math.rad(90), 0, 0)
            });
        elseif args.Type == "cylinder" then 
            Adornment = createInstance("CylinderHandleAdornment", {
                Height = ModelSize.Y * 2,
                Radius = ModelSize.X * 1.085,
                CFrame = CFrame.new() * CFrame.Angles(math.rad(90), 0, 0)
            });
        else 
            Adornment = createInstance("BoxHandleAdornment", {
                Size = ModelSize
            });
        end
    end;

	Adornment.Color3 = args.Color;
	Adornment.Transparency = args.Transparency;
	Adornment.AlwaysOnTop = true;
	Adornment.ZIndex = 10;
	Adornment.Adornee = args.Model;
	Adornment.Parent = Library.Folders.Adornments;

    local TableName = "Adornments";
	local TableIndex = #Library.ESP[TableName] + 1;

	local AdornmentTable = {
        TableIndex = TableIndex, TableName = TableName,

		Settings = args,
		UIElements = { Adornment },
		TracerInstance = args.Tracer.Enabled == true and Library.ESP.Tracer(args.Tracer) or nil
    };
    AdornmentTable.Connections = {
        Library.Connections.Add(args.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local uiTable = Library.ESP[TableName][TableIndex]
                if uiTable ~= nil and typeof(uiTable.Destroy) == "function" then --or typeof(uiTable.Delete) == "function") then
                    uiTable.Destroy()
				end
                AdornmentTable.Destroy();
            end
        end))
    };

    -- // Delete Handler // --
    AdornmentTable.Deleted = false;
    AdornmentTable.Destroy = createDeleteFunction(TableName, TableIndex, AdornmentTable);
    --AdornmentTable.Delete = AdornmentTable.Destroy;

    AdornmentTable.GetDistance = BillboardTable.GetDistance;

    AdornmentTable.Update = function(args, updateVariables)
        if AdornmentTable.Deleted or (not Adornment and not BillboardGui) then return; end

        if AdornmentTable.TracerInstance ~= nil and typeof(args.Tracer) == "table" then 
            AdornmentTable.TracerInstance.Update(Library.Validate(args.Tracer, AdornmentTable.Settings.Tracer), updateVariables); 
        end;
        local settings = AdornmentTable.Settings; AdornmentTable.Settings.Tracer = nil;
        args = Library.Validate(args, settings);

        local _Color = typeof(args.Color) == "Color3" and args.Color or AdornmentTable.Settings.Color;
        local _TextColor = typeof(args.TextColor) == "Color3" and args.TextColor or AdornmentTable.Settings.TextColor;

        Adornment.Color3 = _Color;
        BillboardTable.SetColor(_TextColor, updateVariables);

        if updateVariables ~= false then
            AdornmentTable.Settings.Color     = _Color;
            AdornmentTable.Settings.TextColor = _TextColor;

            AdornmentTable.Settings.MaxDistance = typeof(args.MaxDistance) == "number" and args.MaxDistance or AdornmentTable.Settings.MaxDistance;
        end
    end;
    AdornmentTable.SetColor = AdornmentTable.Update;

	AdornmentTable.SetText = function(text)
        if AdornmentTable.Deleted or not BillboardGui then return; end

        AdornmentTable.Settings.Name = (typeof(text) == "string" and text or AdornmentTable.Settings.Name);
        BillboardTable.SetText(AdornmentTable.Settings.Name);
    end;
    AdornmentTable.SetDistanceText = BillboardTable.SetDistanceText;

	AdornmentTable.SetVisible = function(visible)
        if AdornmentTable.Deleted or not Adornment then return; end

        AdornmentTable.Settings.Visible = (typeof(visible) == "boolean" and visible or AdornmentTable.Settings.Visible);
        Adornment.Adornee = AdornmentTable.Settings.Visible and AdornmentTable.Settings.Model or nil;
        if AdornmentTable.TracerInstance ~= nil then AdornmentTable.TracerInstance.SetVisible(AdornmentTable.Settings.Visible); end;
    end

    -- // Return // --
	Library.ESP[TableName][TableIndex] = AdornmentTable;
	return AdornmentTable;
end

function Library.ESP.Outline(args)
	assert(typeof(args) == "table", "args must be a table.")
	args = Library.Validate(args, Templates.Outline);
    
    -- // Tracer // --
    do 
        args.Tracer = Library.Validate(args.Tracer, Templates.Tracer); 
        args.Tracer.Enabled = typeof(args.Tracer.Enabled) ~= "boolean" and false or args.Tracer.Enabled; 
        args.Tracer.Model = args.Model;
    end
    assert(typeof(args.Model) == "Instance", "args.Model must be an Instance.");

	Library.Debug("Creating Outline '" .. tostring(args.Name) .. "'...")
	local BillboardTable = Library.ESP.Billboard({
		Name = args.Name, 
		Model = args.Model,
        MaxDistance = args.MaxDistance,
        StudsOffset = args.StudsOffset,
		Color = args.TextColor,
		WasCreatedWithDifferentESP = true
	});

	local Outline = createInstance("SelectionBox", {
		Parent = Library.Folders.Outlines,

		SurfaceColor3 = args.SurfaceColor,
		Color3 = args.BorderColor,
		LineThickness = args.Thickness,
		SurfaceTransparency = args.Transparency,

		Adornee = args.Model
	});

    local TableName = "Outlines";
    local TableIndex = #Library.ESP[TableName] + 1;

	local OutlineTable = {
        TableIndex = TableIndex, TableName = TableName,

		Settings = args,
		UIElements = { Adornment },
		TracerInstance = args.Tracer.Enabled == true and Library.ESP.Tracer(args.Tracer) or nil
    };

    OutlineTable.Connections = {
        Library.Connections.Add(args.Model.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local uiTable = Library.ESP[TableName][TableIndex]
                if uiTable ~= nil and typeof(uiTable.Destroy) == "function" then -- or typeof(uiTable.Delete) == "function") then
                    uiTable.Destroy()
				end
                OutlineTable.Destroy();
			end
        end))
    };

    -- // Delete Handler // --
    OutlineTable.Deleted = false;
    OutlineTable.Destroy = createDeleteFunction(TableName, TableIndex, OutlineTable);
    --OutlineTable.Delete = OutlineTable.Destroy;

    OutlineTable.GetDistance = BillboardTable.GetDistance;

    OutlineTable.Update = function(args, updateVariables)
        if OutlineTable.Deleted or (not Outline and not BillboardGui) then return; end

        if OutlineTable.TracerInstance ~= nil and typeof(args.Tracer) == "table" then 
            OutlineTable.TracerInstance.Update(Library.Validate(args.Tracer, OutlineTable.Settings.Tracer), updateVariables); 
        end;
        local settings = OutlineTable.Settings; OutlineTable.Settings.Tracer = nil;
        args = Library.Validate(args, settings);

        local _SurfaceColor = typeof(args.SurfaceColor) == "Color3" and args.SurfaceColor or OutlineTable.Settings.SurfaceColor;
        local _BorderColor = typeof(args.BorderColor) == "Color3" and args.BorderColor or OutlineTable.Settings.BorderColor;
        local _Thickness = typeof(args.Thickness) == "number" and args.Thickness or OutlineTable.Settings.Thickness;
        local _Transparency = typeof(args.Transparency) == "number" and args.Transparency or OutlineTable.Settings.Transparency;
        local _TextColor = typeof(args.TextColor) == "Color3" and args.TextColor or OutlineTable.Settings.TextColor;

        Outline.SurfaceColor3 = _SurfaceColor;
        Outline.Color3 = _BorderColor;
        Outline.LineThickness = _Thickness;
        Outline.SurfaceTransparency = _Transparency;
        BillboardTable.Update(_TextColor, updateVariables);

        if updateVariables ~= false then
            OutlineTable.Settings.SurfaceColor  = _SurfaceColor;
            OutlineTable.Settings.BorderColor   = _BorderColor;
            OutlineTable.Settings.Thickness     = _Thickness;
            OutlineTable.Settings.Transparency  = _Transparency;
            OutlineTable.Settings.TextColor     = _TextColor;

            OutlineTable.Settings.MaxDistance = typeof(args.MaxDistance) == "number" and args.MaxDistance or OutlineTable.Settings.MaxDistance;
        end
    end
    OutlineTable.SetColor = OutlineTable.Update;

    OutlineTable.SetText = function(text)
        if OutlineTable.Deleted or not BillboardGui then return; end
    
        OutlineTable.Settings.Name = (typeof(text) == "string" and text or OutlineTable.Settings.Name);
        BillboardTable.SetText(OutlineTable.Settings.Name);
    end
    OutlineTable.SetDistanceText = BillboardTable.SetDistanceText;

    OutlineTable.SetVisible = function(visible)
        if OutlineTable.Deleted or not Highlight then return; end

        OutlineTable.Settings.Visible = (typeof(visible) == "boolean" and visible or OutlineTable.Settings.Visible);
        Outline.Adornee = OutlineTable.Settings.Visible and OutlineTable.Settings.Model or nil;
        if OutlineTable.TracerInstance ~= nil then OutlineTable.TracerInstance.SetVisible(OutlineTable.Settings.Visible); end;
    end

    -- // Return // --
	Library.ESP[TableName][TableIndex] = OutlineTable;
	return OutlineTable;
end

Library.Connections.Add(RunService.RenderStepped:Connect(function(Delta)
    Library.Rainbow.Step = Library.Rainbow.Step + Delta

    if Library.Rainbow.Step >= (1 / 60) then
        Library.Rainbow.Step = 0

        Library.Rainbow.HueSetup = Library.Rainbow.HueSetup + (1 / 400);
        if Library.Rainbow.HueSetup > 1 then Library.Rainbow.HueSetup = 0; end;

		Library.Rainbow.Hue = Library.Rainbow.HueSetup;
        Library.Rainbow.Color = Color3.fromHSV(Library.Rainbow.Hue, 0.8, 1);
    end
end), "RainbowStepped", true);

-- // Update Handler // --
local function checkUI(uiTable, TableName, TableIndex)
	if uiTable == nil and true or (
        typeof(uiTable) == "table" and uiTable.Deleted == true
    ) then 
        if uiTable then
            if typeof(uiTable.Destroy) == "function" then uiTable.Destroy(); end
            Library.ESP[uiTable.TableName][uiTable.TableIndex] = nil;
        end

        Library.ESP[TableName][TableIndex] = nil;
		return false;
	end

	return true;
end

local function checkVisibility(ui, root)
    local pos, onScreen = worldToViewport(root:GetPivot().Position);
    local distanceFromChar = distanceFromCharacter(root);
    local maxDist = tonumber(ui.Settings.MaxDistance) or 5000

    -- // Check Distance and if its on the screen // --
    if not onScreen or distanceFromChar > maxDist then
        if ui.Hidden ~= true then
            ui.Hidden = true;
            ui.SetVisible(false);
        end

        return pos, onScreen, false;
    end

    return pos, onScreen, true;
end

Library.Connections.Add(RunService.RenderStepped:Connect(function(dt)
	if not camera then workspace:WaitForChild("CurrentCamera", 9e9); camera = workspace.CurrentCamera; end
	if not character and not rootPart then
		if not character then localPlayer.CharacterAdded:Wait() end
		updateVariables(); 
	end;

	for uiName, uiTable in pairs(Library.ESP) do
        if typeof(uiTable) ~= "table" then continue; end

		for _, ui in pairs(uiTable) do
			if not checkUI(ui, uiName, ui.TableIndex) then continue; end
            local pos, onScreen, canContinue;

            -- // Update Tracer // --
            local tracerTable = getTracerTable(ui);
            if tracerTable ~= nil then
                if tracerTable.Deleted ~= true and tracerTable.TracerDeleted ~= true and tracerTable.TracerInstance ~= nil then
                    pos, onScreen, canContinue = checkVisibility(ui, tracerTable.DistancePart)

                    if onScreen and tracerTable.Settings.Visible then
                        if tracerTable.Settings.From == "mouse" then
                            local mousePos = UserInputService:GetMouseLocation();
                            tracerTable.TracerInstance.From = Vector2.new(mousePos.X, mousePos.Y);

                        elseif tracerTable.Settings.From == "top" then
                            tracerTable.TracerInstance.From = Vector2.new(camera.ViewportSize.X / 2, 0);

                        elseif tracerTable.Settings.From == "center" then
                            tracerTable.TracerInstance.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2);

                        else
                            tracerTable.TracerInstance.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y);
                        end
        
                        tracerTable.TracerInstance.To = Vector2.new(pos.X, pos.Y);
                        tracerTable.Update({ Color = Library.Rainbow.Enabled and Library.Rainbow.Color or tracerTable.Settings.Color }, false);
                    else
                        if tracerTable.Hidden ~= true then
                            tracerTable.Hidden = true;
                            tracerTable.TracerInstance.Visible = false;
                        end
                    end
                else
                    if tracerTable.Deleted ~= true then
                        tracerTable.Deleted = true;
                        if tracerTable.TracerInstance ~= nil then
                            tracerTable.TracerInstance.Visible = false;
                        end;
                    end
                end
			end

            -- // Update // --
            local pos, onScreen, canContinue = checkVisibility(ui, ui.Settings.Model)
            if not canContinue then continue; end
            if ui.Hidden == true then ui.Hidden = nil; ui.SetVisible(true); end
            
			if uiName == "Billboards" then
				ui.SetDistanceText(ui.GetDistance());

				if ui.WasCreatedWithDifferentESP ~= true then continue; end
				ui.Update({ Color = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.Color }, false);
			elseif uiName == "Adornments" then
				ui.Update({ 
					Color        = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.Color, 
					TextColor    = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.TextColor
				}, false);
            elseif uiName == "Highlights" then
                ui.Update({ 
                    FillColor    = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.FillColor, 
                    OutlineColor = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.OutlineColor, 
                    TextColor    = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.TextColor
                }, false);
            elseif uiName == "Outlines" then
                ui.Update({ 
                    SurfaceColor = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.SurfaceColor, 
                    OutlineColor = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.OutlineColor, 
                    TextColor    = Library.Rainbow.Enabled and Library.Rainbow.Color or ui.Settings.TextColor
                }, false);
            end
		end
	end
end), "MainUpdate", true);

-- // Set Library and return it // --
global().mstudio45 = global().mstudio45 or { };
global().mstudio45.ESPLibrary = Library;
Library.Print("Loaded!");
return Library;
