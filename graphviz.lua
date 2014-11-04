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
	local _, _, id = string.find(label, "^Node(%d+)")
	assert(id ~= nil, "could not get ID from node label")
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
function graph.graphvizLayout(g, algorithm)
	if not graphvizOk or not cgraphOk then
		error("graphviz library could not be loaded.")
	end
	local nNodes = #g.nodes
	local context = graphviz.gvContext()
	local graphvizGraph = cgraph.agmemread(g:todot())
	local algorithm = algorithm or "dot"
	assert(0 == graphviz.gvLayout(context, graphvizGraph, algorithm),
	       "graphviz layout failed")
	assert(0 == graphviz.gvRender(context, graphvizGraph, algorithm, nil),
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
		positions[id][1] = x
		positions[id][2] = y
	end

	-- Clean up.
	graphviz.gvFreeLayout(context, graphvizGraph)
	cgraph.agclose(graphvizGraph)
	graphviz.gvFreeContext(context)
	return positions
end


function graph.dot(g,title,fname)
	local gv = g:todot(title)
	local fngv = (fname or os.tmpname()) .. '.dot'
	local fgv = io.open(fngv,'w')
	fgv:write(gv)
	fgv:close()
	local fnsvg = (fname or os.tmpname()) .. '.svg'
	os.execute('dot -Tsvg -o ' .. fnsvg .. ' ' .. fngv)
	if not fname then
		require 'qtsvg'
		local qs = qt.QSvgWidget(fnsvg)
		qs:show()
		os.remove(fngv)
		os.remove(fnsvg)
		-- print(fngv,fnpng)
		return qs
	end
end
