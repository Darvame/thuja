local thuja = require "thuja";

local tree = thuja:New();

local say_hello = function(tail_or_env, a1, ...)
	local tail = tail_or_env._thuja_tail_ or tail_or_env;
	local to = #tail > 0 and table.concat(tail, ", ") or "everyone";
	local alsoto = a1 and table.concat({a1, ...}, ", ") or nil;

	print("I want to take this opportunity");
	print("And say Hello to " .. to .. "!");
	if alsoto then print("Especially to " .. alsoto .. "!"); end
end

-- reg it
tree:Set("GET", "/say/hello/to", say_hello);

-- call it
tree:Call("GET", "/say/hello/to/my dog/my cat/my mouse/my beetles///", "my grandma", "my grandpa");

-- call it from env
local env = {
	["REQUEST_METHOD"] = "GET"; -- default value is 'tree._method_default', default key is 'tree._env_method'
	["PATH_INFO"] = "/say/hello/to/my dog/my cat/my mouse/my beetles///"; -- default value is 'tree._path_default', default key is 'tree._env_path'
};

tree:CallEnv(env, "my grandma", "my grandpa"); -- tail will be placed into the env as 'tree._tail_key' value (default: '_thuja_tail_')

--! OR !--
local env = {
	[tree._method_default] = "GET";
	[tree._env_path] = "/say/hello/to/my dog/my cat/my mouse/my beetles///";
};

tree:CallEnv(env, "my grandma", "my grandpa");
