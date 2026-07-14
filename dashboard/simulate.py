"""
simulate.py — ANCHORPULSE / Point Rescue Node Simulator
========================================================
ALAT PENGEMBANGAN (bukan pengganti perangkat asli).

Menulis beberapa node SAR & KORBAN "palsu" yang bergerak pelan ke gps.json,
persis format yang dihasilkan serial_listener.py. Berguna untuk mencoba
dashboard + fitur jarak antar node TANPA perlu 3 unit ESP32.

Catatan: GATEWAY sengaja TIDAK disimulasikan di sini. Gateway tidak punya
modul GPS, jadi posisinya ditetapkan sebagai titik base tetap di dashboard
(CONFIG.GATEWAY_BASE di script.js), bukan dari gps.json.

Cara pakai:
    python simulate.py                       # 2 SAR + 2 KORBAN, update tiap 1 dtk
    python simulate.py --sar 3 --korban 2
    python simulate.py --sos 2001            # node 2001 mengirim SOS
    python simulate.py --interval 0.5 --step 10

Jalankan bersamaan dengan server:
    Terminal 1: python server.py
    Terminal 2: python simulate.py
    Browser   : http://localhost:8000
"""

import argparse
import json
import math
import os
import random
import sys
import time
from pathlib import Path

GPS_JSON_PATH = Path(__file__).parent / "gps.json"

# Pusat sebaran node lapangan (dekat pusat peta default di script.js).
DEFAULT_CENTER = (-7.953850, 112.614955)

ROLE_SAR = 1
ROLE_KORBAN = 2
ROLE_NAMES = {0: "GATEWAY", 1: "SAR", 2: "KORBAN"}


def meters_to_deg(d_north_m: float, d_east_m: float, lat: float) -> tuple[float, float]:
    """Konversi pergeseran meter (utara, timur) ke selisih derajat (lat, lng)."""
    dlat = d_north_m / 111_320.0
    dlng = d_east_m / (111_320.0 * math.cos(math.radians(lat)))
    return dlat, dlng


class SimNode:
    """Satu node simulasi dengan gerak acak (random walk) yang halus."""

    def __init__(self, node_id: int, role: int, center: tuple[float, float],
                 spread_m: float, is_sos: bool):
        self.node_id = node_id
        self.role = role
        self.is_sos = is_sos
        self.seq = 0

        # Posisi awal: offset acak dari pusat dalam radius `spread_m`
        ang = random.uniform(0, 2 * math.pi)
        rad = random.uniform(0, spread_m)
        dlat, dlng = meters_to_deg(rad * math.sin(ang), rad * math.cos(ang), center[0])
        self.lat = center[0] + dlat
        self.lng = center[1] + dlng

        # Arah gerak awal (radian) — berubah pelan tiap tick agar tidak patah-patah
        self.heading = random.uniform(0, 2 * math.pi)
        self.altitude = round(random.uniform(500, 540), 1)

    def step(self, step_m: float) -> None:
        """Gerakkan node sejauh <= step_m meter ke arah heading (dengan sedikit belok)."""
        self.heading += random.uniform(-0.4, 0.4)
        dist = random.uniform(0, step_m)
        d_north = dist * math.cos(self.heading)
        d_east = dist * math.sin(self.heading)
        dlat, dlng = meters_to_deg(d_north, d_east, self.lat)
        self.lat += dlat
        self.lng += dlng
        self.altitude = round(self.altitude + random.uniform(-0.3, 0.3), 1)
        self.seq += 1
        # Kecepatan (m/s) diperkirakan dari jarak tempuh tick ini
        self.speed = round(dist, 3)

    @property
    def device_id(self) -> str:
        return f"{ROLE_NAMES[self.role]}-{self.node_id}"

    def to_entry(self) -> dict:
        return {
            "device_id": self.device_id,
            "latitude": round(self.lat, 7),
            "longitude": round(self.lng, 7),
            "altitude": self.altitude,
            "speed": getattr(self, "speed", 0.0),
            "satellites": random.randint(8, 12),
            "gps_valid": True,
            "last_seen": time.time(),   # sama seperti field yang ditulis serial_listener.py
            "role": ROLE_NAMES[self.role],
            "seq": self.seq,
            "is_sos": self.is_sos,
        }


def write_gps_json(nodes: list[SimNode]) -> None:
    """Tulis semua node ke gps.json secara atomik (temp lalu replace)."""
    data = [n.to_entry() for n in nodes]
    tmp = GPS_JSON_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.replace(tmp, GPS_JSON_PATH)


def build_nodes(args) -> list[SimNode]:
    center = tuple(float(x) for x in args.center.split(","))  # type: ignore
    sos_ids = set()
    if args.sos:
        for part in args.sos.split(","):
            part = part.strip()
            if part:
                sos_ids.add(int(part))

    nodes: list[SimNode] = []
    for i in range(args.sar):
        nid = 1001 + i
        nodes.append(SimNode(nid, ROLE_SAR, center, args.spread, nid in sos_ids))
    for i in range(args.korban):
        nid = 2001 + i
        nodes.append(SimNode(nid, ROLE_KORBAN, center, args.spread, nid in sos_ids))
    return nodes


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Point Rescue — simulator node (SAR & KORBAN) untuk demo dashboard tanpa hardware"
    )
    parser.add_argument("--sar", type=int, default=2, help="Jumlah node SAR (default 2)")
    parser.add_argument("--korban", type=int, default=2, help="Jumlah node KORBAN (default 2)")
    parser.add_argument("--interval", type=float, default=1.0, help="Jeda update detik (default 1.0)")
    parser.add_argument("--step", type=float, default=6.0, help="Gerak maksimum per update, meter (default 6)")
    parser.add_argument("--spread", type=float, default=250.0, help="Radius sebaran awal dari pusat, meter (default 250)")
    parser.add_argument("--center", default=f"{DEFAULT_CENTER[0]},{DEFAULT_CENTER[1]}",
                        help="Pusat sebaran 'lat,lng' (default pusat peta)")
    parser.add_argument("--sos", default="", help="Daftar NODE_ID yang mengirim SOS, dipisah koma (mis. 2001,1001)")
    args = parser.parse_args()

    if args.sar + args.korban < 1:
        print("[ERROR] Minimal harus ada 1 node (SAR atau KORBAN).")
        sys.exit(1)

    nodes = build_nodes(args)

    print("\n[SIM]  ANCHORPULSE Node Simulator (alat pengembangan)")
    print(f"[SIM]  Output : {GPS_JSON_PATH.resolve()}")
    print(f"[SIM]  Node   : {args.sar} SAR + {args.korban} KORBAN = {len(nodes)} total")
    print(f"[SIM]  Update : tiap {args.interval} detik, gerak <= {args.step} m")
    if args.sos:
        print(f"[SIM]  SOS    : {args.sos}")
    print("[SIM]  Tekan Ctrl+C untuk berhenti.\n")

    try:
        while True:
            for n in nodes:
                n.step(args.step)
            write_gps_json(nodes)
            summary = ", ".join(
                f"{n.device_id}{'(SOS)' if n.is_sos else ''}" for n in nodes
            )
            print(f"[SIM]  tick → {summary}")
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[STOP] Simulator dihentikan.")
        # Kosongkan gps.json agar dashboard menunjukkan 'no devices'
        GPS_JSON_PATH.write_text("[]", encoding="utf-8")
        sys.exit(0)


if __name__ == "__main__":
    main()
