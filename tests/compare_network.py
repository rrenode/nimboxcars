"""Compare network output with rrrocket built against boxcars 0.10.11.

Usage: python tests/compare_network.py --nim EXE [--reference rrrocket] [REPLAY ...]
Only network_frames is compared; floats allow small f32 rounding differences.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess


def compare(actual, expected, path="network_frames"):
    if isinstance(expected, dict):
        assert isinstance(actual, dict) and actual.keys() == expected.keys(), path
        for key in expected:
            compare(actual[key], expected[key], f"{path}.{key}")
    elif isinstance(expected, list):
        assert isinstance(actual, list) and len(actual) == len(expected), path
        for index, (left, right) in enumerate(zip(actual, expected)):
            compare(left, right, f"{path}[{index}]")
    elif isinstance(expected, float):
        assert isinstance(actual, (int, float)) and math.isclose(
            actual, expected, rel_tol=2e-6, abs_tol=2e-6
        ), f"{path}: {actual!r} != {expected!r}"
    else:
        assert type(actual) is type(expected) and actual == expected, (
            f"{path}: {actual!r} != {expected!r}"
        )


def output(command):
    completed = subprocess.run(command, check=True, capture_output=True)
    return json.loads(completed.stdout.decode("utf-8"))["network_frames"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nim", required=True)
    parser.add_argument("--reference", default="rrrocket")
    parser.add_argument("replays", nargs="*", type=Path)
    args = parser.parse_args()
    fixtures = args.replays or sorted((Path(__file__).parent / "replays").glob("*.replay"))
    if not fixtures:
        parser.error("No replay fixtures found")
    for fixture in fixtures:
        actual = output([args.nim, "--netdata:all", "--crc", "--json", str(fixture)])
        expected = output([args.reference, "-n", str(fixture)])
        assert actual is not None and expected is not None, "Network output is absent"
        compare(actual, expected)
        print(f"PASS {fixture.name}: {len(actual['frames'])} frames")


if __name__ == "__main__":
    main()
