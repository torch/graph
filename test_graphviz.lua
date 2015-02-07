require 'totem'
require 'graph'
require 'torch'
local tester = totem.Tester()
local tests = {}

function tests.layout()
    local g = graph.Graph()
    local root = graph.Node(10)
    local n1 = graph.Node(1)
    local n2 = graph.Node(2)
    g:add(graph.Edge(root, n1))
    g:add(graph.Edge(n1, n2))

    local positions = graph.graphvizLayout(g, 'dot')
    local xs = positions:select(2, 1)
    local ys = positions:select(2, 2)
    tester:assertlt(xs:add(-xs:mean()):norm(), 1e-3,
                    "x coordinates should be the same")
    tester:assertTensorEq(ys, torch.sort(ys, true), 1e-3,
                    "y coordinates should be ordered")
end


function tests.testDotEscape()
  tester:assert(graph._dotEscape('red') == 'red', 'Don\'t escape single words')
  tester:assert(graph._dotEscape('My label') == '"My label"',
                'Use quotes for spaces')
  tester:assert(graph._dotEscape('Non[an') == '"Non[an"',
                'Use quotes for non-alpha characters')
  tester:assert(graph._dotEscape('My\nnewline') == '"My\\nnewline"',
                'Escape newlines')
  tester:assert(graph._dotEscape('Say "hello"') == '"Say \\"hello\\""',
                'Escape quotes')
end


return tester:add(tests):run()
