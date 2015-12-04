--[[
Title: bmax model
Author(s): leio, refactored LiXizhi
Date: 2015/12/4
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/STLExporter/BMaxModel.lua");
local BMaxModel = commonlib.gettable("Mod.STLExporter.BMaxModel");
local model = BMaxModel:new();
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/XPath.lua");
NPL.load("(gl)script/ide/math/ShapeAABB.lua");
NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)script/ide/math/bit.lua");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local vector3d = commonlib.gettable("mathlib.vector3d");

local BMaxModel = commonlib.inherit(nil,commonlib.gettable("Mod.STLExporter.BMaxModel"));

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

function BMaxModel:ctor()
	self.m_bAutoScale = true;
	self.m_blockAABB = nil;
	self.m_centerPos = nil;
	self.m_fScale = 1;
	self.m_nodes = {};
	self.m_blockModels = {};
end

-- static helper function
function BMaxModel.get_vertex(cube,index_1,index_2,index_3)
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

-- return array of cube vertices
function BMaxModel:CreateCube()
	local cubeVertices = {};

	for k = g_topLB,g_bkRB do
		cubeVertices[k] = {};
	end
	--top face
	cubeVertices[g_topLB].position = {0,1,0};
	cubeVertices[g_topLT].position = {0,1,1};
	cubeVertices[g_topRT].position = {1,1,1};
	cubeVertices[g_topRB].position = {1,1,0};

	cubeVertices[g_topLB].normal = {0,1,0};
	cubeVertices[g_topLT].normal = {0,1,0};
	cubeVertices[g_topRT].normal = {0,1,0};
	cubeVertices[g_topRB].normal = {0,1,0};

	--front face
	cubeVertices[g_frtLB].position = {0,0,0};
	cubeVertices[g_frtLT].position = {0,1,0};
	cubeVertices[g_frtRT].position = {1,1,0};
	cubeVertices[g_frtRB].position = {1,0,0};

	cubeVertices[g_frtLB].normal = {0,0,-1};
	cubeVertices[g_frtLT].normal = {0,0,-1};
	cubeVertices[g_frtRT].normal = {0,0,-1};
	cubeVertices[g_frtRB].normal = {0,0,-1};

	--bottom face
	cubeVertices[g_btmLB].position = {0,0,1};
	cubeVertices[g_btmLT].position = {0,0,0};
	cubeVertices[g_btmRT].position = {1,0,0};
	cubeVertices[g_btmRB].position = {1,0,1};

	cubeVertices[g_btmLB].normal = {0,-1,0};
	cubeVertices[g_btmLT].normal = {0,-1,0};
	cubeVertices[g_btmRT].normal = {0,-1,0};
	cubeVertices[g_btmRB].normal = {0,-1,0};

	--left face
	cubeVertices[g_leftLB].position = {0,0,1};
	cubeVertices[g_leftLT].position = {0,1,1};
	cubeVertices[g_leftRT].position = {0,1,0};
	cubeVertices[g_leftRB].position = {0,0,0};

	cubeVertices[g_leftLB].normal = {-1,0,0};
	cubeVertices[g_leftLT].normal = {-1,0,0};
	cubeVertices[g_leftRT].normal = {-1,0,0};
	cubeVertices[g_leftRB].normal = {-1,0,0};

	--right face
	cubeVertices[g_rightLB].position = {1,0,0};
	cubeVertices[g_rightLT].position = {1,1,0};
	cubeVertices[g_rightRT].position = {1,1,1};
	cubeVertices[g_rightRB].position = {1,0,1};

	cubeVertices[g_rightLB].normal = {1,0,0};
	cubeVertices[g_rightLT].normal = {1,0,0};
	cubeVertices[g_rightRT].normal = {1,0,0};
	cubeVertices[g_rightRB].normal = {1,0,0};

	--back face
	cubeVertices[g_bkLB].position = {1,0,1};
	cubeVertices[g_bkLT].position = {1,1,1};
	cubeVertices[g_bkRT].position = {0,1,1};
	cubeVertices[g_bkRB].position = {0,0,1};

	cubeVertices[g_bkLB].normal = {0,0,1};
	cubeVertices[g_bkLT].normal = {0,0,1};
	cubeVertices[g_bkRT].normal = {0,0,1};
	cubeVertices[g_bkRB].normal = {0,0,1};
	return cubeVertices;
end

function BMaxModel:OffsetPosition(cube,dx,dy,dz)
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

function BMaxModel:Load(bmax_filename)
	if(not bmax_filename)then return end
	local xmlRoot = ParaXML.LuaXML_ParseFile(bmax_filename);
	self:ParseHeader(xmlRoot);
	self:ParseBlocks(xmlRoot);
	self:ParseVisibleBlocks();
	if(self.m_bAutoScale)then
		self:ScaleModels();
	end
end

function BMaxModel:ParseHeader(xmlRoot)
	if(not xmlRoot)then return end
	local blocktemplate = xmlRoot[1];
	if(blocktemplate and blocktemplate.attr and blocktemplate.attr.auto_scale and (blocktemplate.attr.auto_scale == "false" or blocktemplate.attr.auto_scale == "False"))then
		self.m_bAutoScale = false;	
	end
end

function BMaxModel:ParseBlocks(xmlRoot)
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

function BMaxModel:NextPowerOf2(x)
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

function BMaxModel:CalculateScale(length)
	local nPowerOf2Length = self:NextPowerOf2(length + 0.1);
	return g_blockSize / nPowerOf2Length;
end

function BMaxModel:InsertNode(node)
	if(not node)then return end
	local index = self:GetNodeIndex(node.x,node.y,node.z);
	if(index)then
		self.m_nodes[index] = node;
	end
end

function BMaxModel:GetNode(x,y,z)
	local index = self:GetNodeIndex(x,y,z);
	if(not index)then
		return
	end
	return self.m_nodes[index];
end

function BMaxModel:GetNodeIndex(x,y,z)
	if(x < 0 or y < 0 or z < 0)then
		return
	end
	return x + bit.lshift(z, 8) + bit.lshift(y, 16);
	--return (DWORD)x + ((DWORD)z << 8) + ((DWORD)y << 16);
end

function BMaxModel:ParseVisibleBlocks()
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

function BMaxModel:TessellateBlock(x,y,z)
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
	
	for face = 0,nFaceCount - 1 do
		local nFirstVertex = face * 4;
		local pCurBlock = neighborBlocks[RBP_SixNeighbors[face]];
		if(not pCurBlock)then
			for v = 0,3 do
				local i = nFirstVertex + v;
				self:AddVertex(cube,temp_cube, i);
			end
		end
	end
	return cube;
end

function BMaxModel:QueryNeighborBlockData(x,y,z,pBlockData,nFrom,nTo)
	local neighborOfsTable = NeighborOfsTable;
	local node = self:GetNode(x, y, z);
	if(not node)then return end
	
	for i = nFrom,nTo do
		local xx = x + neighborOfsTable[i].x;
		local yy = y + neighborOfsTable[i].y;
		local zz = z + neighborOfsTable[i].z;

		local pBlock = self:GetNode(xx,yy,zz);
		local index = i - nFrom + 1;
		pBlockData[index] = pBlock;
	end
end

function BMaxModel:GetVerticesCount(cube)
	if(not cube)then 
		return 0;
	end
	local cnt = 0;
	
	for k = g_topLB,g_bkRB do
		if(cube[k] and cube[k].position)then
			cnt = cnt + 1;
		end
	end
	return cnt;
end

function BMaxModel:ScaleModels()
	local scale = self.m_fScale;
	for _,cube in ipairs(self.m_blockModels) do
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

function BMaxModel:AddVertex(target_cube,source_cube,index)
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
function BMaxModel:GetTotalTriangleCnt()
	local face_cont = 6;
	local cnt = 0;
	local get_vertex = BMaxModel.get_vertex;
	for _,cube in ipairs(self.m_blockModels) do
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
