const WebSocket = require('ws');
const fs = require('fs');

const luaSrc = fs.readFileSync('src/ServerScriptService/Minigames/DressStationServer.server.lua', 'utf8');

// Count max consecutive = signs in the source for long bracket safety
let maxEq = 0;
const eqMatches = luaSrc.match(/\]=*\]/g) || [];
for (const m of eqMatches) {
    maxEq = Math.max(maxEq, m.length - 2);
}
const eqStr = '='.repeat(maxEq + 1);
const luaLongStr = '[' + eqStr + '[' + luaSrc + ']' + eqStr + ']';

const setSourceCode = `
local sss = game:GetService("ServerScriptService")
local minigamesFolder = sss:FindFirstChild("Minigames")
if not minigamesFolder then
    print("ERROR: Minigames folder not found")
    return
end
local ds = minigamesFolder:FindFirstChild("DressStationServer")
if not ds then
    print("ERROR: DressStationServer not found")
    return
end
local newSrc = ${luaLongStr}
ds.Source = newSrc
print("SUCCESS: DressStationServer source updated, length=" .. #newSrc)
local s = ds.Source
print("getToppingInfo: " .. (s:find("getToppingInfo", 1, true) and "OK" or "MISSING"))
print("collectedTypes: " .. (s:find("collectedTypes", 1, true) and "OK" or "MISSING"))
print("startToppingRemote: " .. (s:find("startToppingRemote", 1, true) and "OK" or "MISSING"))
print("awaitingTopping: " .. (s:find("awaitingTopping", 1, true) and "OK" or "MISSING"))
`;

// Try ports in order
const ports = [1337, 13331, 13333, 13344];
let portIndex = 0;

function tryNextPort() {
    if (portIndex >= ports.length) {
        console.log('All ports failed');
        process.exit(1);
    }
    const port = ports[portIndex++];
    console.log('Trying port', port);

    // Try with the MCP subprotocol
    const ws = new WebSocket('ws://localhost:' + port, {
        headers: {
            'Origin': 'http://localhost'
        }
    });
    let responded = false;
    let timedOut = false;

    const timeout = setTimeout(function() {
        timedOut = true;
        if (!responded) {
            console.log('Port', port, 'timeout');
            ws.terminate();
            tryNextPort();
        }
    }, 3000);

    ws.on('open', function() {
        console.log('Connected on port', port);
        // Try MCP JSON-RPC
        const msg = JSON.stringify({
            jsonrpc: '2.0',
            method: 'tools/call',
            params: {
                name: 'run_code',
                arguments: {
                    code: setSourceCode
                }
            },
            id: 1
        });
        ws.send(msg);
    });

    ws.on('message', function(data) {
        responded = true;
        clearTimeout(timeout);
        const response = data.toString();
        console.log('Response from port', port, ':', response.substring(0, 2000));
        ws.close();
        process.exit(0);
    });

    ws.on('error', function(err) {
        if (!timedOut) {
            clearTimeout(timeout);
            console.log('Port', port, 'error:', err.message);
            tryNextPort();
        }
    });
}

tryNextPort();
