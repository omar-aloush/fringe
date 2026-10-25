#!/usr/bin/env python3
"""
anchor-evidence.py — hash every evidence record and time-stamp the digests
into the Bitcoin blockchain via OpenTimestamps.

    python3 anchor-evidence.py stamp     # hash + submit digests -> .ots proofs
    python3 anchor-evidence.py upgrade   # upgrade once Bitcoin confirms (~48 h)
    python3 anchor-evidence.py status    # show manifest + proof state

Outputs (into Fringe/Resources/Evidence/):
    evidence-manifest.json   — schema, algorithm, generatedAt, per-record sha256
    evidence-<eventId>.ots   — OpenTimestamps proof per record
    evidence-manifest.ots    — proof for the manifest itself

Requires: pip3 install opentimestamps
Calendars: the public pool (a.pool.opentimestamps.org et al.) — free, no keys.
"""
import hashlib
import json
import os
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone

from opentimestamps.calendar import RemoteCalendar
from opentimestamps.core.op import OpSHA256
from opentimestamps.core.notary import BitcoinBlockHeaderAttestation, PendingAttestation
from opentimestamps.core.serialize import BytesSerializationContext, StreamDeserializationContext
from opentimestamps.core.timestamp import DetachedTimestampFile, Timestamp

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVIDENCE_DIR = os.path.join(ROOT, "Fringe", "Resources", "Evidence")
CALENDARS = [
    "https://a.pool.opentimestamps.org",
    "https://alice.btc.calendar.opentimestamps.org",
    "https://bob.btc.calendar.opentimestamps.org",
]


def record_files():
    paths = []
    for name in sorted(os.listdir(EVIDENCE_DIR)):
        if name.startswith("evidence-") and name.endswith(".json") and name != "evidence-manifest.json":
            paths.append(os.path.join(EVIDENCE_DIR, name))
    return paths


def write_manifest():
    records = []
    for path in record_files():
        with open(path, "rb") as f:
            sha = hashlib.sha256(f.read()).hexdigest()
        records.append({
            "eventId": os.path.basename(path)[len("evidence-"):-len(".json")],
            "file": os.path.basename(path),
            "sha256": sha,
        })
    manifest = {
        "schema": "fringe.evidence-manifest/1",
        "algorithm": "sha256",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "records": records,
    }
    out = os.path.join(EVIDENCE_DIR, "evidence-manifest.json")
    with open(out, "w") as f:
        json.dump(manifest, f, sort_keys=True)
        f.write("\n")
    return out


def ots_path(stem):
    return os.path.join(EVIDENCE_DIR, f"{stem}.ots")


def stamp():
    targets = [os.path.basename(p)[:-len(".json")] for p in record_files()]
    targets.append("evidence-manifest")
    for stem in targets:
        src = os.path.join(EVIDENCE_DIR, f"{stem}.json")
        with open(src, "rb") as f:
            data = f.read()
        digest = hashlib.sha256(data).digest()
        file_ts = DetachedTimestampFile(OpSHA256(), Timestamp(digest))

        got_attestation = False
        for cal in CALENDARS:
            try:
                remote = RemoteCalendar(cal)
                remote_ts = remote.submit(digest)
                file_ts.timestamp.merge(remote_ts)
                got_attestation = True
                break
            except Exception as exc:  # try the next calendar
                print(f"  {cal}: {exc}")
        if not got_attestation:
            print(f"FAILED to stamp {stem}")
            continue

        with open(ots_path(stem), "wb") as f:
            ctx = BytesSerializationContext()
            file_ts.serialize(ctx)
            f.write(ctx.getbytes())
        size = os.path.getsize(ots_path(stem))
        print(f"stamped: {stem} ({size} bytes, pending until Bitcoin confirmation)")
    print("\nProofs are PENDING until inclusion in a Bitcoin block (up to ~48 h).")
    print("Run 'anchor-evidence.py upgrade' later to attach the block header.")


def upgrade_timestamp(timestamp, timeout=30, depth=0):
    """Recursively upgrade pending attestations, mirroring `ots upgrade`."""
    if depth > 12:
        return False
    changed = False
    for _op, sub in list(timestamp.ops.items()):
        changed |= upgrade_timestamp(sub, timeout, depth + 1)
    atts = list(timestamp.attestations)
    if any(isinstance(a, BitcoinBlockHeaderAttestation) for a in atts):
        return changed
    if any(isinstance(a, PendingAttestation) for a in atts):
        for pending in atts:
            if not isinstance(pending, PendingAttestation):
                continue
            try:
                remote = RemoteCalendar(pending.uri.rstrip("/"))
                new_ts = remote.get_timestamp(timestamp.msg, timeout=timeout)
                upgrade_timestamp(new_ts, timeout, depth + 1)
                timestamp.merge(new_ts)
                changed = True
            except Exception as exc:
                print(f"  {pending.uri}: {exc}")
    return changed


def read_detached(path):
    with open(path, "rb") as f:
        ctx = StreamDeserializationContext(f)
        return DetachedTimestampFile.deserialize(ctx)


def upgrade():
    targets = [os.path.basename(p)[:-len(".json")] for p in record_files()]
    targets.append("evidence-manifest")
    for stem in targets:
        path = ots_path(stem)
        if not os.path.exists(path):
            print(f"missing: {stem}")
            continue
        file_ts = read_detached(path)
        upgraded = upgrade_timestamp(file_ts.timestamp)
        if upgraded:
            ctx = BytesSerializationContext()
            file_ts.serialize(ctx)
            with open(path, "wb") as f:
                f.write(ctx.getbytes())
            print(f"upgraded: {stem}")
        else:
            print(f"still pending: {stem}")


def status():
    manifest = os.path.join(EVIDENCE_DIR, "evidence-manifest.json")
    if os.path.exists(manifest):
        with open(manifest) as f:
            data = json.load(f)
        for rec in data["records"]:
            confirmed = is_confirmed(rec["eventId"])
            state = "CONFIRMED" if confirmed else "pending"
            print(f"  {rec['eventId']:<20} {rec['sha256'][:16]}…  {state}")
    else:
        print("no manifest yet")


def is_confirmed(stem):
    try:
        file_ts = read_detached(ots_path(stem))
    except FileNotFoundError:
        return False
    for msg, att in file_ts.timestamp.all_attestations():
        cls = type(att).__name__
        if "Bitcoin" in cls:
            return True
    return False


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    {"stamp": stamp, "upgrade": upgrade, "status": status}.get(mode, status)()
