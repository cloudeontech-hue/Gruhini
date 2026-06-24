"""Generates stylized placeholder photos for product cards.

These are NOT real photographs - they are simple programmatic illustrations
used as stand-ins until real product photography is available. Replace the
files in assets/images/products/ with real photos when ready.
"""
import math
import random

from PIL import Image, ImageDraw

OUT_DIR = "assets/images/products"
SIZE = (800, 600)

random.seed(42)


def save(img, name):
    img.convert("RGB").save(f"{OUT_DIR}/{name}", "JPEG", quality=88)
    print(f"wrote {name}")


def gradient_bg(top_color, bottom_color):
    img = Image.new("RGB", SIZE, top_color)
    draw = ImageDraw.Draw(img)
    w, h = SIZE
    for y in range(h):
        t = y / h
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def plate(img, color, radius_ratio=0.38):
    w, h = img.size
    cx, cy = w // 2, int(h * 0.55)
    r = int(min(w, h) * radius_ratio)
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - r, cy - r, cx + r, cy * 0.0 + cy + r], fill=color)
    return cx, cy, r


def murukku():
    img = gradient_bg((250, 215, 140), (222, 168, 70))
    cx, cy, r = plate(img, (255, 244, 222), 0.4)
    draw = ImageDraw.Draw(img)
    for i in range(6):
        ox = cx + random.randint(-r // 2, r // 2)
        oy = cy + random.randint(-r // 3, r // 3)
        coil_r = random.randint(45, 65)
        turns = 3
        points = []
        for t in range(0, 360 * turns, 6):
            rad = math.radians(t)
            rr = coil_r * (t / (360 * turns))
            points.append((ox + rr * math.cos(rad), oy + rr * math.sin(rad)))
        draw.line(points, fill=(120, 70, 20), width=6, joint="curve")
        draw.line(points, fill=(189, 122, 38), width=3, joint="curve")
    save(img, "murukku.jpg")


def banana_chips():
    img = gradient_bg((255, 244, 200), (240, 210, 110))
    cx, cy, r = plate(img, (255, 250, 235), 0.4)
    draw = ImageDraw.Draw(img)
    for i in range(14):
        ox = cx + random.randint(-r + 20, r - 20)
        oy = cy + random.randint(-r + 30, r - 30)
        if (ox - cx) ** 2 + (oy - cy) ** 2 > (r - 10) ** 2:
            continue
        w_, h_ = random.randint(55, 80), random.randint(35, 50)
        shade = random.randint(-12, 12)
        color = (250 + shade, 230 + shade, 140 + shade)
        draw.ellipse([ox - w_ / 2, oy - h_ / 2, ox + w_ / 2, oy + h_ / 2], fill=color, outline=(200, 170, 90))
    save(img, "banana_chips.jpg")


def madras_mixture():
    img = gradient_bg((235, 140, 70), (190, 80, 40))
    cx, cy, r = plate(img, (255, 248, 235), 0.4)
    draw = ImageDraw.Draw(img)
    for i in range(220):
        ox = cx + random.randint(-r + 10, r - 10)
        oy = cy + random.randint(-r + 10, r - 10)
        if (ox - cx) ** 2 + (oy - cy) ** 2 > (r - 8) ** 2:
            continue
        kind = random.random()
        if kind < 0.5:
            length = random.randint(10, 18)
            angle = random.uniform(0, math.pi)
            dx, dy = length * math.cos(angle), length * math.sin(angle)
            draw.line([(ox, oy), (ox + dx, oy + dy)], fill=(235, 200, 90), width=2)
        elif kind < 0.8:
            rr = random.randint(4, 7)
            draw.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=(180, 120, 60))
        else:
            rr = random.randint(3, 5)
            draw.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=(150, 40, 30))
    save(img, "madras_mixture.jpg")


def mysore_pak():
    img = gradient_bg((255, 221, 140), (230, 170, 70))
    cx, cy, r = plate(img, (255, 245, 225), 0.42)
    draw = ImageDraw.Draw(img)
    rows, cols = 3, 4
    start_x = cx - 130
    start_y = cy - 70
    for row in range(rows):
        for col in range(cols):
            x0 = start_x + col * 70
            y0 = start_y + row * 50
            x1, y1 = x0 + 58, y0 + 40
            shade = random.randint(-10, 10)
            color = (224 + shade, 168 + shade, 80 + max(shade, -40))
            draw.rectangle([x0, y0, x1, y1], fill=color, outline=(150, 100, 40))
            draw.line([(x0 + 4, y0 + 4), (x1 - 10, y0 + 8)], fill=(255, 235, 190), width=3)
    save(img, "mysore_pak.jpg")


def ragi_cookies():
    img = gradient_bg((196, 150, 100), (120, 80, 50))
    cx, cy, r = plate(img, (250, 238, 220), 0.4)
    draw = ImageDraw.Draw(img)
    positions = [(-110, -40), (0, -70), (110, -40), (-70, 60), (60, 60), (-160, 70), (150, 80)]
    for ox, oy in positions:
        x, y = cx + ox, cy + oy
        rr = random.randint(48, 58)
        shade = random.randint(-8, 8)
        color = (150 + shade, 105 + shade, 60 + shade)
        draw.ellipse([x - rr, y - rr, x + rr, y + rr], fill=color, outline=(90, 55, 25), width=3)
        for _ in range(10):
            sx = x + random.randint(-rr + 10, rr - 10)
            sy = y + random.randint(-rr + 10, rr - 10)
            draw.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(70, 40, 20))
    save(img, "ragi_cookies.jpg")


def badam_milk():
    img = gradient_bg((255, 244, 224), (235, 210, 170))
    w, h = SIZE
    cx = w // 2
    glass_top, glass_bottom = int(h * 0.22), int(h * 0.86)
    top_w, bottom_w = 170, 130
    draw = ImageDraw.Draw(img)
    draw.polygon(
        [
            (cx - top_w, glass_top),
            (cx + top_w, glass_top),
            (cx + bottom_w, glass_bottom),
            (cx - bottom_w, glass_bottom),
        ],
        fill=(255, 255, 255, 255),
        outline=(210, 190, 160),
    )
    liquid_top = glass_top + 35
    liquid_top_w = top_w - 15
    draw.polygon(
        [
            (cx - liquid_top_w, liquid_top),
            (cx + liquid_top_w, liquid_top),
            (cx + bottom_w - 8, glass_bottom - 8),
            (cx - bottom_w + 8, glass_bottom - 8),
        ],
        fill=(240, 214, 170),
    )
    for i in range(6):
        ax = cx + random.randint(-80, 80)
        ay = liquid_top + random.randint(0, 30)
        draw.ellipse([ax - 14, ay - 5, ax + 14, ay + 5], fill=(225, 196, 150), outline=(190, 160, 120))
    save(img, "badam_milk.jpg")


def peanut_chikki():
    img = gradient_bg((230, 175, 95), (160, 100, 45))
    cx, cy, r = plate(img, (255, 246, 230), 0.4)
    draw = ImageDraw.Draw(img)
    bar_w, bar_h = 220, 110
    x0, y0 = cx - bar_w // 2, cy - bar_h // 2
    x1, y1 = cx + bar_w // 2, cy + bar_h // 2
    draw.rectangle([x0, y0, x1, y1], fill=(196, 138, 60), outline=(120, 75, 30), width=3)
    for _ in range(28):
        nx = random.randint(x0 + 12, x1 - 12)
        ny = random.randint(y0 + 12, y1 - 12)
        nr = random.randint(8, 13)
        shade = random.randint(-10, 10)
        draw.ellipse(
            [nx - nr, ny - nr * 0.7, nx + nr, ny + nr * 0.7],
            fill=(214 + shade, 175 + shade, 120 + shade),
            outline=(140, 95, 50),
        )
    save(img, "peanut_chikki.jpg")


def ribbon_pakoda():
    img = gradient_bg((255, 214, 120), (224, 150, 50))
    cx, cy, r = plate(img, (255, 248, 232), 0.4)
    draw = ImageDraw.Draw(img)
    for i in range(7):
        base_y = cy + 60 - i * 16
        amplitude = random.randint(14, 22)
        length = random.randint(140, 180)
        points = []
        for t in range(0, length, 4):
            x = cx - length // 2 + t
            y = base_y + amplitude * math.sin(t / 14)
            points.append((x, y))
        shade = random.randint(-10, 10)
        color = (235 + shade, 190 + shade, 90 + max(shade, -60))
        draw.line(points, fill=color, width=10, joint="curve")
        draw.line(points, fill=(150, 100, 30), width=2, joint="curve")
    save(img, "ribbon_pakoda.jpg")


if __name__ == "__main__":
    murukku()
    banana_chips()
    madras_mixture()
    mysore_pak()
    ragi_cookies()
    badam_milk()
    peanut_chikki()
    ribbon_pakoda()
