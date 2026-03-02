// Simplified MCP stdio caller for Roblox Studio
const { spawnSync } = require('child_process');
const path = require('path');

const mcpExe = path.resolve('C:/Users/alex1/Downloads/rbx-studio-mcp (5).exe');

const luaCreate = `local ge = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
if not ge then print("ERROR: GameEvents folder not found") return end
local names = { "StartOrderCutscene", "ConfirmNPCOrder" }
for _, name in ipairs(names) do
    if ge:FindFirstChild(name) then
        print(name .. " already exists")
    else
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = ge
        print("Created: " .. name)
    end
end`;

const luaVerify = `local ge = game:GetService("ReplicatedStorage").GameEvents
print("StartOrderCutscene:", ge:FindFirstChild("StartOrderCutscene") ~= nil)
print("ConfirmNPCOrder:", ge:FindFirstChild("ConfirmNPCOrder") ~= nil)`;

function buildInput(code) {
  const msgs = [
    { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gsd', version: '1.0' } } },
    { jsonrpc: '2.0', method: 'notifications/initialized' },
    { jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'run_code', arguments: { command: code } } }
  ];
  return msgs.map(m => JSON.stringify(m)).join('\n') + '\n';
}

console.log('Running CREATE command...');
const r1 = spawnSync(mcpExe, ['--stdio'], {
  input: buildInput(luaCreate),
  encoding: 'utf8',
  timeout: 10000
});
console.log('STDOUT:', r1.stdout);
if (r1.stderr) console.log('STDERR:', r1.stderr);
if (r1.error) console.log('ERROR:', r1.error);

console.log('\nRunning VERIFY command...');
const r2 = spawnSync(mcpExe, ['--stdio'], {
  input: buildInput(luaVerify),
  encoding: 'utf8',
  timeout: 10000
});
console.log('STDOUT:', r2.stdout);
if (r2.stderr) console.log('STDERR:', r2.stderr);
if (r2.error) console.log('ERROR:', r2.error);
