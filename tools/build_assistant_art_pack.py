#!/usr/bin/env python3
"""Build a Godot-ready farming art pack from generated raw sheets."""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = Path("/Users/zhangcong/.codex/generated_images/019e66bb-f2c1-7db0-bcb0-a890311fea3f")
OUT = ROOT / "assets/generated/assistant_art_2026_05_29"


@dataclass(frozen=True)
class PackSpec:
    key: str
    raw_name: str
    rows: int
    cols: int
    cell_size: tuple[int, int]
    fit: float
    align: str
    names: tuple[str, ...]


PACKS: tuple[PackSpec, ...] = (
    PackSpec(
        key="farm_plots",
        raw_name="ig_06b37ad1cea000ba016a187bffbfd08191a5a849a13602e85c.png",
        rows=2,
        cols=4,
        cell_size=(64, 64),
        fit=0.94,
        align="center",
        names=(
            "grass_patch",
            "freshly_hoed",
            "seeded",
            "watered_seeded",
            "sprout_stage",
            "leafy_stage",
            "flowering_stage",
            "harvest_ready",
        ),
    ),
    PackSpec(
        key="crop_icons",
        raw_name="ig_06b37ad1cea000ba016a187c3536108191b542e329d9085be7.png",
        rows=4,
        cols=4,
        cell_size=(48, 48),
        fit=0.86,
        align="center",
        names=(
            "apple",
            "carrot",
            "cabbage",
            "tomato",
            "corn",
            "wheat_bundle",
            "potato",
            "pumpkin",
            "eggplant",
            "cucumber",
            "onion",
            "chili",
            "strawberry",
            "grape",
            "turnip",
            "sunflower",
        ),
    ),
    PackSpec(
        key="ui_icons",
        raw_name="ig_06b37ad1cea000ba016a187c7e84108191975f0f681f11bb05.png",
        rows=4,
        cols=4,
        cell_size=(48, 48),
        fit=0.86,
        align="center",
        names=(
            "coin_stack",
            "backpack",
            "player_portrait",
            "heart",
            "stamina",
            "settings",
            "map_pin",
            "quest_scroll",
            "seed_bag",
            "watering_can",
            "hoe",
            "market_stall",
            "home",
            "chat_bubble",
            "calendar",
            "treasure_chest",
        ),
    ),
    PackSpec(
        key="town_rural_props",
        raw_name="ig_06b37ad1cea000ba016a187cd4c47c8191bba04dec276cc827.png",
        rows=4,
        cols=5,
        cell_size=(96, 96),
        fit=0.88,
        align="bottom",
        names=(
            "wooden_crate",
            "wicker_basket",
            "burlap_sack",
            "milk_can",
            "flower_pot",
            "wooden_stool",
            "lantern",
            "shovel",
            "barrel",
            "watering_trough",
            "clothesline_post",
            "bicycle",
            "market_signboard",
            "hay_bale",
            "bench",
            "bucket",
            "handcart",
            "broom",
            "mailbox",
            "street_lamp",
        ),
    ),
)


def remove_magenta(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            magenta_like = r > 160 and b > 160 and g < 150 and abs(r - b) < 70
            if magenta_like:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return rgba


def cleanup_magenta_fringe(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            magenta_spill = r > 110 and b > 110 and g < 130 and abs(r - b) < 80
            if magenta_spill:
                neutral = max(0, min(255, max(g, min(r, b)) - 12))
                pixels[x, y] = (neutral, neutral, neutral, a)
    return rgba


def trim_transparent(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    return img.crop(bbox)


def split_grid(img: Image.Image, rows: int, cols: int) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for row in range(rows):
        y0 = round(row * img.height / rows)
        y1 = round((row + 1) * img.height / rows)
        for col in range(cols):
            x0 = round(col * img.width / cols)
            x1 = round((col + 1) * img.width / cols)
            frames.append(img.crop((x0, y0, x1, y1)))
    return frames


def normalize_cell(frame: Image.Image, size: tuple[int, int], *, fit: float, align: str) -> Image.Image:
    frame = trim_transparent(remove_magenta(frame))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    bbox = frame.getbbox()
    if bbox is None:
        return canvas

    max_w = max(1, int(size[0] * fit))
    max_h = max(1, int(size[1] * fit))
    scale = min(max_w / frame.width, max_h / frame.height)
    new_size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    frame = frame.resize(new_size, Image.Resampling.LANCZOS)

    x = (size[0] - frame.width) // 2
    if align == "bottom":
        y = size[1] - frame.height - max(1, size[1] // 20)
    else:
        y = (size[1] - frame.height) // 2
    canvas.alpha_composite(frame, (x, y))
    return cleanup_magenta_fringe(canvas)


def compose(frames: list[Image.Image], rows: int, cols: int, cell_size: tuple[int, int]) -> Image.Image:
    sheet = Image.new("RGBA", (cols * cell_size[0], rows * cell_size[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, col = divmod(index, cols)
        sheet.alpha_composite(frame, (col * cell_size[0], row * cell_size[1]))
    return sheet


def write_tileset(path: Path, texture_path: Path, cols: int, rows: int, tile_size: int) -> None:
    resource_path = "res://" + str(texture_path.relative_to(ROOT))
    lines = [
        '[gd_resource type="TileSet" format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{resource_path}" id="1_tex"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_0"]',
        'texture = ExtResource("1_tex")',
        f"texture_region_size = Vector2i({tile_size}, {tile_size})",
    ]
    for y in range(rows):
        for x in range(cols):
            lines.append(f"{x}:{y}/0 = 0")
    lines.extend(
        [
            "",
            "[resource]",
            f"tile_size = Vector2i({tile_size}, {tile_size})",
            'sources/0 = SubResource("TileSetAtlasSource_0")',
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_pack(spec: PackSpec, manifest: dict) -> None:
    pack_dir = OUT / spec.key
    raw_out = pack_dir / "raw"
    items_dir = pack_dir / "items"
    pack_dir.mkdir(parents=True, exist_ok=True)
    raw_out.mkdir(parents=True, exist_ok=True)
    items_dir.mkdir(parents=True, exist_ok=True)

    raw_src = RAW_DIR / spec.raw_name
    raw_copy = raw_out / spec.raw_name
    shutil.copy2(raw_src, raw_copy)

    raw_img = Image.open(raw_src)
    raw_clean = remove_magenta(raw_img)
    raw_clean_path = pack_dir / f"{spec.key}_raw_clean.png"
    raw_clean.save(raw_clean_path)

    normalized = [
        normalize_cell(frame, spec.cell_size, fit=spec.fit, align=spec.align)
        for frame in split_grid(raw_img, spec.rows, spec.cols)
    ]
    sheet = compose(normalized, spec.rows, spec.cols, spec.cell_size)
    sheet_path = pack_dir / f"{spec.key}_sheet.png"
    sheet.save(sheet_path)

    items: dict[str, str] = {}
    for name, frame in zip(spec.names, normalized):
        item_path = items_dir / f"{name}.png"
        frame.save(item_path)
        items[name] = "res://" + str(item_path.relative_to(ROOT))

    manifest[spec.key] = {
        "sheet": "res://" + str(sheet_path.relative_to(ROOT)),
        "rows": spec.rows,
        "cols": spec.cols,
        "cell_size": list(spec.cell_size),
        "items": items,
    }

    if spec.key == "farm_plots":
        tileset_path = pack_dir / "farm_plots_tileset_64.tres"
        write_tileset(tileset_path, sheet_path, spec.cols, spec.rows, spec.cell_size[0])
        manifest[spec.key]["tileset"] = "res://" + str(tileset_path.relative_to(ROOT))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {"generated_at": "2026-05-29", "packs": len(PACKS)}
    for spec in PACKS:
        build_pack(spec, manifest)
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
