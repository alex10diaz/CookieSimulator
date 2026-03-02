# Full round-trip test: POST command, let Studio execute it
# We'll try /command with a 30-second timeout

$base = "http://localhost:44755"

Write-Output "Attempting to POST a Lua command..."

try {
    $wr = [System.Net.WebRequest]::Create("$base/command")
    $wr.Method = "POST"
    $wr.ContentType = "application/json"
    $wr.Timeout = 30000  # 30 seconds

    # Try with a simple Lua print
    $lua = 'print("MCP_TEST_42")'
    $body = "{`"command`":`"$lua`"}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $wr.ContentLength = $bytes.Length
    $stream = $wr.GetRequestStream()
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()

    Write-Output "Request sent, waiting for response..."
    $resp = $wr.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $rbody = $reader.ReadToEnd()
    Write-Output "SUCCESS: $([int]$resp.StatusCode) - $rbody"
} catch [System.Net.WebException] {
    $resp2 = $_.Exception.Response
    if ($resp2) {
        $code = [int]$resp2.StatusCode
        $reader = New-Object System.IO.StreamReader($resp2.GetResponseStream())
        $rbody = $reader.ReadToEnd()
        Write-Output "HTTP $code`: $rbody"
    } else {
        Write-Output "Error: $($_.Exception.Message)"
    }
}
