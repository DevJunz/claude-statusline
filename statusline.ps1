$ErrorActionPreference = 'SilentlyContinue'
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

try {
    $raw = ''
    try {
        $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
    } catch {}
    $j = $null
    if ($raw -and $raw.Trim()) {
        try { $j = $raw | ConvertFrom-Json } catch {}
    }

    $esc = [char]27
    function C([string]$code, [string]$t) { return "$esc[${code}m$t$esc[0m" }
    function PctColor($p) {
        if ($p -ge 80) { return '31' }
        if ($p -ge 50) { return '33' }
        return '32'
    }
    function Num($v) {
        if ($null -eq $v) { return $null }
        $d = 0.0
        if ([double]::TryParse([string]$v, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }
        return $null
    }
    function FromEpoch($v) {
        $n = Num $v
        if ($null -eq $n) { return $null }
        try { return [DateTimeOffset]::FromUnixTimeSeconds([long]$n).LocalDateTime } catch { return $null }
    }

    $iFolder = [char]::ConvertFromUtf32(0x1F4C1)
    $iBranch = [char]::ConvertFromUtf32(0x1F33F)
    $iClock  = [char]::ConvertFromUtf32(0x1F550)
    $dot     = [char]0x25CF

    $parts = New-Object System.Collections.ArrayList

    # directory
    $dir = $null
    if ($j) {
        if ($j.workspace -and $j.workspace.current_dir) { $dir = [string]$j.workspace.current_dir }
        elseif ($j.cwd) { $dir = [string]$j.cwd }
    }
    if (-not $dir) { $dir = (Get-Location).Path }
    $leaf = Split-Path -Leaf ($dir.TrimEnd('\','/'))
    if (-not $leaf) { $leaf = $dir }
    [void]$parts.Add((C '36' "$iFolder $leaf"))

    # git
    try {
        if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $dir)) {
            $env:GIT_OPTIONAL_LOCKS = '0'
            $br = (& git -C $dir rev-parse --abbrev-ref HEAD 2>$null)
            if ($LASTEXITCODE -eq 0 -and $br) {
                $br = ($br | Select-Object -First 1).Trim()
                if ($br -eq 'HEAD') {
                    $br = (& git -C $dir rev-parse --short HEAD 2>$null | Select-Object -First 1)
                }
                $st = @(& git -C $dir status --porcelain 2>$null | Where-Object { $_ })
                $txt = "$iBranch $br"
                if ($st.Count -gt 0) { $txt += " $dot$($st.Count)" }
                [void]$parts.Add((C '35' $txt))
            }
        }
    } catch {}

    # model
    if ($j -and $j.model -and $j.model.display_name) {
        [void]$parts.Add((C '34' ([string]$j.model.display_name)))
    }

    # context
    $ctx = $null
    if ($j -and $j.context_window) {
        $ctx = Num $j.context_window.used_percentage
        if ($null -eq $ctx) {
            $size = Num $j.context_window.context_window_size
            $cu = $j.context_window.current_usage
            $used = $null
            if ($cu) {
                $used = 0.0
                foreach ($k in 'input_tokens','cache_creation_input_tokens','cache_read_input_tokens') {
                    $x = Num $cu.$k
                    if ($null -ne $x) { $used += $x }
                }
            } else { $used = Num $j.context_window.total_input_tokens }
            if ($size -and $size -gt 0 -and $null -ne $used) { $ctx = $used / $size * 100 }
        }
    }
    if ($null -ne $ctx) {
        [void]$parts.Add((C (PctColor $ctx) ("ctx {0:N0}%" -f $ctx)))
    }

    # cost
    if ($j -and $j.cost) {
        $cost = Num $j.cost.total_cost_usd
        if ($null -ne $cost) {
            [void]$parts.Add((C '33' ('$' + $cost.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))))
        }
    }

    # rate limits
    if ($j -and $j.rate_limits) {
        $five = $j.rate_limits.five_hour
        if ($five) {
            $p = Num $five.used_percentage
            if ($null -ne $p) {
                $s = C (PctColor $p) ("5h {0:N0}%" -f $p)
                $d = FromEpoch $five.resets_at
                if ($d) { $s += ' ' + (C '90' ('(' + $d.ToString('HH:mm') + ')')) }
                [void]$parts.Add($s)
            }
        }
        $seven = $j.rate_limits.seven_day
        if ($seven) {
            $p = Num $seven.used_percentage
            if ($null -ne $p) {
                $s = C (PctColor $p) ("7d {0:N0}%" -f $p)
                $d = FromEpoch $seven.resets_at
                if ($d) { $s += ' ' + (C '90' ('(' + $d.ToString('MM\/dd') + ')')) }
                [void]$parts.Add($s)
            }
        }
        # model-specific weekly limits (e.g. seven_day_fable)
        foreach ($prop in $j.rate_limits.PSObject.Properties) {
            if ($prop.Name -notlike 'seven_day_*' -or -not $prop.Value) { continue }
            $p = Num $prop.Value.used_percentage
            if ($null -eq $p) { continue }
            $label = $prop.Name.Substring(10)
            if ($label) { $label = $label.Substring(0,1).ToUpper() + $label.Substring(1) }
            $s = C (PctColor $p) ("7d $label {0:N0}%" -f $p)
            $d = FromEpoch $prop.Value.resets_at
            if ($d) { $s += ' ' + (C '90' ('(' + $d.ToString('MM\/dd') + ')')) }
            [void]$parts.Add($s)
        }
    }

    # session start
    if ($j -and $j.cost) {
        $ms = Num $j.cost.total_duration_ms
        if ($null -ne $ms) {
            $start = (Get-Date).AddMilliseconds(-$ms)
            [void]$parts.Add((C '90' ("$iClock " + $start.ToString('HH:mm'))))
        }
    }

    [Console]::Out.Write(($parts -join (C '90' ' | ')))
} catch {
    try { [Console]::Out.Write('') } catch {}
}
exit 0
