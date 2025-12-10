#!/usr/bin/env python3
"""
Simple script for updating MARKETING_VERSION in Xcode project file.
"""

import argparse
import os
import re
import sys


def update_marketing_version(pbxproj_path, config_name, new_version):
    """
    Update MARKETING_VERSION in specific build configuration.

    Args:
        pbxproj_path: Path to project.pbxproj file
        config_name: Configuration name (e.g., 'Release', 'DevCI')
        new_version: New MARKETING_VERSION (X.Y format)
    """
    if not os.path.isfile(pbxproj_path):
        raise FileNotFoundError(f"Xcode project file not found at {pbxproj_path}")

    # Validate version format (supports X.Y or X.Y.Z)
    if not re.match(r"^\d+\.\d+(?:\.\d+)?$", new_version):
        raise ValueError(
            f"Invalid version format: {new_version}. Must be X.Y or X.Y.Z format"
        )

    with open(pbxproj_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Find configuration block and update MARKETING_VERSION within it
    # Pattern: <config_id> /* <config_name> */ = { ... };
    config_pattern = (
        rf"(\w{{24}}\s*/\*\s*{re.escape(config_name)}\s*\*/\s*=\s*\{{[^}}]*?\}})"
    )

    def update_block(match):
        block = match.group(0)
        block = re.sub(
            r"(MARKETING_VERSION\s*=\s*)[0-9]+\.[0-9]+(?:\.[0-9]+)?;",
            rf"\g<1>{new_version};",
            block,
        )
        return block

    new_content, replacements = re.subn(
        config_pattern, update_block, content, flags=re.DOTALL
    )

    if replacements == 0:
        raise ValueError(f"Could not find configuration block for '{config_name}'")

    # Check if version was actually changed
    if new_content == content:
        print(f"MARKETING_VERSION is already {new_version}")
        return False

    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"Updated MARKETING_VERSION to {new_version} in {config_name} configuration")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Update MARKETING_VERSION in Xcode project"
    )
    parser.add_argument("pbxproj", help="Path to project.pbxproj file")
    parser.add_argument("version", help="New MARKETING_VERSION (X.Y format)")
    parser.add_argument(
        "--config-name",
        required=True,
        help="Configuration name (e.g., 'Release', 'DevCI')",
    )

    args = parser.parse_args()

    try:
        updated = update_marketing_version(args.pbxproj, args.config_name, args.version)

        if not updated:
            sys.exit(0)  # No changes needed

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
