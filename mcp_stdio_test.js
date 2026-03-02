// Test MCP stdio with full wait time
const { spawn } = require('child_process');

const mcpExe = 'C:\\Users\\alex1\\Downloads\\rbx-studio-mcp (5).exe';

const luaCode = `print("TEST_FROM_AGENT_123")`;

const proc = spawn(mcpExe, ['--stdio'], {
  stdio: ['pipe', 'pipe', 'pipe'],
  windowsHide: true
});

let allOutput = '';
proc.stdout.on('data', (d) => {
  allOutput += d.toString();
  const text = d.toString().trim();
  if (text) {
    console.log('[STDOUT]', text.substring(0, 300));
  }
});
proc.stderr.on('data', (d) => {
  const text = d.toString().trim();
  if (text) console.log('[STDERR]', text.substring(0, 200));
});
proc.on('error', (err) => console.log('[ERROR]', err.message));
proc.on('exit', (code) => console.log('[EXIT]', code));

function send(obj) {
  const line = JSON.stringify(obj) + '\n';
  proc.stdin.write(line);
}

// Initialize
send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gsd', version: '1.0' } } });

setTimeout(() => {
  send({ jsonrpc: '2.0', method: 'notifications/initialized' });

  // Call run_code
  send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'run_code', arguments: { command: luaCode } } });
  console.log('[INFO] run_code sent, waiting up to 30s...');

  // Wait 30 seconds for Studio to pick up the command
  setTimeout(() => {
    console.log('[INFO] 30s elapsed. Final output:');
    console.log(allOutput);

    // Parse responses
    const lines = allOutput.split('\n').filter(l => l.trim());
    for (const line of lines) {
      try {
        const obj = JSON.parse(line);
        if (obj.id === 2) {
          console.log('[RESULT id=2]:', JSON.stringify(obj));
        }
      } catch(e) {}
    }

    proc.kill();
    process.exit(0);
  }, 30000);
}, 1000);
