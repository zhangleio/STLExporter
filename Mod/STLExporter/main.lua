--[[
Title: bmax exporter
Author(s): leio
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
	return {x,y,z};
end
local NeighborOfsTable =
	{
		Int16x3(0,0,0),			--0	 rbp_center 
		Int16x3(1,0,0),			--1	 rbp_pX	
		Int16x3(-1,0,0),			--2	 rbp_nX	
		Int16x3(0,1,0),			--3	 rbp_pY	
		Int16x3(0,-1,0),			--4	 rbp_nY	
		Int16x3(0,0,1),			--5	 rbp_pZ	
		Int16x3(0,0,-1),			--6	 rbp_nz	
		Int16x3(1,1,0),			--7	 rbp_pXpY	
		Int16x3(1,-1,0),			--8	 rbp_pXnY	
		Int16x3(1,0,1),			--9	 rbp_pXpZ	
		Int16x3(1,0,-1),			--10 rbp_pXnZ	
		Int16x3(-1,1,0),			--11 rbp_nXpY	
		Int16x3(-1,-1,0),		--12 rbp_nXnY	
		Int16x3(-1,0,1),			--13 rbp_nXpZ	
		Int16x3(-1,0,-1),		--14 rbp_nXnZ	
		Int16x3(0,1,1),			--15 rbp_pYpZ	
		Int16x3(0,1,-1),			--16 rbp_pYnZ	
		Int16x3(0,-1,1),			--17 rbp_nYpZ	
		Int16x3(0,-1,-1),		--18 rbp_nYnZ	
		Int16x3(1,1,1),			--19 rbp_pXpYpZ 
		Int16x3(1,1,-1),			--20 rbp_pXpYnZ 
		Int16x3(1,-1,1),			--21 rbp_pXnYPz 
		Int16x3(1,-1,-1),		--22 rbp_pXnYnZ 
		Int16x3(-1,1,1),			--23 rbp_nXpYpZ 
		Int16x3(-1,1,-1),		--24 rbp_nXpYnZ 
		Int16x3(-1,-1,1),		--25 rbp_nXnYPz 
		Int16x3(-1,-1,-1),		--26 rbp_nXnYnZ 
	};

function STLExporter:ctor()
	self.m_bAutoScale = true;
	self.m_blockAABB = nil;
	self.m_centerPos = nil;
	self.m_fScale = 1;
	self.cube_list = {};
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
	self:Load(input_file_name);
	if(binary)then
		self:Export_internal_binary(output_file_name);
	else
		self:Export_internal(output_file_name);
	end
	BroadcastHelper.PushLabel({id="stlexporter", label = format(L"STL文件成功保存到:%s", commonlib.Encoding.DefaultToUtf8(output_file_name)), max_duration=4000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
		
	--if(ParaScene.BmaxExportToSTL(input_file_name,output_file_name,binary))then
		--BroadcastHelper.PushLabel({id="stlexporter", label = format(L"STL文件成功保存到:%s", commonlib.Encoding.DefaultToUtf8(output_file_name)), max_duration=4000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
	--end
end
function STLExporter:Export_internal_binary(output_file_name)
	ParaIO.CreateDirectory(output_file_name);
	local face_cont = 6;
	local function get_vertex(cube,index_1,index_2,index_3)
		return cube[index_1].position,cube[index_2].position,cube[index_3].position;
	end
	local function write_face(file,vertex_1,vertex_2,vertex_3)
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
		local cube_num = #self.cube_list;
		local face_num = cube_num * 12;

		file:WriteInt(face_num);
		local __,cube;
		for __,cube in ipairs(self.cube_list) do
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
	local function get_vertex(cube,index_1,index_2,index_3)
		return cube[index_1].position,cube[index_2].position,cube[index_3].position;
	end
	local function write_face(file,vertex_1,vertex_2,vertex_3)
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
		for __,cube in ipairs(self.cube_list) do
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
function STLExporter:GetCube()
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
function STLExporter:OffsetPosition(cube,dx,dy,dz,scale)
	if(not cube)then return end
	local k;
	for k = g_topLB,g_bkRB do
		if(cube[k] and cube[k].position)then
			cube[k].position[1] = cube[k].position[1] + dx;
			cube[k].position[2] = cube[k].position[2] + dy;
			cube[k].position[3] = cube[k].position[3] + dz;

			cube[k].position[1] = cube[k].position[1] * scale;
			cube[k].position[2] = cube[k].position[2] * scale;
			cube[k].position[3] = cube[k].position[3] * scale;
		end
	end
end
function STLExporter:Load(bmax_filename)
	if(not bmax_filename)then return end
	local xmlRoot = ParaXML.LuaXML_ParseFile(bmax_filename);
	self:ParseHeader(xmlRoot);
	self:ParseBlocks(xmlRoot);
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
	local aabb = ShapeAABB:new();
	local k,v;
	for k,v in ipairs(blocks) do
		local x = v[1];
		local y = v[2];
		local z = v[3];
		aabb:Extend(x,y,z);
	end
	self.m_blockAABB = aabb;

	local blockMinX,  blockMinY, blockMinZ = self.m_blockAABB:GetMinValues()
	local blockMaxX,  blockMaxY, blockMaxZ = self.m_blockAABB:GetMaxValues();
	local width = blockMaxX - blockMinX;
	local height = blockMaxY - blockMinY;
	local depth = blockMaxZ - blockMinZ;

	--set scaling;
	commonlib.echo("============self.m_fScale");
	if (self.m_bAutoScale) then
		local fMaxLength = math.max(math.max(height, width), depth) + 1;
		self.m_fScale = self:CalculateScale(fMaxLength);
		commonlib.echo(fMaxLength);
		commonlib.echo(self.m_fScale);
	end

	local m_centerPos = self.m_blockAABB:GetCenter();
	m_centerPos[1] = (width + 1.0) * 0.5;
	m_centerPos[2] = 0;
	m_centerPos[3]= (depth + 1.0) * 0.5;
	local k,v;
	for k,v in ipairs(blocks) do
		local x = v[1];
		local y = v[2];
		local z = v[3];
		local offset_x = x - blockMinX - m_centerPos[1];
		local offset_y = y;
		local offset_z = z - blockMinZ - m_centerPos[3];
		local cube = self:GetCube();
		self:OffsetPosition(cube,offset_x,offset_y,offset_z,self.m_fScale);
		self:PushCube(cube);
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
function STLExporter:PushCube(cube)
	if(not cube)then return end
	table.insert(self.cube_list,cube);
end
function STLExporter:TessellateBlock()

end