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


def created_device(runtime_identifier, name):
    device_types = simctl_list("devicetypes")["devicetypes"]
    device_type = next(
        (device_type["identifier"] for device_type in device_types if device_type["name"] == name),
        None,
    )
    if device_type is None:
        sys.exit(f"No simulator device type named {name}")
    print(f"Creating {name} on {runtime_identifier}", file=sys.stderr)
    return simctl("create", name, device_type, runtime_identifier).strip()


def available_runtime():
    deadline = time.monotonic() + TIMEOUT_SECONDS
    while True:
        try:
            runtime = latest_ios_runtime()
        except subprocess.CalledProcessError as error:
            print(f"simctl is not ready: {error.stderr.strip()}", file=sys.stderr)
            runtime = None
        if runtime is not None:
            return runtime
        if time.monotonic() >= deadline:
            sys.exit(f"No available iOS simulator runtime after {TIMEOUT_SECONDS} seconds")
        time.sleep(POLL_INTERVAL_SECONDS)


def main():
    name = sys.argv[1]
    runtime = available_runtime()
    identifier = runtime["identifier"]
    udid = existing_device(identifier, name) or created_device(identifier, name)
    print(f"Booting {name} ({udid}) on {runtime['name']}", file=sys.stderr)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, stdout=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
