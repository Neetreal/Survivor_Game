#!/usr/bin/env python3
"""Подготовка сгенерированных спрайтов к игре.

Что делает:
  1. вырезает фон по хрома-кею (плоский пурпурный #FF00FF, на котором мы генерируем);
  2. убирает розовую кайму по краям (despill);
  3. обрезает пустые поля и приводит к нужной высоте;
  4. складывает готовые PNG в art/sprites/ и рисует превью на тёмном фоне.

Запуск:
    python3 tools/make_sprites.py art/candidates/*.png
    python3 tools/make_sprites.py art/raw/slime.png --height 40 --out art/sprites/enemy_slime.png
"""

from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image

# Порог «пурпурности»: у фона красный и синий высокие, зелёный низкий.
# min(r, b) - g > HARD — гарантированно фон, между SOFT и HARD — полупрозрачная кайма.
SOFT = 24
HARD = 70
# Насколько сильно гасить зелёный в кайме, чтобы не было розового ободка.
DESPILL = 0.85


def key_out_magenta(img: Image.Image) -> Image.Image:
    """Пурпурный фон → прозрачность, с мягкой каймой и подавлением розового ободка."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            magenta = min(r, b) - g
            if magenta >= HARD:
                px[x, y] = (r, g, b, 0)
            elif magenta > SOFT:
                # Полупрозрачная кайма: сглаживаем переход и гасим розовый.
                t = (magenta - SOFT) / float(HARD - SOFT)
                new_a = int(a * (1.0 - t))
                g2 = int(min(255, g + (min(r, b) - g) * DESPILL))
                px[x, y] = (r, g2, b, max(0, new_a))
    return img


def autocrop(img: Image.Image, threshold: int = 8) -> Image.Image:
    """Обрезать прозрачные поля."""
    bbox = img.getbbox()  # учитывает альфу
    if bbox:
        img = img.crop(bbox)
    return img


def fit_height(img: Image.Image, height: int) -> Image.Image:
    scale = height / float(img.height)
    width = max(1, int(round(img.width * scale)))
    return img.resize((width, height), Image.LANCZOS)


def collect_files(args: list[str]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for pattern in args:
        files.extend(sorted(pathlib.Path().glob(pattern)))
    return [f for f in files if f.suffix.lower() == ".png"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", help="маски путей к исходным PNG")
    parser.add_argument("--height", type=int, default=56, help="итоговая высота спрайта в пикселях")
    parser.add_argument("--out", type=str, default="", help="куда положить результат (для одного файла)")
    parser.add_argument("--out-dir", type=str, default="art/sprites", help="папка для результатов")
    parser.add_argument(
        "--common-canvas",
        action="store_true",
        help="выровнять все кадры по общему холсту (центр по X, привязка по низу) — "
        "чтобы персонаж не дёргался между кадрами анимации",
    )
    args = parser.parse_args()

    files = collect_files(args.inputs)
    if not files:
        print("не нашёл исходников по маскам:", args.inputs)
        return 1

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir = pathlib.Path("art/preview")
    preview_dir.mkdir(parents=True, exist_ok=True)

    prepared: list[tuple[pathlib.Path, Image.Image]] = []
    for src in files:
        raw = Image.open(src)
        cut = autocrop(key_out_magenta(raw))
        prepared.append((src, fit_height(cut, args.height)))

    if args.common_canvas and len(prepared) > 1:
        # Общий холст: одинаковая ширина у всех кадров, центр по X и общий «пол» по низу.
        width = max(img.width for _, img in prepared)
        canvas_h = max(img.height for _, img in prepared)
        aligned: list[tuple[pathlib.Path, Image.Image]] = []
        for src, img in prepared:
            canvas = Image.new("RGBA", (width, canvas_h), (0, 0, 0, 0))
            canvas.alpha_composite(img, ((width - img.width) // 2, canvas_h - img.height))
            aligned.append((src, canvas))
        prepared = aligned

    for src, result in prepared:
        dst = pathlib.Path(args.out) if args.out else out_dir / (src.stem + ".png")
        result.save(dst)
        # Превью на тёмном фоне — так видно, как спрайт выглядит в игре.
        preview = Image.new("RGBA", (result.width + 16, result.height + 16), (20, 24, 32, 255))
        preview.alpha_composite(result, (8, 8))
        preview.resize((preview.width * 4, preview.height * 4), Image.NEAREST).save(
            preview_dir / (src.stem + "_preview.png")
        )
        print(f"{src} → {dst}  ({result.width}×{result.height})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
