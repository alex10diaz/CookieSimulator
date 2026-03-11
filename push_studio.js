const WebSocket = require('ws');
const fs = require('fs');

const luaSrc = fs.readFileSync('src/ServerScriptService/Minigames/DressStationServer.server.lua', 'utf8');

// Escape the Lua source for embedding in a Lua string literal using long bracket syntax
// We'll use [====[ ]==== ] with enough = signs to avoid conflicts
// Count the maximum consecutive = signs in the source
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
    print("ERROR: Minigames folder not found in ServerScriptService")
    return
end
local ds = minigamesFolder:FindFirstChild("DressStationServer")
if not ds then
    print("ERROR: DressStationServer not found in Minigames folder")
    return
end
local newSrc = ${luaLongStr}
ds.Source = newSrc
print("SUCCESS: DressStationServer source updated, length=" .. #newSrc)

-- Verify key strings
local s = ds.Source
print("getToppingInfo: " .. (s:find("getToppingInfo", 1, true) and "OK" or "MISSING"))
print("collectedTypes: " .. (s:find("collectedTypes", 1, true) and "OK" or "MISSING"))
print("startToppingRemote: " .. (s:find("startToppingRemote", 1, true) and "OK" or "MISSING"))
print("awaitingTopping: " .. (s:find("awaitingTopping", 1, true) and "OK" or "MISSING"))
`;

const ws = new WebSocket('ws://localhost:1337');
let responded = false;

ws.on('open', function() {
    console.log('Connected to Roblox Studio MCP plugin');
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
    setTimeout(function() {
        if (!responded) {
            console.log('Timeout - no response');
            ws.close();
            process.exit(1);
        }
    }, 10000);
});

ws.on('message', function(data) {
    responded = true;
    const response = data.toString();
    console.log('Response:', response.substring(0, 2000));
    ws.close();
    process.exit(0);
});

ws.on('error', function(err) {
    console.log('WS error:', err.message);
    process.exit(1);
});

ws.on('close', function() {
    if (!responded) {
        console.log('Connection closed without response');
        process.exit(1);
    }
});
