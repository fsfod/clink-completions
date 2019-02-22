local w = require('tables').wrap
local path = require('path')
local matchers = require('matchers')
local parser = clink.arg.new_parser

local function get_containers(key, filter)
  local cmd = "docker ps -a --format {{.Names}} 2>nul"

  if filter == "running" then
    cmd = "docker ps --format {{.Names}} 2>nul"
  elseif filter then
    cmd = string.format("docker ps -f '%s' --format {{.Names}} 2>nul", filter)
  end

  local proc = io.popen(cmd)
  
  if not proc then 
    return {} 
  end

  local value = proc:read("*all")
  proc:close()
  local lines = {}
  for s in value:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end
  
  table.sort(lines, function (a, b)
    return a > b
  end)
  
  return lines
end

local function get_running_containers(key)
  return get_containers(key, "running")
end

local function get_paused()
  return get_containers(key, "status=paused")
end

local function copy_complete(token, first, last)
  --path.is_real_dir(dir) and clink.is_match(token, dir)

  if token == "" then
    return w(get_containers()):concat(matchers.files(token))
  elseif path.is_real_dir(token) then
    return matchers.files(token)
  else
    return get_containers()
  end
end


local docker_parser = parser(
  {
		"attach",
		"build",
		"commit",
		"cp"..parser({copy_complete}, "-a", "--archive", "-L", "--follow-link"),
		"create",
		"diff"..parser({get_containers}),
		"events",
		"exec"..parser({get_running_containers}),
		"export",
		"history",
		"images",
		"import",
		"info",
		"inspect",
		"kill"..parser({get_running_containers}, "-s", "--signal"),
		"load",
		"login",
		"logout",
		"logs"..parser({get_containers, "--details", "-f, --follow", "--since string", "--tail", "-t, --timestamps", "--until"}):loop(1),
		"pause"..parser({get_running_containers}),
		"port",
		"ps",
		"pull",
		"push",
		"rename",
		"restart"..parser({get_containers}),
		"rm"..parser({get_containers}),
		"rmi",
		"run",
		"save",
		"search",
		"start"..parser({get_containers}, "-a", "-i"):loop(1),
		"stats",
		"stop"..parser({get_running_containers}),
		"tag",
		"top",
		"unpause"..parser(get_paused()),
		"update",
		"version",
		"wait"
  }
)

clink.arg.register_parser("docker", docker_parser)