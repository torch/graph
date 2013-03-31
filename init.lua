
graph = {}

torch.include('graph','utils.lua')
torch.include('graph','Node.lua')
torch.include('graph','Edge.lua')


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
	if type(edge) ~= 'table' then
		error('graph.Edge or {graph.Edges} expected')
	end
	if torch.typename(edge) then
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
		edge.from:add(edge.to)
	else
		for i,e in ipairs(edge) do
			self:add(e)
		end
	end
end

-- Clone a Graph
-- this will create new nodes, but will share the data.
-- Note that primitive data types like numbers can not be shared
function Graph:clone()
	local clone = graph.Graph()
	for i,e in ipairs(self.edges) do
		local from = graph.Node(e.from.data)
		local to   = graph.Node(e.to.data)
		clone:add(graph.Edge(from,to))
	end
	return clone
end


-- It returns a new graph where the edges are reversed.
-- The nodes share the data. Note that primitive data types can
-- not be shared.
function Graph:reverse()
	local rg = graph.Graph()
	local mapnodes = {}
	for i,e in ipairs(self.edges) do
		mapnodes[e.from] = mapnodes[e.from] or e.from.new(e.from.data)
		mapnodes[e.to]   = mapnodes[e.to] or e.to.new(e.to.data)
		local from = mapnodes[e.from]
		local to   = mapnodes[e.to]
		rg:add(graph.Edge(to,from))
	end
	return rg
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
	local rg = self:reverse()

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

	if #sortednodes ~= #self.nodes then
		print('Graph has cycles')
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
	table.sort(roots,function(a,b) return self.nodes[a] < self.nodes[b] end )
	return roots
end

function Graph:todot()
	local nodes = self.nodes
	local edges = self.edges
	str = {}
	table.insert(str,'digraph G {\n')
	table.insert(str,'node [shape = oval]; ')
	local nodelabels = {}
	for i,node in ipairs(nodes) do
		local l =  '"' .. (node:label() or 'n' .. i) .. '"'
		nodelabels[node] = 'n' .. i
		table.insert(str, '\n' .. nodelabels[node] .. '[label=' .. l .. '];')
	end
	table.insert(str,'\n')
	for i,edge in ipairs(edges) do
		table.insert(str,nodelabels[edge.from] .. ' -> ' .. nodelabels[edge.to] .. ';\n')
	end
	table.insert(str,'}')
	return table.concat(str,'')
end

