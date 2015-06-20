require 'totem'
require 'graph'
require 'torch'
local tester = totem.Tester()
local tests = {}

function tests.test_annotateGraph()
    require 'nngraph'
    local input = nn.Identity()():annotate({name = 'Input', description = 'DescA',
      graphAttributes = {color = 'red'}})

    local hidden_a = nn.Linear(10, 10)(input):annotate({name = 'Hidden A', description = 'DescB',
      graphAttributes = {color = 'blue', fontcolor='green', tooltip = 'I am green'}})
    local hidden_b = nn.Sigmoid()(hidden_a)
    local output = nn.Linear(10, 10)(hidden_b)
    local net = nn.gModule({input}, {output})

    tester:assert(hidden_a:label():match('DescB'))
    local fg_tmpfile = os.tmpname()
    local bg_tmpfile = os.tmpname()
    graph.dot(net.fg, 'Test', fg_tmpfile)
    graph.dot(net.fg, 'Test BG', bg_tmpfile)

    local function checkDotFile(tmpfile)
        local dotcontent = io.open(tmpfile .. '.dot', 'r'):read("*all")
        tester:assert(dotcontent:match('%[.*label=%"Input.*DescA.*%".*%]'))
        tester:assert(dotcontent:match('%[.*color=red.*%]'))
        tester:assert(dotcontent:match('%[.*label=%"Hidden A.*DescB.*%".*%]'))
        tester:assert(dotcontent:match('%[.*label=%".*DescB.*%"*%]'))
        tester:assert(dotcontent:match('%[.*color=blue.*%]'))
        tester:assert(dotcontent:match('%[.*label=%".*DescB.*%".*%]'))
        tester:assert(dotcontent:match('%[.*tooltip=%".*'.. paths.basename(paths.thisfile()) .. '.*%".*%]'))
    end
    checkDotFile(fg_tmpfile)
    checkDotFile(bg_tmpfile)
end

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
    tester:assert(graph._dotEscape('My label') == '"My label"', 'Use quotes for spaces')
    tester:assert(graph._dotEscape('Non[an') == '"Non[an"', 'Use quotes for non-alpha characters')
    tester:assert(graph._dotEscape('My\nnewline') == '"My\\nnewline"', 'Escape newlines')
    tester:assert(graph._dotEscape('Say "hello"') == '"Say \\"hello\\""', 'Escape quotes')
end

return tester:add(tests):run()
