local win = ide.osname == 'Windows'

local debinit = [[
local mdb = require('mobdebug')
local line = mdb.line
mdb.line = function(...)
  local r = line(...)
  return type(r) == 'string' and loadstring("return "..r)() or r
end]]

local qlua
local qluaInterpreter = {
  name = "QLua-LuaJIT",
  description = "Qt hooks for luajit",
  api = {"baselib", "qlua"},
  frun = function(self,wfilename,rundebug)
    qlua = qlua or ide.config.path.qlua -- check if the path is configured
    -- Go search for qlua
    if not qlua then
      local sep = win and ';' or ':'
      local default = ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(os.getenv('QLUA_BIN') or '')..sep
                 ..(os.getenv('HOME') and os.getenv('HOME') .. '/bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        qlua = qlua or GetFullPathIfExists(p, 'qlua')
        table.insert(paths, p)
      end
      if not qlua then
        DisplayOutput("Can't find qlua executable in any of the folders in PATH or QLUA_BIN: "
          ..table.concat(paths, ", ").."\n")
        return
      end
    end

    -- make minor modifications to the cpath to take care of OSX
    -- make sure the root is using Torch exe location
    local torchroot = GetPathWithSep(qlua).. '../'
    local luapath =      ''
    luapath = luapath .. torchroot .. "share/lua/5.1/?.lua;"
    luapath = luapath .. torchroot .. "share/lua/5.1/?/init.lua;"
    local _, path = wx.wxGetEnv("LUA_PATH")
    if path then
       wx.wxSetEnv("LUA_PATH", luapath..";"..path)
    end
    local luacpath = ''
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/?.so;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/?.dylib;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/loadall.so;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/loadall.dylib;"
    local _, cpath = wx.wxGetEnv("LUA_CPATH")
    if cpath then
       wx.wxSetEnv("LUA_CPATH", luacpath..";"..cpath)
    end
    local filepath = wfilename:GetFullPath()
    local script
    if rundebug then
      DebuggerAttachDefault({runstart = ide.config.debugger.runonstart == true, init = debinit})
      script = rundebug
    else
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if ide.osname == 'Windows' and pcall(require, "winapi")
      and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        filepath = winapi.short_path(filepath)
      end

      script = ('dofile [[%s]]'):format(filepath)
    end
    local code = ([[xpcall(function() io.stdout:setvbuf('no'); %s end,function(err) print(debug.traceback(err)) end)]]):format(script)
    local cmd = '"'..qlua..'" -e "'..code..'"'
    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    return CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil,
      function() ide.debugger.pid = nil end)
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  scratchextloop = true,
}

local torch
local torchInterpreter = {
  name = "Torch-7",
  description = "Torch machine learning package",
  api = {"baselib", "torch"},
  frun = function(self,wfilename,rundebug)
    torch = torch or ide.config.path.torch -- check if the path is configured
    -- Go search for torch
    if not torch then
      local sep = win and ';' or ':'
      local default = ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(os.getenv('TORCH_BIN') or '')..sep
                 ..(os.getenv('HOME') and os.getenv('HOME') .. '/bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        torch = torch or GetFullPathIfExists(p, (win and 'th.bat ' or 'th'))
        table.insert(paths, p)
      end
      
      if not torch then
        DisplayOutput("Can't find torch executable in any of the folders in PATH or TORCH_BIN: "
          ..table.concat(paths, ", ").."\n")
        return
      end
    end

    -- make minor modifications to the cpath to take care of OSX
    -- make sure the root is using Torch exe location
    local torchroot = GetPathWithSep(torch).. '../'
    local luapath =      ''
    luapath = luapath .. torchroot .. "share/lua/5.1/?.lua;"
    luapath = luapath .. torchroot .. "share/lua/5.1/?/init.lua;"
    local _, path = wx.wxGetEnv("LUA_PATH")
    if path then
       wx.wxSetEnv("LUA_PATH", luapath..";"..path)
    end
    local luacpath = ''
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/?.so;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/?.dylib;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/loadall.so;"
    luacpath = luacpath .. torchroot .. "lib/lua/5.1/loadall.dylib;"
    local _, cpath = wx.wxGetEnv("LUA_CPATH")
    if cpath then
       wx.wxSetEnv("LUA_CPATH", luacpath..";"..cpath)
    end
    local filepath = wfilename:GetFullPath()
    local script
    if rundebug then
      DebuggerAttachDefault({runstart = ide.config.debugger.runonstart == true, init = debinit})
      script = rundebug
    else
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      script = ('dofile [[%s]]'):format(filepath)
    end
    
    -- local code = ([[xpcall(function() io.stdout:setvbuf('no'); %s end,function(err) print(debug.traceback(err)) end)]]):format(script)
    -- local cmd = '"'..torch..'" -e "'..code..'"'
    local params = ide.config.arg.any or ide.config.arg.lua or ''
    local cmd = 'bash -c "cd $(dirname ' .. filepath .. ') && ' .. torch .. ' ' .. filepath .. ' ' .. params .. '"'
    if ide.osname == "Windows" then
      cmd = 'cmd /c "cd ' .. filepath .. '/../ && ' .. torch .. ' ' .. filepath .. ' ' .. params .. '"'
    end
    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    return CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil,
      function() ide.debugger.pid = nil end)
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  scratchextloop = true,
}

return {
  name = "Torch7",
  description = "Integration with torch7 environment",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = 1.10,

  onRegister = function(self)
    ide:AddInterpreter("torch", torchInterpreter)
    ide:AddInterpreter("qlua", qluaInterpreter)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter("torch")
    ide:RemoveInterpreter("qlua")
  end,
}
