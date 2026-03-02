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

const verifyCode = `
local ge = game:GetService("ReplicatedStorage").GameEvents
print("StartOrderCutscene:", ge:FindFirstChild("StartOrderCutscene") ~= nil)
print("ConfirmNPCOrder:", ge:FindFirstChild("ConfirmNPCOrder") ~= nil)
`;

const proc = spawn(mcpExe, ['--stdio'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let outputBuffer = '';
proc.stdout.on('data', (d) => {
  outputBuffer += d.toString();
});
proc.stderr.on('data', (d) => {
  console.log('STDERR:', d.toString().trim());
});
proc.on('error', (err) => console.log('ERROR:', err.message));
proc.on('exit', (code) => console.log('Process exited:', code));

function sendMessage(msg) {
  proc.stdin.write(JSON.stringify(msg) + '\n');
}

function parseResponses() {
  return outputBuffer.split('\n').filter(l => l.trim()).map(l => {
    try { return JSON.parse(l); } catch(e) { return null; }
  }).filter(Boolean);
}

// Step 1: Initialize
sendMessage({
  jsonrpc: '2.0', id: 1, method: 'initialize',
  params: {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'gsd-agent', version: '1.0' }
  }
});

setTimeout(() => {
  // Step 2: Initialized notification
  sendMessage({ jsonrpc: '2.0', method: 'notifications/initialized' });

  // Step 3: Call run_code with luaCode (tool name = run_code, param = command)
  sendMessage({
    jsonrpc: '2.0', id: 10, method: 'tools/call',
    params: {
      name: 'run_code',
      arguments: { command: luaCode }
    }
  });

  setTimeout(() => {
    const responses = parseResponses();
    const createResp = responses.find(r => r.id === 10);
    if (createResp) {
      console.log('--- CREATE RESPONSE ---');
      console.log(JSON.stringify(createResp.result || createResp.error, null, 2));
    }

    // Step 4: Verify both exist
    sendMessage({
      jsonrpc: '2.0', id: 11, method: 'tools/call',
      params: {
        name: 'run_code',
        arguments: { command: verifyCode }
      }
    });

    setTimeout(() => {
      const responses2 = parseResponses();
      const verifyResp = responses2.find(r => r.id === 11);
      if (verifyResp) {
        console.log('--- VERIFY RESPONSE ---');
        console.log(JSON.stringify(verifyResp.result || verifyResp.error, null, 2));
      }
      proc.kill();
      process.exit(0);
    }, 8000);
  }, 2000);
}, 1000);
