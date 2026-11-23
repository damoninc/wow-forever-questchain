"""Install Blizzard's Forever dungeon card screenshots for local playtesting.

Requires Pillow. Pass the installed ForeverQuestChain directory as addon_dir.
"""

import argparse
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen

from PIL import Image, ImageOps


# https://news.blizzard.com/en-us/article/24301455/explore-the-new-dungeons-of-world-of-warcraft-forever
MEDIA_URL = "https://bnetcmsus-a.akamaihd.net/cms/content_entry_media/"
SCREENSHOTS = {
    "CityOfDalaran": "ha/HARQTHBQCYMR1792014060266.png",
    "RuinsOfLordaeron": "GTBUD9QLE3XW1792014833094.png",
    "ExcavationSiteWetlands": "TFBBUPOTALTZ1792014832338.png",
    "HallOfThanes": "XRAT25OFDIIQ1792014832498.png",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("addon_dir", type=Path)
    args = parser.parse_args()
    if not (args.addon_dir / "ForeverQuestChain.toc").is_file():
        parser.error("addon_dir must contain ForeverQuestChain.toc")

    cards = {}
    for name, path in SCREENSHOTS.items():
        with urlopen(MEDIA_URL + path, timeout=20) as response:
            source = response.read()
        with Image.open(BytesIO(source)) as screenshot:
            card = ImageOps.fit(screenshot.convert("RGB"), (175, 95), Image.Resampling.LANCZOS)
        # Match the journal button's upper-left image region in a power-of-two texture.
        texture = Image.new("RGB", (256, 128))
        texture.paste(card, (0, 0))
        cards[name] = texture

    directory = args.addon_dir / "Media" / "DungeonCards"
    directory.mkdir(parents=True, exist_ok=True)
    for name, texture in cards.items():
        path = directory / f"{name}.tga"
        texture.save(path)
        print(path)


if __name__ == "__main__":
    main()
