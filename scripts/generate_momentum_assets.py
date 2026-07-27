#!/usr/bin/env python3
"""Generate all Momentum brand assets from apps/momentum/assets/logo.png.

Run from repo root:  python3 scripts/generate_momentum_assets.py
Then regenerate platform icon sets:  scripts/generate_app_icon_assets.sh
"""
from PIL import Image, ImageFilter
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = f'{ROOT}/apps/momentum/assets/logo.png'

logo = Image.open(SRC).convert('RGBA')

# --- 1. Extract the opaque rounded tile ------------------------------------
alpha = logo.getchannel('A')
mask_solid = alpha.point(lambda v: 255 if v > 250 else 0)
tile_bbox = mask_solid.getbbox()
tile = logo.crop(tile_bbox)
tw, th = tile.size
# Erode the tile mask a few pixels: kills the light anti-alias halo the source
# logo carries along the rounded edge (visible against the darker canvas).
tile_mask = alpha.crop(tile_bbox).filter(ImageFilter.MinFilter(7))
tile.putalpha(tile_mask)
print('tile bbox', tile_bbox, 'size', tile.size)

# Background colour sampled at tile centre-top (inside, away from artwork).
BG = tile.getpixel((tw // 2, 8))[:3]
print('tile background', BG)

# --- 2. Full-bleed square icon (tile pasted on same-colour square) ----------
side = max(tw, th)
solid = Image.new('RGB', (side, side), BG)
solid.paste(tile, ((side - tw) // 2, (side - th) // 2), tile)

def save_rgb(img, size, path, fmt='PNG', quality=92):
    out = img.resize((size, size), Image.LANCZOS) if img.size != (size, size) else img
    out.save(path, fmt, quality=quality, optimize=True)
    print('wrote', path)

# --- 3. Split mark vs wordmark via row profile of non-background pixels -----
small = solid.convert('RGB')
px = small.load()
W, H = small.size
def colordist(c):
    return max(abs(c[0] - BG[0]), abs(c[1] - BG[1]), abs(c[2] - BG[2]))
rows = []
for y in range(H):
    n = 0
    for x in range(0, W, 4):
        if colordist(px[x, y]) > 40:
            n += 1
    rows.append(n)
# clusters of consecutive rows with content
clusters, start = [], None
for y, n in enumerate(rows):
    if n > 2 and start is None:
        start = y
    elif n <= 2 and start is not None:
        clusters.append((start, y - 1)); start = None
if start is not None:
    clusters.append((start, H - 1))
clusters = [c for c in clusters if c[1] - c[0] > 20]
print('row clusters', clusters)
assert len(clusters) >= 2, 'expected mark + wordmark clusters'
mark_rows = clusters[0]
# columns of the mark
xs = [x for x in range(W) for y in range(mark_rows[0], mark_rows[1] + 1, 6)
      if colordist(px[x, y]) > 40]
mark_bbox = (min(xs), mark_rows[0], max(xs) + 1, mark_rows[1] + 1)
print('mark bbox', mark_bbox)
mark_solid = small.crop(mark_bbox)

# --- 4. Colour-keyed transparent mark (for foreground / transparent uses) ---
def keyed(img_rgb):
    src = img_rgb.convert('RGB')
    out = Image.new('RGBA', src.size)
    sp, op = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            c = sp[x, y]
            d = math.dist(c, BG) / 255.0
            a = max(0.0, min(1.0, (d - 0.06) / 0.10))
            a = a * a * (3 - 2 * a)  # smoothstep
            op[x, y] = (c[0], c[1], c[2], round(a * 255))
    return out

mark_alpha = keyed(mark_solid)

def fit_center(img, box, canvas_size, bg=None):
    """Scale img to fit in a centred box inside a square canvas."""
    scale = min(box / img.width, box / img.height)
    nw, nh = round(img.width * scale), round(img.height * scale)
    scaled = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGBA' if bg is None else 'RGB', (canvas_size, canvas_size),
                       (0, 0, 0, 0) if bg is None else bg)
    pos = ((canvas_size - nw) // 2, (canvas_size - nh) // 2)
    canvas.paste(scaled, pos, scaled if scaled.mode == 'RGBA' else None)
    return canvas

BRAND = f'{ROOT}/apps/momentum/assets/brand'

# Solid app icons (full-bleed, RGB)
for size, path in [
    (1024, f'{BRAND}/padelandia_app_icon_1024.png'),
    (4096, f'{BRAND}/padelandia_app_icon_4096.png'),
    (1024, f'{BRAND}/rallymate_app_icon_1024.png'),
    (1024, f'{ROOT}/apps/momentum/assets/rallymate_app_icon_1024.png'),
    (1024, f'{ROOT}/apps/momentum-web/src/assets/brand/padelandia-app-icon.png'),
    (512, f'{ROOT}/docs/store-assets/google-play/play-store-icon-512.png'),
]:
    save_rgb(solid, size, path)

# Adaptive foreground: mark inside 61.9% safe zone (matches previous 195..829)
fg_1024 = fit_center(mark_alpha, 634, 1024)
fg_1024.save(f'{BRAND}/rallymate_icon_foreground_1024.png'); print('wrote fg 1024')
fg_1024.save(f'{BRAND}/padelandia_icon_foreground_1024.png')
fit_center(mark_alpha, 2536, 4096).save(f'{BRAND}/padelandia_icon_foreground_4096.png')
print('wrote fg 4096')

# App marks 256 (solid RGB, mark only)
mark256 = fit_center(mark_alpha, 190, 256, bg=BG)
mark256.save(f'{BRAND}/padelandia_app_mark_256.png')
mark256.save(f'{BRAND}/rallymate_app_mark_256.png'); print('wrote marks 256')

# Loading splash 1440x2560: tile (mark+wordmark) seamless on brand background
for path, fmt in [
    (f'{BRAND}/rallymate_loading_splash.jpg', 'JPEG'),
    (f'{BRAND}/padelandia_loading_splash.jpg', 'JPEG'),
    (f'{BRAND}/rallymate_loading_splash.png', 'PNG'),
]:
    splash = Image.new('RGB', (1440, 2560), BG)
    target_w = 880
    scale = target_w / tw
    tile_s = tile.resize((target_w, round(th * scale)), Image.LANCZOS)
    splash.paste(tile_s, ((1440 - tile_s.width) // 2, (2560 - tile_s.height) // 2), tile_s)
    splash.save(path, fmt, quality=90, optimize=True)
    print('wrote', path)

# Wear OS: in-app mark (transparent) + adaptive launcher foreground
WEAR = f'{ROOT}/wear/wearos/app/src/main/res/drawable-nodpi'
fit_center(mark_alpha, 200, 256).save(f'{WEAR}/rally_app_mark.png'); print('wrote wear mark')
# Same 61.9% safe zone as the mobile adaptive foreground.
fit_center(mark_alpha, 317, 512).save(f'{WEAR}/rally_launcher_fg.png')
print('wrote wear launcher foreground')

# watchOS: in-app mark shown by WatchViews (asset catalog + SPM resource bundle)
watch_mark = fit_center(mark_alpha, 200, 256)
watch_mark.save(f'{ROOT}/wear/watchos/MomentumWatchApp/Assets.xcassets/'
                'RallyAppMark.imageset/rally_app_mark.png')
watch_mark.save(f'{ROOT}/wear/watchos/MomentumCore/Sources/MomentumWatchKit/'
                'Resources/Backgrounds/rally_app_mark.png')
print('wrote watchos marks')

# Garmin launcher icon 70x70 (RGB) and Fitbit icon 80x80 (RGBA transparent)
fit_center(mark_alpha, 58, 70, bg=BG).save(
    f'{ROOT}/wear/garmin-connectiq/resources/images/icon.png'); print('wrote garmin icon')
fit_center(mark_alpha, 68, 80).save(
    f'{ROOT}/wear/fitbit-os/resources/icon.png'); print('wrote fitbit icon')

# Garmin Connect IQ store assets: icon 500 + hero 1440x720
save_rgb(solid, 500, f'{ROOT}/docs/store-assets/garmin/rallymate_connectiq_store_icon_500.png')
hero = Image.new('RGB', (1440, 720), BG)
tile_h = tile.resize((round(tw * 560 / th), 560), Image.LANCZOS)
hero.paste(tile_h, ((1440 - tile_h.width) // 2, (720 - tile_h.height) // 2), tile_h)
hero.save(f'{ROOT}/docs/store-assets/garmin/rallymate_connectiq_hero_1440x720.jpg',
          'JPEG', quality=90, optimize=True)
print('wrote garmin store assets')

print('DONE')
