"""Implementasi acuan Rng (xorshift32) untuk menghitung nilai emas.

Harus identik dengan packages/question_engine/lib/src/rng.dart. Nilai di
packages/question_engine/test/rng_test.dart dihitung dari skrip ini:

    python tool/rng_reference.py
"""

MASK = 0xFFFFFFFF
ZERO_SEED_STATE = 0x6D2B79F5
WARM_UP = 8
DERIVE_MULTIPLIER = 0x9E3779B1


class Rng:
    def __init__(self, seed):
        s = seed & MASK
        self.state = ZERO_SEED_STATE if s == 0 else s
        for _ in range(WARM_UP):
            self.next_uint32()

    @staticmethod
    def derive(seed, attempt):
        return Rng((seed ^ ((attempt * DERIVE_MULTIPLIER) & MASK)) & MASK)

    def next_uint32(self):
        x = self.state
        x ^= (x << 13) & MASK
        x ^= x >> 17
        x ^= (x << 5) & MASK
        self.state = x
        return x

    def next_int(self, max_):
        limit = (0x100000000 // max_) * max_
        while True:
            v = self.next_uint32()
            if v < limit:
                return v % max_

    def next_bool(self):
        return self.next_int(2) == 1

    def pick(self, items):
        return items[self.next_int(len(items))]

    def shuffle(self, items):
        out = list(items)
        for i in range(len(out) - 1, 0, -1):
            j = self.next_int(i + 1)
            out[i], out[j] = out[j], out[i]
        return out


def take(r, n):
    return [r.next_uint32() for _ in range(n)]


if __name__ == "__main__":
    for seed in (1, 42, 123456789, 0):
        print(f"Rng({seed}).nextUint32 x5", take(Rng(seed), 5))
    r = Rng(42)
    print("Rng(42).nextInt(10) x10", [r.next_int(10) for _ in range(10)])
    r = Rng(7)
    print("Rng(7).nextInt(6) x12", [r.next_int(6) for _ in range(12)])
    print("derive(100, 3) x3", take(Rng.derive(100, 3), 3))
    print("derive(100, 0xFFFFFFFF) x3", take(Rng.derive(100, 0xFFFFFFFF), 3))
    print("derive(0xDEADBEEF, 19) x3", take(Rng.derive(0xDEADBEEF, 19), 3))
    print("Rng(-1).nextUint32 x3", take(Rng(-1), 3))
    print("Rng(2^40 + 5).nextUint32 x3", take(Rng(2**40 + 5), 3))
    r = Rng(2024)
    print("Rng(2024).nextBool x12", [r.next_bool() for _ in range(12)])
    r = Rng(3)
    print("Rng(3).nextInt(1000000007) x4", [r.next_int(1000000007) for _ in range(4)])
    r = Rng(11)
    print("Rng(11).pick(A-H) x8", [r.pick("ABCDEFGH") for _ in range(8)])
    print("Rng(5).shuffle(0..9)", Rng(5).shuffle(range(10)))
    r = Rng(9)
    print("Rng(9).shuffle(0..7) x2", r.shuffle(range(8)), r.shuffle(range(8)))
