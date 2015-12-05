--[[
Title: stl file writer
Author(s): leio, refactored LiXizhi
Date: 2015/12/5
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/STLExporter/STLWriter.lua");
local STLWriter = commonlib.gettable("Mod.STLExporter.STLWriter");
local writer = STLWriter:new();
writer:LoadModel(model);
writer:SaveAsText(filename);
writer:SaveAsBinary(filename);
------------------------------------------------------------
]]
NPL.load("(gl)Mod/STLExporter/BMaxModel.lua");
NPL.load("(gl)script/ide/math/vector.lua");
local vector3d = commonlib.gettable("mathlib.vector3d");
local BMaxModel = commonlib.gettable("Mod.STLExporter.BMaxModel");
local STLWriter = commonlib.inherit(nil,commonlib.gettable("Mod.STLExporter.STLWriter"));

function STLWriter:ctor()
end

function STLWriter:LoadModelFromBMaxFile(filename)
	local model = BMaxModel:new();
	model:Load(filename);
	self:LoadModel(model);
end

function STLWriter:LoadModel(bmaxModel)
	self.model = bmaxModel;
end

function STLWriter:IsValid()
	if(self.model) then
		return true;
	end
end

-- save as binary stl file
function STLWriter:SaveAsBinary(output_file_name)
	if(not self:IsValid()) then
		return false;
	end

	ParaIO.CreateDirectory(output_file_name);
	
	local function write_face(file,vertex_1,vertex_2,vertex_3)
		local a = vertex_3 + vertex_1;
		local b = vertex_3 + vertex_2;
		local normal = a*b;
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
		for k = string.len(name),total-1 do
			name = name .. "\0";
		end
		file:write(name,total);
		local count = self.model:GetTotalTriangleCount();
		file:WriteInt(count);
		for _, cube in ipairs(self.model.m_blockModels) do
			for nFaceIndex = 0, cube:GetFaceCount()-1 do
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 0);
				write_face(file,vertex_1,vertex_2,vertex_3);
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 1);
				write_face(file,vertex_1,vertex_2,vertex_3);
			end
		end	
		file:close();
		return true;
	end
end

-- save as plain-text stl file
function STLWriter:SaveAsText(output_file_name)
	if(not self:IsValid()) then
		return false;
	end

	local get_vertex = BMaxModel.get_vertex;
	ParaIO.CreateDirectory(output_file_name);
	
	local function write_face(file,vertex_1,vertex_2,vertex_3)
		local a = vertex_3 + vertex_1;
		local b = vertex_3 + vertex_2;
		local normal = a*b;
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
		for _, cube in ipairs(self.model.m_blockModels) do
			for nFaceIndex = 0, cube:GetFaceCount()-1 do
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 0);
				write_face(file,vertex_1,vertex_2,vertex_3);
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 1);
				write_face(file,vertex_1,vertex_2,vertex_3);
			end
		end	
		file:WriteString(string.format("endsolid %s\n",name));
		file:close();
		return true;
	end
end