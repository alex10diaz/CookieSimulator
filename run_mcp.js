// Temporary script to call Roblox Studio MCP via stdio
const { spawn } = require('child_process');

const mcpExe = 'C:\\Users\\alex1\\Downloads\\rbx-studio-mcp (5).exe';

const luaCode = `
local ge = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
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
end
`;

const proc = spawn(mcpExe, ['--stdio'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let outputBuffer = '';
proc.stdout.on('data', (d) => {
  outputBuffer += d.toString();
  console.log('STDOUT:', d.toString().trim());
});
proc.stderr.on('data', (d) => {
  console.log('STDERR:', d.toString().trim());
});
proc.on('error', (err) => console.log('ERROR:', err.message));
proc.on('exit', (code) => console.log('Process exited:', code));

// MCP protocol: send initialize first
const initMsg = JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'gsd-agent', version: '1.0' }
  }
}) + '\n';

proc.stdin.write(initMsg);

setTimeout(() => {
  // Send initialized notification
  const notif = JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n';
  proc.stdin.write(notif);

  // Then call run_code
  const callMsg = JSON.stringify({
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/call',
    params: {
      name: 'run_code',
      arguments: { code: luaCode }
    }
  }) + '\n';
  proc.stdin.write(callMsg);

  setTimeout(() => {
    console.log('--- Final output buffer ---');
    console.log(outputBuffer);
    proc.kill();
    process.exit(0);
  }, 6000);
}, 1000);
