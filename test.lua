-- TODO better test
-- meh.. too lazy

local T = require "thuja";

T._meta_index._not_found = function(self,m,p,h,e,o)
	print("NOT found", m, p, o);
	assert(o == "NO", o);
end

local print_env = function(env, ...)
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

my1:Call("GET", "/my/2/1/2/3/4", nil, "OK");
my1:Del("GET", "my/2");
my1:Call("GET", "/my/2/1/2/3/4", nil, "NO");

my1:Call(nil, "my/3/4/5", {}, "OK");

my1:SetOver("GET", "/my/1/2/3", function(a) print(">>OVER<<"); print(a[0]); end);
my1:Call("GET", "my/1/2/3", nil, "OK");
my1:DelOver("GET", "my/1/2/3")
my1:Call("GET", "my/1/2/3", nil, "OK");

my1:Set("POST", "/", {
	level1 = {
		level2 = {
			this = print_env;
		};

		and_this = print_env;
	}
});

my1:Call("POST", "/level1/level2/this/hello/there!", nil, "OK");
my1:Call("POST", "/level1/and_this/and/there!", {}, "OK");

my1:Del("POST", "/level1/level2/");
my1:Call("POST", "/level1/level2/this/never/here", nil, "NO");
my1:Call("POST", "/level1/and_this//////but/there!", nil, "OK");
my1:Call("POST", "/my/1/2/3/nope", {}, "NO");

my1:Call("WTF", "/yo/mad", {}, "NO");
