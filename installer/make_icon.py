"""Generates the EduTrace app icon (multi-size .ico) from app_logo.png."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LOGO_PATH = ROOT / "flutter_application_1" / "assets" / "app_logo.png"
OUT = ROOT / "flutter_application_1" / "windows" / "runner" / "resources" / "app_icon.ico"
PREVIEW = OUT.parent / "app_icon_preview.png"

def make_icon() -> None:
    img = Image.open(LOGO_PATH).convert("RGBA")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sizes = [
        (16, 16),
        (20, 20),
        (24, 24),
        (32, 32),
        (40, 40),
        (48, 48),
        (64, 64),
        (96, 96),
        (128, 128),
        (256, 256),
    ]
    img.save(OUT, format="ICO", sizes=sizes)
    img.resize((512, 512), Image.Resampling.LANCZOS).save(PREVIEW)
    print("Saved EduTrace logo icon to:", OUT)

if __name__ == "__main__":
    make_icon()
