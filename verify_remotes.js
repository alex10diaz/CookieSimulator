// Verify RemoteEvents in Roblox Studio
const { spawn } = require('child_process');

const mcpExe = 'C:\\Users\\alex1\\Downloads\\rbx-studio-mcp (5).exe';

// Use tostring() to convert booleans to strings
const luaVerify = `local ge = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
if not ge then print("ERROR: GameEvents folder not found") return end
local so = ge:FindFirstChild("StartOrderCutscene")
local cn = ge:FindFirstChild("ConfirmNPCOrder")
print("StartOrderCutscene: " .. tostring(so ~= nil))
print("ConfirmNPCOrder: " .. tostring(cn ~= nil))
if so then print("StartOrderCutscene ClassName: " .. so.ClassName) end
if cn then print("ConfirmNPCOrder ClassName: " .. cn.ClassName) end`;

function runMcpCommand(luaCode) {
  return new Promise((resolve, reject) => {
    const proc = spawn(mcpExe, ['--stdio'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true
    });

    let allOutput = '';
    proc.stdout.on('data', (d) => { allOutput += d.toString(); });
    proc.stderr.on('data', (d) => {});
    proc.on('error', reject);

    function send(obj) { proc.stdin.write(JSON.stringify(obj) + '\n'); }

    send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gsd', version: '1.0' } } });

    setTimeout(() => {
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'run_code', arguments: { command: luaCode } } });

      const deadline = Date.now() + 45000;
      const check = setInterval(() => {
        const lines = allOutput.split('\n').filter(l => l.trim());
        for (const line of lines) {
          try {
            const obj = JSON.parse(line);
            if (obj.id === 2) {
              clearInterval(check);
              proc.kill();
              if (obj.result) {
                const text = obj.result.content.map(c => c.text).join('');
                resolve(text);
              } else {
                reject(new Error(JSON.stringify(obj.error)));
              }
              return;
            }
          } catch(e) {}
        }
        if (Date.now() > deadline) {
          clearInterval(check);
          proc.kill();
          reject(new Error('Timeout'));
        }
      }, 500);
    }, 1000);
  });
}

async function main() {
  console.log('Verifying RemoteEvents in Studio...');
  const output = await runMcpCommand(luaVerify);
  console.log('Output:');
  console.log(output);

  const startOk = output.includes('StartOrderCutscene: true');
  const confirmOk = output.includes('ConfirmNPCOrder: true');

  console.log('=== RESULT ===');
  console.log('StartOrderCutscene exists:', startOk);
  console.log('ConfirmNPCOrder exists:', confirmOk);
  console.log('BOTH CONFIRMED:', startOk && confirmOk ? 'YES' : 'NO');
}

main().catch(err => { console.error('FAILED:', err.message); process.exit(1); });
