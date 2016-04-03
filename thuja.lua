local T = { _VERSION = 100 };

local next = next;
local type = type;
local unpack = unpack;
local tostring = tostring;
local tonumber = tonumber;
local tconcat = table.concat;
local split;

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
	_route_complex = l2NodeClosed,
	_not_found = nullFunction,
	_not_found_env = nullFunction,
	-- _split_separator = '/',
	-- _split = require 'teateatea'.pack,
};

local meta_copy = { -- must be copied but not in meta_index by default
	_split_separator = true,
	_split = true,
}

T._node_l2_meta = l2NodeMeta;
T._table_l2_meta = l2TableMeta;

T._meta_index = meta_index;
T._meta_copy = meta_copy;
--T._metatable = { __index = meta_index };

meta_index._node_static = { -- node description
	[""] = true, -- me
	[".."] = true, -- parent
	["."] = true, -- me
	[1] = true, -- my order number
	[2] = true, -- my name
	-- [0] -- workload
	-- [string_key1] ... [string_keyn] -- children
};

-- split func, must be set manualy in case of fail
-- module._meta_index._split = your_split_function;
do
	local _;_, split = pcall(function()
		return require("teateatea").pack;
	end);
end

T.New = function(self, conf)

	local meta_copy = self._meta_copy;

	local thu = {};

	if conf then
		for k, v in next, conf do
			if meta_copy[k] then
				thu[k] = v;
			end
		end
	end

	return self:Set(thu);
end

T.SetMeta = function(self, thu)

	assert(thu, "no argument");
	assert(self._meta_index._split or split, "no split function");

	local meta = self._metatable or { __index = self._meta_index };

	return setmetatable(thu, meta);
end

T.SetNode = function(self, thu)

	assert(thu, "no argument");

	if not thu._route_quickscope then
		thu._route_quickscope = setmetatable({}, self._table_l2_meta);
	end

	if not thu._route_complex then
		thu._route_complex = setmetatable({}, self._node_l2_meta);
	end

	return thu;
end

T.Set = function(self, thu)

	assert(thu, "no argument");

	return self:SetMeta(self:SetNode(thu));
end

local new_tail = function(path, onum, ohai)

	if ohai and onum <= #ohai then
		return {[0] = path, unpack(ohai, onum)};
	end

	return {[0] = path};
end

meta_index._found_env = function(self, env, method, path, func, onum, ohai, ...)

	env[self._tail_key] = new_tail(path, onum, ohai);

	return func(self, env, ...);
end

meta_index._found = function(self, method, path, func, onum, ohai, ...)

	return func(self, new_tail(path, onum, ohai), ...);
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

meta_index._seek_by_path = function(self, method, path)

	local candy = self._route_quickscope[method][path];

	if candy then
		return candy;
	end

	return self:_seek_by_table(method, (self._split or split)(path, self._split_separator or "/", true));
end

meta_index._seek_by_table = function(self, method, ohai)

	local candy, pos = complex_search(self._route_complex[method], ohai, 1);

	return candy, ohai, pos;
end

meta_index.CallEnv = function(self, env, ...)

	local method;
	local path;

	if not env then
		env = {};
		method = self._method_default or error("no method defined");
		path = self._path_default or error("no path defined");
	else
		method = env[self._env_method] or (self._method_default or error("no method defined"));
		path = tostring(env[self._env_path]) or (self._path_default or error("no path defined"));
	end

	local candy, ohai, pos = self:_seek_by_path(method, path);

	if candy then
		return self:_found_env(env, method, path, candy, pos, ohai, ...);
	end

	return self:_not_found_env(env, method, path, ohai, ...);
end

meta_index.Call = function(self, method, path, ...)

	if not method then method = (self._method_default or error("no method defined")); end
	path = tostring(path) or (self._path_default or error("no path defined"));

	local candy, ohai, pos = self:_seek_by_path(method, path);

	if candy then
		return self:_found(method, path, candy, pos, ohai, ...);
	end

	return self:_not_found(method, path, ohai, ...);
end

meta_index.CallAny = function(self, env_or_meth, ...)

	return self[type(env_or_meth) == "table" and "CallEnv" or "Call"](self, env_or_meth, ...);
end

local function quickscope_path(node, table, sep)

	if node[1] == 1 then
		return tconcat(table, sep or "/");
	end

	table[node[1] - 1] = node[2];
	return quickscope_path(node[".."], table, sep);
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

meta_index._set_quickscope = function(self, method, path, value)

	local quick = self:_table_ensure(self._route_quickscope, method, value);
	local sep = self._split_separator or "/";

	--self[path] = value; -- x/a/b/c
	--self[path .. "/"] = value; -- x/a/b/c/
	quick[sep .. path] = value;	-- /x/a/b/c
	quick[sep .. path .. sep] = value; -- /x/a/b/c/
end

meta_index._update_quickscope = function(self, method, node, ntail)

	if ntail and ntail > 0 then -- quickscope is only for 0 and -1
		return;
	end

	local candy = node[0];

	-- updating
	return self:_set_quickscope(method, quickscope_path(node, {}, self._split_separator), candy[0] or candy[-1]);
end

meta_index._remove_quickscope = function(self, method, node)

	return self:_set_quickscope(method, quickscope_path(node, {}, self._split_separator), nil);
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

meta_index._set_table = function(self, method, path, func)

	for key, value in next, func do

		if type(key) == "string" then
			self:_set_table(method, path .. (self._split_separator or "/") .. key,
				type(value) == "table" and value or {[-1] = value});
		elseif type(key) == "number" then
			if key < -1 then
				error(string.format("invalid tail size: %d", key));
			end

			self:_set_func(method, path, key, value);
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

meta_index._set_valid_types = {
	["function"] = true, ["table"] = true, ["userdata"] = true;
}

meta_index._set_func = function(self, method, path, ntail, func)

	local node = self:_node_root(self._route_complex, method, func);

	if func then

		if not self._set_valid_types[type(func)] then
			error(string.format("invalid callable type: %s", type(func)));
		end

		local ohai = (self._split or split)(path, self._split_separator or "/", true);

		for i = 1, #ohai do
			node = node[ohai[i]] or self:_node_new(node, ohai[i]);
		end

		local candy = node[0];

		if not candy then
			node[0] = {[ntail] = func};
		else
			candy[ntail] = func;
		end

		self:_update_quickscope(method, node, ntail);
	else
		node = node_pass(node, (self._split or split)(path, self._split_separator or "/", true));

		local candy = node[0];

		if not candy then
			return;
		end

		candy[ntail] = nil;

		self:_update_quickscope(method, node, ntail);

		if not next(candy) then
			node[0] = nil;
			node_clean(node, self._node_static);
		end
	end
end

local check_path_method_tail = function(method, path, tail)

	if not method then
		error("no method defined");
	end

	path = tostring(path);

	if not path then
		error("no path defined");
	end

	if tail then
		local ntail = tonumber(tail);

		if not ntail then
			error(string.format("invalid tail type: %s", type(tail)));
		end

		if (ntail < -1) then
			error(string.format("invalid tail size: %d", ntail));
		end

		return path, ntail;
	end

	return path, -1;
end

meta_index.Get = function(self, method, path, ntail)

	path, ntail = check_path_method_tail(method, path, ntail);

	local node = node_pass(self:_node_root(self._route_complex, method),
		(self._split or split)(path, self._split_separator or "/", true));

	if node and node[0] then
		return node[0][ntail];
	end
end

meta_index.Set = function(self, method, path, ntail, func)

	if not func and not tonumber(ntail) then
		func = ntail;
		ntail = nil;
	end

	path, ntail = check_path_method_tail(method, path, ntail);

	if func and type(func) == "table" then
		return self:_set_table(method, path, func);
	end

	return self:_set_func(method, path, ntail, func);
end

meta_index.Del = function(self, method, path, ntail)

	return self:Set(method, path, ntail, nil);
end

local function node_clean_chld(self, method, node)

	local static = self._node_static;
	self:_remove_quickscope(method, node);
	node[0] = nil;

	for key, value in next, node do
		if not static[key] then
			node_clean_chld(self, method, value);
			node[key] = nil;
		end
	end
end

meta_index.NodeDel = function(self, method, path)

	path = check_path_method_tail(method, path, nil);

	local node = node_pass(self:_node_root(self._route_complex, method),
		(self._split or split)(path, self._split_separator or "/", true));

	if not node then
		return;
	end

	node[".."][node[2]] = nil;
	return node_clean_chld(self, method, node);
end

-- now push meta_index to meta_copy and return
for k,v in next, meta_index do
	meta_copy[k] = true;
end

return T;
