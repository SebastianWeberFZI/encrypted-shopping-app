"""Eigene Piktogramme im Stil von Fluent Emoji Flat (32×32, flache Flächen, keine Konturen).

Jede mit @icon("name") markierte Funktion liefert den SVG-Inhalt eines Symbols.
`python3 zeichnen.py` schreibt alle Symbole als <name>.svg nach ../eigene/,
`python3 zeichnen.py lachs fisch` nur die genannten.

Stilregeln (damit eigene und Fluent-Symbole zusammenpassen):
- Zeichenfläche 32×32, Motiv füllt etwa 2…30, leicht verspielt, frontal oder schräg.
- Nur flache Flächen, keine Konturen, keine Verläufe, keine Transparenz.
- Farben aus der Fluent-Palette unten; Glanzlicht als heller, schmaler Streifen.
- Verpackungen über die Bausteine (carton, bottle, jar, tub, tube, squeeze, bag, can).
- Wo ein Fluent-Emoji fast passt, lieber umfärben (fluent(...)) als neu zeichnen.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FLUENT = os.path.join(HERE, "..", "fluent")

# --- Fluent-Palette -----------------------------------------------------------
RED, RED_D, RED_DD = "#F8312F", "#CA0B4A", "#990838"
PINK, PINK_L, SALMON, ROSE = "#FF6DC6", "#FBB8AB", "#FF8687", "#FFDEA7"
ORANGE, ORANGE_D, AMBER = "#FF822D", "#FF6723", "#FFB02E"
YELLOW, YELLOW_L, CREAM_Y = "#FCD53F", "#FFF478", "#FFE8A3"
GREEN, GREEN_D, GREEN_M, LIME, LIME_L = "#00D26A", "#008463", "#44911B", "#86D72F", "#C3EF3C"
BLUE, BLUE_D, BLUE_L, BLUE_LL, CYAN = "#00A6ED", "#0074BA", "#AEDDFF", "#D9F1FF", "#26EAFC"
PURPLE, PURPLE_D, PURPLE_L = "#8D65C5", "#533566", "#CBA6F7"
BROWN, BROWN_D, BROWN_L, TAN, TAN_L, SAND = "#8C5543", "#6D4534", "#B97028", "#D3883E", "#E19747", "#F3AD61"
BEIGE, BEIGE_L = "#F3C07B", "#FFE2B7"
WHITE, OFFWHITE, GRAY_LL, GRAY_L, GRAY, GRAY_M, GRAY_D, DARK = (
    "#FFFFFF", "#F3EEF8", "#F4F4F4", "#E1D8EC", "#D3D3D3", "#9B9B9B", "#636363", "#1C1C1C")


def svg(*els):
    body = "\n".join(e for e in els if e)
    return ('<svg width="32" height="32" viewBox="0 0 32 32" fill="none" '
            'xmlns="http://www.w3.org/2000/svg">\n' + body + "\n</svg>\n")


def n(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def rect(x, y, w, h, fill, rx=0, tf=None):
    t = f' transform="{tf}"' if tf else ""
    r = f' rx="{n(rx)}"' if rx else ""
    return f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}"{r} fill="{fill}"{t}/>'


def circ(cx, cy, r, fill):
    return f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="{fill}"/>'


def ell(cx, cy, rx, ry, fill, rot=None):
    t = f' transform="rotate({n(rot)} {n(cx)} {n(cy)})"' if rot else ""
    return f'<ellipse cx="{n(cx)}" cy="{n(cy)}" rx="{n(rx)}" ry="{n(ry)}" fill="{fill}"{t}/>'


def path(d, fill, tf=None):
    t = f' transform="{tf}"' if tf else ""
    return f'<path d="{d}" fill="{fill}"{t}/>'


def g(tf, *els):
    return f'<g transform="{tf}">\n' + "\n".join(els) + "\n</g>"


def fluent(key, recolor=None, drop=(), keep=None):
    """Elemente eines Fluent-Symbols (optional umgefärbt / ausgedünnt)."""
    s = open(os.path.join(FLUENT, key + ".svg")).read()
    els = re.findall(r"<(?:path|rect|circle|ellipse)[^>]*/>", s)
    out = []
    for i, e in enumerate(els):
        if i in drop or (keep is not None and i not in keep):
            continue
        if recolor:
            def sub(m):
                c = m.group(1).upper()
                return f'fill="{recolor.get(c, recolor.get(i, m.group(1)))}"'
            e = re.sub(r'fill="([^"]+)"', sub, e)
            if i in recolor:
                e = re.sub(r'fill="[^"]+"', f'fill="{recolor[i]}"', e)
        out.append(e)
    return out


# --- Bausteine ---------------------------------------------------------------
def carton(body, roof, band=None, small=False, extra=()):
    """Getränkekarton (Milch, Sahne, Hafermilch)."""
    if small:
        x, w, top, fin = 7.5, 17, 13, 8.5
    else:
        x, w, top, fin = 6.5, 19, 10, 3
    els = [
        rect(x + 3, fin, w - 6, 2.5, roof, rx=0.8),
        path(f"M{x} {top}L{x+3} {fin+2}H{x+w-3}L{x+w} {top}Z", roof),
        rect(x, top, w, 30 - top, body, rx=1.6),
    ]
    if band:
        els.append(rect(x, top + (30 - top) * 0.42, w, (30 - top) * 0.34, band))
    els.append(rect(x + 1.4, top + 1.6, 1.4, 30 - top - 3.6, WHITE, rx=0.7))
    return els + list(extra)


def bottle(body, cap, label=None, label_y=17, label_h=8, slim=False, extra=()):
    x0, x1 = (9.5, 22.5) if slim else (8, 24)
    els = [
        rect(13.5, 2, 5, 4, cap, rx=1),
        path(f"M14 6H18V8.5C18 10.5 {x1} 11 {x1} 14.5V27.5C{x1} 28.9 {x1-1.1} 30 {x1-2.5} 30"
             f"H{x0+2.5}C{x0+1.1} 30 {x0} 28.9 {x0} 27.5V14.5C{x0} 11 14 10.5 14 8.5Z", body),
    ]
    if label:
        els.append(rect(x0, label_y, x1 - x0, label_h, label))
    els.append(rect(x0 + 1.3, 14, 1.4, 12, WHITE, rx=0.7))
    return els + list(extra)


def jar(lid, content, glass=BLUE_LL, label=None, lid_d=None, extra=()):
    els = [
        rect(7, 9, 18, 21, glass, rx=4),
        rect(8.5, 12, 15, 16.5, content, rx=3),
        rect(8, 3, 16, 6.5, lid, rx=1.6),
    ]
    if lid_d:
        els.append(rect(8, 7.2, 16, 2.3, lid_d))
    if label:
        els.append(rect(7, 16, 18, 8, label))
    els.append(rect(9.6, 13.5, 1.6, 12, WHITE, rx=0.8))
    return els + list(extra)


def tub(body, lid, round_=True, extra=()):
    """Becher mit Deckel (Joghurt, Schmand)."""
    els = [
        path("M6 12H26L23.6 28.2C23.4 29.2 22.6 30 21.6 30H10.4C9.4 30 8.6 29.2 8.4 28.2Z", body),
        rect(4.5, 9, 23, 4, lid, rx=2),
        path("M8.6 14.5H10.3L11.8 27.5H10.3Z", WHITE),
    ]
    return els + list(extra)


def box_tub(body, lid, extra=()):
    """Eckige Schale mit Deckel (Quark, Frischkäse flach)."""
    return [
        path("M4 13H28L26.5 27.5C26.4 28.9 25.2 30 23.8 30H8.2C6.8 30 5.6 28.9 5.5 27.5Z", body),
        rect(3, 10, 26, 4.2, lid, rx=1.6),
        rect(6.5, 16, 1.4, 11, WHITE, rx=0.7),
    ] + list(extra)


def tube(body, cap, stripe=None, extra=()):
    """Tube, schräg (Zahnpasta, Tomatenmark, Senf)."""
    inner = [
        rect(13, 1.5, 6, 2.5, GRAY_M, rx=1),
        path("M12 3.5H20L22 26H10Z", body),
        rect(12.5, 26, 7, 4.5, cap, rx=1.5),
    ]
    if stripe:
        inner += [path("M12.6 10H19.4L19.7 13.5H12.3Z", stripe), path("M12.1 16H19.9L20.2 19.5H11.8Z", stripe)]
    inner.append(path("M13.4 5H14.6L13.6 24.5H12.2Z", WHITE))
    return [g("rotate(40 16 16)", *(inner + list(extra)))]


def squeeze(body, cap, nozzle=None, extra=()):
    """Quetschflasche (Ketchup, Mayo, Senf, Spülmittel)."""
    return [
        path("M14 2.5H18L19 7H13Z", nozzle or cap),
        rect(10.5, 6, 11, 4, cap, rx=1.5),
        path("M10 10H22C23.5 10 24 11 24 12.5V27C24 28.7 22.7 30 21 30H11C9.3 30 8 28.7 8 27V12.5C8 11 8.5 10 10 10Z", body),
        rect(9.6, 12.5, 1.6, 14, WHITE, rx=0.8),
    ] + list(extra)


def bag(body, top, label=None, extra=()):
    """Tüte/Sack (Mehl, Chips, Erde)."""
    els = [
        path("M7 7H25L26.5 27.5C26.6 28.9 25.5 30 24.1 30H7.9C6.5 30 5.4 28.9 5.5 27.5Z", body),
        path("M7 3.5L9 5.5L11 3.5L13 5.5L15 3.5L17 5.5L19 3.5L21 5.5L23 3.5L25 5.5V8.5H7V5.5Z", top),
    ]
    if label:
        els.append(rect(8.5, 13, 15, 12, label, rx=2))
    els.append(rect(7.3, 10, 1.4, 16, WHITE, rx=0.7))
    return els + list(extra)


def can(body, top=GRAY, label=None, short=False, extra=()):
    y0 = 13 if short else 4
    els = [
        rect(7, y0 + 1.5, 18, 30 - y0 - 3, body, rx=1),
        rect(6, y0, 20, 3, top, rx=1.5),
        rect(6, 27.5, 20, 3, top, rx=1.5),
    ]
    if label:
        els.append(rect(7, y0 + (30 - y0) * 0.3, 18, (30 - y0) * 0.42, label))
    els.append(rect(8.5, y0 + 3.5, 1.5, 30 - y0 - 7, WHITE, rx=0.75))
    return els + list(extra)


def box(body, side, top, extra=()):
    return [
        path("M5 10L11 6H28L22 10Z", top),
        path("M22 10L28 6V25L22 29Z", side),
        rect(4, 10, 18, 19, body, rx=1),
    ] + list(extra)


def fish_mark(cx, cy, s, fill):
    return path(f"M{cx-s} {cy}C{cx-s*0.4} {cy-s*0.75} {cx+s*0.5} {cy-s*0.6} {cx+s*0.75} {cy}"
                f"L{cx+s*1.3} {cy-s*0.55}V{cy+s*0.55}L{cx+s*0.75} {cy}"
                f"C{cx+s*0.5} {cy+s*0.6} {cx-s*0.4} {cy+s*0.75} {cx-s} {cy}Z", fill)


def leaf(cx, cy, l, w, rot, fill, vein=None):
    els = [ell(cx, cy, l, w, fill, rot)]
    if vein:
        els.append(ell(cx, cy, l * 0.85, w * 0.12, vein, rot))
    return els


def drop(cx, cy, s, fill):
    return path(f"M{cx} {cy-s}C{cx} {cy-s} {cx-s*0.75} {cy-s*0.05} {cx-s*0.75} {cy+s*0.35}"
                f"C{cx-s*0.75} {cy+s*0.8} {cx-s*0.4} {cy+s*1.1} {cx} {cy+s*1.1}"
                f"C{cx+s*0.4} {cy+s*1.1} {cx+s*0.75} {cy+s*0.8} {cx+s*0.75} {cy+s*0.35}"
                f"C{cx+s*0.75} {cy-s*0.05} {cx} {cy-s} {cx} {cy-s}Z", fill)


def snowflake(cx, cy, s, fill):
    els = []
    for a in (0, 60, 120):
        els.append(rect(cx - s, cy - s * 0.12, 2 * s, s * 0.24, fill, rx=s * 0.12, tf=f"rotate({a} {n(cx)} {n(cy)})"))
    return els


ICONS = {}


def icon(name):
    def deco(f):
        ICONS[name] = f
        return f
    return deco


# === Obst & Gemüse ===========================================================
@icon("mandarinen")
def _():
    return svg(circ(11.5, 19.5, 8.5, ORANGE), circ(9, 16.5, 1.6, AMBER),
               circ(21.5, 13.5, 7.5, ORANGE_D), circ(19.3, 11, 1.4, AMBER),
               *leaf(23.5, 5.6, 3.4, 1.6, -30, GREEN), circ(21.6, 6.6, 1, GREEN_D))


@icon("limetten")
def _():
    return svg(*fluent("u1f34b", {"#FCD53F": LIME, "#86D72F": GREEN_D}))



@icon("rote-zwiebeln")
def _():
    return svg(*fluent("u1f9c5", {"#D3883E": "#7D2A5E", "#E19747": "#A63D78", "#F3AD61": "#C9659A"}))



@icon("blumenkohl")
def _():
    florets = [(10, 12, 5.2), (16, 9, 5.6), (22, 12, 5.2), (8.5, 17.5, 4.6), (16, 15, 6), (23.5, 17.5, 4.6), (12.5, 19, 4.8), (19.5, 19, 4.8)]
    els = [ell(16, 22.5, 13.5, 7.5, GREEN_M), path("M3 20C6 26 11 29.5 16 29.5C21 29.5 26 26 29 20C26 22 21 23 16 23C11 23 6 22 3 20Z", GREEN)]
    els += [circ(x, y, r, "#F1E3BF") for x, y, r in florets]
    els += [circ(x - r * 0.35, y - r * 0.35, r * 0.38, "#FFF6DD") for x, y, r in florets]
    return svg(*els)


@icon("zucchini")
def _():
    return svg(*fluent("u1f952", {"#44911B": "#1F6B3A", "#86D72F": "#6DBE45"}),
               rect(26.2, 2.4, 3.6, 3.4, "#B5A16A", rx=1.2, tf="rotate(45 28 4.1)"))




@icon("champignons")
def _():
    cap, gill, stem = "#E9DCC9", "#C9B497", "#F7F1E8"
    return svg(rect(18.8, 17, 5.5, 11, stem, rx=2.5), path("M12 19.5C12 14.5 16.5 11 21.5 11C26.5 11 31 14.5 31 19.5Z", cap),
               rect(12, 18.6, 19, 2.3, gill, rx=1.1), ell(18.5, 14, 2.4, 1.2, WHITE, -20),
               rect(7.3, 16, 6.5, 13, stem, rx=3), path("M1 18.5C1 12 5.5 7.5 10.5 7.5C15.5 7.5 20 12 20 18.5Z", cap),
               rect(1, 17.6, 19, 2.6, gill, rx=1.3), ell(6.5, 11.5, 2.6, 1.3, WHITE, -30))


@icon("erbsen")
def _():
    return svg(path("M3 22C6 13 14 7 25 5C27.5 4.6 29.3 6.5 28.6 9C25.8 18 18 25 7.5 26.5C4.6 27 2.3 24.8 3 22Z", GREEN_M),
               path("M5.5 22C8.5 15 15 10.5 24.5 8.3C22 16 16 21.5 7.5 23.6C6 24 5 23.2 5.5 22Z", LIME),
               circ(9, 20.5, 2.6, GREEN), circ(13.4, 17, 2.7, GREEN), circ(17.8, 13.8, 2.7, GREEN), circ(22, 10.8, 2.5, GREEN),
               circ(8.3, 19.7, 0.8, LIME_L), circ(12.7, 16.2, 0.8, LIME_L), circ(17.1, 13, 0.8, LIME_L), circ(21.3, 10, 0.8, LIME_L),
               path("M26 6C27.5 4 28.5 2.6 30 2", GREEN_D), rect(26.2, 2.2, 1.4, 5, GREEN_D, rx=0.7, tf="rotate(40 27 4.7)"))


@icon("kuerbis")
def _():
    o, od, ol = "#FF822D", "#E5631A", "#FFA25F"
    return svg(rect(14.6, 3, 3, 7, GREEN_M, rx=1.2, tf="rotate(12 16 6.5)"),
               ell(9.5, 19, 7, 10, od), ell(22.5, 19, 7, 10, od), ell(16, 19, 7.5, 10.8, o),
               ell(11.8, 19, 4, 9.6, o), ell(20.2, 19, 4, 9.6, o),
               rect(13.4, 10.5, 1.2, 17, od, rx=0.6), rect(17.4, 10.5, 1.2, 17, od, rx=0.6),
               ell(8.5, 16, 1.4, 3.6, ol), ell(15, 13.5, 1.2, 2.6, ol),
               *leaf(21.5, 6.5, 3.6, 1.8, -20, GREEN))


@icon("spargel")
def _():
    def spear(x, rot, c, tip):
        return g(f"rotate({rot} {x} 30)",
                 rect(x - 1.7, 6, 3.4, 24, c, rx=1.7),
                 path(f"M{x-1.7} 8C{x-1.7} 4 {x} 2 {x} 2C{x} 2 {x+1.7} 4 {x+1.7} 8Z", tip),
                 path(f"M{x-1.7} 14L{x} 12.5L{x+1.7} 14Z", tip), path(f"M{x-1.7} 20L{x} 18.5L{x+1.7} 20Z", tip))
    return svg(spear(12, -14, LIME, GREEN_M), spear(16, -4, "#9BD46A", GREEN_M), spear(20, 6, LIME, GREEN_M), spear(23, 15, "#9BD46A", GREEN_M),
               rect(8, 21, 17, 3.6, "#C24C3E", rx=1.2))



@icon("lauch")
def _():
    return svg(g("rotate(35 16 16)",
                 rect(13, 13, 6, 18, OFFWHITE, rx=3),
                 rect(13, 11, 6, 6, "#D6EBB4"),
                 path("M13 12C11 7 9 3 7.5 0.5L10.5 1C12.5 4 14 8 15 12Z", GREEN_M),
                 path("M19 12C21 7 23 3 24.5 0.5L21.5 1C19.5 4 18 8 17 12Z", GREEN_M),
                 path("M14.5 12C14.5 7 15 3 16 -0.5C17 3 17.5 7 17.5 12Z", GREEN_D),
                 rect(14, 15, 1.2, 13, WHITE, rx=0.6),
                 path("M14 30.2C15 31.2 17 31.2 18 30.2L17 31.8H15Z", "#C9B497")))


@icon("basilikum")
def _():
    lf, lv = GREEN, GREEN_M
    return svg(rect(15.2, 10, 1.6, 20, GREEN_M, rx=0.8),
               *leaf(9.5, 20.5, 6.6, 4.2, 28, lf, lv), *leaf(22.5, 20.5, 6.6, 4.2, -28, lf, lv),
               *leaf(10.5, 11.5, 5.6, 3.6, 38, lf, lv), *leaf(21.5, 11.5, 5.6, 3.6, -38, lf, lv),
               ell(16, 5.5, 3, 4.2, LIME), ell(16, 5.8, 0.4, 3.2, GREEN))


@icon("radieschen")
def _():
    r, rl = "#E03C6B", "#FF7A9C"
    return svg(*leaf(10, 7, 6, 2.6, -55, GREEN, GREEN_M), *leaf(18.5, 6, 6, 2.6, 60, GREEN, GREEN_M), *leaf(14, 5.5, 5, 2.3, 5, GREEN_M),
               rect(13.3, 9, 1.6, 6, GREEN_M, rx=0.8, tf="rotate(-20 14 12)"), rect(16.6, 9, 1.6, 6, GREEN_M, rx=0.8, tf="rotate(20 17 12)"),
               circ(11, 19, 6.3, r), path("M9.5 24.5L11 30.5L12.5 24.5Z", "#F2D0D9"), circ(8.8, 16.6, 1.6, rl),
               circ(21.5, 20.5, 5.8, r), path("M20.2 25.6L21.5 31L22.8 25.6Z", "#F2D0D9"), circ(19.5, 18.3, 1.5, rl),
               ell(11, 23.6, 4.5, 1.4, "#F7E6EB"), ell(21.5, 24.8, 4, 1.3, "#F7E6EB"))


# === Brot & Gebäck ============================================================
@icon("brot")
def _():
    c, d, l = "#C97C3A", "#9E5A25", "#E5A35E"
    return svg(path("M2.5 20C2.5 12 8.5 7 16 7C23.5 7 29.5 12 29.5 20C29.5 25 26.5 27.5 22 27.5H10C5.5 27.5 2.5 25 2.5 20Z", c),
               path("M2.5 21C3.5 25.5 6 27.5 10 27.5H22C26 27.5 28.5 25.5 29.5 21C27 23 22 24 16 24C10 24 5 23 2.5 21Z", d),
               ell(9.5, 14.5, 3.4, 1.2, d, -35), ell(16, 12.8, 3.4, 1.2, d, -35), ell(22.5, 14.5, 3.4, 1.2, d, -35),
               ell(9, 11.5, 2.4, 0.9, l, -20), ell(23.5, 11, 1.4, 0.7, l, 20))



@icon("knaeckebrot")
def _():
    c, d = "#E8B96F", "#B98A45"
    dots = [circ(x, y, 0.75, d) for x in (8, 12, 16, 20, 24) for y in (11, 15, 19, 23)]
    return svg(g("rotate(-12 16 16)",
                 rect(3.5, 6.5, 25, 20, "#D29C52", rx=2), rect(3.5, 5.5, 25, 20, c, rx=2), *dots,
                 rect(5, 7, 1.2, 17, "#F5D59C", rx=0.6)))


@icon("broetchen")
def _():
    c, d, l = "#E0A055", "#B8732F", "#F3C584"
    return svg(ell(16, 18.5, 14, 9.5, d), ell(16, 17.5, 14, 9, c),
               path("M5.5 17C9 14.2 13 13.3 16 13.3C19 13.3 23 14.2 26.5 17C23 16.2 19.5 15.9 16 15.9C12.5 15.9 9 16.2 5.5 17Z", d),
               path("M7 16.3C10 14.5 13 14 16 14C19 14 22 14.5 25 16.3C22 15.6 19 15.3 16 15.3C13 15.3 10 15.6 7 16.3Z", "#F7D7A6"),
               ell(9.5, 12.5, 3, 1.3, l, -15), ell(22, 21.5, 2.5, 1, l, -10))


@icon("cherrytomaten")
def _():
    return svg(rect(6, 4.9, 20, 1.6, GREEN_D, rx=0.8),
               rect(9.2, 5.5, 1.4, 6, GREEN_D, rx=0.7), rect(15.6, 3.6, 1.4, 6, GREEN_D, rx=0.7), rect(21.8, 5.5, 1.4, 5, GREEN_D, rx=0.7),
               circ(10, 16, 6, RED), circ(22.3, 14.5, 5.6, RED), circ(16.2, 23.8, 6.2, RED_D), circ(16.2, 23.8, 5.6, RED),
               circ(7.8, 14, 1.3, SALMON), circ(20.4, 12.5, 1.2, SALMON), circ(13.9, 21.6, 1.3, SALMON),
               path("M10 10.5L7.6 9.2H12.4Z", GREEN), path("M22.3 9.4L20 8.2H24.6Z", GREEN), path("M16.2 18L13.8 16.6H18.6Z", GREEN))


@icon("himbeeren")
def _():
    base, dr, hl = "#B5174A", "#E52E62", "#FF8FB1"
    pts = [(12.8, 11.5), (16.4, 10.6), (20, 11.8), (10.6, 15.2), (14.4, 14.8), (18.2, 14.8), (21.8, 15.4),
           (10.8, 19.2), (14.6, 18.8), (18.4, 18.8), (22, 19.3), (12.6, 23), (16.4, 22.8), (20.2, 23), (16.4, 26.4)]
    els = [path("M16.4 8.5C11 8.5 8.4 12.5 8.4 17C8.4 23 12 28.8 16.4 28.8C20.8 28.8 24.4 23 24.4 17C24.4 12.5 21.8 8.5 16.4 8.5Z", base)]
    for x, y in pts:
        els += [circ(x, y, 2.3, dr), circ(x - 0.75, y - 0.75, 0.75, hl)]
    els += [path("M16.4 10.5L10.5 8.2L13.6 7.6L12.6 4.6L15.4 6.6L16.4 3.4L17.4 6.6L20.2 4.6L19.2 7.6L22.3 8.2Z", GREEN_D)]
    return svg(*els)




@icon("fruehlingszwiebeln")
def _():
    def stalk(x, rot):
        return g(f"rotate({rot} {x} 29)",
                 path(f"M{x-1.8} 3.5C{x-1.8} 2.5 {x+1.8} 2.5 {x+1.8} 3.5V18H{x-1.8}Z", GREEN),
                 rect(x - 0.45, 4.5, 0.9, 12, LIME, rx=0.45),
                 rect(x - 1.8, 17, 3.6, 3.5, "#CFE8A8"),
                 path(f"M{x-1.8} 20H{x+1.8}C{x+1.8} 22 {x+3.2} 23.5 {x+3.2} 25.5C{x+3.2} 27.5 {x+1.8} 28.5 {x} 28.5C{x-1.8} 28.5 {x-3.2} 27.5 {x-3.2} 25.5C{x-3.2} 23.5 {x-1.8} 22 {x-1.8} 20Z", OFFWHITE),
                 path(f"M{x-1.2} 28.3L{x-1.8} 30.5M{x} 28.5V30.8M{x+1.2} 28.3L{x+1.8} 30.5", GRAY_M),
                 rect(x - 1.25, 28.2, 0.5, 2.3, "#C9B497"), rect(x - 0.25, 28.4, 0.5, 2.4, "#C9B497"), rect(x + 0.75, 28.2, 0.5, 2.3, "#C9B497"))
    return svg(stalk(10, -14), stalk(22, 14), stalk(16, 0), rect(10.5, 20.5, 11, 2.6, BLUE, rx=1))


@icon("rucola")
def _():
    def lf(rot, c):
        e = [rect(15.4, 8, 1.2, 22, LIME, rx=0.6)]
        for i, y in enumerate((9.5, 13.5, 17.5, 21.5)):
            w = 3.6 - i * 0.35
            e += [ell(15.8 - w, y, w, 1.7, c, -35), ell(16.2 + w, y, w, 1.7, c, 35)]
        e.append(ell(16, 6.2, 2.2, 3.4, c))
        return g(f"rotate({rot} 16 29)", *e)
    return svg(lf(-30, GREEN_M), lf(30, GREEN_M), lf(0, "#5BAE2A"))


@icon("spinat")
def _():
    def sp(rot, col, vein):
        return g(f"rotate({rot} 16 29) translate(16 29) scale(0.92) translate(-16 -29)",
                 rect(15.3, 18, 1.4, 11, LIME, rx=0.7),
                 path("M16 3C10.5 6 8.3 11 9.3 15.5C10.2 19.3 13.3 21.5 16 21.5C18.7 21.5 21.8 19.3 22.7 15.5C23.7 11 21.5 6 16 3Z", col),
                 rect(15.4, 5, 1.2, 16, vein, rx=0.6))
    return svg(sp(-30, GREEN_D, GREEN), sp(30, GREEN_D, GREEN), sp(0, "#00A65A", LIME))


# === Milch, Käse & Eier ======================================================
@icon("milch")
def _():
    return svg(*carton(WHITE, BLUE, band=BLUE_L, extra=[drop(16, 18.5, 3.6, BLUE)]))


@icon("hafermilch")
def _():
    oat = "#C98F45"
    return svg(*carton("#F6E7CF", "#B97028", band="#EAD0A6", extra=[
        rect(15.4, 15, 1.2, 10, oat, rx=0.6),
        *leaf(14, 16.5, 1.9, 1, 40, oat), *leaf(18, 16.5, 1.9, 1, -40, oat),
        *leaf(14, 19.5, 1.9, 1, 40, oat), *leaf(18, 19.5, 1.9, 1, -40, oat),
        ell(16, 13.6, 1, 1.8, oat)]))


@icon("sahne")
def _():
    return svg(*carton(WHITE, YELLOW, band=CREAM_Y, small=True, extra=[
        ell(16, 23.5, 4.2, 2.4, WHITE), ell(14.2, 22, 2.4, 1.8, WHITE), ell(17.8, 22, 2.4, 1.8, WHITE), ell(16, 20.6, 1.8, 1.6, WHITE)]))


@icon("joghurt")
def _():
    return svg(*tub(WHITE, PINK_L, extra=[ell(16, 20.5, 5.3, 4.3, PINK_L), circ(14.4, 19.8, 1.6, RED), circ(17.6, 21.2, 1.6, RED),
                                        *leaf(17, 17.2, 1.7, 0.8, -30, GREEN)]))


@icon("quark")
def _():
    return svg(*box_tub(WHITE, BLUE, extra=[rect(10, 18.5, 12, 6, BLUE_L, rx=1.5), rect(12, 20.6, 8, 1.8, BLUE, rx=0.9)]))


@icon("schmand")
def _():
    return svg(*tub("#F6F0E4", GREEN, extra=[rect(9.6, 18.5, 12.8, 6, GREEN, rx=1.4), rect(11.6, 20.6, 8.8, 1.8, WHITE, rx=0.9)]))


@icon("frischkaese")
def _():
    return svg(path("M4 15H28V25.5C28 27.4 26.4 29 24.5 29H7.5C5.6 29 4 27.4 4 25.5Z", WHITE),
               ell(16, 15, 12, 4.6, "#DDEBF5"), ell(16, 14, 12.6, 4.8, BLUE_L), ell(16, 13.5, 9.5, 3, BLUE_LL),
               rect(10.5, 20, 11, 4.6, BLUE_L, rx=1.4), rect(6, 18, 1.4, 8, BLUE_LL, rx=0.7))


@icon("mozzarella")
def _():
    return svg(ell(16, 27, 12, 2.6, "#DCE6EE"), circ(11, 18.5, 8, WHITE), circ(22, 20, 6.8, "#F2F4F7"),
               circ(8.5, 15.5, 2, "#FFFFFF"), ell(11, 23.5, 5, 1.4, "#E8EEF4"), ell(22, 24.6, 4.4, 1.2, "#E2E9F0"),
               *leaf(20, 9, 3.6, 2, -30, GREEN, GREEN_M), *leaf(25, 9.8, 3, 1.7, 25, GREEN_M))



@icon("feta")
def _():
    return svg(path("M4 12L10 7H28L22 12Z", "#F7F9FB"), path("M22 12L28 7V22L22 27Z", "#DCE3EA"),
               rect(4, 12, 18, 15, WHITE, rx=0.6),
               circ(8, 16.5, 0.9, "#E3E9EF"), circ(13, 21, 0.8, "#E3E9EF"), circ(17.5, 15.5, 0.9, "#E3E9EF"), circ(9.5, 23.5, 0.7, "#E3E9EF"),
               circ(25, 28, 1.4, WHITE), circ(28.5, 26.5, 1, "#F2F4F7"), circ(6, 29, 1, WHITE))


# === Fleisch, Fisch & Tofu ===================================================
@icon("hackfleisch")
def _():
    m, md, ml = "#E0566B", "#B8344B", "#F28A99"
    blobs = [circ(x, y, 2.2, ml if (i % 3 == 0) else md) for i, (x, y) in enumerate(
        [(9, 15), (13, 13.5), (17.5, 13.5), (22, 15), (11, 18.5), (15.5, 17.5), (20, 18.5), (24, 19), (8.5, 20.5), (13.5, 21.5), (18, 21.5)])]
    return svg(path("M2 15H30L28 27C27.8 28.2 26.8 29 25.6 29H6.4C5.2 29 4.2 28.2 4 27Z", GRAY_L),
               rect(1.5, 14, 29, 3, "#C7BBD6", rx=1.5),
               path("M6 20C6 13 10 10 16 10C22 10 26 13 26 20C26 23 22 24 16 24C10 24 6 23 6 20Z", m), *blobs)


@icon("wuerstchen")
def _():
    s, sd, sl = "#D9644A", "#B04A34", "#F09577"
    def w(dy, rot):
        return g(f"rotate({rot} 16 16) translate(0 {dy})",
                 rect(3, 12, 26, 7, sd, rx=3.5), rect(3, 11.2, 26, 6.6, s, rx=3.3),
                 rect(6, 12.5, 14, 1.5, sl, rx=0.75), circ(2.6, 14.7, 1, sd), circ(29.4, 14.7, 1, sd))
    return svg(w(-4, -18), w(5.5, -18))


@icon("aufschnitt")
def _():
    def sl(cx, cy, r):
        return [circ(cx, cy, r, "#8E2236"), circ(cx, cy, r - 1.1, "#C8364F"),
                circ(cx - r * 0.4, cy - r * 0.3, 0.9, "#F7D9DE"), circ(cx + r * 0.35, cy - r * 0.15, 0.8, "#F7D9DE"),
                circ(cx - r * 0.1, cy + r * 0.4, 0.9, "#F7D9DE"), circ(cx + r * 0.45, cy + r * 0.45, 0.7, "#F7D9DE"),
                circ(cx - r * 0.55, cy + r * 0.25, 0.6, "#F7D9DE")]
    return svg(*sl(10.5, 11.5, 8), *sl(21, 15, 8), *sl(13, 22.5, 8))


@icon("schinken")
def _():
    return svg(path("M4 13C4 8 9 5 15 5C22 5 28 9 28 16C28 23 22 27 15 27C9 27 4 24 4 19Z", "#F7E3D8"),
               path("M6.5 14C6.5 10 10.5 7.6 15 7.6C20.5 7.6 25.3 10.8 25.3 16C25.3 21.2 20.5 24.4 15 24.4C10.5 24.4 6.5 22 6.5 18Z", "#F08A96"),
               path("M9 15C10.5 12 14 11 17 12.5", "#F7B8BF"), ell(13, 13, 3.5, 1.2, "#F7B8BF", -20), ell(19.5, 19, 2.6, 1, "#E06F7D", -10),
               path("M14 27.5C18 31 23 29.5 26.5 26C24 27.2 20 28.4 14 27.5Z", "#E9CBBE"))


@icon("lachs")
def _():
    o, od, ol, w = "#FF8A5B", "#E8643A", "#FFB08F", "#FFE3D6"
    return svg(path("M3 19C3 12 9 8 17 8C24 8 29 11 29 16C29 21 24 24.5 17 24.5C9 24.5 3 24 3 19Z", od),
               path("M3 18C3 12 9 8.5 17 8.5C23.5 8.5 28.5 11.5 28.5 15.5C28.5 19.5 24 22.5 17 22.5C9 22.5 3 22.5 3 18Z", o),
               rect(8.6, 10.5, 1.1, 11, w, rx=0.55, tf="rotate(8 9 16)"),
               rect(13.3, 9, 1.1, 13.5, w, rx=0.55, tf="rotate(10 14 16)"), rect(18.1, 9, 1.1, 13.5, w, rx=0.55, tf="rotate(12 18.6 16)"),
               rect(22.8, 10, 1.1, 11.5, w, rx=0.55, tf="rotate(14 23.4 16)"),
               ell(12, 12, 3, 1, ol, -10), path("M3 19C3 22.5 8 24.5 17 24.5C24 24.5 29 21 29 16C29 21 24 26 17 26C9 26 3 24 3 19Z", "#9AA7B5"))


@icon("tofu")
def _():
    t, ts, tt = "#FFF8E6", "#EDE1C3", "#FFFDF5"
    def cube(x, y, s):
        return [path(f"M{x} {y}L{x+s*0.45} {y-s*0.32}H{x+s*1.45}L{x+s} {y}Z", tt),
                path(f"M{x+s} {y}L{x+s*1.45} {y-s*0.32}V{y+s*0.68}L{x+s} {y+s}Z", ts),
                rect(x, y, s, s, t, rx=0.4)]
    return svg(*cube(3, 16, 11), *cube(15, 18, 10), *cube(8.5, 7, 9.5))


@icon("thunfisch")
def _():
    return svg(*can(BLUE_D, short=True, label=BLUE, extra=[fish_mark(15, 21.8, 4.6, "#FF9E8A")]))


# === Vorrat ==================================================================
@icon("nudeln")
def _():
    y, yd, yl = "#F9C23C", "#E19747", "#FFE08A"
    def penne(cx, cy, rot):
        return g(f"rotate({rot} {cx} {cy})",
                 path(f"M{cx-6} {cy-2.6}H{cx+4}L{cx+6} {cy+2.6}H{cx-4}Z", y),
                 path(f"M{cx+4} {cy-2.6}L{cx+6} {cy+2.6}L{cx+5} {cy+2.6}L{cx+3.1} {cy-2.6}Z", yd),
                 rect(cx - 4, cy - 1.6, 7, 0.7, yd, rx=0.35), rect(cx - 3.6, cy + 0.3, 7, 0.7, yd, rx=0.35),
                 rect(cx - 5, cy - 2.2, 4, 0.6, yl, rx=0.3))
    return svg(penne(11, 10, -35), penne(21, 13, 20), penne(12, 21, 15), penne(21, 24, -40))


@icon("couscous")
def _():
    return svg(*fluent("u1f35a", {"#F4F4F4": "#F9D671", "#BEBEBE": "#E19747"}))


@icon("linsen")
def _():
    pts = [(8, 22), (12, 21), (16, 21.5), (20, 21), (24, 22), (10, 18), (14, 17.5), (18, 17.5), (22, 18.5),
           (12, 14.5), (16, 13.8), (20, 15), (14, 11), (18, 11.2), (16, 25), (11, 25), (21, 25), (6, 25.5), (26, 25.5)]
    return svg(path("M2 28C4 18 10 9 16 9C22 9 28 18 30 28Z", "#D2643A"),
               *[ell(x, y, 2.1, 1.5, "#E8834F" if i % 2 else "#C9552D", (i * 37) % 60 - 30) for i, (x, y) in enumerate(pts)],
               *[circ(x - 0.6, y - 0.4, 0.5, "#F6B48A") for x, y in pts[::3]],
               rect(2, 27.5, 28, 2.5, "#B9481F", rx=1.2))


@icon("kichererbsen")
def _():
    c, d, l = "#E9C27D", "#C99A52", "#F8E1B0"
    pts = [(7.5, 24), (13, 24.5), (19, 24.5), (24.5, 24), (10, 19), (16, 19), (22, 19), (13, 14), (19, 14), (16, 9.5)]
    els = []
    for x, y in pts:
        els += [circ(x, y, 3.3, d), circ(x - 0.2, y - 0.3, 3, c), circ(x - 1.2, y - 1.3, 0.9, l), ell(x + 0.8, y - 2.2, 0.5, 0.9, d, 30)]
    return svg(*els)


@icon("haferflocken")
def _():
    flakes = [ell(x, y, 1.9, 1.3, "#F3D9A4", r) for x, y, r in ((12, 18, -20), (16.5, 17, 15), (20.5, 18.5, -35), (13.5, 21.5, 30), (18, 21.8, -10), (15.5, 24.5, 20))]
    return svg(*bag("#F6E7CF", "#C98F45", label="#E7C48F", extra=flakes))


# === Zutaten & Gewürze =======================================================
@icon("mehl")
def _():
    w = "#D9A441"
    return svg(*bag(WHITE, "#E8E1D3", label="#F4EBD6", extra=[
        rect(15.4, 15, 1.2, 9, w, rx=0.6), *leaf(14, 16.4, 1.8, 0.9, 40, w), *leaf(18, 16.4, 1.8, 0.9, -40, w),
        *leaf(14, 19, 1.8, 0.9, 40, w), *leaf(18, 19, 1.8, 0.9, -40, w), ell(16, 14, 0.9, 1.7, w)]))


@icon("zucker")
def _():
    def cube(x, y, s):
        return [path(f"M{x} {y}L{x+s*0.5} {y-s*0.35}H{x+s*1.5}L{x+s} {y}Z", WHITE),
                path(f"M{x+s} {y}L{x+s*1.5} {y-s*0.35}V{y+s*0.65}L{x+s} {y+s}Z", "#D9DEE6"),
                rect(x, y, s, s, "#F0F2F6", rx=0.4), circ(x + s * 0.3, y + s * 0.35, 0.5, "#D9DEE6"), circ(x + s * 0.7, y + s * 0.7, 0.45, "#D9DEE6")]
    return svg(*cube(3, 18, 10), *cube(14.5, 18, 10), *cube(9, 8, 10))


@icon("pfeffer")
def _():
    return svg(*fluent("u1f9c2", {"#F4F4F4": "#4A4A4A", 0: "#AEDDFF"}),
               circ(13.5, 21, 0.8, "#1C1C1C"), circ(17, 23, 0.8, "#1C1C1C"), circ(18.5, 20, 0.7, "#1C1C1C"), circ(14.5, 25, 0.7, "#1C1C1C"))


@icon("olivenoel")
def _():
    return svg(*bottle("#B9C94A", GREEN_D, label="#F6EFD5", slim=True, extra=[
        ell(16, 21, 2.2, 2.8, GREEN_M, -20), *leaf(18.3, 18.6, 1.9, 0.8, -40, GREEN_D)]))


@icon("speiseoel")
def _():
    return svg(*bottle("#F9C23C", AMBER, label=WHITE, slim=True, extra=[
        circ(16, 21, 2.6, YELLOW), *[rect(15.6, 16.6, 0.8, 1.6, AMBER, rx=0.4, tf=f"rotate({a} 16 21)") for a in range(0, 360, 45)]]))


@icon("essig")
def _():
    return svg(*bottle("#7A1F2B", DARK, label="#F3E3C3", slim=True, extra=[rect(13, 20, 6, 1.4, "#7A1F2B", rx=0.7)]))


@icon("hefe")
def _():
    return svg(path("M4 13L9 9H27L22 13Z", "#F7E7A9"), path("M22 13L27 9V24L22 28Z", "#D9B64A"),
               rect(4, 13, 18, 15, "#EDCF6A", rx=0.8),
               path("M4 13L9 9H13L8 13Z", "#D3D3D3"), path("M4 13H8V28H5C4.4 28 4 27.6 4 27Z", "#E4E4E4"),
               rect(10, 17, 9, 1.2, "#D9B64A", rx=0.6), rect(10, 20, 6.5, 1.2, "#D9B64A", rx=0.6))


@icon("backpulver")
def _():
    return svg(g("rotate(-10 16 16)",
                 rect(6, 4, 20, 24, WHITE, rx=1.2), rect(6, 4, 20, 3, "#E4E4E4"),
                 rect(6, 10, 20, 6, RED), rect(9, 19, 14, 1.5, "#D3D3D3", rx=0.75), rect(9, 22.5, 10, 1.5, "#D3D3D3", rx=0.75),
                 circ(16, 13, 1.6, WHITE)))


@icon("senf")
def _():
    return svg(*squeeze(YELLOW, "#E5A100", extra=[rect(11, 17, 10, 7, "#E5A100", rx=1.5), rect(13, 19.4, 6, 2.2, YELLOW, rx=1.1)]))


@icon("ketchup")
def _():
    return svg(*squeeze(RED, RED_DD, extra=[rect(11, 16.5, 10, 8, WHITE, rx=1.5), circ(16, 20.5, 2.6, RED), path("M16 17.6L14.8 16.6H17.2Z", GREEN)]))


@icon("mayonnaise")
def _():
    return svg(*squeeze("#FFF6D5", BLUE, extra=[rect(11, 16.5, 10, 8, BLUE_L, rx=1.5), ell(16, 20.5, 2.4, 2.9, WHITE), ell(16, 21.3, 1.2, 1.4, YELLOW)]))


@icon("tomatenmark")
def _():
    return svg(*tube(RED, WHITE, stripe=WHITE, extra=[circ(16, 21.5, 2.2, RED_DD)]))


@icon("sojasauce")
def _():
    return svg(rect(12, 2, 8, 3.5, RED, rx=1), path("M13 5.5H19L19.5 8.5H12.5Z", RED_D),
               path("M12.5 8.5H19.5C22 11 24 13.5 24 17V27.5C24 28.9 22.9 30 21.5 30H10.5C9.1 30 8 28.9 8 27.5V17C8 13.5 10 11 12.5 8.5Z", "#3B2416"),
               rect(8, 17.5, 16, 7.5, WHITE), rect(11, 19.6, 10, 3.2, RED, rx=1.6), rect(9.6, 12, 1.4, 4.5, "#6D4534", rx=0.7))


@icon("gewuerze")
def _():
    def jar_(x, cont, lid):
        return [rect(x, 12, 9.5, 17.5, BLUE_LL, rx=2), rect(x + 1, 16, 7.5, 12.5, cont, rx=1.5),
                rect(x - 0.3, 7.5, 10.1, 5, lid, rx=1.2), rect(x + 1.2, 17, 1, 9, WHITE, rx=0.5)]
    return svg(*jar_(4, "#D9432B", DARK), *jar_(18.5, "#E5A100", GRAY_D), *jar_(11.2, "#6B8E23", "#4A4A4A"))


# === Frühstück ===============================================================
@icon("marmelade")
def _():
    return svg(*jar(RED, "#C8102E", lid_d=RED_DD, extra=[
        rect(8, 3, 4, 3.2, WHITE), rect(16, 3, 4, 3.2, WHITE), rect(12, 6.2, 4, 3, WHITE), rect(20, 6.2, 4, 3, WHITE),
        rect(9.5, 17, 13, 7, WHITE, rx=1.5), circ(16, 20.5, 2.2, RED), path("M16 18.6L14.9 17.6H17.1Z", GREEN)]))


@icon("nussnougatcreme")
def _():
    return svg(*jar(WHITE, "#5A3420", lid_d="#E6E6E6", extra=[rect(9.5, 17, 13, 7, WHITE, rx=1.5),
                                                            ell(14.5, 20.5, 2, 1.5, "#8C5543"), ell(18, 20.5, 2, 1.5, "#5A3420")]))


@icon("erdnussbutter")
def _():
    return svg(*jar(RED, "#C98F45", lid_d=RED_DD, extra=[rect(9.5, 17, 13, 7, YELLOW, rx=1.5),
                                                        ell(16, 20.5, 2.4, 1.6, "#B97028"), ell(16, 20.5, 0.9, 0.6, "#E19747")]))


@icon("parmesan")
def _():
    return svg(*fluent("u1f9c0", {"#FCD53F": "#F6DA8A", 1: "#C8963E"}, keep=(0, 1)),
               circ(10, 20, 0.8, "#E2BC62"), circ(15, 24, 0.9, "#E2BC62"), circ(20, 19, 0.8, "#E2BC62"), circ(23, 24.5, 0.7, "#E2BC62"),
               circ(13, 16.5, 0.6, "#E2BC62"), circ(18, 27, 0.7, "#E2BC62"))


# === Tiefkühl & Snacks =======================================================
@icon("tk-gemuese")
def _():
    return svg(*bag(BLUE_L, BLUE, extra=[
        *snowflake(23, 12, 3, WHITE),
        circ(11, 20, 2.2, GREEN), circ(14.5, 23.5, 2.2, GREEN), circ(10.5, 25, 2, GREEN),
        rect(16, 16, 2.4, 7, ORANGE, rx=1.2, tf="rotate(35 17 19.5)"), rect(19.5, 19, 2.4, 7, ORANGE, rx=1.2, tf="rotate(-20 20.7 22.5)"),
        rect(17.5, 24, 3.2, 3.2, YELLOW, rx=0.8)]))


@icon("fischstaebchen")
def _():
    c, d, l = "#F2A93B", "#D4801E", "#FFD27A"
    def stick(y, rot):
        return g(f"rotate({rot} 16 {y})", rect(4, y - 3.2, 24, 6.4, d, rx=1.6), rect(4, y - 3.6, 24, 6.2, c, rx=1.6),
                 *[circ(x, y - 1.2 + (x % 3) * 0.6, 0.55, l) for x in range(6, 27, 3)])
    return svg(stick(10, -12), stick(17, -12), stick(24, -12))


@icon("chips")
def _():
    return svg(path("M6 4.5H26C26 8 25 9 25 16C25 23 26 24 26 27.5H6C6 24 7 23 7 16C7 9 6 8 6 4.5Z", RED),
               rect(5.5, 2.5, 21, 3, RED_D, rx=1), rect(5.5, 26.5, 21, 3, RED_D, rx=1),
               ell(16, 16.5, 6.8, 5.6, YELLOW), ell(14.5, 15, 2.2, 1.2, YELLOW_L, -20), circ(18.5, 18.5, 0.7, AMBER), circ(13, 18.8, 0.6, AMBER),
               rect(8, 7, 1.4, 18, "#FF6B69", rx=0.7))


@icon("gummibaerchen")
def _():
    def bear(cx, cy, c, hl, rot):
        return g(f"rotate({rot} {cx} {cy})",
                 circ(cx - 2.4, cy - 7.2, 1.5, c), circ(cx + 2.4, cy - 7.2, 1.5, c), circ(cx, cy - 5, 3.6, c),
                 ell(cx, cy + 2, 4.2, 5, c), circ(cx - 4, cy - 0.3, 1.6, c), circ(cx + 4, cy - 0.3, 1.6, c),
                 circ(cx - 2.8, cy + 6, 1.8, c), circ(cx + 2.8, cy + 6, 1.8, c),
                 ell(cx - 1.4, cy - 6.2, 1, 0.7, hl), ell(cx - 1.6, cy + 0.5, 1.1, 2, hl))
    return svg(bear(9, 13, RED, SALMON, -12), bear(23, 13, GREEN, LIME_L, 12), bear(16, 20.5, AMBER, YELLOW_L, 0))


@icon("salzstangen")
def _():
    sticks = []
    for i, (x, rot) in enumerate(((9, -16), (12.5, -8), (16, 0), (19.5, 8), (23, 16))):
        sticks.append(g(f"rotate({rot} 16 30)", rect(x - 1.1, 2.5, 2.2, 26, "#A85A22", rx=1.1),
                        rect(x - 0.6, 3.5, 0.6, 22, "#C9773A", rx=0.3),
                        *[rect(x - 0.4 + (j % 2) * 0.6, 4 + j * 3.1, 0.7, 0.7, WHITE) for j in range(8)]))
    return svg(*sticks, rect(8, 19, 16, 11, BLUE_L, rx=2), rect(9.5, 20.5, 1.3, 8, WHITE, rx=0.65))


# === Getränke ================================================================
@icon("wasser")
def _():
    return svg(rect(13, 1.5, 6, 3.5, BLUE, rx=1), rect(13.5, 5, 5, 2, BLUE_D),
               path("M13.5 7H18.5C18.5 9 22.5 10 22.5 13.5V15C22.5 16 21.8 16.5 21.8 17.5C21.8 18.5 22.5 19 22.5 20V27.5C22.5 28.9 21.4 30 20 30H12C10.6 30 9.5 28.9 9.5 27.5V20C9.5 19 10.2 18.5 10.2 17.5C10.2 16.5 9.5 16 9.5 15V13.5C9.5 10 13.5 9 13.5 7Z", BLUE_L),
               rect(9.5, 20.5, 13, 6, BLUE), drop(16, 22.5, 2, WHITE), rect(11, 10.5, 1.3, 8, WHITE, rx=0.65))



@icon("sirup")
def _():
    return svg(*bottle("#B5174A", WHITE, label=WHITE, extra=[circ(14.3, 21.3, 1.6, "#B5174A"), circ(17.5, 21, 1.6, "#7B1E7A"), circ(16, 23.5, 1.6, "#B5174A"),
                                                            *leaf(17.3, 18.8, 1.6, 0.7, -30, GREEN)]))


# === Haushalt ================================================================
@icon("spuelmittel")
def _():
    return svg(*squeeze(LIME, GREEN_D, nozzle=GREEN_D, extra=[rect(10.5, 16.5, 11, 7.5, WHITE, rx=1.5), *leaf(16, 20.2, 2.6, 1.5, -25, GREEN),
                                                            circ(25.5, 7, 2.2, BLUE_LL), circ(27.5, 11.5, 1.4, BLUE_LL), circ(24.8, 3, 1.2, BLUE_LL)]))


@icon("spuelmaschinentabs")
def _():
    def tab(x, y, rot):
        return g(f"rotate({rot} {x+6} {y+5})", rect(x, y, 13, 10, "#DCE6F0", rx=2), rect(x, y, 13, 5.5, WHITE, rx=2),
                 rect(x, y + 3, 13, 2.5, WHITE), rect(x, y + 5.5, 13, 4.5, BLUE, rx=0), path(f"M{x} {y+5.5}H{x+13}V{y+8}C{x+13} {y+9.1} {x+12.1} {y+10} {x+11} {y+10}H{x+2}C{x+0.9} {y+10} {x} {y+9.1} {x} {y+8}Z", BLUE),
                 circ(x + 6.5, y + 5.5, 2.3, RED), circ(x + 5.8, y + 4.8, 0.7, SALMON))
    return svg(tab(3, 15, -10), tab(15.5, 9, 12), circ(8, 8, 2, BLUE_LL), circ(12, 4.5, 1.3, BLUE_LL), circ(27, 25, 1.5, BLUE_LL))


@icon("waschmittel")
def _():
    return svg(path("M8 8H20V6C20 4.9 20.9 4 22 4H25C26.1 4 27 4.9 27 6V27C27 28.7 25.7 30 24 30H8C6.3 30 5 28.7 5 27V11C5 9.3 6.3 8 8 8Z", BLUE),
               path("M21.5 7H25V15H21.5Z", BLUE_D), rect(8, 3, 7, 5, WHITE, rx=1.2),
               rect(7, 15, 15, 11, WHITE, rx=2), circ(12, 20.5, 2.6, BLUE_L), circ(16.5, 19.5, 2, BLUE_L), circ(16, 23.3, 1.5, BLUE_L),
               rect(6.5, 10.5, 1.4, 16, "#5CC8F5", rx=0.7))


@icon("weichspueler")
def _():
    return svg(path("M8 8H20V6C20 4.9 20.9 4 22 4H25C26.1 4 27 4.9 27 6V27C27 28.7 25.7 30 24 30H8C6.3 30 5 28.7 5 27V11C5 9.3 6.3 8 8 8Z", PURPLE_L),
               path("M21.5 7H25V15H21.5Z", PURPLE), rect(8, 3, 7, 5, PURPLE, rx=1.2),
               rect(7, 15, 15, 11, WHITE, rx=2), path("M14.5 23.5C11 21 9.5 19 11 17.6C12.3 16.4 14 17.3 14.5 18.4C15 17.3 16.7 16.4 18 17.6C19.5 19 18 21 14.5 23.5Z", PINK),
               rect(6.5, 10.5, 1.4, 16, "#E2CDFB", rx=0.7))


@icon("muellbeutel")
def _():
    return svg(path("M12 7C9 9 5 14 5 21C5 27 9 30 16 30C23 30 27 27 27 21C27 14 23 9 20 7Z", GRAY_D),
               path("M12 7L9 2.5C11 3.5 13 4 16 4.8C19 4 21 3.5 23 2.5L20 7Z", "#4A4A4A"), rect(11, 6, 10, 2.6, DARK, rx=1.3),
               path("M9 15C8 18 8 22 9.5 25", "#8A8A8A"), rect(8.6, 14, 1.4, 11, "#8A8A8A", rx=0.7, tf="rotate(8 9 19)"),
               rect(17, 13, 1.2, 12, "#555555", rx=0.6, tf="rotate(-6 17.6 19)"))


@icon("kuechenrolle")
def _():
    dots = [circ(x, y, 0.7, BLUE_L) for x in (10.5, 14, 17.5, 21) for y in (8, 12, 16, 20, 24)]
    return svg(rect(7, 4, 18, 23, WHITE, rx=2.5), *dots, ell(16, 4.6, 9, 2.4, "#E6E6E6"), ell(16, 4.6, 2.6, 1, GRAY_M),
               path("M7 24H25V28.5C25 29.3 24.3 30 23.5 30H8.5C7.7 30 7 29.3 7 28.5Z", "#E9EEF3"),
               rect(8.4, 7, 1.4, 16, "#EEF2F6", rx=0.7))


@icon("taschentuecher")
def _():
    return svg(path("M10 13C11 9 12.5 5 16 3.5C19.5 5 21 9 22 13Z", WHITE), path("M16 3.5C14 6 13.5 9.5 13.8 13H16Z", "#E6EEF5"),
               rect(3, 12, 26, 17, BLUE, rx=2), rect(8, 11, 16, 4, "#0B5C8F", rx=2), path("M10 12.5C12 14.5 20 14.5 22 12.5V11H10Z", WHITE),
               rect(5, 19, 22, 1.4, BLUE_L, rx=0.7), rect(4.5, 14.5, 1.3, 12, "#33B8F0", rx=0.65))


def _foil_box(sheet, sheet_d, body):
    return svg(path("M4 13L10 7H29L23 13Z", sheet), path("M10 7H29L27 9.5H11.5Z", sheet_d),
               path("M3 13H23V24H3Z", body), path("M23 13L29 7V18L23 24Z", "#C9C9C9" if body == GRAY else body),
               rect(3, 22, 20, 7, body), path("M23 24L29 18V23L23 29Z", "#BDBDBD"),
               path("M3 16H23V18L21 17.2L19 18L17 17.2L15 18L13 17.2L11 18L9 17.2L7 18L5 17.2L3 18Z", "#E8E8E8"))


@icon("alufolie")
def _():
    return svg(path("M2 14L9 8H30L23 14Z", "#E6EAEE"), path("M9 8H30L28.5 10H10.5Z", "#B8C2CC"),
               rect(2, 14, 21, 15, BLUE, rx=1.5), path("M23 14L30 8V22.5L23 29Z", BLUE_D),
               path("M2 14H23V17L21 16.2L19 17L17 16.2L15 17L13 16.2L11 17L9 16.2L7 17L5 16.2L3 17L2 16.6Z", "#C7CED6"),
               rect(5, 21, 15, 4, "#C7CED6", rx=2), rect(7, 22.3, 11, 1.4, WHITE, rx=0.7))


@icon("frischhaltefolie")
def _():
    return svg(path("M2 14L9 8H30L23 14Z", "#D9F1FF"), path("M9 8H30L28.5 10H10.5Z", "#9FD6F5"),
               rect(2, 14, 21, 15, GREEN, rx=1.5), path("M23 14L30 8V22.5L23 29Z", GREEN_D),
               path("M2 14H23V17L21 16.2L19 17L17 16.2L15 17L13 16.2L11 17L9 16.2L7 17L5 16.2L3 17L2 16.6Z", "#C2E8FA"),
               rect(5, 21, 15, 4, "#C2E8FA", rx=2), rect(7, 22.3, 11, 1.4, WHITE, rx=0.7))


@icon("backpapier")
def _():
    return svg(path("M2 14L9 8H30L23 14Z", "#F6E7CF"), path("M9 8H30L28.5 10H10.5Z", "#E3C99B"),
               rect(2, 14, 21, 15, RED, rx=1.5), path("M23 14L30 8V22.5L23 29Z", RED_D),
               path("M2 14H23V17L21 16.2L19 17L17 16.2L15 17L13 16.2L11 17L9 16.2L7 17L5 16.2L3 17L2 16.6Z", "#F0DDB9"),
               rect(5, 21, 15, 4, "#F0DDB9", rx=2), rect(7, 22.3, 11, 1.4, WHITE, rx=0.7))


@icon("reiniger")
def _():
    return svg(path("M9 6H21L25 9L23.5 10.5L21 9.5H19V13H11V9.5L9 9Z", "#F9C23C"), rect(11.5, 2, 9, 4.5, "#F9C23C", rx=1.5),
               path("M10 11.5H18L16.5 14H11.5Z", "#E19747"), rect(19.5, 10, 2.3, 7, "#E19747", rx=1.1, tf="rotate(-25 20.6 13.5)"),
               path("M11 13H19C21 15 23 17 23 20V27.5C23 28.9 21.9 30 20.5 30H9.5C8.1 30 7 28.9 7 27.5V20C7 17 9 15 11 13Z", BLUE),
               rect(9, 19, 12, 7.5, WHITE, rx=1.5), *snowflake(15, 22.7, 2.4, BLUE_L), rect(8.6, 17, 1.4, 9, "#5CC8F5", rx=0.7),
               circ(27.5, 6, 0.9, BLUE_L), circ(29.5, 9, 0.8, BLUE_L), circ(27.8, 11.6, 0.7, BLUE_L))


@icon("wasserkocher")
def _():
    return svg(rect(5, 26, 22, 4, GRAY_D, rx=1.5),
               path("M8 9H22L24 25.5C24.1 26.3 23.5 27 22.7 27H7.3C6.5 27 5.9 26.3 6 25.5Z", "#E9EEF3"),
               path("M22 9C26.5 9 29 11 29 15V20C29 22.5 27.5 23.5 24 23.5V20.5C25.5 20.5 26 20 26 19V15.5C26 13 25 12 22.5 12Z", GRAY_D),
               path("M8 9L3 6.5L3.5 9L8 12Z", "#C7CED6"), rect(8, 5, 14, 4.5, GRAY_D, rx=2), rect(13, 3, 4, 2.5, DARK, rx=1),
               rect(10, 13, 2, 11, BLUE_L, rx=1), rect(10.4, 18, 1.2, 5.6, BLUE, rx=0.6), rect(15, 11, 1.4, 13, WHITE, rx=0.7))


# === Drogerie ================================================================
@icon("shampoo")
def _():
    return svg(rect(10, 2, 12, 4.5, PURPLE_D, rx=1.5), rect(12, 6, 8, 2.5, PURPLE),
               path("M10 8.5H22C24 8.5 25 10 25 12V27C25 28.7 23.7 30 22 30H10C8.3 30 7 28.7 7 27V12C7 10 8 8.5 10 8.5Z", PURPLE),
               rect(9.5, 15, 13, 9, WHITE, rx=1.5), circ(13.5, 19.5, 2, PURPLE_L), circ(17.5, 18.5, 1.5, PURPLE_L), circ(17, 21.8, 1.2, PURPLE_L),
               rect(8.6, 11, 1.4, 16, "#A98AD8", rx=0.7))


@icon("duschgel")
def _():
    return svg(path("M7 7C7 4 9.5 2 12.5 2H19.5C22.5 2 25 4 25 7V22C25 23.7 23.7 25 22 25H10C8.3 25 7 23.7 7 22Z", CYAN),
               rect(10.5, 25, 11, 2.5, BLUE_D), rect(9.5, 27, 13, 3.5, BLUE, rx=1.5),
               rect(10, 9, 12, 9.5, WHITE, rx=1.5), drop(16, 12.4, 2.6, BLUE),
               rect(8.6, 5, 1.4, 15, "#9AF4FD", rx=0.7))


@icon("zahnpasta")
def _():
    return svg(*tube(WHITE, BLUE, stripe=BLUE_L, extra=[rect(12.4, 13.5, 7.2, 2.5, RED, rx=0.5)]))


@icon("deo")
def _():
    return svg(rect(11, 2, 10, 6, BLUE_D, rx=2), rect(13.5, 3, 5, 2.5, BLUE, rx=1),
               rect(10, 7.5, 12, 2, GRAY), rect(9.5, 9, 13, 21, GRAY_LL, rx=2.5),
               rect(9.5, 14, 13, 10, BLUE), path("M9.5 21C13 17 18 20 22.5 16.5V19.5C18 23 13 20 9.5 24Z", WHITE),
               rect(11, 10.5, 1.4, 17, WHITE, rx=0.7))


@icon("sonnencreme")
def _():
    return svg(*tube(AMBER, ORANGE_D, extra=[circ(16, 15, 3.2, YELLOW_L), *[rect(15.5, 9, 1, 2.2, YELLOW_L, rx=0.5, tf=f"rotate({a} 16 15)") for a in range(0, 360, 45)]]))


@icon("wattepads")
def _():
    els = []
    for i, y in enumerate((25, 21.5, 18, 14.5, 11)):
        els += [ell(16, y + 1.2, 12, 4.2, "#DCE3EA"), ell(16, y, 12, 4.2, WHITE)]
    els += [ell(16, 11, 7, 2.2, "#EEF2F6"), circ(12, 10.5, 0.6, "#DCE3EA"), circ(17, 12, 0.6, "#DCE3EA"), circ(20, 10, 0.6, "#DCE3EA")]
    return svg(*els)


@icon("hygieneartikel")
def _():
    return svg(rect(5, 6, 22, 24, PINK_L, rx=2.5), rect(5, 6, 22, 5, "#F48FB1", rx=2.5), rect(5, 9, 22, 2, "#F48FB1"),
               rect(10.5, 14, 11, 12, WHITE, rx=5.5), rect(13, 16, 6, 8, "#FCE4EC", rx=3),
               rect(6.5, 12.5, 1.4, 15, "#FFD6CC", rx=0.7))


# === Tierbedarf ==============================================================
@icon("katzenfutter")
def _():
    return svg(*can(PURPLE, short=True, label=PURPLE_L, extra=[
        path("M11 25.5V19L13 21H19L21 19V25.5C21 27 19.5 27.5 16 27.5C12.5 27.5 11 27 11 25.5Z", "#4A4A4A"),
        circ(14, 23.2, 0.7, YELLOW), circ(18, 23.2, 0.7, YELLOW)]),
               fish_mark(16, 7, 4.5, AMBER))


@icon("hundefutter")
def _():
    kib = [circ(x, y, 1.6, "#A0522D" if i % 2 else "#8C5543") for i, (x, y) in enumerate(((9, 17), (12.5, 16), (16, 15.5), (19.5, 16), (23, 17), (11, 19), (15, 18.5), (19, 18.8)))]
    return svg(*kib, path("M3 18.5H29L27 27.5C26.7 28.9 25.5 30 24 30H8C6.5 30 5.3 28.9 5 27.5Z", RED),
               rect(2.5, 17.5, 27, 3, RED_D, rx=1.5),
               g("rotate(-20 16 8)", rect(9, 6.5, 14, 3.5, OFFWHITE, rx=1.7), circ(9, 6.3, 2.1, OFFWHITE), circ(9, 10.2, 2.1, OFFWHITE),
                 circ(23, 6.3, 2.1, OFFWHITE), circ(23, 10.2, 2.1, OFFWHITE)))


@icon("katzenstreu")
def _():
    paw = [ell(16, 20.5, 3.4, 2.8, GRAY_D), circ(12.3, 16.6, 1.4, GRAY_D), circ(15, 15.2, 1.4, GRAY_D), circ(17.8, 15.2, 1.4, GRAY_D), circ(20.3, 16.8, 1.4, GRAY_D)]
    return svg(*bag(GRAY_L, PURPLE, label=WHITE, extra=paw))


# === Baumarkt & Garten =======================================================
@icon("blumenerde")
def _():
    return svg(*bag(GREEN_D, "#00573F", label="#6D4534", extra=[
        path("M9.5 20C12 18.5 20 18.5 22.5 20V24H9.5Z", "#4A2E20"),
        rect(15.3, 14.5, 1.4, 5.5, GREEN, rx=0.7), *leaf(13.5, 15, 2.4, 1.2, 30, GREEN), *leaf(18.5, 14.2, 2.4, 1.2, -30, LIME)]))


@icon("klebeband")
def _():
    return svg(circ(15, 16, 12, "#C9A36B"), circ(15, 16, 10.5, "#E3C08A"), circ(15, 16, 6.2, "#B8915A"), circ(15, 16, 5, WHITE),
               ell(11, 9.5, 3.5, 1.2, "#F3DDB5", -35), path("M25.5 20L30 21.5V28L24 25.5Z", "#E3C08A"), path("M24 25.5L30 28L28.5 29.5L22.5 27Z", "#C9A36B"))


@icon("farbe")
def _():
    return svg(path("M6 10H26V27C26 28.7 24.7 30 23 30H9C7.3 30 6 28.7 6 27Z", GRAY_LL),
               ell(16, 10, 10, 3, GRAY), ell(16, 10, 8.5, 2.2, BLUE), path("M8.5 10.5C8.5 13 9 15 8 17.5C7.5 18.7 9 19 9.3 17.6C9.8 15.5 10 13 11.5 11.5Z", BLUE),
               rect(6, 16, 20, 9, BLUE), rect(7.5, 13, 1.4, 14, WHITE, rx=0.7),
               path("M6 11C6 4 26 4 26 11", GRAY_D), path("M6 11C6 3 26 3 26 11H24.6C24.6 5.5 7.4 5.5 7.4 11Z", GRAY_M))


@icon("grillkohle")
def _():
    return svg(*bag(DARK, "#4A4A4A", label=ORANGE_D, extra=[
        path("M16 14C16 14 12.5 17.5 12.5 20.5C12.5 22.5 14 24 16 24C18 24 19.5 22.5 19.5 20.5C19.5 17.5 16 14 16 14Z", YELLOW),
        path("M16 18C16 18 14.6 19.7 14.6 21C14.6 22 15.2 22.6 16 22.6C16.8 22.6 17.4 22 17.4 21C17.4 19.7 16 18 16 18Z", WHITE)]))


@icon("cola")
def _():
    return svg(rect(8, 3.5, 16, 26, "#4A2416", rx=2.5), rect(9, 2, 14, 3, GRAY, rx=1.2), rect(9, 28.5, 14, 2, GRAY, rx=1),
               rect(8, 11, 16, 11, "#B4632E"), rect(8, 12.2, 16, 1.2, "#D98A4B"),
               circ(12, 16.5, 1.3, "#E9B27F"), circ(16.5, 18.5, 1, "#E9B27F"), circ(20, 15.5, 1.5, "#E9B27F"), circ(14.5, 20.3, 0.8, "#E9B27F"),
               circ(12, 7, 0.9, "#6D3A24"), circ(19, 8, 0.7, "#6D3A24"), circ(15.5, 25.5, 0.9, "#6D3A24"),
               rect(9.5, 5, 1.4, 22, "#6D3A24", rx=0.7))


@icon("ingwer")
def _():
    c, d, l = "#E2B26B", "#C08A43", "#F4D39A"
    return svg(g("rotate(-12 16 17)",
                 rect(3, 14, 26, 9, c, rx=4.5),
                 ell(8, 12.5, 3, 4.5, c, -25), ell(16.5, 11, 3.2, 5, c, 10), ell(24.5, 13, 2.8, 4, c, 30),
                 ell(12, 24.5, 3, 3.5, c, 20), ell(22, 24, 2.6, 3.2, c, -20),
                 rect(10.6, 14.5, 1.1, 8, d, rx=0.55), rect(19.4, 14.5, 1.1, 8, d, rx=0.55),
                 ell(16.5, 8.2, 1.6, 1, "#9BC46B"), ell(8, 9.2, 1.4, 0.9, "#9BC46B", -25),
                 rect(5, 15.5, 5, 1.4, l, rx=0.7), rect(13, 15.5, 5, 1.4, l, rx=0.7), ell(16, 9.5, 1, 1.8, l, 10)))


@icon("fisch")
def _():
    w, wd, wl = "#F6EEE6", "#E0D2C4", "#FFFFFF"
    return svg(path("M3 19C3 12 9 8 17 8C24 8 29 11 29 16C29 21 24 24.5 17 24.5C9 24.5 3 24 3 19Z", "#B9C3CC"),
               path("M3 18C3 12 9 8.5 17 8.5C23.5 8.5 28.5 11.5 28.5 15.5C28.5 19.5 24 22.5 17 22.5C9 22.5 3 22.5 3 18Z", w),
               rect(8.6, 10.5, 1.1, 11, wd, rx=0.55, tf="rotate(8 9 16)"), rect(13.3, 9, 1.1, 13.5, wd, rx=0.55, tf="rotate(10 14 16)"),
               rect(18.1, 9, 1.1, 13.5, wd, rx=0.55, tf="rotate(12 18.6 16)"), rect(22.8, 10, 1.1, 11.5, wd, rx=0.55, tf="rotate(14 23.4 16)"),
               ell(12, 12, 3, 1, wl, -10), *leaf(24.5, 7, 2.6, 1.3, -30, GREEN), circ(26.5, 22, 2.6, YELLOW), circ(26.5, 22, 1.6, YELLOW_L))


@icon("spirituosen")
def _():
    return svg(rect(13, 1.5, 6, 4.5, DARK, rx=1), rect(13.5, 6, 5, 3, "#B97028"),
               path("M13.5 8.5H18.5L22.5 11.5C23.5 12.3 24 13 24 14.5V27.5C24 28.9 22.9 30 21.5 30H10.5C9.1 30 8 28.9 8 27.5V14.5C8 13 8.5 12.3 9.5 11.5Z", "#C8771E"),
               path("M8 18H24V27.5C24 28.9 22.9 30 21.5 30H10.5C9.1 30 8 28.9 8 27.5Z", "#A85F12"),
               rect(10, 16, 12, 9, "#F6EBD5", rx=1), rect(12, 18.5, 8, 1.4, "#8C5543", rx=0.7), rect(13, 21.5, 6, 1.2, "#C8771E", rx=0.6),
               rect(9.4, 13, 1.4, 13, "#E9A65B", rx=0.7))


if __name__ == "__main__":
    # python3 zeichnen.py            – alle eigenen Symbole nach ../eigene/ schreiben
    # python3 zeichnen.py lachs fisch – nur die genannten
    ziel = os.path.join(HERE, "..", "eigene")
    os.makedirs(ziel, exist_ok=True)
    nur = set(sys.argv[1:])
    unbekannt = nur - set(ICONS)
    if unbekannt:
        sys.exit(f"Unbekannt: {sorted(unbekannt)}")
    for name, f in ICONS.items():
        if nur and name not in nur:
            continue
        open(os.path.join(ziel, name + ".svg"), "w").write(f())
    print(len(nur or ICONS), "Symbole geschrieben nach", os.path.normpath(ziel))
