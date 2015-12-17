--[[
Title: based on NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/SaveSTLDialog.lua"); 
Author(s): leio
Date: 2015/12/17
Desc: Display a dialog with text that let user to enter filename. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/STLExporter/SaveSTLDialog.lua");
local SaveSTLDialog = commonlib.gettable("Mod.STLExporter.SaveSTLDialog");
SaveSTLDialog.ShowPage("Please enter text", function(result)
	echo(result);
end, default_text, title, filters)
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Files.lua");
local Files = commonlib.gettable("MyCompany.Aries.Game.Common.Files");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");

local SaveSTLDialog = commonlib.gettable("Mod.STLExporter.SaveSTLDialog");
-- whether in save mode. 
SaveSTLDialog.IsSaveMode = false;

SaveSTLDialog.unit_max_value = 10000;
SaveSTLDialog.unit_ds = {
	{ text = "0.1", value = 0.1, } ,
	{ text = "0.5", value = 0.5, } ,
	{ text = "1", value = 1, selected="selected", } ,
	{ text = "5", value = 5, } ,
	{ text = "10", value = 10, } ,
	{ text = "50", value = 50, } ,
	{ text = "100", value = 100, } ,
	{ text = "500", value = 500, } ,
	{ text = "1000", value = 1000, } ,
	{ text = tostring(SaveSTLDialog.unit_max_value), value = SaveSTLDialog.unit_max_value, } ,
}
local page;
function SaveSTLDialog.OnInit()
	page = document:GetPageCtrl();
end

-- @param filterName: "model", "bmax", "audio", "texture"
function SaveSTLDialog.GetFilters(filterName)
	if(filterName == "model") then
		return {
			{L"全部文件(*.fbx,*.x,*.bmax)",  "*.fbx;*.x;*.bmax"},
			{L"FBX模型(*.fbx)",  "*.fbx"},
			{L"bmax模型(*.bmax)",  "*.bmax"},
			{L"ParaX模型(*.x)",  "*.x"},
		};
	elseif(filterName == "bmax") then
		return {
			{L"bmax模型(*.bmax)",  "*.bmax"},
		};
	elseif(filterName == "audio") then
		return {
			{L"全部文件(*.mp3,*.ogg,*.wav)",  "*.mp3;*.ogg;*.wav"},
			{L"mp3(*.mp3)",  "*.mp3"},
			{L"ogg(*.ogg)",  "*.ogg"},
			{L"wav(*.wav)",  "*.wav"},
		};
	elseif(filterName == "texture") then
		return {
			{L"全部文件(*.png,*.jpg)",  "*.png;*.jpg"},
			{L"png(*.png)",  "*.png"},
			{L"jpg(*.jpg)",  "*.jpg"},
		};
	end
end

-- @param default_text: default text to be displayed. 
-- @param filters: "model", "bmax", "audio", "texture", nil for any file, or filters table
function SaveSTLDialog.ShowPage(text, OnClose, default_text, title, filters, IsSaveMode)
	SaveSTLDialog.result = nil;
	SaveSTLDialog.text = text;
	SaveSTLDialog.title = title;
	if(type(filters) == "string") then
		filters = SaveSTLDialog.GetFilters(filters)
	end
	SaveSTLDialog.filters = filters;
	
	SaveSTLDialog.IsSaveMode = IsSaveMode == true;

	local params = {
			url = "Mod/STLExporter/SaveSTLDialog.html", 
			name = "SaveSTLDialog.ShowPage", 
			isShowTitleBar = false,
			DestroyOnClose = true,
			bToggleShowHide=false, 
			style = CommonCtrl.WindowFrame.ContainerStyle,
			allowDrag = true,
			click_through = false, 
			enable_esc_key = true,
			bShow = true,
			isTopLevel = true,
			---app_key = MyCompany.Aries.Creator.Game.Desktop.App.app_key, 
			directPosition = true,
				align = "_ct",
				x = -200,
				y = -150,
				width = 400,
				height = 400,
		};
	System.App.Commands.Call("File.MCMLWindowFrame", params);

	if(default_text) then
		params._page:SetUIValue("text", default_text);
	end
	params._page.OnClose = function()
		if(OnClose) then
			OnClose(SaveSTLDialog.result);
		end
	end
end


function SaveSTLDialog.OnOK()
	if(page) then
		local filename = page:GetValue("text");
		local unit = page:GetValue("comboUnits");
		unit  = tonumber(unit) or -1;
		if(unit < 0 )then
			_guihelper.MessageBox("invalid value!");
			return
		end
		if(unit > SaveSTLDialog.unit_max_value)then
			_guihelper.MessageBox(string.format("the max value is %d!",SaveSTLDialog.unit_max_value));
			return
		end
		SaveSTLDialog.result = {
			filename = filename,
			unit = unit,	
		}
		page:CloseWindow();
	end
end

function SaveSTLDialog.OnSaveSTLDialog()
	NPL.load("(gl)script/ide/OpenFileDialog.lua");
	local filename = CommonCtrl.OpenFileDialog.ShowDialog_Win32(SaveSTLDialog.filters, 
		SaveSTLDialog.title,
		ParaIO.GetCurDirectory(0)..(GameLogic.GetWorldDirectory() or ""), 
		SaveSTLDialog.IsSaveMode);
	if(filename and page) then
		local fileItem = Files.ResolveFilePath(filename);
		if(fileItem and fileItem.relativeToWorldPath) then
			local filename = fileItem.relativeToWorldPath;
			page:SetValue("text", filename);
		end
	end
end

function SaveSTLDialog.GetText()
	return SaveSTLDialog.text or L"请输入:";
end