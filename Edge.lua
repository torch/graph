--[[
A Directed Edge class
No methods, just two fields, from and to.
]]--
local Edge = torch.class('graph.Edge')

function Edge:__init(from,to,weight)
   self.from = from
   self.to = to
   self.weight = weight
end
