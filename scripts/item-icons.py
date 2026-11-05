#!/usr/bin/env python3
"""Turns item model renders into transparent UI icons.

Each model's preview.png (from `scripts/build-model.sh <Model>`) is rendered
on a flat grey; this keys the grey out, crops to the model, centres it in a
square and writes art/ui/Items/<Icon>.png at 128px, ready for
`scripts/upload-ui.sh Items <Icon>...`.

    scripts/item-icons.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "ui" / "Items"
SIZE = 128
# Colour distance (summed over RGB) under which a pixel is background, and
# the band above it that fades in so edges stay soft.
CLEAR, SOFT = 18, 22

# Icon name: model folder. Items use Item<ItemId>, weapons Weapon<Name>.
ICONS = {
    "ItemRustyGear": "RustyGear",
    "ItemBentBolt": "BentBolt",
    "ItemCopperCoil": "CopperCoil",
    "ItemOldBattery": "OldBattery",
    "ItemCircuitBoard": "CircuitBoard",
    "ItemServoMotor": "ServoMotor",
    "ItemReactorCore": "ReactorCore",
    "ItemGoldenCog": "GoldenCog",
    "WeaponBat": "StarterWeapon",
    "WeaponSpanner": "BigSpanner",
}


def key_out(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    background = image.getpixel((2, 2))[:3]
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            distance = abs(r - background[0]) + abs(g - background[1]) + abs(b - background[2])
            if distance < CLEAR:
                pixels[x, y] = (r, g, b, 0)
            elif distance < CLEAR + SOFT:
                pixels[x, y] = (r, g, b, int(255 * (distance - CLEAR) / SOFT))
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for icon, model in ICONS.items():
        preview = ROOT / "art" / "models" / model / "preview.png"
        if not preview.exists():
            raise SystemExit(f"no {preview}; build it with: scripts/build-model.sh {model}")
        keyed = key_out(Image.open(preview))
        keyed = keyed.crop(keyed.getbbox())
        side = max(keyed.size)
        square = Image.new("RGBA", (side, side))
        square.paste(keyed, ((side - keyed.width) // 2, (side - keyed.height) // 2))
        square.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{icon}.png")
        print(f"item-icons: {icon}")


if __name__ == "__main__":
    main()
