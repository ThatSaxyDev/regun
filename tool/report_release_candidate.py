"""Register release metadata after distribution upload. Does not publish."""

import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--origin", required=True)
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument("--platform", required=True, choices=("ios", "android", "macos"))
    parser.add_argument("--channel", required=True, choices=("production", "beta"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()
    origin = urlsplit(args.origin)
    if (origin.scheme != "https" or not origin.hostname or origin.username is not None
            or origin.path.rstrip("/") or origin.query or origin.fragment):
        parser.error("Use an HTTPS Regun identity origin")
    token = args.token_file.read_text().strip()
    if not token or not all(char.isascii() and (char.isalnum() or char in "_-") for char in token):
        parser.error("Invalid release pipeline token")
    body = {field: getattr(args, field) for field in ("platform", "channel", "version", "build", "source")}
    request = Request(
        f"{args.origin.rstrip('/')}/app/v1/release-candidate",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with build_opener(NoRedirects()).open(request, timeout=12) as response:
            if json.loads(response.read(4096)).get("ok") is not True:
                parser.error("The server did not accept this candidate")
    except (OSError, ValueError):
        parser.error("The server could not register this release candidate")
    print(f"Registered {args.platform} {args.version} ({args.build}) for review.")


if __name__ == "__main__":
    main()
