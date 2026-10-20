Add-Type -AssemblyName System.Drawing
$src = "C:\Users\sahil\.gemini\antigravity-ide\brain\f9959a18-f6ca-4d8d-b256-851e028f4aef\milo_app_icon_1792438142715.jpg"
$resDir = "c:\Users\sahil\Downloads\milo\mobile\android\app\src\main\res"

$resolutions = @(
    @{ folder = "mipmap-mdpi"; size = 48 },
    @{ folder = "mipmap-hdpi"; size = 72 },
    @{ folder = "mipmap-xhdpi"; size = 96 },
    @{ folder = "mipmap-xxhdpi"; size = 144 },
    @{ folder = "mipmap-xxxhdpi"; size = 192 }
)

$img = [System.Drawing.Image]::FromFile($src)

foreach ($r in $resolutions) {
    $folderName = $r.folder
    $sz = $r.size
    $targetDir = Join-Path $resDir $folderName
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $bmp = New-Object System.Drawing.Bitmap $sz, $sz
    $graph = [System.Drawing.Graphics]::FromImage($bmp)
    $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graph.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graph.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graph.DrawImage($img, 0, 0, $sz, $sz)

    $dest = Join-Path $targetDir "ic_launcher.png"
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $graph.Dispose()
    Write-Host "Created: $dest ($sz x $sz)"
}

$img.Dispose()
Write-Host "Milo App Icon generation complete!"
