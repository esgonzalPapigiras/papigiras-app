#!/usr/bin/env python3
"""Read-only AAB ELF + bundle packaging validation. Does not sign or publish.

Reference: https://developer.android.com/guide/practices/page-sizes
Runtime testing on a 16 KB Android device is still required.
"""
import argparse
import hashlib
import json
import struct
import subprocess
import zipfile
from pathlib import Path

PAGE = 16384


def inspect_elf(data):
    if data[:4] != b'\x7fELF':
        raise ValueError('Expected ELF shared library')
    bits = {1: 32, 2: 64}[data[4]]
    endian = {1: '<', 2: '>'}[data[5]]
    if bits == 64:
        phoff = struct.unpack_from(endian + 'Q', data, 32)[0]
        phsize, count = struct.unpack_from(endian + 'HH', data, 54)
        layout = endian + 'IIQQQQQQ'
    else:
        phoff = struct.unpack_from(endian + 'I', data, 28)[0]
        phsize, count = struct.unpack_from(endian + 'HH', data, 42)
        layout = endian + 'IIIIIIII'
    loads, relro = [], []
    for index in range(count):
        ph = struct.unpack_from(layout, data, phoff + index * phsize)
        if bits == 64:
            kind, flags, offset, address, _, filesize, memsize, alignment = ph
        else:
            kind, offset, address, _, filesize, memsize, flags, alignment = ph
        record = dict(offset=offset, virtual_address=address, file_size=filesize,
                      memory_size=memsize, flags=flags, alignment=alignment)
        if kind == 1:
            record['aligned_16kb'] = alignment >= PAGE and (address - offset) % PAGE == 0
            loads.append(record)
        elif kind == 0x6474e552:
            relro.append(record)
    for area in relro:
        end = area['virtual_address'] + area['memory_size']
        protected_end = (end + PAGE - 1) // PAGE * PAGE
        # A dedicated RELRO LOAD is safe even if padding ends below the page.
        overlap = any(segment['flags'] & 2 and
                      max(end, segment['virtual_address']) <
                      min(protected_end, segment['virtual_address'] + segment['memory_size'])
                      for segment in loads)
        area['end_aligned_16kb'] = end % PAGE == 0
        area['no_writable_data_after_relro_in_page'] = not overlap
    return dict(bits=bits, load_segments=loads, relro_segments=relro,
                load_alignment_pass=bool(loads) and all(s['aligned_16kb'] for s in loads),
                relro_page_pass=all(s['no_writable_data_after_relro_in_page'] for s in relro))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    tools = root.parent / 'papigiras-tools'
    java = tools / 'jdk-17/amazon-corretto-17.jdk/Contents/Home/bin/java'
    bundletool = tools / 'bundletool/bundletool-all-1.18.3.jar'
    assert hashlib.sha256(bundletool.read_bytes()).hexdigest() == 'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29'
    config = subprocess.run([str(java), '-jar', str(bundletool), 'dump', 'config',
                             '--bundle=' + str(args.bundle)], capture_output=True, text=True, check=True)
    config_data = json.loads(config.stdout)
    packaging_pass = 'PAGE_ALIGNMENT_16K' in config.stdout
    libraries = []
    with zipfile.ZipFile(args.bundle) as archive:
        for name in sorted(archive.namelist()):
            if '/lib/' in name and name.endswith('.so'):
                result = inspect_elf(archive.read(name))
                libraries.append(dict(path=name, **result))
        signing_files = [n for n in archive.namelist() if n.startswith('META-INF/') and n.upper().endswith(('.RSA', '.DSA', '.EC', '.SF'))]
    required = [item for item in libraries if item['bits'] == 64]
    passed = bool(required) and packaging_pass and all(item['load_alignment_pass'] and item['relro_page_pass'] for item in required)
    report = dict(bundle=str(args.bundle.resolve()), sha256=hashlib.sha256(args.bundle.read_bytes()).hexdigest(),
                  size_bytes=args.bundle.stat().st_size, unsigned=not signing_files,
                  bundletool_version='1.18.3', packaging_16kb=packaging_pass,
                  bundle_config=config_data, libraries=libraries,
                  libraries_64bit=len(required), structural_16kb_pass=passed,
                  runtime_16kb_device_tested=False,
                  note='Structural check only. No signing, upload, physical-device or 16 KB runtime test.')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    for item in libraries:
        print(item['path'], 'ELF' + str(item['bits']),
              'LOAD=' + str(item['load_alignment_pass']), 'RELRO=' + str(item['relro_page_pass']))
    print(f"Packaging 16 KB: {packaging_pass}; unsigned: {not signing_files}; structural result: {passed}; runtime untested")
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
