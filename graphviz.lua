local ffi = require 'ffi'
require 'torch'

ffi.cdef[[
typedef struct FILE FILE;

typedef struct Agraph_s Agraph_t;
typedef struct Agnode_s Agnode_t;

extern Agraph_t *agmemread(const char *cp);
extern char *agget(void *obj, char *name);
extern int agclose(Agraph_t * g);
extern Agnode_t *agfstnode(Agraph_t * g);
extern Agnode_t *agnxtnode(Agraph_t * g, Agnode_t * n);
extern Agnode_t *aglstnode(Agraph_t * g);
extern Agnode_t *agprvnode(Agraph_t * g, Agnode_t * n);

typedef struct Agraph_s graph_t;
typedef struct GVJ_s GVJ_t;
typedef struct GVG_s GVG_t;
typedef struct GVC_s GVC_t;
extern GVC_t *gvContext(void);
extern int gvLayout(GVC_t *context, graph_t *g, const char *engine);
extern int gvRender(GVC_t *context, graph_t *g, const char *format, FILE *out);
extern int gvFreeLayout(GVC_t *context, graph_t *g);
extern int gvFreeContext(GVC_t *context);
]]

local graphvizOk, graphviz = pcall(function() return ffi.load('libgvc') end)
local cgraphOk, cgraph = pcall(function() return ffi.load('libcgraph') end)

-- Retrieve attribute data from a graphviz object.
local function getAttribute(obj, name)
	local res = cgraph.agget(obj, ffi.cast("char*", name))
	assert(res ~= ffi.cast("char*", nil), 'could not get attr ' .. name)
	return ffi.string(res)
end
-- Iterate through nodes of a graphviz graph.
local function nodeIterator(graph)
	local node = cgraph.agfstnode(graph)
	local nextNode
	return function()
		if node == nil then return end
		if node == cgraph.aglstnode(graph) then nextNode = nil end
		nextNode = cgraph.agnxtnode(graph, node)
		local result = node
		node = nextNode
		return result
	end
end
-- Convert a string of comma-separated numbers to actual numbers.
local function extractNumbers(n, attr)
	local res = {}
	for number in string.gmatch(attr, "[^%,]+") do
		table.insert(res, tonumber(number))
	end
	assert(#res == n, "attribute is not of expected form")
	return unpack(res)
end
-- Transform from graphviz coordinates to unit square.
local function getRelativePosition(node, bbox)
	local x0, y0, w, h = unpack(bbox)
	local x, y = extractNumbers(2, getAttribute(node, 'pos'))
	local xt = (x - x0) / w
	local yt = (y - y0) / h
	assert(xt >= 0 and xt <= 1, "bad x coordinate")
	assert(yt >= 0 and yt <= 1, "bad y coordinate")
	return xt, yt
end
-- Retrieve a node's ID based on its label string.
local function getID(node)
	local label = getAttribute(node, 'label')
	local _, _, id = string.find(label, "^Node(%d+)") or string.find(label, "%((%d+)%)\\n")
	-- assert(id ~= nil, "could not get ID from node label")
	return tonumber(id)
end

--[[ Lay out a graph and return the positions of the nodes.

Args:
* `g` - graph to lay out.
* `algorithm` - name of the graphviz algorithm to use. (default: "dot")

Returns:
* `torch.Tensor(n, 2)` containing the resulting positions of the nodes.
where `n` is the number of nodes in the graph.

Coordinates are in the interval [0, 1].

]]
function graph.graphvizLayout(g, algorithm, fname)
	if not graphvizOk or not cgraphOk then
		error("graphviz library could not be loaded.")
	end
	local nNodes = #g.nodes
	local context = graphviz.gvContext()
	local graphvizGraph = cgraph.agmemread(g:todot())
	local algorithm = algorithm or "dot"
	assert(0 == graphviz.gvLayout(context, graphvizGraph, algorithm),
	       "graphviz layout failed")
	-- the algorithm that is passed is a loyout algorithm not a rendering
	-- format, which is typically like png, svg or dot
	assert(0 == graphviz.gvRender(context, graphvizGraph, 'dot', nil),
	       "graphviz render failed")

	-- Extract bounding box.
	local x0, y0, x1, y1 = extractNumbers(4,
	    getAttribute(graphvizGraph, 'bb'), ",")
	local w = x1 - x0
	local h = y1 - y0
	local bbox = { x0, y0, w, h }

	-- Extract node positions.
	local positions = torch.zeros(nNodes, 2)
	for node in nodeIterator(graphvizGraph) do
		local id = getID(node)
		local x, y = getRelativePosition(node, bbox)
		if id then
			positions[id][1] = x
			positions[id][2] = y
		end
	end

	-- Clean up.
	graphviz.gvFreeLayout(context, graphvizGraph)
	cgraph.agclose(graphvizGraph)
	graphviz.gvFreeContext(context)
	return positions
end

function graph.graphvizFile(g, algorithm, fname)
	algorithm = algorithm or 'dot'
	local _,_,rendertype = fname:reverse():find('(%a+)%.%w+')
	rendertype = rendertype:reverse()

	local context = graphviz.gvContext()
	local graphvizGraph = cgraph.agmemread(g:todot())
	assert(0 == graphviz.gvLayout(context, graphvizGraph, algorithm),
	       "graphviz layout failed")
	assert(0 == graphviz.gvRender(context, graphvizGraph, rendertype, io.open(fname, 'w')),
		   "graphviz render failed")
	graphviz.gvFreeLayout(context, graphvizGraph)
	cgraph.agclose(graphvizGraph)
	graphviz.gvFreeContext(context)
end

--[[
Given a graph, dump an SVG or display it using graphviz.

Args:
* `g` - graph to display
* `title` - Title to display in the graph
* `fname` - [optional] if given it should contain a file name without an extension,
   the graph is saved on disk as fname.svg and display is not shown. If not given
   the graph is shown on qt display (you need to have qtsvg installed and running qlua)

Returns:
* `qs` - the window handle for the qt display (if fname given) or nil
]]
function graph.dot(g,title,fname)
	local qt_display = fname == nil
	fname = fname or os.tmpname()
	local fnsvg = fname .. '.svg'
	local fndot = fname .. '.dot'
	graph.graphvizFile(g, 'dot', fnsvg)
	graph.graphvizFile(g, 'dot', fndot)
	if qt_display then
		require 'qtsvg'
		local qs = qt.QSvgWidget(fname .. '.svg')
		qs:show()
		os.remove(fnsvg)
		os.remove(fndot)
		return qs
	end
end


local function dotEscape(str)
	if string.find(str, '[^a-zA-Z]') then
		-- Escape newlines and quotes.
		local escaped = string.gsub(str, '\n', '\\n')
		escaped = string.gsub(escaped, '"', '\\"')
		str = '"' .. escaped .. '"'
	end
	return str
end
graph._dotEscape = dotEscape

--[[ Generate a string like 'color=blue tailport=s' from a table
  (e.g. {color = 'blue', tailport = 's'}. Its up to the user to escape
  strings properly.
]]
local function makeAttributeString(attributes)
	local str = {}
	for k, v in pairs(attributes) do
		table.insert(str, tostring(k) .. '=' .. dotEscape(tostring(v)))
	end
	return ' ' .. table.concat(str, ' ')
end


local Graph = torch.getmetatable('graph.Graph')
--[[
todot function for graph class, one can use graphviz to display the graph or save on disk

Args:
* `title` - title to display on the graph
 ]]--
function Graph:todot(title)

	local nodes = self.nodes
	local edges = self.edges
	local str = {}
	table.insert(str,'digraph G {\n')
	if title then
		table.insert(str,'labelloc="t";\nlabel="' .. title .. '";\n')
	end
	table.insert(str,'node [shape = oval]; ')
	local nodelabels = {}
	for i,node in ipairs(nodes) do
		local nodeName
		if node.graphNodeName then
			nodeName = node:graphNodeName()
		else
			nodeName = 'Node' .. node.id
		end
		local l = dotEscape(nodeName .. '\n' .. node:label())
		nodelabels[node] = 'n' .. node.id
		local graphAttributes = ''
		if node.graphNodeAttributes then
			graphAttributes = makeAttributeString(node:graphNodeAttributes())
		end
		table.insert(str, '\n' .. nodelabels[node] .. '[label=' .. l .. graphAttributes .. '];')
	end
	table.insert(str,'\n')
	for i,edge in ipairs(edges) do
		table.insert(str,nodelabels[edge.from] .. ' -> ' .. nodelabels[edge.to] .. ';\n')
	end
	table.insert(str,'}')
	return table.concat(str,'')
end
