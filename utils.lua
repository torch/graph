

function graph.dot(g,title,fname)
	require 'qtsvg'
	local gv = g:todot(title)
	local fngv = (fname or os.tmpname()) .. '.dot'
	local fgv = io.open(fngv,'w')
	fgv:write(gv)
	fgv:close()
	local fnsvg = (fname or os.tmpname()) .. '.svg'
	os.execute('dot -Tsvg -o ' .. fnsvg .. ' ' .. fngv)
	if not fname then
		local qs = qt.QSvgWidget(fnsvg)
		qs:show()
		os.remove(fngv)
		os.remove(fnsvg)
		-- print(fngv,fnpng)
		return qs
	end
end
