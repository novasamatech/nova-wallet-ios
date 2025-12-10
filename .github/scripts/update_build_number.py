#!/usr/bin/env python3
"""
Simple script for updating CURRENT_PROJECT_VERSION (build number) in Xcode project file.
Can either increment the current build number or set it to a specific value.
"""

import argparse
import os
import re
import sys


def update_build_number(pbxproj_path, config_name, build_number=None):
    """
    Update CURRENT_PROJECT_VERSION in specific build configuration.

    Args:
        pbxproj_path: Path to project.pbxproj file
        config_name: Configuration name (e.g., 'Release', 'DevCI')
        build_number: If provided, set to this value. If None, increment current value.

    Returns:
        Tuple of (success: bool, new_build_number: int)
    """
    if not os.path.isfile(pbxproj_path):
        raise FileNotFoundError(f"Xcode project file not found at {pbxproj_path}")

    with open(pbxproj_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Find configuration block by name
    # Pattern: <config_id> /* <config_name> */ = { ... };
    config_pattern = (
        rf"(\w{{24}}\s*/\*\s*{re.escape(config_name)}\s*\*/\s*=\s*\{{[^}}]*?\}})"
    )
    config_match = re.search(config_pattern, content, re.DOTALL)

    if not config_match:
        raise ValueError(f"Could not find configuration block for '{config_name}'")

    # Find current build number in the config block
    config_block = config_match.group(0)
    build_match = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*(\d+);", config_block)

    if not build_match:
        raise ValueError(
            f"Could not find CURRENT_PROJECT_VERSION in {config_name} configuration"
        )

    current_build = int(build_match.group(1))

    if build_number is not None:
        # Set to specific value
        new_build = build_number
        action = "Set"
    else:
        # Increment current value
        new_build = current_build + 1
        action = "Incremented"

    # Update build number in the configuration block
    def update_block(match):
        block = match.group(0)
        block = re.sub(
            r"(CURRENT_PROJECT_VERSION\s*=\s*)\d+;", rf"\g<1>{new_build};", block
        )
        return block

    new_content = re.sub(config_pattern, update_block, content, flags=re.DOTALL)

    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(
        f"{action} CURRENT_PROJECT_VERSION: {current_build} -> {new_build} in {config_name} configuration"
    )
    return True, new_build


def main():
    parser = argparse.ArgumentParser(
        description="Update CURRENT_PROJECT_VERSION in Xcode project"
    )
    parser.add_argument("pbxproj", help="Path to project.pbxproj file")
    parser.add_argument(
        "--config-name",
        required=True,
        help="Configuration name (e.g., 'Release', 'DevCI')",
    )
    parser.add_argument(
        "--build-number",
        type=int,
        help="Set build number to this value (if not provided, will increment current value)",
    )
    parser.add_argument(
        "--output-github",
        action="store_true",
        help="Output in GitHub Actions format to GITHUB_OUTPUT",
    )

    args = parser.parse_args()

    try:
        success, new_build = update_build_number(
            args.pbxproj, args.config_name, args.build_number
        )

        if args.output_github and os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a") as f:
                f.write(f"new_build={new_build}\n")
                f.write(f"build_updated=true\n")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
