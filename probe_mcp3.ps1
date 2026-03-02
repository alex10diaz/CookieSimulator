# Try to post a command directly and see if /request responds
$base = "http://localhost:44755"

# Try submitting a command via various paths
$submitPaths = @("/command", "/submit", "/send", "/task", "/run", "/enqueue", "/job", "/script")

foreach ($p in $submitPaths) {
    try {
        $wr = [System.Net.WebRequest]::Create("$base$p")
        $wr.Method = "POST"
        $wr.ContentType = "application/json"
        $wr.Timeout = 2000
        $body = '{"command":"print(42)"}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $wr.ContentLength = $bytes.Length
        $stream = $wr.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
        $resp = $wr.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $rbody = $reader.ReadToEnd()
        Write-Output "POST $p`: $([int]$resp.StatusCode) - $($rbody.Substring(0,[Math]::Min(200,$rbody.Length)))"
    } catch [System.Net.WebException] {
        $resp2 = $_.Exception.Response
        if ($resp2) {
            $code = [int]$resp2.StatusCode
            $reader = New-Object System.IO.StreamReader($resp2.GetResponseStream())
            $rbody = $reader.ReadToEnd()
            Write-Output "POST $p`: $code - $($rbody.Substring(0,[Math]::Min(100,$rbody.Length)))"
        } else {
            Write-Output "POST $p`: TIMEOUT/ERROR - $($_.Exception.Message.Substring(0,[Math]::Min(60,$_.Exception.Message.Length)))"
        }
    }
}
