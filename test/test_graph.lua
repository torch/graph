
require 'graph'
require 'totem'

local tester = totem.Tester()
local tests = {}

local function create_graph(nlayers, ninputs, noutputs, nhiddens, droprate)
	local g = graph.Graph()
	local conmat = torch.rand(nlayers, nhiddens, nhiddens):ge(droprate)[{ {1, -2}, {}, {} }]

	-- create nodes
	local nodes = { [0] = {}, [nlayers+1] = {} }
	local nodecntr = 1
	for inode = 1, ninputs do
		local node = graph.Node(nodecntr)
		nodes[0][inode] = node
		nodecntr = nodecntr + 1
	end
	for ilayer = 1, nlayers do
		nodes[ilayer] = {}
		for inode = 1, nhiddens do
			local node = graph.Node(nodecntr)
			nodes[ilayer][inode] = node
			nodecntr = nodecntr + 1
		end
	end
	for inode = 1, noutputs do
		local node = graph.Node(nodecntr)
		nodes[nlayers+1][inode] = node
		nodecntr = nodecntr + 1
	end

	-- now connect inputs to all first layer hiddens
	for iinput = 1, ninputs do
		for inode = 1, nhiddens do
			g:add(graph.Edge(nodes[0][iinput], nodes[1][inode]))
		end
	end
	-- now run through layers and connect them
	for ilayer = 1, nlayers-1 do
		for jnode = 1, nhiddens do
			for knode = 1, nhiddens do
				if conmat[ilayer][jnode][knode] == 1 then
					g:add(graph.Edge(nodes[ilayer][jnode], nodes[ilayer+1][knode]))
				end
			end
		end
	end
	-- now connect last layer hiddens to outputs
	for inode = 1, nhiddens do
		for ioutput = 1, noutputs do
			g:add(graph.Edge(nodes[nlayers][inode], nodes[nlayers+1][ioutput]))
		end
	end

	-- there might be nodes left out and not connected to anything. Connect them
	for i = 1, nlayers do
		for j = 1, nhiddens do
			if not g.nodes[nodes[i][j]] then
				local jto = torch.random(1, nhiddens)
				g:add(graph.Edge(nodes[i][j], nodes[i+1][jto]))
				conmat[i][j][jto] = 1
			end
		end
	end

	return g, conmat
end


function tests.graph()
	local nlayers = torch.random(2,5)
	local ninputs = torch.random(1,10)
	local noutputs = torch.random(1,10)
	local nhiddens = torch.random(10,20)
	local droprates = {0, torch.uniform(0.2, 0.8), 1}
	for i, droprate in ipairs(droprates) do
		local g,c = create_graph(nlayers, ninputs, noutputs, nhiddens, droprate)

		local nedges = nhiddens * (ninputs+noutputs) + c:sum()
		local nnodes = ninputs + noutputs + nhiddens*nlayers
		local nroots = ninputs + c:sum(2):eq(0):sum()
		local nleaves = noutputs + c:sum(3):eq(0):sum()

		tester:asserteq(#g.edges, nedges, 'wrong number of edges')
		tester:asserteq(#g.nodes, nnodes, 'wrong number of nodes')
		tester:asserteq(#g:roots(), nroots, 'wrong number of roots')
		tester:asserteq(#g:leaves(), nleaves, 'wrong number of leaves')
	end
end

function tests.test_dfs()
	local nlayers = torch.random(5,10)
	local ninputs = 1
	local noutputs = 1
	local nhiddens = 1
	local droprate = 0

	local g,c = create_graph(nlayers, ninputs, noutputs, nhiddens, droprate)
	local roots = g:roots()
	local leaves = g:leaves()

	tester:asserteq(#roots, 1, 'expected a single root')
	tester:asserteq(#leaves, 1, 'expected a single leaf')

	local dfs_nodes = {}
	roots[1]:dfs(function(node) table.insert(dfs_nodes, node) end)

	for i, node in ipairs(dfs_nodes) do
		tester:asserteq(node.data, #dfs_nodes - i +1, 'dfs order wrong')
	end
end

function tests.test_bfs()
	local nlayers = torch.random(5,10)
	local ninputs = 1
	local noutputs = 1
	local nhiddens = 1
	local droprate = 0

	local g,c = create_graph(nlayers, ninputs, noutputs, nhiddens, droprate)
	local roots = g:roots()
	local leaves = g:leaves()

	tester:asserteq(#roots, 1, 'expected a single root')
	tester:asserteq(#leaves, 1, 'expected a single leaf')

	local bfs_nodes = {}
	roots[1]:bfs(function(node) table.insert(bfs_nodes, node) end)

	for i, node in ipairs(bfs_nodes) do
		tester:asserteq(node.data, i, 'bfs order wrong')
	end
end

return tester:add(tests):run()
