
require 'debug'

local Node, parent = torch.class('graph.AnnotatedNode', 'graph.Node')

function Node:__init(data, infoLevel)
	-- level 2 is the calling function
	infoLevel = infoLevel or 2
	parent.__init(self, data)
	self.data.annotations = self.data.annotations or {}
	
	if not data.annotations._debugLabel then
		local dinfo = debug.getinfo(infoLevel, 'Sl')
		data.annotations._debugLabel =
			string.format('[%s]:%d', dinfo.short_src, dinfo.currentline, dinfo.name)
	end
end

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

