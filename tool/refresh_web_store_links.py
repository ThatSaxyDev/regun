"""Resolve mobile download destinations from the Regun Telling release policy."""

import json
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlencode, urlsplit


STORE_HOSTS = {
    "ios": {"apps.apple.com", "testflight.apple.com"},
    "android": {
        "play.google.com",
        "appdistribution.firebase.dev",
        "appdistribution.firebase.google.com",
    },
}


def store_link(endpoint, key, platform):
    query = urlencode({"platform": platform, "version": "0.0.0", "build": "0"})
    # Read the header from stdin so the project key stays out of the process args.
    response = subprocess.run(
        ["curl", "--fail", "--silent", "--show-error", "--max-time", "8",
         "--header", "@-", f"{endpoint}/project/version-check?{query}"],
        input=f"x-api-key: {key}\n",
        text=True,
        capture_output=True,
    )
    if response.returncode:
        raise ValueError(f"Telling could not resolve the {platform} release policy")
    value = json.loads(response.stdout).get("storeUrl")
    if not isinstance(value, str) or not value.strip():
        return None
    value = value.strip()
    uri = urlsplit(value)
    if (uri.scheme != "https" or uri.hostname not in STORE_HOSTS[platform]
            or uri.username is not None or uri.port is not None or uri.fragment):
        raise ValueError(f"Telling returned an invalid {platform} store URL")
    return value


def main():
    config_path, output_path = map(Path, sys.argv[1:])
    config = json.loads(config_path.read_text())
    endpoint = config.get(
        "TELLING_API_URL", "https://telling-api.kiishi.space/api/v1"
    ).rstrip("/")
    uri = urlsplit(endpoint)
    key = config.get("TELLING_PROJECT_KEY", "").strip()
    if (uri.scheme != "https" or not uri.hostname or uri.username is not None
            or uri.query or uri.fragment or not key or "\r" in key or "\n" in key):
        raise ValueError("Configure an HTTPS Telling endpoint and project key")
    links = {platform: store_link(endpoint, key, platform) for platform in STORE_HOSTS}
    temporary = output_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(links) + "\n")
    temporary.replace(output_path)
    print("Telling store destinations resolved for " +
          ", ".join(platform for platform, link in links.items() if link))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(str(error))
