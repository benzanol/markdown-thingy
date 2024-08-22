local function _merge(t1, t2)
   t = {}
   for k,v in pairs(t1 or {}) do
      t[k] = v
   end
   for k,v in pairs(t2 or {}) do
      t[k] = v
   end
   return t
end

return {
   col = function (args) return _merge(args, {type='column'}) end,
   row = function (args) return _merge(args, {type='row'}) end,
   table = function (args) return _merge(args, {type='table'}) end,

   field = function (content, onChange, args)
      return _merge(args, {type='field', onChange=onChange, content})
   end,

   text = function (text, args)
      return _merge(args, {type='label', text})
   end,
   icon = function (icon, args)
      return _merge(args, {type='label', theme='icon', icon})
   end,
   button = function (text, onPress, args)
      return _merge(args, {type='label', theme='button', onPress=onPress, text})
   end,
   iconBtn = function (icon, onPress, args)
      return _merge(args, {type='label', theme='icon-button', onPress=onPress, icon})
   end,
}
