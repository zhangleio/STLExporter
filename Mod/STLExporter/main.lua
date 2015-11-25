--[[
Title: bmax exporter
Author(s): leio
Date: 2015/11/25
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/STLExporter/main.lua");
local STLExporter = commonlib.gettable("Mod.STLExporter");
------------------------------------------------------------
]]
local STLExporter = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.STLExporter"));
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");	
local BroadcastHelper = commonlib.gettable("CommonCtrl.BroadcastHelper");

function STLExporter:ctor()
end

-- virtual function get mod name

function STLExporter:GetName()
	return "STLExporter"
end

-- virtual function get mod description 

function STLExporter:GetDesc()
	return "STLExporter is a plugin in paracraft"
end

function STLExporter:init()
	LOG.std(nil, "info", "STLExporter", "plugin initialized");
	self:RegisterCommand();
end

function STLExporter:OnLogin()
end
-- called when a new world is loaded. 

function STLExporter:OnWorldLoad()
end
-- called when a world is unloaded. 

function STLExporter:OnLeaveWorld()
end

function STLExporter:OnDestroy()
end

function STLExporter:RegisterCommand()
	local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
	Commands["stlexporter"] = {
		name="stlexporter", 
		quick_ref="/stlexporter", 
		desc=[[export a bmax file to stl file
/stlexporter input_file_name
/stlexporter input_file_name true
]], 
		handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
			local input_file_name,cmd_text = CmdParser.ParseString(cmd_text);
			local binary = CmdParser.ParseBool(cmd_text);
			self:Export(input_file_name,nil,binary);
		end,
	};
end
function STLExporter:Export(input_file_name,output_file_name,binary)
	if(not input_file_name)then return end
	if(binary == nil)then
		binary = false;
	end
	if(not output_file_name)then
		local __,__,name = string.find(input_file_name,"(.+).bmax");
		name = name or input_file_name;
		output_file_name = name .. ".stl";
	end
	if(ParaScene.BmaxExportToSTL(input_file_name,output_file_name,binary))then
		BroadcastHelper.PushLabel({id="stlexporter", label = format(L"STL文件成功保存到:%s", commonlib.Encoding.DefaultToUtf8(output_file_name)), max_duration=4000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
	end
end
