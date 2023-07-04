import json
import re

from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen

CALIBRE_REPO = "kovidgoyal/calibre"
CALIBRE_PLUGINS_REPO_URL = "https://plugins.calibre-ebook.com/"
CALIBRE_PLUGIN_VERSION_PATTERN = r"[\s\S]+?<li>Version: <b>([\d\w.]+)</b></li>"
KINDLE_PREVIEWER_URL = (
    "https://d2bzeorukaqrvt.cloudfront.net/KindlePreviewerInstaller.exe"
)
WINE_REPO_URL = (
    "https://dl.winehq.org/wine-builds/debian/dists/bullseye/main/binary-amd64/"
)


def get_headers(url):
    with urlopen(Request(url, method="HEAD")) as response:
        return response.info()


def get_page(url):
    with urlopen(url) as response:
        return response.read().decode("utf-8")


def get_json(url):
    with urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))


def convert_date(date_str):
    return str(datetime.strptime(date_str, "%a, %d %b %Y %H:%M:%S %Z")).split(" ")[0]


def main():
    base = re.search(r"FROM (.*)", Path("Dockerfile").read_text()).group(1)
    calibre = get_json(f"https://api.github.com/repos/{CALIBRE_REPO}/releases")[0][
        "tag_name"
    ]
    calibre_plugins_page = get_page(CALIBRE_PLUGINS_REPO_URL)
    kfx_input = re.search(
        f"KFX Input{CALIBRE_PLUGIN_VERSION_PATTERN}",
        calibre_plugins_page,
        re.M,
    ).group(1)
    kfx_output = re.search(
        f"KFX Output{CALIBRE_PLUGIN_VERSION_PATTERN}",
        calibre_plugins_page,
        re.M,
    ).group(1)
    kindle_previewer = convert_date(get_headers(KINDLE_PREVIEWER_URL)["last-modified"])
    wine = re.findall(
        r"winehq-stable_(.*?)_amd64\.deb",
        get_page(WINE_REPO_URL),
        re.M,
    ).pop()
    if not all([base, calibre, kfx_input, kfx_output, kindle_previewer, wine]):
        exit()
    return json.dumps(
        {
            "base": base,
            "calibre": calibre,
            "kfx_input": kfx_input,
            "kfx_output": kfx_output,
            "kindle_previewer": kindle_previewer,
            "wine": wine,
        },
        indent=4,
    )


if __name__ == "__main__":

    Path("versions.json").write_text(main())
