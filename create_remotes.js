// Create RemoteEvents in Roblox Studio via MCP stdio
const { spawn } = require('child_process');

const mcpExe = 'C:\\Users\\alex1\\Downloads\\rbx-studio-mcp (5).exe';

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

function runMcpCommand(luaCode, label) {
  return new Promise((resolve, reject) => {
    const proc = spawn(mcpExe, ['--stdio'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true
    });

    let allOutput = '';
    proc.stdout.on('data', (d) => { allOutput += d.toString(); });
    proc.stderr.on('data', (d) => { /* ignore */ });
    proc.on('error', reject);

    function send(obj) { proc.stdin.write(JSON.stringify(obj) + '\n'); }

    send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gsd', version: '1.0' } } });

    setTimeout(() => {
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'run_code', arguments: { command: luaCode } } });

      const deadline = Date.now() + 45000;
      const checkInterval = setInterval(() => {
        const lines = allOutput.split('\n').filter(l => l.trim());
        for (const line of lines) {
          try {
            const obj = JSON.parse(line);
            if (obj.id === 2) {
              clearInterval(checkInterval);
              proc.kill();
              if (obj.result) {
                const text = obj.result.content.map(c => c.text).join('');
                resolve({ label, output: text });
              } else {
                reject(new Error(`Error: ${JSON.stringify(obj.error)}`));
              }
              return;
            }
          } catch(e) {}
        }
        if (Date.now() > deadline) {
          clearInterval(checkInterval);
          proc.kill();
          reject(new Error('Timeout waiting for Studio response'));
        }
      }, 500);
    }, 1000);
  });
}

async function main() {
  console.log('Step 1: Creating RemoteEvents...');
  const createResult = await runMcpCommand(luaCreate, 'CREATE');
  console.log('CREATE output:');
  console.log(createResult.output);

  console.log('\nStep 2: Verifying RemoteEvents...');
  const verifyResult = await runMcpCommand(luaVerify, 'VERIFY');
  console.log('VERIFY output:');
  console.log(verifyResult.output);

  // Check both are true
  const output = verifyResult.output;
  const startOk = output.includes('StartOrderCutscene: true');
  const confirmOk = output.includes('ConfirmNPCOrder: true');

  console.log('\n=== VERIFICATION RESULT ===');
  console.log('StartOrderCutscene present:', startOk);
  console.log('ConfirmNPCOrder present:', confirmOk);
  console.log('Both confirmed:', startOk && confirmOk);
}

main().catch(err => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
