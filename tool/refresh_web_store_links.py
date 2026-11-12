"""Resolve mobile download destinations from Regun's published release policies."""

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import urlopen


STORES = {
    "ios": {"apps.apple.com", "testflight.apple.com"},
    "android": {"play.google.com", "appdistribution.firebase.dev"},
}


def main():
    config_path, output_path = map(Path, sys.argv[1:])
    config = json.loads(config_path.read_text())
    endpoint = config.get("REGUN_IDENTITY_URL", "https://regunserver.kiishi.space")
    uri = urlsplit(endpoint)
    if (uri.scheme != "https" or not uri.hostname or uri.username is not None
            or uri.query or uri.fragment or uri.path.rstrip("/")):
        raise ValueError("Configure an HTTPS Regun identity origin")
    with urlopen(f"{endpoint.rstrip('/')}/app/v1/downloads", timeout=8) as response:
        data = json.loads(response.read(8192))
    links = {}
    for platform, hosts in STORES.items():
        value = data.get(platform)
        if value is None:
            links[platform] = None
            continue
        if not isinstance(value, str):
            raise ValueError(f"Invalid {platform} download link")
        link = urlsplit(value)
        if (link.scheme != "https" or link.hostname not in hosts or
                link.username is not None or link.port is not None or link.fragment or
                (link.hostname == "appdistribution.firebase.dev" and
                 not re.fullmatch(r"/i/[A-Za-z0-9_-]{6,}/?", link.path)) or
                (link.hostname == "testflight.apple.com" and
                 not re.fullmatch(r"/join/[A-Za-z0-9]{8}/?", link.path))):
            raise ValueError(f"Invalid {platform} download link")
        links[platform] = value
    temporary = output_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(links) + "\n")
    temporary.replace(output_path)
    print("Regun store destinations refreshed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(str(error))
