
graph = {}

torch.include('graph','utils.lua')

--[[
	Defines a graph and general operations on grpahs like topsort, 
	connected components, ...
	uses two tables, one for nodes, one for edges
]]--
local Graph = torch.class('graph.Graph')

function Graph:__init()
	self.nodes = {}
	self.edges = {}
end

-- add a new edge into the graph.
-- an edge has two fields, from and to that are inserted into the
-- nodes table. the edge itself is inserted into the edges table.
function Graph:add(edge)
	if torch.typename(edge) == 'graph.Edge' then
		-- add edge
		if not self.edges[edge] then
			table.insert(self.edges,edge)
			self.edges[edge] = #self.edges
		end
		-- add from node
		if not self.nodes[edge.from] then
			table.insert(self.nodes,edge.from)
			self.nodes[edge.from] = #self.nodes
		end
		-- add to node
		if not self.nodes[edge.to] then
			table.insert(self.nodes,edge.to)
			self.nodes[edge.to] = #self.nodes
		end
		-- add the edge to the node for parsing in nodes
		edge.from:add(edge)
	elseif type(edge) == 'table' then
		for i,e in ipairs(edge) do
			self:add(e)
		end
	else
		error('graph.Edge or {graph.Edges} expected')
	end
end

--[[
	Topological Sort
]]--
function Graph:topsort()
	-- first clone the graph
	local g = self:clone()
	local nodes = g.nodes
	local edges = g.edges
	for i,node in ipairs(nodes) do
		node.children = {}
	end

	-- reverse the graph
	local rg = graph.Graph()
	for i,edge in ipairs(edges) do
		rg:add(graph.Edge(edge.to,edge.from))
	end

	-- work on the sorted graph
	local sortednodes = {}
	local rootnodes = rg:roots()

	if #rootnodes == 0 then
		print('Graph has cycles')
	end

	-- run
	for i,root in ipairs(rootnodes) do
		root:dfs(function(node) table.insert(sortednodes,node) end)
	end
	return sortednodes,rg,rootnodes
end

-- find root nodes
function Graph:roots()
	local edges = self.edges
	local rootnodes = {}
	for i,edge in ipairs(edges) do
		--table.insert(rootnodes,edge.from)
		if not rootnodes[edge.from] then
			rootnodes[edge.from] = #rootnodes+1
		end
	end
	for i,edge in ipairs(edges) do
		if rootnodes[edge.to] then
			rootnodes[edge.to] = nil
		end
	end
	local roots = {}
	for root,i in pairs(rootnodes) do
		table.insert(roots, root)
	end
	return roots
end

function Graph:clone()
	local mf = torch.MemoryFile()
	mf:writeObject(self)
	mf:synchronize()
	mf:seek(1)
	local clone = mf:readObject()
	mf:close()
	return clone
end

function Graph:todot()
	local nodes = self.nodes
	local edges = self.edges
	str = {}
	table.insert(str,'digraph G {\n')
	table.insert(str,'node [shape = circle]; ')
	local nodelabels = {}
	for i,node in ipairs(nodes) do
		nodelabels[node] = node:label() or 'n' .. i
		table.insert(str, ' ' .. nodelabels[node])
	end
	table.insert(str,';\n')
	for i,edge in ipairs(edges) do
		table.insert(str,nodelabels[edge.from] .. ' -> ' .. nodelabels[edge.to] .. ';\n')
	end
	table.insert(str,'}')
	return table.concat(str,'')
end

--[[
	A Directed Edge class
	No methods, just two fields, from and to.
]]--
local Edge = torch.class('graph.Edge')

function Edge:__init(from,to)
	self.from = from
	self.to = to
end

--[[
	Node class. This class is generally used with edge to add edges into a graph.
	graph:add(graph.Edge(graph.Node(),graph.Node()))

	But, one can also easily use this node class to create a graph. It will register
	all the edges into its children table and one can parse the graph from any given node.
	The drawback is there will be no global edge table and node table, which is mostly useful
	to run algorithms on graphs. If all you need is just a data structure to store data and 
	run DFS, BFS over the graph, then this method is also quick and nice.
--]]
local Node = torch.class('graph.Node')

function Node:__init(d,p)
	self.data = d
	self.children = {}
	self.visited = false
	self.marked = false
end

function Node:add(child)
	if torch.typename(child) == 'graph.Node' then
		table.insert(self.children,graph.Edge(self,child))
	elseif torch.typename(child) == 'graph.Edge' then
		table.insert(self.children, child)
	elseif type(child) == 'table' then
		for i,v in ipairs(child) do
			self:add(v)
		end
	else
		error('graph.Node|graph.Edge or {graph.Node|graph.Edge} expected')
	end
end

-- visitor
function Node:visit(pre_func,post_func)
	if not self.visited then
		if pre_func then pre_func(self) end
		for i,child in ipairs(self.children) do
			child.to:visit(pre_func, post_func)
		end
		if post_func then post_func(self) end
	end
end

function Node:label()
	return tostring(self.data)
end

function Node:dfs(func)
	local visitednodes = {}
	local dfs_func = function(node)
		func(node)
		table.insert(visitednodes,node)
	end
	local dfs_func_pre = function(node)
		node.visited = true
	end
	self:visit(dfs_func_pre, dfs_func)
	for i,node in ipairs(visitednodes) do
		node.visited = false
	end
end

function Node:bfs(func)
	local visitednodes = {}
	local bfsnodes = {}
	local bfs_func = function(node)
		func(node)
		for i,child in ipairs(node.children) do
			if not child.to.marked then
				child.to.marked = true
				table.insert(bfsnodes,child.to)
			end
		end
	end
	table.insert(bfsnodes,self)
	self.marked = true
	while #bfsnodes > 0 do
		local node = table.remove(bfsnodes,1)
		table.insert(visitednodes,node)
		bfs_func(node)
	end
	for i,node in ipairs(visitednodes) do
		node.marked = false
	end
end


