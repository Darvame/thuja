# thuja

<h2>First Look</h2>
```lua
local thuja = require "thuja";

local tree = thuja:New();

local say_hello = function(tail, a1, ...)
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
```
---
```
I want to take this opportunity
And say Hello to my dog, my cat, my mouse, my beetles!
Especially to my grandma, my grandpa!
```
