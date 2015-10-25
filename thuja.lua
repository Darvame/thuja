local T = {};

local next = next;
local type = type;
local unpack = unpack;
local tostring = tostring;
local tconcat = table.concat;
local gsub = string.gsub;

local emptyTable = {};
local emptyNode = {1, ""};
local nullFunction = function() end
local tableFunction = function() return emptyTable; end
local nodeFunction = function() return emptyNode; end

emptyNode["."] = emptyNode;
emptyNode[".."] = emptyNode;

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

local metaDefauts = {
	_tail_key = "_thuja_tail_",
	_path_default = "/",
	_method_default = "GET",
	_env_method = "REQUEST_METHOD",
	_env_path = "PATH_INFO",
	_route_quickscope = l2TableClosed,
	_route_complex = l2TableNode,
	_not_found = nullFunction,
};

T._node_l2_meta = l2NodeMeta;
T._meta_index = metaDefauts;
T._table_l2_meta = l2TableMeta;

metaDefauts._node_static = {
	[".."] = true,
	["."] = true,
	[1] = true,
	[2] = true,
};

T.New = function(self, cpy)

	if not cpy then cpy = emptyTable; end

	local thuthu = setmetatable({}, {__index = self._meta_index});

	if not cpy._split and not self._meta_index._split then
		self._meta_index._split = require("teateatea").pack;
	end

	for key, value in next, cpy do
		thuthu[key] = value;
	end

	thuthu._route_quickscope = setmetatable({}, self._table_l2_meta);
	thuthu._route_complex = setmetatable({}, self._node_l2_meta);

	return thuthu;
end

metaDefauts._found = function(self, env, func, path, onum, ohai, ...)
	local tail;

	if onum > 0 then
		tail = {[0] = path, unpack(ohai, onum)};
	else
		tail = {[0] = path};
	end

	if env then
		env[self._tail_key] = tail;
		return func(env, ...);
	end

	return func(tail, ...);
end

metaDefauts.Call = function(self, method, path, env, ...)

	if not method then method = (env and env[self._env_method]) or self._method_default; end
	path = tostring(path or (env and env[self._env_path]) or self._path_default);

	local quick = self._route_quickscope[method][path];

	if quick then
		return self:_found(env, quick, path, 0, nil, ...);
	end

	local ohai = self._split(path, "/");
	local obye = self._route_complex[method];
	local osize = #ohai;

	for i = 1, osize do
		local nah = obye[ohai[i]];

		if not nah then
			break;
		end

		obye = nah;
	end

	for i = obye[1], 1, -1 do
		local candy = obye[0];

		if candy then
			local diff = osize - i + 1;
			local func = candy[diff] or candy[-1];

			if func then
				return self:_found(env, func, path, osize - diff, ohai, ...);
			end
		end

		obye = obye[".."];
	end

	return self:_not_found(method, path, ohai, env, ...);
end

local function path_center(path)
	return gsub(gsub(gsub(tostring(path), "/+", "/"), "^/", ""), "/$", "");
end

local quickScopeTail = { [-1] = true, [0] = true };

local function quickScopePath(node, table)
	if node[1] == 1 then
		return tconcat(table, "/");
	end

	table[node[1] - 1] = node[2];
	return quickScopePath(node[".."], table);
end

local function node_clean(node, st)
	for key in next, node do
		if not st[key] then
			return;
		end
	end

	if node[1] > 1 then
		return node_clean(node[".."], st);
	end
end

metaDefauts._set_quickscope_set = function(_, self, path, value)
	--self[path] = value; -- x/a/b/c
	--self[path .. "/"] = value; -- x/a/b/c/
	self["/" .. path] = value;	-- /x/a/b/c
	self["/" .. path .. "/"] = value; -- /x/a/b/c/
end

metaDefauts._set_quickscope = function(self, quick, node, ntail, value)
	if not quickScopeTail[ntail] then
		return;
	end

	local path = quickScopePath(node, {});
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

metaDefauts._table_ensure = function(self, table, key, flag)
	if flag and not rawget(table, key) then
		table[key] = {};
	end

	return table[key];
end

metaDefauts._node_root = function(self, table, key, flag)
	local node = rawget(table, key);

	if not node and flag then
		node = {1, ""};
		node[".."] = node;
		node["."] = node;
		table[key] = node;
	end

	return node or table[key];
end

metaDefauts._node_new = function(self, table, key)

	local node = {
		[1] = table[1] + 1,
		[2] = key,
		[".."] = table,
	};

	node["."] = node;
	table[key] = node;
	return node;
end

metaDefauts._set_table = function(self, node, quick, path, func)
	for key, value in next, func do
		if type(key) == "string" then
			local key = path_center(key);
			if key:len() > 0 then
				self:_set_table(node, quick, path .. "/" .. key, type(value) == "table" and value or {[-1] = value});
			end
		elseif type(key) == "number" and key > -2 then
			self:_set_func(node, quick, path, key, value);
		end
	end
end

metaDefauts._set_func = function(self, node, quick, path, ntail, func)
	local ohai = self._split(path, "/");

	if func then
		for i = 1, #ohai do
			node = node[ohai[i]] or self:_node_new(node, ohai[i]);
		end

		local candy = node[0];

		if not candy then
			node[0] = {[ntail] = func};
		else
			candy[ntail] = func;
		end

		self:_set_quickscope(quick, node, ntail);
	else
		for i = 1, #ohai do
			node = node[ohai[i]];

			if not node then
				return;
			end
		end

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

metaDefauts.Set = function(self, method, path, ntail, func)

	if not path or not method then
		return;
	end

	if not func and type(ntail) ~= "number" then
		func = ntail;
		ntail = -1;
	end

	if not ntail then
		ntail = -1;
	elseif ntail < -1 then
		return;
	end

	path = path_center(path);
	local node = self:_node_root(self._route_complex, method, func);
	local quick = self:_table_ensure(self._route_quickscope, method, func);

	if func and type(func) == "table" then
		return self:_set_table(node, quick, path, func);
	end

	return self:_set_func(node, quick, path, ntail, func);
end

metaDefauts.Del = function(self, method, path, ntail)
	return self:Set(method, path, type(ntail) == "number" and ntail or -1, nil);
end

local function node_clean_chld(self, node, quick)
	local static = self._node_static;
	self:_set_quickscope_set(quick, quickScopePath(node, {}));
	node[0] = nil;

	for key, value in next, node do
		if not static[key] then
			node_clean_chld(self, value, quick);
			node[key] = nil;
		end
	end
end

metaDefauts.NodeDel = function(self, method, path)

	if not path or not method then
		return;
	end

	local node = self:_node_root(self._route_complex, method);

	if not node then
		return;
	end

	local ohai = self._split(tostring(path), "/");
	local quick = self:_table_ensure(self._route_quickscope, method);

	for i = 1, #ohai do
		node = node[ohai[i]];

		if not node then
			return;
		end
	end

	node[".."][node[2]] = nil;
	return node_clean_chld(self, node, quick);
end

return T;
