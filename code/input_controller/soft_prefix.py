"""Soft Prefix生成 — bi/utils.py 完全互換"""
import base64, random, struct

P, H = 1, 1536
VALS = [0.0, 1e-4, 1e-3, 1e-2]

def f32_to_bf16_u16(x: float) -> int:
    return (struct.unpack("<I", struct.pack("<f", x))[0] >> 16) & 0xFFFF

def make_sp_b64(val: float, p: int = P, h: int = H) -> str:
    raw = struct.pack("<H", f32_to_bf16_u16(val)) * (p * h)
    return base64.b64encode(raw).decode("ascii")

def make_random_sp_b64(p: int = P, h: int = H) -> str:
    return make_sp_b64(random.choice(VALS), p, h)

def sensor_to_sp_b64(value: float, p: int = P, h: int = H) -> str:
    """0~1 → 離散VALS=[0,1e-3,1e-2,1e-1]

    TinySwallow-1.5B/H=1536 用に上シフト (2026-06-16)。旧 [0,1e-4,1e-3,1e-2] は
    下2段がほぼ無変化で実質2段階だった。感度曲線で 1e-1 でも崩壊せず詩的に変化を確認。
    """
    v = max(0.0, min(1.0, value))
    if   v < 0.25: s = 0.0
    elif v < 0.5:  s = 1e-3
    elif v < 0.75: s = 1e-2
    else:          s = 1e-1
    return make_sp_b64(s, p, h)
