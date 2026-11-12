"""Kontaktbogen: rendert SVGs (eigene + optional Fluent) als Kacheln wie in der App."""
import sys, os, io, glob
import cairosvg
from PIL import Image, ImageDraw, ImageFont
files = sys.argv[2:]
out = sys.argv[1]
S, PAD, LBL = 96, 14, 26
cols = 8
rows = (len(files) + cols - 1) // cols
W, H = cols * (S + PAD * 2), rows * (S + PAD * 2 + LBL)
img = Image.new("RGB", (W, H * 2 + 20), (250, 250, 248))
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
except Exception:
    font = ImageFont.load_default()
d = ImageDraw.Draw(img)
for half, bg, fg in ((0, (47, 125, 107), (255, 255, 255)), (1, (230, 236, 233), (30, 40, 36))):
    for i, f in enumerate(files):
        r, c = divmod(i, cols)
        x = c * (S + PAD * 2); y = half * (H + 20) + r * (S + PAD * 2 + LBL)
        d.rounded_rectangle([x + 4, y + 4, x + S + PAD * 2 - 4, y + S + PAD * 2 + LBL - 4], 16, fill=bg)
        png = cairosvg.svg2png(url=f, output_width=S, output_height=S)
        ic = Image.open(io.BytesIO(png)).convert("RGBA")
        img.paste(ic, (x + PAD, y + PAD), ic)
        name = os.path.basename(f)[:-4]
        tw = d.textlength(name, font=font)
        d.text((x + (S + PAD * 2 - tw) / 2, y + S + PAD + 4), name, fill=fg, font=font)
img.save(out)
print(out, img.size)
