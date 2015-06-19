
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

--[[
Node class

It is the building block of the graph structure. It contains 
 `data` which is given as an argument to the constructor
 `id` which is default to 0, but when the graph is built using Graph class, the ids are set with global consistency.
 `children` a table that contains the set of children in the order they are added.
 `visited` boolean flag that is used by DFS/BFS algorithms to mark if this node is visited.
 `marked` boolean flag that is used by DFS/BFS algorithms to color the node.
Args:
* `data` - data table to be contained in the node. The node does not create a copy, but just points
to the given table.
]]
function Node:__init(data)
	assert(type(d) == 'table' and not torch.typename(d), 'expecting a table for data')
	self.data = d
	self.id = 0
	self.children = {}
	self.visited = false
	self.marked = false
end

--[[
Add one more child node(s) to this node.

Args:
* `child` - an instance of a graph node or a table of instances.
]]
function Node:add(child)
	local children = self.children
	if type(child) == 'table' and not torch.typename(child) then
		for i,v in ipairs(child) do
			self:add(v)
		end
	elseif not children[child] then
		table.insert(children,child)
		children[child] = #children
	end
end

--[[
Interface for visitor objects.

Args:
* `pre_func` - run before calling visit on children
* `post_func` - run after calling visit on children
]]
function Node:visit(pre_func,post_func)
	if not self.visited then
		if pre_func then pre_func(self) end
		for i,child in ipairs(self.children) do
			child:visit(pre_func, post_func)
		end
		if post_func then post_func(self) end
	end
end

--[[
Return a string representation for the node. Default to 
calling

```lua
tostring(self.data)
```
]]
function Node:label()
	return tostring(self.data)
end

--[[
Create a graph by traversal starting from this Node
]]
function Node:graph()
	local g = graph.Graph()
	local function build_graph(node)
		for i,child in ipairs(node.children) do
			g:add(graph.Edge(node,child))
		end
	end
	self:bfs(build_graph)
	return g
end

function Node:dfs_dirty(func)
	local visitednodes = {}
	local dfs_func = function(node)
		func(node)
		table.insert(visitednodes,node)
	end
	local dfs_func_pre = function(node)
		node.visited = true
	end
	self:visit(dfs_func_pre, dfs_func)
	return visitednodes
end

--[[
Depth First Search traversal over the graph starting from this node.
Args:
 `func` - The function that is run on every node during traversal.
]]
function Node:dfs(func)
	for i,node in ipairs(self:dfs_dirty(func)) do
		node.visited = false
	end
end

function Node:bfs_dirty(func)
	local visitednodes = {}
	local bfsnodes = {}
	local bfs_func = function(node)
		func(node)
		for i,child in ipairs(node.children) do
			if not child.marked then
				child.marked = true
				table.insert(bfsnodes,child)
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
	return visitednodes
end

--[[
Breadth First Search tarversal over the graph starting at this node.
Args:
 `func` - The function that is run on every node during traversal.
]]
function Node:bfs(func)
	for i,node in ipairs(self:bfs_dirty(func)) do
		node.marked = false
	end
end


