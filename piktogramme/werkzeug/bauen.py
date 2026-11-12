"""Baut die Piktogramme der Einkaufsliste.

Rendert alle SVGs aus piktogramme/fluent/ (Fluent Emoji Flat, MIT) und
piktogramme/eigene/ (selbst gezeichnet) als PNG nach assets/piktos/<name>.png und
erzeugt lib/src/models/piktos.g.dart mit der Liste der vorhandenen Symbole.

Aufruf im Ordner der App:
    pip install cairosvg pillow
    python3 piktogramme/werkzeug/zeichnen.py      # eigene SVGs aus dem Code neu erzeugen (optional)
    python3 piktogramme/werkzeug/bauen.py         # PNGs + Dart-Liste
    python3 piktogramme/werkzeug/bauen.py --hole 🍉 🥝   # weitere Fluent-Emoji laden

Dateinamen: Fluent-Emoji heißen nach ihren Codepoints ohne FE0F (u1f34e = 🍎),
eigene Symbole nach dem Artikel (hafermilch). Der Name ist der Schlüssel, unter
dem App, Katalog und Widget das Symbol finden.
"""
import io, os, sys, urllib.request

import cairosvg
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
FLUENT = os.path.join(ROOT, "piktogramme", "fluent")
EIGENE = os.path.join(ROOT, "piktogramme", "eigene")
ASSETS = os.path.join(ROOT, "assets", "piktos")
DART = os.path.join(ROOT, "lib", "src", "models", "piktos.g.dart")
SIZE = 128  # px – scharf bis ~42 dp auf 3x-Displays
MIRROR = "https://raw.githubusercontent.com/shuding/fluentui-emoji-unicode/main/assets/"


def key(emoji):
    return "u" + "-".join(f"{ord(c):x}" for c in emoji if ord(c) != 0xFE0F)


def hole(emojis):
    for e in emojis:
        cps = [f"{ord(c):x}" for c in e]
        for v in dict.fromkeys(["-".join(cps), "-".join(c for c in cps if c != "fe0f"), cps[0] + "-fe0f"]):
            try:
                data = urllib.request.urlopen(MIRROR + v + "_flat.svg", timeout=30).read()
            except Exception:
                continue
            open(os.path.join(FLUENT, key(e) + ".svg"), "wb").write(data)
            print("geladen:", e, key(e))
            break
        else:
            print("nicht in Fluent Emoji:", e, "– eigenes Symbol zeichnen")


def render(svg_path, png_path):
    png = cairosvg.svg2png(url=svg_path, output_width=SIZE, output_height=SIZE)
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    # Flache Symbole kommen mit einer kleinen Palette aus: deutlich kleinere Dateien.
    q = img.quantize(colors=96, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    q.save(png_path, optimize=True)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--hole":
        hole(sys.argv[2:])
    os.makedirs(ASSETS, exist_ok=True)
    fluent = sorted(f[:-4] for f in os.listdir(FLUENT) if f.endswith(".svg"))
    eigene = sorted(f[:-4] for f in os.listdir(EIGENE) if f.endswith(".svg"))
    doppelt = set(fluent) & set(eigene)
    if doppelt:
        sys.exit(f"Name doppelt in fluent/ und eigene/: {sorted(doppelt)}")
    alle = set(fluent) | set(eigene)
    for f in os.listdir(ASSETS):
        if f.endswith(".png") and f[:-4] not in alle:
            os.remove(os.path.join(ASSETS, f))
    for name in fluent:
        render(os.path.join(FLUENT, name + ".svg"), os.path.join(ASSETS, name + ".png"))
    for name in eigene:
        render(os.path.join(EIGENE, name + ".svg"), os.path.join(ASSETS, name + ".png"))

    def lst(names):
        out, line = [], "  "
        for n in names:
            item = f"'{n}', "
            if len(line) + len(item) > 80:
                out.append(line.rstrip())
                line = "  "
            line += item
        out.append(line.rstrip())
        return "\n".join(out)

    with open(DART, "w") as f:
        f.write("// GENERIERT von piktogramme/werkzeug/bauen.py – nicht von Hand ändern.\n\n")
        f.write("/// Fluent Emoji Flat (MIT), Schlüssel = Codepoints ohne FE0F.\n")
        f.write(f"const List<String> kFluentPiktos = [\n{lst(fluent)}\n];\n\n")
        f.write("/// Selbst gezeichnete Symbole (piktogramme/eigene).\n")
        f.write(f"const List<String> kEigenePiktos = [\n{lst(eigene)}\n];\n\n")
        f.write("/// Alle mitgelieferten Symbole (`assets/piktos/<schlüssel>.png`).\n")
        f.write("final Set<String> kPiktos = {...kFluentPiktos, ...kEigenePiktos};\n")
    size = sum(os.path.getsize(os.path.join(ASSETS, f)) for f in os.listdir(ASSETS))
    print(f"{len(fluent)} Fluent + {len(eigene)} eigene Symbole, {size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
