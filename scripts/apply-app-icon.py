#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

source = Path("assets/quran-app-icon.jpg")
if not source.exists():
    raise SystemExit("App icon source image is missing")
sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
im = Image.open(source).convert("RGBA")
side = min(im.size)
left = (im.width - side) // 2
top = (im.height - side) // 2
im = im.crop((left, top, left + side, top + side))
res = Path("android/app/src/main/res")
for folder, size in sizes.items():
    target = res / folder
    target.mkdir(parents=True, exist_ok=True)
    icon = im.resize((size, size), Image.Resampling.LANCZOS)
    icon.save(target / "ic_launcher.png", optimize=True)
    icon.save(target / "ic_launcher_round.png", optimize=True)

# Remove default adaptive icons so Android uses the custom density-specific artwork.
for folder in (res / "mipmap-anydpi-v26",):
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        p = folder / name
        if p.exists():
            p.unlink()

manifest = Path("android/app/src/main/AndroidManifest.xml")
s = manifest.read_text()
s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher"')
if 'android:roundIcon=' in s:
    import re
    s = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@mipmap/ic_launcher_round"', s)
else:
    s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"')
manifest.write_text(s)
print("Installed custom Quran app launcher icon.")
