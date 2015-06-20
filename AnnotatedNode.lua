
require 'debug'

local Node, parent = torch.class('graph.AnnotatedNode', 'graph.Node')

--[[
AnnotatedNode class adds general debug info and capability to add annotations to the graph nodes

Args:
* `data` - data table to be contained in the node. The node does not create a copy, but just points
to the given table.
* `infolevel` - the level to use with debug.getinfo. Level 2 corresponds function creating an
instance of the AnnotatedNode. (default=2)
]]
function Node:__init(data, infoLevel)
	-- level 2 is the calling function
	infoLevel = infoLevel or 4
	assert(type(data) == 'table' and not torch.typename(d), 'expecting a table for data')
	parent.__init(self, data)
	self.data.annotations = self.data.annotations or {}
	
	if not data.annotations._debugLabel then
		local dinfo = debug.getinfo(infoLevel, 'Sl')
		data.annotations._debugLabel =
			string.format('[%s]:%d', dinfo.short_src, dinfo.currentline, dinfo.name)
	end
end

--[[
Add a set of annotation key/value pairs to store in the data table.
]]
function Node:annotate(annotations)
	self.data = self.data or {}
	for k, v in pairs(annotations) do
		self.data.annotations[k] = v
	end
	return self
end

function Node:graphNodeName()
	if self.data.annotations.name then
		return self.data.annotations.name .. ' (' .. self.id .. ')'
	else
		return 'Node' .. self.id
	end
end

function Node:graphNodeAttributes()
	self.data.annotations.graphAttributes = self.data.annotations.graphAttributes or {}
	if not self.data.annotations.graphAttributes.tooltip then
		self.data.annotations.graphAttributes.tooltip = self.data.annotations._debugLabel
	end
	return self.data.annotations.graphAttributes
end

--[[
Returns a textual representation of the Node that can be used by graphviz library visualization.
]]
function Node:label()

	local function getNanFlag(data)
		if data:nElement() == 0 then
			return ''
		end
		local isNan = (data:ne(data):sum() > 0)
		if isNan then
			return 'NaN'
		end
		if data:max() == math.huge then
			return 'inf'
		end
		if data:min() == -math.huge then
			return '-inf'
		end
		return ''
	end
	local function getstr(data)
		if not data then return '' end
		if torch.isTensor(data) then
			local nanFlag = getNanFlag(data)
			local tensorType = 'Tensor'
			if data:type() ~= torch.Tensor():type() then
				tensorType = data:type()
			end
			return tensorType .. '[' .. table.concat(data:size():totable(),'x') .. ']' .. nanFlag
		elseif not torch.isTensor(data) and type(data) == 'table' then
			local tstr = {}
			for i,v in ipairs(data) do
				table.insert(tstr, getstr(v))
			end
			return '{' .. table.concat(tstr,',') .. '}'
		else
			return tostring(data):gsub('\n','\\l')
		end
	end
	local lbl = {}

	for k,v in pairs(self.data) do
		local vstr = ''
		if k == 'annotations' then
			-- the forwardNodeId is not displayed in the label.
		else
			vstr = getstr(v)
			table.insert(lbl, k .. ' = ' .. vstr)
		end
	end

	local desc = ''
	if self.data.annotations.description then
		desc = 'desc = ' .. self.data.annotations.description .. '\\n'
	end
	return desc .. table.concat(lbl,"\\l")
end

