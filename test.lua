-- TODO better test
-- meh.. too lazy

local T = require "thuja";

T._meta_index._not_found = function(self,m,p,h,o)
	print("NOT found", m, p, o);
	assert(o == "NO", o);
end

local print_env = function(self, env, ...)
	local t = env._thuja_tail_ or env;

	print('TAIL: (' .. #t .. ') ' .. t[0]);
	for i = 1, #t do
		print(i .. ": >>" .. t[i] .. "<<");
	end
	print('ARGS:')
	print(...);

	local o = ...;
	assert(o == "OK", o);
end

local my1 = T:New();

my1:Set("GET", "/my/1", print_env);
my1:Set("GET", "/my/2", print_env);
my1:Set("GET", "/my/3/4/5", print_env);

my1:Call("GET", "/my/2/1/2/3/4", "OK");
my1:Del("GET", "my/2");
my1:Call("GET", "/my/2/1/2/3/4", "NO");

my1:Call(nil, "my/3/4/5", "OK");

my1:Call("GET", "my/1/2/3", "OK");
my1:Call("GET", "my/1/2/3", "OK");

my1:Set("POST", "/", {
	level1 = {
		level2 = {
			this = {
				[""] = print_env;
			}
		};

		and_this = print_env;
	}
});

my1:Call("POST", "/level1/level2/this/hello/there!", "OK");
my1:Call("POST", "/level1/and_this/and/there!", "OK");

my1:NodeDel("POST", "/level1/level2/");
my1:Call("POST", "/level1/level2/this/never/here", "NO");
my1:Call("POST", "/level1/./and_this//////but/there!", "OK");
my1:Call("POST", "/my/1/2/3/nope", "NO");

my1:Call("WUT", "/yo/mad", "NO");

my1:Set(0, "/l1/l2", 2, print_env);
my1:Call(0, "/l1/l2/abc/bcd", "OK");
my1:Call(0, "/l1/././././././l2/abc/bcd", "OK");
my1:Call(0, "/l1/../l1/../l1/././././././../l1/./l2/./abc/bcd", "OK");
my1:Call(0, "/l1/l2/3rgs/donot/call", "NO");

my1:Set(1, "/l1/l2/", print_env);
my1:Set(1, "/l1/l2/special", 0, print_env);

my1._env_path = "teh_path";
my1._env_method = "teh_method";

my1:Call(1, "/l1/l2/./../l2/special/./special/././special/more/than/0/args/here", "OK");
my1:CallEnv({
	["REQUEST_METHOD"] = 1,
	["PATH_INFO"] = "/l1/l2/./../l2/special/./special/././special/more/than/0/args/here"
}, "OK");

my1._env_path = "teh_path";
my1._env_method = "teh_method";
my1:CallEnv({
	teh_method = 1,
	teh_path = "/l1/l2/./../l2/special/./special/././special/more/than/0/args/here"
}, "OK");

local a = function() end

my1:Set("GETTEST", "/1/2/3/abc/abr/$!@#/lol", 3, a);
assert(a == my1:Get("GETTEST", "/1/2/3/abc/abr/$!@#/lol", 3), ":GET() fail");
assert(my1:Get("GETTEST", "/1/2/3/abc/abr/$!@#/lol") == nil, ":GET() fail");

assert(pcall(function() -- faild
	my1:Get("GETTEST", "/1/2/3/abc/abr/$!@#/lol", -2);
end) == false, ":GET() fail");

assert(pcall(function() -- faild
	my1:Set(nil, "/1/2/3/abc/abr/$!@#/lol", 3, a);
end) == false, ":SET() fail");

assert(pcall(function() -- faild
	my1:Set(1, "/", { [-3] = function() end });
end) == false, ":SET() fail");

-- quick
my1:Set("Q", "/1/2/3/4", 0, function() return 0; end);
my1:Set("Q", "/1/2/3/4", function() return 1; end);

assert(my1:Call("Q", "/1/2/3/4") == 0, "qu arg");
assert(my1:Call("Q", "/1/2/3/4/5/6") == 1, "qu arg");

print("__end__");
