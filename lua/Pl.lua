local modules = {
   'Date', 'List', 'Map', 'MultiMap', 'OrderedMap', 'Set',
   'class', 'func', 'seq', 'stringx', 'tablex',
}

local Pl = {}
for idx,mod in ipairs(modules) do
   Pl[mod] = require('pl.' .. mod)
end

return Pl
