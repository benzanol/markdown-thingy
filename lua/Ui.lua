local function merge(t1, t2)
   t = {}
   for k,v in pairs(t1 or {}) do
      t[k] = v
   end
   for k,v in pairs(t2 or {}) do
      t[k] = v
   end
   return t
end


local Ui = {}

function Ui.col(args) return merge(args, {type='column'}) end
function Ui.row(args) return merge(args, {type='row'}) end
function Ui.table(args) return merge(args, {type='table'}) end

function Ui.field(content, onChange, args)
   return merge(args, {type='field', onChange=onChange, content})
end

function Ui.text(text, args)
   return merge(args, {type='label', text})
end

function Ui.icon(icon, args)
   return merge(args, {type='label', theme='icon', icon})
end

function Ui.button(text, onPress, args)
   return merge(args, {type='label', theme='button', onPress=onPress, text})
end

function Ui.iconBtn(icon, onPress, args)
   return merge(args, {type='label', theme='icon-button', onPress=onPress, icon})
end


function Ui.object(obj, set)
   if getmetatable(obj) == Pl.Date then
      return Ui.text(Lib.time_stamp(obj))
   elseif type(obj) == 'number' then
      return Ui.field(tostring(obj), function (s) set(tonumber(s) or obj) end)
   elseif type(obj) == 'string' then
      return Ui.field(obj, set)
   elseif type(obj) == 'boolean' then
      return Ui.iconBtn(obj and 'check' or 'close', function () set(not obj) end)
   else
      return Ui.text(tostring(obj))
   end
end

function Ui.props(tbl)
   local rows = {}

   for key,val in pairs(tbl) do
      if type(key) == 'string' and key ~= 'content' then
         local row = Ui.row{
            Ui.text(key .. ':'),
            Ui.object(val, function (new) tbl[key] = new end)
         }
         table.insert(rows, row)
      end
   end

   local content = Ui.object(tbl.content, function (new) tbl.content = new end)
   table.insert(rows, content)
   return Ui.col(rows)
end

return Ui
