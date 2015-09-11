require 'graph'
dofile 'graphviz.lua'

g=graph.Graph()
root=graph.Node(10)
n1=graph.Node(1)
n2=graph.Node(2)
g:add(graph.Edge(root,n1))
g:add(graph.Edge(root,n2))
nend = graph.Node(20)
g:add(graph.Edge(n1,nend))
g:add(graph.Edge(n2,nend))
g:add(graph.Edge(nend,root))

local i = 0
print('======= BFS ==========')
root:bfs(function(node) i=i+1;print('i='..i);print(node:label())end)
print('======= DFS ==========')
i = 0
root:dfs(function(node) i=i+1;print('i='..i);print(node:label())end)

print('======= topsort ==========')
s,rg,rn = g:topsort()

graph.dot(g, 'g', 'g')
