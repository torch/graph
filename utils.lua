
require 'qtsvg'

function graph.dot(g)
	local gv = g:todot()
	local fngv = os.tmpname()
	local fgv = io.open(fngv,'w')
	fgv:write(gv)
	fgv:close()
	local fnsvg = os.tmpname()
	os.execute('dot -Tsvg -o ' .. fnsvg .. ' ' .. fngv)
	local qs = qt.QSvgWidget(fnsvg)
	qs:show()
	os.remove(fngv)
	os.remove(fnsvg)
	-- print(fngv,fnpng)
	return qs
end
