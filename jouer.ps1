# jouer.ps1 - Relais de commandes pour Windows, sans rien installer.
# Usage :  powershell -ExecutionPolicy Bypass -File jouer.ps1
param([string]$Secret = "fritax-relay-774f7d3d911fa7434fbb-c")

$sha = [System.Security.Cryptography.SHA256]::Create()
$octets = [Text.Encoding]::UTF8.GetBytes($Secret)
$hash = ($sha.ComputeHash($octets) | ForEach-Object { $_.ToString("x2") }) -join ""
$topic = "fritax-relay-" + $hash.Substring(0, 20)
$cmdUrl = "https://ntfy.sh/$topic-c"
$resUrl = "https://ntfy.sh/$topic-r"

Write-Host ""
Write-Host "  Pilote Windows - en attente de commandes"
Write-Host "  canal : $topic"
Write-Host "  laisse cette fenetre ouverte, elle ne s'arrete pas toute seule"
Write-Host ""

$since = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - 5

while ($true) {
    try {
        $msgs = Invoke-RestMethod -Uri "$cmdUrl/json?poll=1&since=$since" -TimeoutSec 25
        foreach ($m in $msgs) {
            if ($m.event -ne "message") { continue }
            $since = [int]$m.time
            try { $p = $m.message | ConvertFrom-Json } catch { continue }
            if (-not $p.cmd) { continue }
            Write-Host ("  > " + $p.cmd.Substring(0, [Math]::Min(90, $p.cmd.Length)))
            $sortie = & powershell -NoProfile -Command $p.cmd 2>&1 | Out-String
            $corps = @{ id = $p.id; out = $sortie; err = ""; rc = 0 } | ConvertTo-Json -Compress
            try {
                Invoke-RestMethod -Uri $resUrl -Method Post -Body $corps -TimeoutSec 20 | Out-Null
            } catch {
                Write-Host "  resultat non envoye"
            }
            Write-Host ("  < " + $sortie.Length + " caracteres")
        }
    } catch {
        Start-Sleep -Seconds 2
    }
    Start-Sleep -Milliseconds 800
}
