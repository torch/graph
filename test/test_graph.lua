
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

function tests.test_topsort()
   local n1 = graph.Node(1)
   local n2 = graph.Node(2)
   local n3 = graph.Node(3)
   local n4 = graph.Node(4)
   local g = graph.Graph()
   g:add(graph.Edge(n1, n2))
   g:add(graph.Edge(n1, n3))
   g:add(graph.Edge(n2, n3))
   g:add(graph.Edge(n2, n4))
   g:add(graph.Edge(n3, n4))

   local sorted = g:topsort()
   tester:assert(sorted[1] == n1, 'wrong sort order' )
   tester:assert(sorted[2] == n2, 'wrong sort order' )
   tester:assert(sorted[3] == n3, 'wrong sort order' )
   tester:assert(sorted[4] == n4, 'wrong sort order' )


   -- add an extra root
   local n0 = graph.Node(0)
   g:add(graph.Edge(n0, n2))
   local sorted2 = g:topsort()
   tester:assert(sorted2[1] == n1 or sorted2[1] == n0, 'wrong sort order' )
   tester:assert(sorted2[5] == n4, 'wrong sort order' )

   -- add an extra leaf
   local n5 = graph.Node(5)
   g:add(graph.Edge(n3, n5))
   local sorted2 = g:topsort()
   tester:assert(sorted2[1] == n1 or sorted2[1] == n0, 'wrong sort order' )
   tester:assert(sorted2[6] == n4 or sorted2[6] == n5, 'wrong sort order' )
   tester:assert(sorted2[5] == n4 or sorted2[5] == n5, 'wrong sort order' )
   tester:assert(sorted2[6] ~= sorted2[5], 'wrong sort order' )


   -- add a bottleneck and a new set of nodes
   local n11 = graph.Node(11)
   local n12 = graph.Node(12)
   local n13 = graph.Node(13)
   local n14 = graph.Node(14)
   local n15 = graph.Node(15)
   local n16 = graph.Node(16)

   g:add(graph.Edge(n4, n11))
   g:add(graph.Edge(n5, n11))
   g:add(graph.Edge(n11, n12))
   g:add(graph.Edge(n11, n13))
   g:add(graph.Edge(n12, n13))
   g:add(graph.Edge(n13, n14))
   g:add(graph.Edge(n14, n15))
   g:add(graph.Edge(n12, n15))
   g:add(graph.Edge(n13, n16))

   local sorted3 = g:topsort()
   -- check all the first 6 sorted elements have data <= 5
   for i=1, 6 do
      tester:assert(sorted3[i].data <= 5, 'wrong sort order')
   end
   tester:assert(sorted3[7] == n11, 'wrong sort order')
   tester:assert(sorted3[8] == n12, 'wrong sort order' )
   tester:assert(sorted3[9] == n13, 'wrong sort order' )
   tester:assert(sorted3[11] == n16 or sorted3[12] == n16, 'wrong sort order')
end

function tests.test_cycle()
   local n1 = graph.Node(1)
   local n2 = graph.Node(2)
   local n3 = graph.Node(3)
   local n4 = graph.Node(4)
   local cycle = graph.Graph()
   cycle:add(graph.Edge(n1, n2))
   cycle:add(graph.Edge(n1, n3))
   cycle:add(graph.Edge(n2, n3))
   cycle:add(graph.Edge(n3, n2))
   cycle:add(graph.Edge(n2, n4))
   cycle:add(graph.Edge(n3, n4))

   tester:asserteq(cycle:hasCycle(), true, 'Graph is supposed to have cycle')

   local n1 = graph.Node(1)
   local n2 = graph.Node(2)
   local n3 = graph.Node(3)
   local n4 = graph.Node(4)
   local nocycle = graph.Graph()
   nocycle:add(graph.Edge(n1, n2))
   nocycle:add(graph.Edge(n1, n3))
   nocycle:add(graph.Edge(n2, n3))
   nocycle:add(graph.Edge(n2, n4))
   nocycle:add(graph.Edge(n3, n4))

   tester:asserteq(nocycle:hasCycle(), false, 'Graph is not supposed to have cycle')

   local function create_cycle(g, node0, length)
      local node1, node2 = node0, nil
      for i = 1, length-1 do
         node2 = graph.Node('c' .. i)
         local e = graph.Edge(node1, node2)
         g:add(e)
         node1 = node2
      end
      g:add(graph.Edge(node1, node0))
   end

   local bigcycle = graph.Graph()
   local n1 = graph.Node(1)
   local n2 = graph.Node(2)
   local n3 = graph.Node(3)
   local n4 = graph.Node(4)
   bigcycle:add(graph.Edge(n1, n2))
   bigcycle:add(graph.Edge(n1, n3))
   bigcycle:add(graph.Edge(n2, n3))
   bigcycle:add(graph.Edge(n2, n4))
   bigcycle:add(graph.Edge(n3, n4))
   create_cycle(bigcycle, n2, 5)

   tester:asserteq(cycle:hasCycle(), true, 'Graph is supposed to have cycle')

end

return tester:add(tests):run()
