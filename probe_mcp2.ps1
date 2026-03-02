# Probe more MCP HTTP endpoints
$base = "http://localhost:44755"
$tests = @(
    @{ M="GET"; P="/request"; B=$null },
    @{ M="GET"; P="/response"; B=$null },
    @{ M="POST"; P="/poll"; B='{}' },
    @{ M="GET"; P="/"; B=$null },
    @{ M="GET"; P="/health"; B=$null },
    @{ M="GET"; P="/status"; B=$null },
    @{ M="POST"; P="/status"; B='{}' }
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
        Write-Output "$($t.M) $($t.P): $([int]$resp.StatusCode) - $($body.Substring(0,[Math]::Min(200,$body.Length)))"
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int]$resp.StatusCode
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Output "$($t.M) $($t.P): $code - $($body.Substring(0,[Math]::Min(200,$body.Length)))"
        } else {
            Write-Output "$($t.M) $($t.P): ERROR - $($_.Exception.Message)"
        }
    }
}
