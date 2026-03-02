# Probe MCP HTTP endpoints
$base = "http://localhost:44755"
$tests = @(
    @{ M="POST"; P="/run_code"; B='{"command":"print(1)"}' },
    @{ M="POST"; P="/execute"; B='{"command":"print(1)"}' },
    @{ M="GET"; P="/poll"; B=$null },
    @{ M="POST"; P="/queue"; B='{"command":"print(1)"}' },
    @{ M="POST"; P="/request"; B='{"command":"print(1)"}' }
)

foreach ($t in $tests) {
    try {
        $wr = [System.Net.WebRequest]::Create("$base$($t.P)")
        $wr.Method = $t.M
        $wr.Timeout = 3000
        if ($t.B) {
            $wr.ContentType = "application/json"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($t.B)
            $wr.ContentLength = $bytes.Length
            $stream = $wr.GetRequestStream()
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Close()
        }
        $resp = $wr.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $body = $reader.ReadToEnd()
        Write-Output "$($t.M) $($t.P): $([int]$resp.StatusCode) - $($body.Substring(0,[Math]::Min(100,$body.Length)))"
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int]$resp.StatusCode
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Output "$($t.M) $($t.P): $code - $($body.Substring(0,[Math]::Min(100,$body.Length)))"
        } else {
            Write-Output "$($t.M) $($t.P): ERROR - $($_.Exception.Message)"
        }
    }
}
