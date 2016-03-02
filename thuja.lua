local T = { _VERSION = 100 };

local next = next;
local type = type;
local unpack = unpack;
local tostring = tostring;
local tonumber = tonumber;
local tconcat = table.concat;

local emptyTable = {};
local emptyNode = {1, ""};
local nullFunction = function() end
local tableFunction = function() return emptyTable; end
local nodeFunction = function() return emptyNode; end

emptyNode["."] = emptyNode;
emptyNode[".."] = emptyNode;
emptyNode[""] = emptyNode;

local setmetatable = setmetatable;
setmetatable(emptyTable, {__newindex = nullFunction});
setmetatable(emptyNode, {__newindex = nullFunction});

local ER_NO_PATH = "no path defined";
local ER_NO_METHOD = "no method defined";

local ER_INVALID_TAIL_SIZE = "invalid tail size: %d";
local ER_INVALID_TAIL_TYPE = "invalid tail type: %s";
local ER_INVALID_CALLABLE_TYPE = "invalid callable type: %s";

local l2TableMeta = {
	__index = tableFunction;
};

local l2NodeMeta = {
	__index = nodeFunction;
}

local l2TableClosed = setmetatable({}, {
	__index = tableFunction;
	__newindex = nullFunction;
});

local l2NodeClosed = setmetatable({}, {
	__index = nodeFunction;
	__newindex = nullFunction;
});

local meta_index = {
	_tail_key = "_thuja_tail_",
	_path_default = "/",
	_method_default = "GET",
	_env_method = "REQUEST_METHOD",
	_env_path = "PATH_INFO",
	_route_quickscope = l2TableClosed,
	_route_complex = l2TableNode,
	_not_found = nullFunction,
	_not_found_env = nullFunction,
};

T._node_l2_meta = l2NodeMeta;
T._meta_index = meta_index;
T._table_l2_meta = l2TableMeta;

meta_index._node_static = { -- node description
	[""] = true, -- me
	[".."] = true, -- parent
	["."] = true, -- me
	[1] = true, -- my order number
	[2] = true, -- my name
	-- [0] -- workload
	-- [string_key1] ... [string_keyn] -- children
};

T.New = function(self, thu)

	if not thu then
		thu = {};
	end

	if not self._meta_index._split and not thu._split then
		self._meta_index._split = require("teateatea").pack;
	end

	if not thu._route_quickscope then
		thu._route_quickscope = setmetatable({}, self._table_l2_meta);
	end

	if not thu._route_complex then
		thu._route_complex = setmetatable({}, self._node_l2_meta);
	end

	return setmetatable(thu, { __index = self._meta_index });
end

local new_tail = function(path, onum, ohai)

	if ohai and onum <= #ohai then
		return {[0] = path, unpack(ohai, onum)};
	end

	return {[0] = path};
end

meta_index._found_env = function(self, env, func, path, onum, ohai, ...)

	env[self._tail_key] = new_tail(path, onum, ohai);

	return func(env, ...);
end

meta_index._found = function(self, func, path, onum, ohai, ...)

	return func(new_tail(path, onum, ohai), ...);
end

local function complex_search(node, ohai, pos)

	if pos <= #ohai then
		local nxt = node[ohai[pos]];

		if nxt then
			local candy, pos = complex_search(nxt, ohai, pos + 1);

			if candy then
				return candy, pos;
			end
		end
	end

	local candy = node[0];

	if candy then
		candy = candy[#ohai - pos + 1] or candy[-1];

		if candy then
			return candy, pos;
		end
	end
end

meta_index.CallEnv = function(self, env, ...)

	local method;
	local path;

	if not env then
		env = {};
		method = self._method_default or error(ER_NO_METHOD);
		path = self._path_default or error(ER_NO_PATH);
	else
		method = env[self._env_method] or (self._method_default or error(ER_NO_METHOD));
		path = tostring(env[self._env_path]) or (self._path_default or error(ER_NO_PATH));
	end

	local quick = self._route_quickscope[method][path];

	if quick then
		return self:_found_env(env, quick, path, nil, nil, ...);
	end

	local ohai = self._split(path, "/", true);
	local candy, pos = complex_search(self._route_complex[method], ohai, 1);

	if candy then
		return self:_found_env(env, candy, path, pos, ohai, ...);
	end

	return self:_not_found_env(env, method, path, ohai, ...);
end

meta_index.Call = function(self, method, path, ...)

	if not method then method = (self._method_default or error(ER_NO_METHOD)); end
	path = tostring(path) or (self._path_default or error(ER_NO_PATH));

	local quick = self._route_quickscope[method][path];

	if quick then
		return self:_found(quick, path, nil, nil, ...);
	end

	local ohai = self._split(path, "/", true);
	local candy, pos = complex_search(self._route_complex[method], ohai, 1);

	if candy then
		return self:_found(candy, path, pos, ohai, ...);
	end

	return self:_not_found(method, path, ohai, ...);
end

meta_index.CallAny = function(self, env_or_meth, ...)

	return self[type(env_or_meth) == "table" and "CallEnv" or "Call"](self, env_or_meth, ...);
end

local quickScopeTail = { [-1] = true, [0] = true };

local function quick_scope_path(node, table)

	if node[1] == 1 then
		return tconcat(table, "/");
	end

	table[node[1] - 1] = node[2];
	return quick_scope_path(node[".."], table);
end

local function node_clean(node, st)

	for key in next, node do
		if not st[key] then
			return;
		end
	end

	if node[1] > 1 then
		local parent = node[".."];
		parent[node[2]] = nil;
		return node_clean(parent, st);
	end
end

meta_index._set_quickscope_set = function(_, self, path, value)

	--self[path] = value; -- x/a/b/c
	--self[path .. "/"] = value; -- x/a/b/c/
	self["/" .. path] = value;	-- /x/a/b/c
	self["/" .. path .. "/"] = value; -- /x/a/b/c/
end

meta_index._set_quickscope = function(self, quick, node, ntail, value)

	if not quickScopeTail[ntail] then
		return;
	end

	local path = quick_scope_path(node, {});
	local candy = node[0];

	if not value then -- delete
		if ntail == 0 and candy[-1] then
			self:_set_quickscope_set(quick, path, candy[-1]);
			return;
		end
	end

	if ntail == 0 or ntail == -1 and not candy[0] then
		self:_set_quickscope_set(quick, path, value);
	end
end

meta_index._table_ensure = function(self, table, key, flag)

	if flag and not rawget(table, key) then
		table[key] = {};
	end

	return table[key];
end

meta_index._node_root = function(self, table, method, new)

	local node = rawget(table, method);

	if new and not node then
		node = {1, ""};
		node[""] = node;
		node[".."] = node;
		node["."] = node;
		table[method] = node;
	end

	return node or table[method];
end

meta_index._node_new = function(self, table, key)

	local node = {
		[1] = table[1] + 1,
		[2] = key,
		[".."] = table,
	};

	node[""] = node;
	node["."] = node;
	table[key] = node;

	return node;
end

meta_index._set_table = function(self, node, quick, path, func)

	for key, value in next, func do
		if type(key) == "string" then
			self:_set_table(node, quick, path .. "/" .. key, type(value) == "table" and value or {[-1] = value});
		elseif type(key) == "number" then
			if key < -1 then
				error(string.format(ER_INVALID_TAIL_SIZE, key));
			end

			self:_set_func(node, quick, path, key, value);
		end
	end
end

local node_pass = function(node, ohai)

	for i = 1, #ohai do
		node = node[ohai[i]];

		if not node then
			return nil;
		end
	end

	return node;
end

meta_index._set_func = function(self, node, quick, path, ntail, func)

	if func then
		local ohai = self._split(path, "/", true);

		for i = 1, #ohai do
			node = node[ohai[i]] or self:_node_new(node, ohai[i]);
		end

		local candy = node[0];

		if not candy then
			node[0] = {[ntail] = func};
		else
			candy[ntail] = func;
		end

		self:_set_quickscope(quick, node, ntail, value);
	else
		node = node_pass(node, self._split(path, "/", true));

		local candy = node[0];

		if not candy then
			return;
		end

		candy[ntail] = nil;

		self:_set_quickscope(quick, node, ntail);

		if not next(candy) then
			node[0] = nil;
			node_clean(node, self._node_static);
		end
	end
end

local check_path_method_tail = function(method, path, tail)

	if not method then
		error(ER_NO_METHOD);
	end

	path = tostring(path);

	if not path then
		error(ER_NO_PATH);
	end

	if tail then
		local ntail = tonumber(tail);

		if not ntail then
			error(string.format(ER_INVALID_TAIL_TYPE, type(tail)));
		end

		if (ntail < -1) then
			error(string.format(ER_INVALID_TAIL_SIZE, ntail));
		end

		return path, ntail;
	end

	return path, -1;
end

meta_index.Get = function(self, method, path, ntail)

	path, ntail = check_path_method_tail(method, path, ntail);

	local node = node_pass(self:_node_root(self._route_complex, method), self._split(path, "/", true));

	if node and node[0] then
		return node[0][ntail];
	end
end

meta_index._set_valid_types = {
	["function"] = true, ["table"] = true, ["userdata"] = true;
}

meta_index.Set = function(self, method, path, ntail, func)

	if not func and not tonumber(ntail) then
		func = ntail;
		ntail = nil;
	end

	path, ntail = check_path_method_tail(method, path, ntail);

	local node = self:_node_root(self._route_complex, method, func);
	local quick = self:_table_ensure(self._route_quickscope, method, func);

	if func then
		local ftype = type(func);

		if not self._set_valid_types[ftype] then
			error(string.format(ER_INVALID_CALLABLE_TYPE, ftype));
		end

		if ftype == "table" then
			return self:_set_table(node, quick, path, func);
		end
	end

	return self:_set_func(node, quick, path, ntail, func);
end

meta_index.Del = function(self, method, path, ntail)

	return self:Set(method, path, ntail, nil);
end

local function node_clean_chld(self, node, quick)

	local static = self._node_static;
	self:_set_quickscope_set(quick, quick_scope_path(node, {}));
	node[0] = nil;

	for key, value in next, node do
		if not static[key] then
			node_clean_chld(self, value, quick);
			node[key] = nil;
		end
	end
end

meta_index.NodeDel = function(self, method, path)

	path = check_path_method_tail(method, path, nil);

	local node = node_pass(self:_node_root(self._route_complex, method), self._split(path, "/", true));

	if not node then
		return;
	end

	local quick = self:_table_ensure(self._route_quickscope, method);

	node[".."][node[2]] = nil;
	return node_clean_chld(self, node, quick);
end

return T;
