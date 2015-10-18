local T = {};

local type = type;
local unpack = unpack;
local tostring = tostring;
local find = string.find;
local gsub = string.gsub;

local emptyTable = {};
local nullFunction = function() end
local tableFunction = function() return emptyTable; end

setmetatable(emptyTable, {__newindex = nullFunction});

local l2TableMeta = {
	__index = tableFunction;
};

local l2TableClosed = setmetatable({}, {
	__index = tableFunction;
	__newindex = nullFunction;
});

local metaDefauts = {
	_tail_key = "_thuja_tail_",
	_path_default = "/",
	_method_default = "GET",
	_env_method = "REQUEST_METHOD",
	_env_path = "INFO_PATH",
	_route_over = l2TableClosed,
	_route_complex_direct = l2TableClosed,
	_route_complex = l2TableClosed,
	_not_found = nullFunction,
};

local regL2 = {
	"_route_over",
	"_route_complex_direct",
	"_route_complex",
};

local regCopy = {
	"_method_default",
	"_path_default",
	"_tail_key",
	"_env_path",
	"_env_method",
};

T._meta_index = metaDefauts;
T._reg_l2 = regL2;
T._reg_copy = regCopy;

T.New = function(self, t)

	if not t then t = emptyTable; end
	local setmetatable = setmetatable;

	local p = setmetatable({}, {__index = self._meta_index});

	if not t._split and not self._meta_index._split then
		self._meta_index._split = require("teateatea").pack;
	end

	local regL2 = T._reg_l2;
	local regCopy = T._reg_copy;

	for i = 1, #regL2 do
		p[regL2[i]] = t[regL2[i]] or setmetatable({}, l2TableMeta);
	end

	for i = 1, #regCopy do
		p[regCopy[i]] = t[regCopy[i]];
	end

	return p;
end

metaDefauts.Call = function(self, method, path, env, ...)

	if not method then method = (env and env[self._env_method]) or self._method_default; end
	path = tostring(path or (env and env[self._env_path]) or self._path_default);

	local over = self._route_over[method];
	local direct = self._route_complex_direct[method];

	local f = over[path] or direct[path];

	if not f and find(path, "//", nil, true) then -- try again if path is incorrect;
		path = gsub(path, "/+", "/"); -- correct plx
		f = over[path] or direct[path];
	end

	if f then
		local tail = {[0] = path};

		if env then
			env[self._tail_key] = tail;
			return f(env, ...);
		end

		return f(tail, ...);
	end

	local ohai = self._split(path, "/");
	local obye = self._route_complex[method];
	local to = #ohai;

	for i = 1, to do
		local ya = obye[ohai[i]];

		if not ya then
			break;
		end

		if type(ya) == "function" then
			local tail = {[0] = path, unpack(ohai, i + 1)};

			if env then
				env[self._tail_key] = tail;
				return ya(env, ...);
			end

			return ya(tail, ...);
		end

		obye = ya;
	end

	return self:_not_found(method, path, ohai, env, ...);
end

local function path_center(path)
	return gsub(gsub(gsub(tostring(path), "/+", "/"), "^/", ""), "/$", "");
end

local function path_set(self, path, value)
	self[path] = value;
	self[path .. "/"] = value;
	self["/" .. path] = value;
	self["/" .. path .. "/"] = value;
end

local function complex_remove(prefix, direct, source)
	for key, value in next, source do
		if type(value) == "table" then
			complex_remove(prefix .. "/" .. key, direct, value);
		else
			path_set(direct, prefix .. "/" .. key, nil);
		end
	end
end

local function table_ensure(table, key, flag)
	if flag and not rawget(table, key) then
		table[key] = {};
	end

	return table[key];
end

metaDefauts.Set = function(self, method, path, func)

	if not path or not method then
		return;
	end

	path = path_center(path);

	if func and type(func) == "table" then
		for key, value in next, func do
			self:Set(method, path .. "/" .. key, value);
		end

		return;
	end

	local direct = table_ensure(self._route_complex_direct, method, func);
	table_ensure(self._route_over, method, func); -- also commiting for over (lookup speed)

	local ohai = self._split(path, "/");
	local obye = table_ensure(self._route_complex, method, func);
	local to = #ohai - 1;
	local ya;

	if func ~= nil then
		for i = 1, to do
			ya = obye[ohai[i]];

			if ya and type(ya) == "function" then
				path_set(direct, table.concat({unpack(ohai, 1, i)}, "/"), nil);
				ya = nil;
			end

			if not ya then
				ya = {};
				obye[ohai[i]] = ya;
			end

			obye = ya;
		end
	else
		for i = 1, to do
			ya = obye[ohai[i]];

			if not ya or type(ya) == "function" then
				return;
			end

			obye = ya;
		end
	end

	local last = ohai[#ohai];
	local finally = obye[last];

	if finally and type(finally) == "table" then
		complex_remove(path, direct, finally);
	end

	if func or finally then
		obye[last] = func;
		path_set(direct, path, func);
	end
end

metaDefauts.Del = function(self, method, path)
	return self:Set(method, path, nil);
end

metaDefauts.SetOver = function(self, method, path, func)
	if method and path then
		path_set(table_ensure(self._route_over, method, func), path_center(path), func);
	end
end

metaDefauts.DelOver = function(self, method, path)
	return self:SetOver(method, path, nil);
end

return T;
