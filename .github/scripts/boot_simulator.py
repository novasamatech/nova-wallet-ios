#!/usr/bin/env python3
import json
import subprocess
import sys
import time

TIMEOUT_SECONDS = 300
POLL_INTERVAL_SECONDS = 5


def simctl(*args):
    return subprocess.run(
        ["xcrun", "simctl", *args], check=True, capture_output=True, text=True
    ).stdout


def simctl_list(*args):
    return json.loads(simctl("list", *args, "-j"))


def version_key(version):
    return tuple(int(part) for part in version.split("."))


def latest_ios_runtime():
    runtimes = [
        runtime
        for runtime in simctl_list("runtimes", "available")["runtimes"]
        if runtime.get("platform") == "iOS" and runtime.get("isAvailable")
    ]
    return max(runtimes, key=lambda runtime: version_key(runtime["version"]), default=None)


def existing_device(runtime_identifier, name):
    devices = simctl_list("devices", "available")["devices"].get(runtime_identifier, [])
    return next((device["udid"] for device in devices if device["name"] == name), None)


def available_device(name):
    deadline = time.monotonic() + TIMEOUT_SECONDS
    runtime = None
    while True:
        try:
            runtime = latest_ios_runtime()
            udid = existing_device(runtime["identifier"], name) if runtime is not None else None
        except subprocess.CalledProcessError as error:
            print(f"simctl is not ready: {error.stderr.strip()}", file=sys.stderr)
            udid = None
        if udid is not None:
            return runtime, udid
        if time.monotonic() >= deadline:
            runtime_name = runtime["name"] if runtime is not None else "no iOS runtime"
            sys.exit(f"No available {name} simulator on {runtime_name} after {TIMEOUT_SECONDS} seconds")
        time.sleep(POLL_INTERVAL_SECONDS)


def main():
    name = sys.argv[1]
    runtime, udid = available_device(name)
    print(f"Booting {name} ({udid}) on {runtime['name']}", file=sys.stderr)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, stdout=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
