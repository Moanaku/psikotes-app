"""Membuat semua ikon app dari tool/ikon/ikon.svg (hanya <rect>).

  python tool/ikon/gen_ikon.py            # tulis ikon Android dan web
  python tool/ikon/gen_ikon.py --preview DIR   # juga tulis contoh crop lingkaran dan kotak membulat
"""
from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SVG = Path(__file__).with_name("ikon.svg")
RES = ROOT / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "web"
NS = "{http://www.w3.org/2000/svg}"
CANVAS = 108
SS = 4  # supersampling


def read_svg():
    root = ET.parse(SVG).getroot()
    bg, cells = None, []
    for r in root.iter(NS + "rect"):
        d = {k: float(r.get(k, 0)) for k in ("x", "y", "width", "height", "rx")}
        d["fill"] = r.get("fill")
        if r.get("id") == "latar":
            bg = d
        else:
            cells.append(d)
    assert bg and len(cells) == 9, "SVG harus punya 1 latar dan 9 sel"
    return bg["fill"], cells


def rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def render(size: int, bg, cells, scale=1.0, shape="square", with_bg=True) -> Image.Image:
    """shape: square (penuh), round (lingkaran), squircle (kotak membulat ~ 22%)."""
    n = size * SS
    k = n / CANVAS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if with_bg:
        d.rectangle([0, 0, n, n], fill=rgb(bg) + (255,))
    c = CANVAS / 2
    for s in cells:
        x0 = (c + (s["x"] - c) * scale) * k
        y0 = (c + (s["y"] - c) * scale) * k
        w = s["width"] * scale * k
        d.rounded_rectangle([x0, y0, x0 + w, y0 + s["height"] * scale * k],
                            radius=s["rx"] * scale * k, fill=rgb(s["fill"]) + (255,))
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    if shape == "round":
        md.ellipse([0, 0, n - 1, n - 1], fill=255)
    elif shape == "squircle":
        md.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=255)
    else:
        md.rectangle([0, 0, n, n], fill=255)
    img.paste(layer, (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


def vec_path(s) -> str:
    x, y, w, h, r = s["x"], s["y"], s["width"], s["height"], s["rx"]
    f = lambda v: f"{v:g}"
    return (f"M{f(x + r)},{f(y)}H{f(x + w - r)}A{f(r)},{f(r)} 0 0 1 {f(x + w)},{f(y + r)}"
            f"V{f(y + h - r)}A{f(r)},{f(r)} 0 0 1 {f(x + w - r)},{f(y + h)}"
            f"H{f(x + r)}A{f(r)},{f(r)} 0 0 1 {f(x)},{f(y + h - r)}"
            f"V{f(y + r)}A{f(r)},{f(r)} 0 0 1 {f(x + r)},{f(y)}Z")


def vector(cells, mono=False) -> str:
    paths = "".join(
        f'\n    <path android:fillColor="{"#FF000000" if mono else s["fill"].upper().replace("#", "#FF")}" '
        f'android:pathData="{vec_path(s)}"/>' for s in cells)
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp"\n'
            '    android:viewportWidth="108" android:viewportHeight="108">'
            f'{paths}\n</vector>\n')


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    a = ap.parse_args()
    bg, cells = read_svg()

    # Android adaptif (API 26+)
    write(RES / "drawable" / "ic_launcher_foreground.xml", vector(cells))
    write(RES / "drawable" / "ic_launcher_monochrome.xml", vector(cells, mono=True))
    write(RES / "values" / "ic_launcher_background.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{bg.upper().replace("#", "#FF")}</color>\n</resources>\n')
    write(RES / "mipmap-anydpi-v26" / "ic_launcher.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background"/>\n'
          '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
          '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
          '</adaptive-icon>\n')
    # Android lama (sebelum API 26): kotak membulat
    for d, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render(px, bg, cells, scale=1.3, shape="squircle").save(RES / f"mipmap-{d}" / "ic_launcher.png")

    # Web: ikon biasa memenuhi kanvas dengan sudut membulat, maskable tanpa pembulatan dan kisi di zona aman
    for px in (192, 512):
        render(px, bg, cells, scale=1.3, shape="squircle").save(WEB / "icons" / f"Icon-{px}.png")
        render(px, bg, cells, scale=1.0).save(WEB / "icons" / f"Icon-maskable-{px}.png")
    render(32, bg, cells, scale=1.5, shape="squircle").save(WEB / "favicon.png")

    if a.preview:
        out = Path(a.preview)
        out.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGBA", (3 * 216 + 16, 232), (241, 242, 237, 255))
        for i, shp in enumerate(("round", "squircle", "square")):
            sheet.paste(render(200, bg, cells, scale=1.0, shape=shp), (8 + i * 216, 16),
                        render(200, bg, cells, scale=1.0, shape=shp))
        sheet.save(out / "adaptif-crop.png")
        sm = Image.new("RGBA", (400, 100), (241, 242, 237, 255))
        for i, px in enumerate((48, 32, 24, 16)):
            im = render(px, bg, cells, scale=1.5, shape="squircle")
            sm.paste(im, (10 + i * 70, 10), im)
        sm.save(out / "kecil.png")


if __name__ == "__main__":
    main()
