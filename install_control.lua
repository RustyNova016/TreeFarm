-- Get control script
os.run({}, "rm control.lua")
os.run({}, "wget https://raw.githubusercontent.com/RustyNova016/TreeFarm/master/control.lua")

-- Get lain lib script
os.run({}, "rm lain.lua")
os.run({}, "wget https://raw.githubusercontent.com/RustyNova016/TreeFarm/master/lain.lua")

-- Run Control's setup
os.run({}, "control.lua")