import json
import re
import gzip

from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen

CALIBRE_REPO = "kovidgoyal/calibre"
CALIBRE_PLUGINS_REPO_URL = "https://plugins.calibre-ebook.com/"
CALIBRE_PLUGIN_VERSION_PATTERN = r"[\s\S]+?<li>Version: <b>([\d\w.]+)</b></li>"
KINDLE_PREVIEWER_RELEASE_NOTES_URL = (
    "https://s3.amazonaws.com/kindlepreviewer/UG_ReleaseNotes_EN.txt"
)
KINDLE_PREVIEWER_URL = (
    "https://d2bzeorukaqrvt.cloudfront.net/KindlePreviewerInstaller.exe"
)
KINDLE_PREVIEWER_VERSION_PATTERN = r"New in Kindle Previewer (\d+(?:\.\d+){2,}):"
WINE_REPO_URL = "https://dl.winehq.org/wine-builds/debian/dists/"


def get_headers(url):
    with urlopen(Request(url, method="HEAD")) as response:
        return response.info()


def get_page(url):
    req = Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        },
    )
    with urlopen(req) as response:
        return response.read().decode("utf-8")


def get_json(url):
    with urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))


def get_file(url):
    with urlopen(url) as response:
        return response.read()


def get_kindle_previewer_version():
    try:
        page = get_page(KINDLE_PREVIEWER_RELEASE_NOTES_URL)
    except Exception:
        return None

    if version_match := re.search(KINDLE_PREVIEWER_VERSION_PATTERN, page, re.I):
        return version_match.group(1)
    return None


def convert_date(date_str):
    return str(datetime.strptime(date_str, "%a, %d %b %Y %H:%M:%S %Z")).split(" ")[0]


def main():
    base = (
        re.search(r"^FROM\s+([^\s]+)", Path("Dockerfile").read_text(), re.M)
        .group(1)
        .split("/")[-1]
        .split("@")[0]
    )
    debian_distribution = base.split("-")[-1]
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
    # Try to get version from release notes
    kindle_previewer_version = get_kindle_previewer_version()

    # Get installer date
    kindle_previewer_date = convert_date(
        get_headers(KINDLE_PREVIEWER_URL)["last-modified"]
    )
    wine = re.findall(
        r"Package: wine-stable[\s\S]+?Version: (.*)\n",
        gzip.decompress(
            get_file(
                f"{WINE_REPO_URL}{debian_distribution}/main/binary-amd64/Packages.gz"
            )
        ).decode("utf-8"),
        re.M,
    ).pop(0)
    if not all([base, calibre, kfx_input, kfx_output, wine]):
        exit()

    # Build kindle_previewer string in format "version (date)"
    kindle_previewer = (
        f"{kindle_previewer_version} ({kindle_previewer_date})"
        if kindle_previewer_version
        else kindle_previewer_date
    )

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
