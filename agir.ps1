# agir.ps1 - les yeux et les mains, sans rien installer.
#   -Action shot                     capture l'ecran et renvoie un lien
#   -Action info                     taille de l'ecran
#   -Action move   -X 900 -Y 500
#   -Action click  -X 900 -Y 500 [-Bouton droit]
#   -Action key    -Touche 32 [-Duree 80]      (code de touche Windows)
#   -Action text   -Texte "bonjour"
param(
    [string]$Action = "info",
    [int]$X = -1, [int]$Y = -1,
    [string]$Bouton = "gauche",
    [int]$Touche = 0, [int]$Duree = 80,
    [string]$Texte = ""
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Souris {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, int e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, int e);
  [DllImport("user32.dll")] public static extern int VkKeyScan(char c);
}
"@

function Capture {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
    $chemin = Join-Path $env:TEMP "ecran.png"
    $bmp.Save($chemin, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    $lien = & curl.exe -s -m 60 -F "reqtype=fileupload" -F "time=1h" -F "fileToUpload=@$chemin" https://litterbox.catbox.moe/resources/internals/api.php
    Write-Output "$lien"
}

switch ($Action.ToLower()) {
    "shot"  { Capture }
    "info"  {
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $p = [System.Windows.Forms.Cursor]::Position
        Write-Output "ecran $($b.Width)x$($b.Height) | souris $($p.X),$($p.Y)"
    }
    "move"  {
        if ($X -lt 0) { $X = 100 }; if ($Y -lt 0) { $Y = 100 }
        [Souris]::SetCursorPos($X, $Y) | Out-Null
        Write-Output "ok"
    }
    "click" {
        if ($X -ge 0) { [Souris]::SetCursorPos($X, $Y) | Out-Null; Start-Sleep -Milliseconds 60 }
        if ($Bouton -eq "droit") {
            [Souris]::mouse_event(0x0008, 0, 0, 0, 0); Start-Sleep -Milliseconds 50
            [Souris]::mouse_event(0x0010, 0, 0, 0, 0)
        } else {
            [Souris]::mouse_event(0x0002, 0, 0, 0, 0); Start-Sleep -Milliseconds 50
            [Souris]::mouse_event(0x0004, 0, 0, 0, 0)
        }
        Write-Output "ok"
    }
    "key"   {
        [Souris]::keybd_event([byte]$Touche, 0, 0, 0)
        Start-Sleep -Milliseconds $Duree
        [Souris]::keybd_event([byte]$Touche, 0, 2, 0)
        Write-Output "ok"
    }
    "text"  {
        foreach ($c in $Texte.ToCharArray()) {
            $code = [Souris]::VkKeyScan($c)
            $vk = $code -band 0xFF
            [Souris]::keybd_event([byte]$vk, 0, 0, 0)
            Start-Sleep -Milliseconds 25
            [Souris]::keybd_event([byte]$vk, 0, 2, 0)
            Start-Sleep -Milliseconds 25
        }
        Write-Output "ok"
    }
    default { Write-Output "action inconnue : $Action" }
}
