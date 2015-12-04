--[[
Title: bmax exporter
Author(s): leio, refactored LiXizhi
Date: 2015/11/25
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/STLExporter/main.lua");
local STLExporter = commonlib.gettable("Mod.STLExporter");
local exporter = STLExporter:new();
exporter:Export("test/default.bmax",nil,true);
------------------------------------------------------------
]]
local STLExporter = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.STLExporter"));
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");	
local BroadcastHelper = commonlib.gettable("CommonCtrl.BroadcastHelper");
NPL.load("(gl)script/ide/XPath.lua");
NPL.load("(gl)script/ide/math/ShapeAABB.lua");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
NPL.load("(gl)script/ide/math/vector.lua");
local vector3d = commonlib.gettable("mathlib.vector3d");
NPL.load("(gl)script/ide/math/bit.lua");
local bit = mathlib.bit;
--    LT  -----  RT
--       |     |
--       |     |
--    LB  -----  RB   
--vertex indices
--top face
local g_topLB = 0;
local g_topLT = 1;
local g_topRT = 2;
local g_topRB = 3;

--front face
local g_frtLB = 4;
local g_frtLT = 5;
local g_frtRT = 6;
local g_frtRB = 7;

--bottom face
local g_btmLB = 8;
local g_btmLT = 9;
local g_btmRT = 10;
local g_btmRB = 11;

--left face
local g_leftLB = 12;
local g_leftLT = 13;
local g_leftRT = 14;
local g_leftRB = 15;

--right face
local g_rightLB = 16;
local g_rightLT = 17;
local g_rightRT = 18;
local g_rightRB = 19;

--back face
local g_bkLB = 20;
local g_bkLT = 21;
local g_bkRT = 22;
local g_bkRB = 23;

local g_regionBlockDimX = 512;
local g_regionBlockDimY = 256;
local g_regionBlockDimZ = 512;

local g_chunkBlockDim = 16;
local g_chunkBlockCount = 16 * 16 * 16;

local g_regionChunkDimX = g_regionBlockDimX / g_chunkBlockDim; -- 32
local g_regionChunkDimY = g_regionBlockDimY / g_chunkBlockDim; -- 16
local g_regionChunkDimZ = g_regionBlockDimZ / g_chunkBlockDim; -- 32
local g_regionChunkCount = g_regionChunkDimX * g_regionChunkDimY * g_regionChunkDimZ;

-- make this bigger, but no bigger than (65536/6) = 10920, should be multiple of 6.
-- because we need to reference with 16 bits index in a shared index buffer. (2*3 vertices per face)
local g_maxFaceCountPerBatch = 9000;

local g_maxValidLightValue = 127;
local g_sunLightValue = 0xf;
local g_maxLightValue = 0xf;

local g_regionSize = 533.3333;
local g_chunkSize = g_regionSize * (1.0 / g_regionChunkDimX);
local g_dBlockSize = (g_regionSize) * (1.0 / g_regionBlockDimX);
local g_dBlockSizeInverse = 1.0 / g_dBlockSize;
local g_blockSize = g_dBlockSize;
local g_half_blockSize = g_blockSize*0.5;
local function Int16x3(x,y,z)
	return {x = x,y = y,z = z};
end
local NeighborOfsTable =
	{
		[0] = Int16x3(0,0,0),			--0	 rbp_center 
		[1] = Int16x3(1,0,0),			--1	 rbp_pX	
		[2] = Int16x3(-1,0,0),			--2	 rbp_nX	
		[3] = Int16x3(0,1,0),			--3	 rbp_pY	
		[4] = Int16x3(0,-1,0),			--4	 rbp_nY	
		[5] = Int16x3(0,0,1),			--5	 rbp_pZ	
		[6] = Int16x3(0,0,-1),			--6	 rbp_nz	
		[7] = Int16x3(1,1,0),			--7	 rbp_pXpY	
		[8] = Int16x3(1,-1,0),			--8	 rbp_pXnY	
		[9] = Int16x3(1,0,1),			--9	 rbp_pXpZ	
		[10] = Int16x3(1,0,-1),			--10 rbp_pXnZ	
		[11] = Int16x3(-1,1,0),			--11 rbp_nXpY	
		[12] = Int16x3(-1,-1,0),		--12 rbp_nXnY	
		[13] = Int16x3(-1,0,1),			--13 rbp_nXpZ	
		[14] = Int16x3(-1,0,-1),		--14 rbp_nXnZ	
		[15] = Int16x3(0,1,1),			--15 rbp_pYpZ	
		[16] = Int16x3(0,1,-1),			--16 rbp_pYnZ	
		[17] = Int16x3(0,-1,1),			--17 rbp_nYpZ	
		[18] = Int16x3(0,-1,-1),		--18 rbp_nYnZ	
		[19] = Int16x3(1,1,1),			--19 rbp_pXpYpZ 
		[20] = Int16x3(1,1,-1),			--20 rbp_pXpYnZ 
		[21] = Int16x3(1,-1,1),			--21 rbp_pXnYPz 
		[22] = Int16x3(1,-1,-1),		--22 rbp_pXnYnZ 
		[23] = Int16x3(-1,1,1),			--23 rbp_nXpYpZ 
		[24] = Int16x3(-1,1,-1),		--24 rbp_nXpYnZ 
		[25] = Int16x3(-1,-1,1),		--25 rbp_nXnYPz 
		[26] = Int16x3(-1,-1,-1),		--26 rbp_nXnYnZ 
	};
local RelativeBlockPos_Start_Index = -1;
local function get_next()
	RelativeBlockPos_Start_Index = RelativeBlockPos_Start_Index + 1;
	return RelativeBlockPos_Start_Index;
end
local rbp_center			= get_next(); --0
local rbp_pX				= get_next();
local rbp_nX				= get_next();
local rbp_pY				= get_next();
local rbp_nY				= get_next();
local rbp_pZ				= get_next();
local rbp_nZ				= get_next();

local rbp_pXpY				= get_next();
local rbp_pXnY				= get_next();
local rbp_pXpZ				= get_next();
local rbp_pXnZ				= get_next();

local rbp_nXpY				= get_next();
local rbp_nXnY				= get_next();
local rbp_nXpZ				= get_next();
local rbp_nXnZ				= get_next();

local rbp_pYpZ				= get_next();
local rbp_pYnZ				= get_next();
local rbp_nYpZ				= get_next();
local rbp_nYnZ				= get_next();

local rbp_pXpYpZ			= get_next();
local rbp_pXpYnZ			= get_next();
local rbp_pXnYPz			= get_next();
local rbp_pXnYnZ			= get_next();
local rbp_nXpYpZ			= get_next();
local rbp_nXpYnZ			= get_next();
local rbp_nXnYPz			= get_next();
local rbp_nXnYnZ			= get_next();


local RBP_SixNeighbors = {
		[0] = rbp_pY,
		[1] = rbp_nZ,
		[2] = rbp_nY,
		[3] = rbp_nX,
		[4] = rbp_pX,
		[5] = rbp_pZ,
	};
local MAX_BLOCK_CNT = 256 * 256 * 256;

local function get_vertex(cube,index_1,index_2,index_3)
	if(not cube)then return end
	local pos_1;
	local pos_2;
	local pos_3;
	if(cube[index_1] and cube[index_1].position)then
		pos_1 = cube[index_1].position;
	end
	if(cube[index_2] and cube[index_2].position)then
		pos_2 = cube[index_2].position;
	end
	if(cube[index_3] and cube[index_3].position)then
		pos_3 = cube[index_3].position;
	end
	return pos_1,pos_2,pos_3;
end

function STLExporter:ctor()
	LOG.std(nil, "info", "STLExporter", "ctor");
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

	self.m_bAutoScale = true;
	self.m_blockAABB = nil;
	self.m_centerPos = nil;
	self.m_fScale = 1;
	self.m_nodes = {};
	self.m_blockModels = {};

	self:RegisterCommand();
	self:RegisterExporter();
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

function STLExporter:RegisterExporter()
	GameLogic.GetFilters():add_filter("GetExporters", function(exporters)
		exporters[#exporters+1] = {id="STL", title="STL exporter", desc="export stl files for 3d printing"}
		return exporters;
	end);

	GameLogic.GetFilters():add_filter("select_exporter", function(id)
		if(id == "STL") then
			id = nil; -- prevent other exporters
			self:OnClickExport();
		end
		return id;
	end);
end

function STLExporter:RegisterCommand()
	local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
	Commands["stlexporter"] = {
		name="stlexporter", 
		quick_ref="/stlexporter [-b|binary] [-native|cpp] [filename]", 
		desc=[[export a bmax file or current selection to stl file
@param -b: export as binary STL file
@param -native: use C++ exporter, instead of NPL.
/stlexporter test.stl			export current selection to test.stl file
/stlexporter -b test.bmax		convert test.bmax file to test.stl file
]], 
		handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
			local file_name, options;
			options, cmd_text = CmdParser.ParseOptions(cmd_text);
			file_name,cmd_text = CmdParser.ParseString(cmd_text);

			local save_as_binary = options.b~=nil or options.binary~=nil;
			local use_cpp_native = options.native~=nil or options.cpp~=nil;
			self:Export(file_name,nil, save_as_binary, use_cpp_native);
		end,
	};
end

function STLExporter:OnClickExport()
	NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/SaveFileDialog.lua");
	local SaveFileDialog = commonlib.gettable("MyCompany.Aries.Game.GUI.SaveFileDialog");
	SaveFileDialog.ShowPage("please enter STL file name", function(result)
		if(result and result~="") then
			STLExporter.last_filename = result;
			local filename = GameLogic.GetWorldDirectory()..result;
			LOG.std(nil, "info", "STLExporter", "exporting to %s", filename);
			GameLogic.RunCommand("stlexporter", filename);
		end
	end, STLExporter.last_filename, nil, "stl");
end

-- @param input_file_name: file name. if it is *.bmax, we will convert this file and save output to *.stl file.
-- if it is not, we will convert current selection to *.stl files. 
-- @param output_file_name: this should be nil, unless you explicitly specify an output name. 
-- @param -binary: export as binary STL file
-- @param -native: use C++ exporter, instead of NPL.
function STLExporter:Export(input_file_name,output_file_name,binary,native)
	input_file_name = input_file_name or "default.stl";
	binary = binary == true;

	local name, extension = string.match(input_file_name,"(.+).(%w%w%w)$");

	if(not output_file_name)then
		if(extension == "bmax") then
			output_file_name = name .. ".stl";
		elseif(extension == "stl") then
			output_file_name = name .. ".stl";
		else
			output_file_name = input_file_name..".stl";
		end
	end
	LOG.std(nil, "info", "STLExporter", "exporting from %s to %s", input_file_name, output_file_name);
	self:Load(input_file_name);

	if(native)then
		if(ParaScene.BmaxExportToSTL)then
			if(ParaScene.BmaxExportToSTL(input_file_name,output_file_name, binary))then
				BroadcastHelper.PushLabel({id="stlexporter", label = format(L"STL文件成功保存到:%s", commonlib.Encoding.DefaultToUtf8(output_file_name)), max_duration=4000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
			end
		end
	else
		if(binary)then
			self:Export_internal_binary(output_file_name);
		else
			self:Export_internal(output_file_name);
		end
		BroadcastHelper.PushLabel({id="stlexporter", label = format(L"STL文件成功保存到:%s", commonlib.Encoding.DefaultToUtf8(output_file_name)), max_duration=4000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
	end
end
function STLExporter:Export_internal_binary(output_file_name)
	ParaIO.CreateDirectory(output_file_name);
	local face_cont = 6;
	
	local function write_face(file,vertex_1,vertex_2,vertex_3)
		if(not vertex_1 or not vertex_2 or not vertex_3)then
			return
		end
		local a = vector3d.__sub(vertex_3,vertex_1);
		local b = vector3d.__sub(vertex_3,vertex_2);
		local normal = vector3d.__mul(a,b);
		normal:normalize();
		file:WriteFloat(normal[1]);
		file:WriteFloat(normal[2]);
		file:WriteFloat(normal[3]);

		file:WriteFloat(vertex_1[1]);
		file:WriteFloat(vertex_1[2]);
		file:WriteFloat(vertex_1[3]);

		file:WriteFloat(vertex_2[1]);
		file:WriteFloat(vertex_2[2]);
		file:WriteFloat(vertex_2[3]);

		file:WriteFloat(vertex_3[1]);
		file:WriteFloat(vertex_3[2]);
		file:WriteFloat(vertex_3[3]);

		local dummy = "\0\0";
		file:write(dummy,2);
	end
	local file = ParaIO.open(output_file_name, "w");
	if(file:IsValid()) then
		local name = "ParaEngine";
		local total = 80;
		local k;
		for k = string.len(name),total-1 do
			name = name .. "\0";
		end
		file:write(name,total);
		local cnt = self:GetTotalTriangleCnt();
		file:WriteInt(cnt);
		local __,cube;
		for __,cube in ipairs(self.m_blockModels) do
			local k;
			for k = 0,face_cont-1 do	
				local start_index = k * 4;
				local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 1,start_index + 2);
				write_face(file,vertex_1,vertex_2,vertex_3);

				local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 2,start_index + 3);
				write_face(file,vertex_1,vertex_2,vertex_3);
			end
		end	
		file:close();
	end
end
function STLExporter:Export_internal(output_file_name)
	ParaIO.CreateDirectory(output_file_name);
	local face_cont = 6;
	local function write_face(file,vertex_1,vertex_2,vertex_3)
		if(not vertex_1 or not vertex_2 or not vertex_3)then
			return
		end
		local a = vector3d.__sub(vertex_3,vertex_1);
		local b = vector3d.__sub(vertex_3,vertex_2);
		local normal = vector3d.__mul(a,b);
		normal:normalize();
		file:WriteString(string.format(" facet normal %f %f %f\n", normal[1], normal[2], normal[3]));
		file:WriteString(string.format("  outer loop\n"));
		file:WriteString(string.format("  vertex %f %f %f\n", vertex_1[1], vertex_1[2], vertex_1[3]));
		file:WriteString(string.format("  vertex %f %f %f\n", vertex_2[1], vertex_2[2], vertex_2[3]));
		file:WriteString(string.format("  vertex %f %f %f\n", vertex_3[1], vertex_3[2], vertex_3[3]));
		file:WriteString(string.format("  endloop\n"));
		file:WriteString(string.format(" endfacet\n"));
	end
	local file = ParaIO.open(output_file_name, "w");
	if(file:IsValid()) then
		local name = "ParaEngine";
		file:WriteString(string.format("solid %s\n",name));
		local __,cube;
		for __,cube in ipairs(self.m_blockModels) do
			local k;
			for k = 0,face_cont-1 do	
				local start_index = k * 4;
				local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 1,start_index + 2);
				write_face(file,vertex_1,vertex_2,vertex_3);

				local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 2,start_index + 3);
				write_face(file,vertex_1,vertex_2,vertex_3);
			end
		end	
		file:WriteString(string.format("endsolid %s\n",name));
		file:close();
	end
end
function STLExporter:CreateCube()
	local m_Vertices = {};
	local k;
	for k = g_topLB,g_bkRB do
		m_Vertices[k] = {};
	end
	--top face
	m_Vertices[g_topLB].position = {0,1,0};
	m_Vertices[g_topLT].position = {0,1,1};
	m_Vertices[g_topRT].position = {1,1,1};
	m_Vertices[g_topRB].position = {1,1,0};

	m_Vertices[g_topLB].normal = {0,1,0};
	m_Vertices[g_topLT].normal = {0,1,0};
	m_Vertices[g_topRT].normal = {0,1,0};
	m_Vertices[g_topRB].normal = {0,1,0};

	--front face
	m_Vertices[g_frtLB].position = {0,0,0};
	m_Vertices[g_frtLT].position = {0,1,0};
	m_Vertices[g_frtRT].position = {1,1,0};
	m_Vertices[g_frtRB].position = {1,0,0};

	m_Vertices[g_frtLB].normal = {0,0,-1};
	m_Vertices[g_frtLT].normal = {0,0,-1};
	m_Vertices[g_frtRT].normal = {0,0,-1};
	m_Vertices[g_frtRB].normal = {0,0,-1};

	--bottom face
	m_Vertices[g_btmLB].position = {0,0,1};
	m_Vertices[g_btmLT].position = {0,0,0};
	m_Vertices[g_btmRT].position = {1,0,0};
	m_Vertices[g_btmRB].position = {1,0,1};

	m_Vertices[g_btmLB].normal = {0,-1,0};
	m_Vertices[g_btmLT].normal = {0,-1,0};
	m_Vertices[g_btmRT].normal = {0,-1,0};
	m_Vertices[g_btmRB].normal = {0,-1,0};

	--left face
	m_Vertices[g_leftLB].position = {0,0,1};
	m_Vertices[g_leftLT].position = {0,1,1};
	m_Vertices[g_leftRT].position = {0,1,0};
	m_Vertices[g_leftRB].position = {0,0,0};

	m_Vertices[g_leftLB].normal = {-1,0,0};
	m_Vertices[g_leftLT].normal = {-1,0,0};
	m_Vertices[g_leftRT].normal = {-1,0,0};
	m_Vertices[g_leftRB].normal = {-1,0,0};

	--right face
	m_Vertices[g_rightLB].position = {1,0,0};
	m_Vertices[g_rightLT].position = {1,1,0};
	m_Vertices[g_rightRT].position = {1,1,1};
	m_Vertices[g_rightRB].position = {1,0,1};

	m_Vertices[g_rightLB].normal = {1,0,0};
	m_Vertices[g_rightLT].normal = {1,0,0};
	m_Vertices[g_rightRT].normal = {1,0,0};
	m_Vertices[g_rightRB].normal = {1,0,0};

	--back face
	m_Vertices[g_bkLB].position = {1,0,1};
	m_Vertices[g_bkLT].position = {1,1,1};
	m_Vertices[g_bkRT].position = {0,1,1};
	m_Vertices[g_bkRB].position = {0,0,1};

	m_Vertices[g_bkLB].normal = {0,0,1};
	m_Vertices[g_bkLT].normal = {0,0,1};
	m_Vertices[g_bkRT].normal = {0,0,1};
	m_Vertices[g_bkRB].normal = {0,0,1};
	return m_Vertices;
end
function STLExporter:OffsetPosition(cube,dx,dy,dz)
	if(not cube)then return end
	local k;
	for k = g_topLB,g_bkRB do
		if(cube[k] and cube[k].position)then
			cube[k].position[1] = cube[k].position[1] + dx;
			cube[k].position[2] = cube[k].position[2] + dy;
			cube[k].position[3] = cube[k].position[3] + dz;
		end
	end
end
function STLExporter:Load(bmax_filename)
	if(not bmax_filename)then return end
	local xmlRoot = ParaXML.LuaXML_ParseFile(bmax_filename);
	self:ParseHeader(xmlRoot);
	self:ParseBlocks(xmlRoot);
	self:ParseVisibleBlocks();
	if(self.m_bAutoScale)then
		self:ScaleModels();
	end
end
function STLExporter:ParseHeader(xmlRoot)
	if(not xmlRoot)then return end
	local blocktemplate = xmlRoot[1];
	if(blocktemplate and blocktemplate.attr and blocktemplate.attr.auto_scale and (blocktemplate.attr.auto_scale == "false" or blocktemplate.attr.auto_scale == "False"))then
		self.m_bAutoScale = false;	
	end
end
function STLExporter:ParseBlocks(xmlRoot)
	if(not xmlRoot)then return end
	local node;
	local result;
	for node in commonlib.XPath.eachNode(xmlRoot, "/pe:blocktemplate/pe:blocks") do
		--find block node
		result = node;
		break;
	end
	if(not result)then return end
	local blocks = commonlib.LoadTableFromString(result[1]);
	local nodes = {};
	local aabb = ShapeAABB:new();
	local k,v;
	for k,v in ipairs(blocks) do
		local x = v[1];
		local y = v[2];
		local z = v[3];
		local template_id = v[4];
		local block_data = v[5];
		aabb:Extend(x,y,z);
		local node = {
			x = x,
			y = y,
			z = z,
			template_id = template_id,
			block_data = block_data,
		}
		table.insert(nodes,node);
	end
	self.m_blockAABB = aabb;

	local blockMinX,  blockMinY, blockMinZ = self.m_blockAABB:GetMinValues()
	local blockMaxX,  blockMaxY, blockMaxZ = self.m_blockAABB:GetMaxValues();
	local width = blockMaxX - blockMinX;
	local height = blockMaxY - blockMinY;
	local depth = blockMaxZ - blockMinZ;

	self.m_centerPos = self.m_blockAABB:GetCenter();
	self.m_centerPos[1] = (width + 1.0) * 0.5;
	self.m_centerPos[2] = 0;
	self.m_centerPos[3]= (depth + 1.0) * 0.5;


	local offset_x = blockMinX;
	local offset_y = blockMinY;
	local offset_z = blockMinZ;

	local k,node;
	for k,node in ipairs(nodes) do
		node.x = node.x - offset_x;
		node.y = node.y - offset_y;
		node.z = node.z - offset_z;
		self:InsertNode(node);
	end
	--set scaling;
	if (self.m_bAutoScale) then
		local fMaxLength = math.max(math.max(height, width), depth) + 1;
		self.m_fScale = self:CalculateScale(fMaxLength);
	end
end

function STLExporter:NextPowerOf2(x)
	x = x - 1;
	x = bit.bor(x,bit.rshift(x,1));
	x = bit.bor(x,bit.rshift(x,2));
	x = bit.bor(x,bit.rshift(x,4));
	x = bit.bor(x,bit.rshift(x,8));
	x = bit.bor(x,bit.rshift(x,16));
	return x + 1;
	--x = x | (x >> 1);
	--x = x | (x >> 2);
	--x = x | (x >> 4);
	--x = x | (x >> 8);
	--x = x | (x >> 16);
	--return x + 1;
end
function STLExporter:CalculateScale(length)
	local nPowerOf2Length = self:NextPowerOf2(length + 0.1);
	return g_blockSize / nPowerOf2Length;
end

function STLExporter:InsertNode(node)
	if(not node)then return end
	local index = self:GetNodeIndex(node.x,node.y,node.z);
	if(index)then
		self.m_nodes[index] = node;
	end
end
function STLExporter:GetNode(x,y,z)
	local index = self:GetNodeIndex(x,y,z);
	if(not index)then
		return
	end
	return self.m_nodes[index];
end
function STLExporter:GetNodeIndex(x,y,z)
	if(x < 0 or y < 0 or z < 0)then
		return
	end
	return x + bit.lshift(z, 8) + bit.lshift(y, 16);
	--return (DWORD)x + ((DWORD)z << 8) + ((DWORD)y << 16);
end
function STLExporter:ParseVisibleBlocks()
	local k,node;
	local k;
	for k = 0,MAX_BLOCK_CNT do
		local node = self.m_nodes[k];
		if(node)then
			local cube = self:TessellateBlock(node.x,node.y,node.z);
			if(self:GetVerticesCount(cube) > 0)then
				table.insert(self.m_blockModels,cube);
			end
		end
	end
end
function STLExporter:TessellateBlock(x,y,z)
	local node = self:GetNode(x,y,z);
	if(not node)then
		return
	end
	local cube = {};
	local nNearbyBlockCount = 27;
	local neighborBlocks = {};
	neighborBlocks[rbp_center] = node;
	self:QueryNeighborBlockData(x, y, z, neighborBlocks, 1, nNearbyBlockCount - 1);
	local temp_cube = self:CreateCube();
	local dx = node.x - self.m_centerPos[1];
	local dy = node.y - self.m_centerPos[2];
	local dz = node.z - self.m_centerPos[3];
	self:OffsetPosition(temp_cube,dx,dy,dz);

	local nFaceCount = 6;
	local face;
	for face = 0,nFaceCount - 1 do
		local nFirstVertex = face * 4;
		local pCurBlock = neighborBlocks[RBP_SixNeighbors[face]];
		if(not pCurBlock)then
			local v;
			for v = 0,3 do
				local i = nFirstVertex + v;
				self:AddVertex(cube,temp_cube, i);
			end
		end
	end
	return cube;
end
function STLExporter:QueryNeighborBlockData(x,y,z,pBlockData,nFrom,nTo)
	local neighborOfsTable = NeighborOfsTable;
	local node = self:GetNode(x, y, z);
	if(not node)then return end
	local i;
	for i = nFrom,nTo do
		local xx = x + neighborOfsTable[i].x;
		local yy = y + neighborOfsTable[i].y;
		local zz = z + neighborOfsTable[i].z;

		local pBlock = self:GetNode(xx,yy,zz);
		local index = i - nFrom + 1;
		pBlockData[index] = pBlock;
	end
end
function STLExporter:GetVerticesCount(cube)
	if(not cube)then 
		return 0;
	end
	local cnt = 0;
	local k;
	for k = g_topLB,g_bkRB do
		if(cube[k] and cube[k].position)then
			cnt = cnt + 1;
		end
	end
	return cnt;
end
function STLExporter:ScaleModels()
	local scale = self.m_fScale;
	local __,cube;
	for __,cube in ipairs(self.m_blockModels) do
		local k;
		for k = g_topLB,g_bkRB do
			if(cube[k] and cube[k].position)then
				cube[k].position[1] = cube[k].position[1] * scale;
				cube[k].position[2] = cube[k].position[2] * scale;
				cube[k].position[3] = cube[k].position[3] * scale;
			end
		end
	end
end
function STLExporter:AddVertex(target_cube,source_cube,index)
	if(not target_cube or not source_cube)then
		return
	end
	target_cube[index] = target_cube[index] or {};
	target_cube[index].position = {
		source_cube[index].position[1],
		source_cube[index].position[2],
		source_cube[index].position[3],
	};
	target_cube[index].nomral= {
		source_cube[index].normal[1],
		source_cube[index].normal[2],
		source_cube[index].normal[3],
	};
end
function STLExporter:GetTotalTriangleCnt()
	local face_cont = 6;
	local cnt = 0;
	local __,cube;
	for __,cube in ipairs(self.m_blockModels) do
		local k;
		for k = 0,face_cont-1 do	
			local start_index = k * 4;
			local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 1,start_index + 2);
			if(vertex_1)then
				cnt = cnt + 1;
			end

			local vertex_1,vertex_2,vertex_3 = get_vertex(cube,start_index + 0,start_index + 2,start_index + 3);
			if(vertex_1)then
				cnt = cnt + 1;
			end
		end
	end	
	return cnt;
end
