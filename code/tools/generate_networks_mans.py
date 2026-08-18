#!/usr/bin/env python3
"""Generate networks CSV for the MANS 2026 deployment (30-50 units, 3-5 clusters).

Devices keep their factory-set IDs (= last octet of the static IP already
configured on each unit), so the topology is built over whatever sparse set
of IDs survives the fleet check. The single source of truth is a hand-edited
cluster map:

    id,cluster,note
    23,A,east gate side
    31,A,
    47,B,

Topology:
  - Within a cluster: bidirectional ring over sorted IDs (each node targets
    prev,next). Survives a single dead unit (tokens reroute the other way).
  - --skip N adds a forward shortcut (node -> +N positions) like the original
    CCBT layout, for extra redundancy.
  - Between clusters (default ON): one-way ring of clusters. The gate node
    (lowest ID) of each cluster also targets the gate of the next cluster,
    so generated tokens migrate across the whole installation.
    --no-bridge produces fully isolated clusters instead.

Output keeps the CCBT 100-row format (ID,IP,To with IP=10.0.0.<id>); rows for
unused IDs get an empty To and are inert. Compatible with
utils/network_config.py and the monitor's node_ip() convention.

Usage:
  python3 tools/generate_networks_mans.py config/cluster_map_mans.csv \
      -o config/networks_mans.csv [--no-bridge] [--skip N]
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import OrderedDict
from pathlib import Path

MAX_ID = 100


def load_cluster_map(path: Path) -> "OrderedDict[str, list[int]]":
    clusters: "OrderedDict[str, list[int]]" = OrderedDict()
    seen: dict[int, str] = {}
    errors = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None or "id" not in reader.fieldnames or "cluster" not in reader.fieldnames:
            sys.exit(f"ERROR: {path} must have header columns 'id,cluster'")
        for lineno, row in enumerate(reader, start=2):
            raw_id = (row.get("id") or "").strip()
            cluster = (row.get("cluster") or "").strip()
            if not raw_id and not cluster:
                continue  # blank line
            try:
                device_id = int(raw_id)
            except ValueError:
                errors.append(f"line {lineno}: id '{raw_id}' is not an integer")
                continue
            if not (1 <= device_id <= MAX_ID):
                errors.append(f"line {lineno}: id {device_id} out of range 1-{MAX_ID}")
                continue
            if not cluster:
                errors.append(f"line {lineno}: id {device_id} has no cluster")
                continue
            if device_id in seen:
                errors.append(
                    f"line {lineno}: id {device_id} already assigned to cluster {seen[device_id]}"
                )
                continue
            seen[device_id] = cluster
            clusters.setdefault(cluster, []).append(device_id)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    if not clusters:
        sys.exit("ERROR: cluster map is empty")
    for ids in clusters.values():
        ids.sort()
    return clusters


def build_targets(
    clusters: "OrderedDict[str, list[int]]", bridge: bool, skip: int
) -> dict[int, list[int]]:
    targets: dict[int, list[int]] = {}
    warnings = []

    for name, ids in clusters.items():
        n = len(ids)
        if n == 1:
            warnings.append(f"cluster {name} has a single node (id {ids[0]}): no intra-cluster relay")
            targets[ids[0]] = []
            continue
        for i, device_id in enumerate(ids):
            prev_id = ids[(i - 1) % n]
            next_id = ids[(i + 1) % n]
            tgt = [prev_id, next_id]
            if skip > 0 and n > 2:
                tgt.append(ids[(i + skip) % n])
            # dedupe, drop self, keep order
            uniq = []
            for t in tgt:
                if t != device_id and t not in uniq:
                    uniq.append(t)
            targets[device_id] = uniq

    if bridge and len(clusters) > 1:
        names = sorted(clusters.keys())
        for i, name in enumerate(names):
            gate = clusters[name][0]
            next_gate = clusters[names[(i + 1) % len(names)]][0]
            if next_gate != gate and next_gate not in targets[gate]:
                targets[gate].append(next_gate)

    for w in warnings:
        print(f"WARNING: {w}", file=sys.stderr)
    return targets


def write_csv(path: Path, targets: dict[int, list[int]]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ID", "IP", "To"])
        for device_id in range(1, MAX_ID + 1):
            to = ",".join(str(t) for t in targets.get(device_id, []))
            writer.writerow([device_id, f"10.0.0.{device_id}", to])


def print_summary(
    clusters: "OrderedDict[str, list[int]]", targets: dict[int, list[int]], bridge: bool, skip: int
) -> None:
    total = sum(len(v) for v in clusters.values())
    print(f"clusters={len(clusters)} devices={total} bridge={'on' if bridge else 'off'} skip={skip}")
    names = sorted(clusters.keys())
    for name in names:
        ids = clusters[name]
        print(f"  [{name}] n={len(ids)} gate={ids[0]} ids={ids}")
    if bridge and len(names) > 1:
        chain = " -> ".join(f"{name}:{clusters[name][0]}" for name in names)
        first = names[0]
        print(f"  bridges: {chain} -> {first}:{clusters[first][0]}")
    # verify every target is an active device
    active = {i for ids in clusters.values() for i in ids}
    bad = {
        (src, t) for src, tgts in targets.items() for t in tgts if t not in active
    }
    if bad:
        for src, t in sorted(bad):
            print(f"ERROR: {src} targets inactive id {t}", file=sys.stderr)
        sys.exit(1)
    print("  verify: all targets active OK")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("cluster_map", type=Path, help="cluster map CSV (id,cluster[,note])")
    ap.add_argument("-o", "--output", type=Path, required=True, help="output networks CSV")
    ap.add_argument("--no-bridge", action="store_true", help="isolated clusters (no inter-cluster links)")
    ap.add_argument("--skip", type=int, default=0, metavar="N",
                    help="extra forward shortcut +N inside each cluster (CCBT style), default off")
    args = ap.parse_args()

    clusters = load_cluster_map(args.cluster_map)
    targets = build_targets(clusters, bridge=not args.no_bridge, skip=args.skip)
    write_csv(args.output, targets)
    print_summary(clusters, targets, bridge=not args.no_bridge, skip=args.skip)
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
