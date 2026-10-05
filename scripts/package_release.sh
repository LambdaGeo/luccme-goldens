#!/usr/bin/env bash
# ==============================================================================
# package_release.sh — Compute SHA-256 Checksums and Build Release ZIP Archive
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="${VERSION:-v1.1.0}"
# Image used to generate the goldens; prefer a digest (repo@sha256:...) so it is verifiable
DOCKER_IMAGE="${DOCKER_IMAGE:-profsergiocosta/terrame-luccme}"
case "$DOCKER_IMAGE" in
    *@sha256:*) ;;
    *) echo "Warning: DOCKER_IMAGE has no digest (@sha256:...); manifest.json will not pin the exact image." >&2 ;;
esac
ZIP_NAME="luccme-goldens-${VERSION}.zip"
CHECKSUMS_FILE="$ROOT_DIR/checksums.sha256"
MANIFEST_FILE="$ROOT_DIR/manifest.json"

mkdir -p "$RELEASE_DIR"

echo "========================================================================"
echo " Generating Checksums and Packaging Release: $VERSION"
echo "========================================================================"

cd "$ROOT_DIR"

# 1. Compute SHA-256 for all goldens
echo "==> Computing SHA-256 checksums..."
rm -f "$CHECKSUMS_FILE"
find goldens/ -type f \( -name "*.csv" -o -name "*.csv.gz" -o -name "*.shp" -o -name "*.dbf" -o -name "*.tif" -o -path "goldens/timing/*.json" \) | sort | while read -r f; do
    sha256sum "$f" >> "$CHECKSUMS_FILE"
done
cat "$CHECKSUMS_FILE"

# 2. Build manifest.json and create ZIP archive via Python standard library
echo "==> Building manifest.json and $ZIP_NAME..."
python3 -c "
import json, hashlib, os, glob, zipfile

files_info = []
for f in sorted(glob.glob('goldens/**/*.*', recursive=True)):
    if os.path.isfile(f) and not f.endswith('.sha256'):
        with open(f, 'rb') as fp:
            digest = hashlib.sha256(fp.read()).hexdigest()
        size = os.path.getsize(f)
        files_info.append({
            'path': f,
            'sha256': digest,
            'size_bytes': size
        })

manifest = {
    'name': 'luccme-goldens',
    'version': '$VERSION',
    'generator': 'TerraME 2.0.1 + LuccME 3.1 in Docker (Ubuntu 18.04)',
    'docker_image': '$DOCKER_IMAGE',
    'description': 'Canonical reference execution outputs (goldens) for LuccME simulation models and TerraME GIS fill operations.',
    'files': files_info
}

with open('$MANIFEST_FILE', 'w') as out:
    json.dump(manifest, out, indent=2)
print(f'Wrote {len(files_info)} artifacts to $MANIFEST_FILE')

# Create zip
zip_path = os.path.join('$RELEASE_DIR', '$ZIP_NAME')
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
    for base_file in ['README.md', 'LICENSE', 'checksums.sha256', 'manifest.json', 'Makefile']:
        if os.path.exists(base_file):
            z.write(base_file)
    for folder in ['goldens', 'sources', 'scripts']:
        for root, dirs, files in os.walk(folder):
            for file in files:
                full_path = os.path.join(root, file)
                z.write(full_path)

print(f'Created {zip_path} ({os.path.getsize(zip_path):,} bytes)')
"

echo "========================================================================"
echo " Packaging complete!"
echo " Release artifact: $RELEASE_DIR/$ZIP_NAME"
ls -lh "$RELEASE_DIR/$ZIP_NAME"
