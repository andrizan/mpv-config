# mpv-config

Konfigurasi ini ditargetkan untuk [mpv v0.41.0](https://github.com/mpv-player/mpv/releases/tag/v0.41.0).
Rilis ini sudah memakai `gpu-next` sebagai default dan lebih mengutamakan Vulkan hardware decoding saat tersedia.

## Config Path

Windows:

```text
%APPDATA%\mpv
```

Linux:

```text
~/.config/mpv
```

## Config Files

Repo ini menyimpan preset, bukan `mpv.conf` aktif. File `mpv.conf` dibuat dengan menyalin salah satu preset berikut ke folder config mpv:

- `mpv.conf.height`: konfigurasi high-end untuk RTX 4060 + Ryzen 9 9900X.
- `mpv.conf.low.windows`: konfigurasi low Windows untuk HP Pavilion Gaming 15-ec0001ax, Ryzen 5 3550H, RAM 8GB, GTX 1050 3GB.
- `mpv.conf.low.linux`: konfigurasi low Linux/CachyOS untuk laptop yang sama.

Contoh Windows:

```powershell
Copy-Item .\mpv.conf.low.windows "$env:APPDATA\mpv\mpv.conf"
```

Contoh Linux:

```sh
cp ./mpv.conf.low.linux ~/.config/mpv/mpv.conf
```

## Auto Power Profile

`scripts/power-profile.lua` otomatis memilih profil berdasarkan status charger:

- Charger dicabut: `battery`
- Charging/AC tersambung: `full-performance`

Deteksi:

- Windows: membaca `System.Windows.Forms.SystemInformation.PowerStatus` lewat PowerShell.
- Linux: membaca `/sys/class/power_supply`.

Opsi ada di:

```text
script-opts/power-profile.conf
```

Profil bisa dipanggil manual:

```powershell
mpv --profile=battery "video.mkv"
mpv --profile=full-performance "video.mkv"
mpv --profile=bateray "video.mkv"
mpv --profile=full-performa "video.mkv"
```

Catatan Windows: `mpv.conf.low.windows` memaksa `d3d11-adapter="NVIDIA GeForce GTX 1050"` untuk mode full performance. Jika nama adapter berbeda, ubah atau kosongkan baris itu.

## Plugin List

- [autoload.lua](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua)
- [pause-when-minimize.lua](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/pause-when-minimize.lua)
- [change-OSD-media-title.lua](https://github.com/nmoorthy524/mpv-Change-OSD-Media-Title)
- [delete_current_file.lua](https://github.com/stax76/mpv-scripts/blob/main/delete_current_file.lua)
- [thumbfast.lua](https://github.com/po5/thumbfast) `%APPDATA%\mpv\script-opts\thumbfast.conf`
- [playlistmanager.lua](https://github.com/jonniek/mpv-playlistmanager) `%APPDATA%\mpv\script-opts\playlistmanager.conf`
- `power-profile.lua`
- `show_chapters.lua`
- [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua)

## Upscaler

Pakai `mpv.conf.low.windows` atau `mpv.conf.low.linux` jika perangkat terbatas. Pakai `mpv.conf.height` untuk perangkat high-end.

- [FSR](https://gist.github.com/agyild/82219c545228d70c5604f865ce0b0ce5) (AMD FidelityFX Super Resolution v1.0.2)
- [nnedi3](https://github.com/bjin/mpv-prescalers/blob/master/compute/nnedi3-nns128-win8x4.hook) (nnedi3-nns128-win8x4)
- [ArtCNN](https://github.com/Artoriuz/ArtCNN/blob/main/GLSL/ArtCNN_C4F32.glsl) (ArtCNN-C4F32)
<!-- - [NVScaler](https://gist.github.com/agyild/7e8951915b2bf24526a9343d951db214) (NVIDIA Image Scaling v1.0.2) -->

## UI Rich

- [uosc](https://github.com/tomasklaen/uosc) (Feature-rich minimalist proximity-based UI for MPV player.)
