"""Break down the largest observed update gaps from paired iOS probe reports."""

import json
import sys
from pathlib import Path


def summarize(report, peer):
    trace = {row["tick"]: row for row in report["tickTrace"]}
    peer_trace = {row["tick"]: row for row in peer["tickTrace"]}
    observed = report["observedTicks"]

    def interval(rows, start, end, field):
        before = rows.get(start, {}).get(field)
        after = rows.get(end, {}).get(field)
        if before is not None and after is not None:
            return round((after - before) / 1000, 2)
        return None

    gaps = []
    for before, after in zip(observed, observed[1:]):
        start, end = before["tick"], after["tick"]
        current = trace.get(end, {})
        cache, applied = current.get("cache"), current.get("applied")
        gaps.append({
            "fromTick": start,
            "toTick": end,
            "observedMs": round((after["observedUs"] - before["observedUs"]) / 1000, 2),
            "serverMs": interval(trace, start, end, "server"),
            "cacheMs": interval(trace, start, end, "cache"),
            "peerCacheMs": interval(peer_trace, start, end, "cache"),
            "appliedMs": interval(trace, start, end, "applied"),
            "cacheToAppliedMs": (
                round((applied - cache) / 1000, 2)
                if cache is not None and applied is not None else None
            ),
            "pollGapMs": round(after["pollGapUs"] / 1000, 2),
        })
    return sorted(gaps, key=lambda row: row["observedMs"], reverse=True)[:5]


if __name__ == "__main__":
    folder = Path(sys.argv[1])
    host, peer = [
        json.loads((folder / f"{role}-result.json").read_text())
        for role in ("host", "peer")
    ]
    print(json.dumps({
        "host": summarize(host, peer),
        "peer": summarize(peer, host),
    }, indent=2))
