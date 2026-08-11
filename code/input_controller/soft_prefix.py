"""Soft Prefix生成 — bi/utils.py 完全互換"""
import base64, random, struct

P, H = 1, 1536
# mode A ランダム用。sensor_to_sp_b64 の離散値と統一 (2026-06-17 device99 実機整合)。
# エンコードは bi/utils.py 互換、値域のみ新スケール [0,0.1,1,10]。
VALS = [0.0, 0.1, 1.0, 10.0]

def f32_to_bf16_u16(x: float) -> int:
    return (struct.unpack("<I", struct.pack("<f", x))[0] >> 16) & 0xFFFF

def make_sp_b64(val: float, p: int = P, h: int = H) -> str:
    raw = struct.pack("<H", f32_to_bf16_u16(val)) * (p * h)
    return base64.b64encode(raw).decode("ascii")

def make_random_sp_b64(p: int = P, h: int = H) -> str:
    return make_sp_b64(random.choice(VALS), p, h)

def sensor_to_sp_b64(value: float, p: int = P, h: int = H) -> str:
    """0~1 → 離散VALS=[0,0.1,1,10]

    実機スイープ (2026-06-17, device99) で実効域 ≈(0,~100]、高応答(沈黙は)・豊か(光は)で
    4段階フルに振れることを確認し [0,1e-3,1e-2,1e-1] から上シフト。中応答(森が)は上段が飽和、
    暴れ系(水が)は val=10 で baseline に逆戻りする傾向。6/19 現場で AE 実 RMS 分布に合わせ
    閾値・刻みを微調整予定。
    """
    v = max(0.0, min(1.0, value))
    if   v < 0.25: s = 0.0
    elif v < 0.5:  s = 0.1
    elif v < 0.75: s = 1.0
    else:          s = 10.0
    return make_sp_b64(s, p, h)
