local w = require('tables').wrap
local path = require('path')
local matchers = require('matchers')
local parser = clink.arg.new_parser

local function lines_totable(linestr)
  local lines = {}
  for s in linestr:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end
  
  table.sort(lines, function (a, b)
    return a > b
  end)
  
  return lines
end

local function cmdtotable(cmd)
  local proc = io.popen(cmd)
  
  if not proc then 
    return {} 
  end

  local value = proc:read("*all")
  proc:close()

  return lines_totable(value)
end

local function buildfilter(filter)
  if type(filter) == "string" then
    return " --filter "..filter
  else
    assert(type(filter) == "table")
    local cmd = ""
    for k, v in pairs(filter) do
      --Check if we have multiple values for all for the same key to filter on 
      if type(v) ~= "table" then
        for i, entry in pairs(v) do
          cmd = cmd.. string.format(" --filter %s=%s ", k, entry)
        end
      else
        cmd = cmd.. string.format(" --filter %s=%s ", k, tostring(v))
      end
    end
    print(cmd)
    return cmd
  end
end

local function get_machines(key, filter)
  local cmd = "docker-machine ls --format {{.Name}} 2>nul"

  if filter then
    cmd = string.format("docker-machine ls %s --format {{.Name}} 2>nul", buildfilter(filter))
  end

  return cmdtotable(cmd)
end

local function get_running_machines(key)
  return get_machines(key, {state = {"Running", "Starting"}})
end

local function get_containers(key, filter)
  local cmd = "docker ps -a --format {{.Names}} 2>nul"

  if filter == "running" then
    cmd = "docker ps --format {{.Names}} 2>nul"
  elseif filter then
    cmd = string.format("docker ps --filter '%s' --format {{.Names}} 2>nul", filter)
  end

  return cmdtotable(cmd)
end

local function get_running_containers(key)
  return get_containers(key, "running")
end

local function get_paused()
  return get_containers(key, "state=paused")
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

local function get_images(key, filter)
  local cmd = "docker images --format {{.Repository}}:{{.Tag}} 2>nul"

  if filter then
    cmd = string.format("docker images --format {{.Repository}}:{{.Tag}} %s 2>nul", buildfilter(filter))
  end

  return cmdtotable(cmd)
end

local function get_volumes(key, filter)
  local cmd = "docker volume ls --format {{.Name}} 2>nul"

  if filter then
    cmd = string.format("docker volume ls --format {{.Name}} %s 2>nul", buildfilter(filter))
  end

  return cmdtotable(cmd)
end

local function get_networks(key, filter)
  local cmd = "docker network ls --format {{.Name}} 2>nul"

  if filter then
    cmd = string.format("docker network  --format {{.Name}} %s 2>nul", buildfilter(filter))
  end

  return cmdtotable(cmd)
end

local docker_run = parser(
  "--add-host", 
  "-a", "--attach", 
  "--blkio-weight", 
  "--blkio-weight-device", 
  "--cap-add", 
  "--cap-drop", 
  "--cgroup-parent", 
  "--cidfile", 
  "--cpu-period", 
  "--cpu-quota", 
  "--cpu-rt-period", 
  "--cpu-rt-runtime", 
  "-c", "--cpu-shares", 
  "--cpus", 
  "--cpuset-cpus", 
  "--cpuset-mems",
  "-d", "--detach", 
  "--detach-keys", 
  "--device",
  "--device-cgroup-rule", 
  "--device-read-bps", 
  "--device-read-iops", 
  "--device-write-bps",
  "--device-write-iops", 
  "--disable-content-trust",
  "--dns", 
  "--dns-option", 
  "--dns-search", 
  "--entrypoint", 
  "-e", "--env", 
  "--env-file",
  "--expose", 
  "--group-add", 
  "--health-cmd", 
  "--health-interval", 
  "--health-retries", 
  "--health-start-period", 
  "--health-timeout",
  "--help", 
  "-h", "--hostname", 
  "--init", 
  "-i", "--interactive", 
  "--ip", 
  "--ip6", 
  "--ipc", 
  "--isolation", 
  "--kernel-memory", 
  "-l", "--label", 
  "--label-file", 
  "--link", 
  "--link-local-ip", 
  "--log-driver", 
  "--log-opt",
  "--mac-address", 
  "-m", "--memory", 
  "--memory-reservation", 
  "--memory-swap", 
  "--memory-swappiness", 
  "--mount", 
  "--name", 
  "--network"..parser({get_networks}), 
  "--network-alias", 
  "--no-healthcheck", 
  "--oom-kill-disable", 
  "--oom-score-adj",
  "--pid", 
  "--pids-limit", 
  "--privileged", 
  "-p", "--publish", 
  "-P", "--publish-all", 
  "--read-only", 
  "--restart", 
  "--rm", 
  "--runtime", 
  "--security-opt", 
  "--shm-size", "--sig-prox", 
  "--stop-signal", 
  "--stop-timeout", 
  "--storage-opt", 
  "--sysctl", 
  "--tmpfs", 
  "-t", "--tty", 
  "--ulimit", 
  "-u", "--user",
  "--userns", 
  "--uts", 
  "-v"..parser({get_volumes}), "--volume"..parser({get_volumes}), 
  "--volume-driver",
  "--volumes-from", 
  "-w", "--workdir"
)

local image_build = parser(
  --add-host", "--build-arg", "--cache-from", "--cgroup-parent", "--compress", "--cpu-period", "--cpu-quota", 
  "-c,", "--cpu-shares", "--cpuset-cpus", "--cpuset-mems", "--disable-content-trust", "-f,", "--file", "--force-rm", 
  "--iidfile", "--isolation", "--label", "-m,", "--memory", "--memory-swap", "--network", "--no-cache", "--pull", 
  "-q", "--quiet", "--rm", "--security-opt", "--shm-size", "-t,", "--tag", "--target", "--ulimit"
)

local docker_parser = parser(
  {
		"attach",
		"build"..image_build,
		"commit",
		"cp"..parser({copy_complete}, "-a", "--archive", "-L", "--follow-link"),
		"create",
		"diff"..parser({get_containers}),
		"events",
		"exec"..parser({get_running_containers}),
		"export",
		"history"..parser({get_images}),
		"image"..parser({"build"..image_build,
                     "history"..parser({get_images}),
                     "import",
                     "inspect"..parser({get_images}),
                     "load",
                     "ls"..parser("-a", "--all", "--digests", "-f", "--filter", "--format", "--no-trunc", "-q", "--quiet"),
                     "prune"..parser({get_images}, "-a", "--all", "-f", "--force"),
                     "pull",
                     "push",
                     "rm"..parser({get_images}),
                     "save"..parser({get_images}):loop(1),
                     "tag"}),
		"import",
		"info",
		"inspect"..parser({get_containers}),
		"kill"..parser({get_running_containers}, "-s", "--signal"),
		"load",
		"login",
		"logout",
		"logs"..parser({get_containers}, "--details", "-f, --follow", "--since string", "--tail", "-t, --timestamps", "--until"),
		"pause"..parser({get_running_containers}),
		"port"..parser({get_running_containers}),
		"ps",
		"pull",
		"push",
		"rename"..parser({get_containers}),
		"restart"..parser({get_containers}),
		"rm"..parser({get_containers}, "-f", "--force", "-l", "--link", "-v", "--volumes"),
		"rmi",
		"run"..docker_run,
		"save"..parser({get_images}),
		"search",
		"start"..parser({get_containers}, "-a", "--attach", "--checkpoint", "--checkpoint-dir", "--detach-keys", "-i", "--interactive"),
		"stats",
		"stop"..parser({get_running_containers}),
		"tag"..parser({get_images}),
		"top",
		"unpause"..parser({get_paused}),
		"update",
		"version",
		"wait"..parser({get_running_containers}):loop(),
 
    "builder",
    "config",
    "container",
    "network"..parser({"connect", "create", "disconnect", "inspect", "ls", "prune", "rm"}),
    "node",
    "plugin",
    "secret",
    "service",
    "stack",
    "swarm",
    "system"..parser("df", "events", "info", "prune"..parser({"-a", "--all", "--filter", "-f", "--force", "--volumes"})),
    "trust",
    "volume"..parser({"create", "inspect"..parser({get_volumes}), "ls", "prune", "rm"..parser({get_volumes})})
  }
)

local docker_machine_parser = parser(
  {
    "active",
    "config",
    "create",
    "env",
    "inspect",
    "ip"..parser({get_machines}),
    "kill"..parser({get_running_machines}),
    "ls",
    "provision",
    "regenerate-certs",
    "restart"..parser({get_machines}),
    "rm"..parser({get_machines}),
    "ssh"..parser({get_running_machines}),
    "scp"..parser({get_running_machines}),
    "mount",
    "start"..parser({get_machines}),
    "status"..parser({get_machines}),
    "stop"..parser({get_running_machines}),
    "upgrade",
    "url",
    "version",
    "help"
  }
)

clink.arg.register_parser("docker", docker_parser)

clink.arg.register_parser("docker-machine", docker_machine_parser)
