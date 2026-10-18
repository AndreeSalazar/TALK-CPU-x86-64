"""Instala archivos del puente en una copia de nuestro disco FAT32 virtual.

Solo acepta archivos .img bajo build/. Nunca abre dispositivos fisicos.
"""
import argparse
from pathlib import Path
import shutil
import struct
import uuid
import zlib

root = Path(__file__).resolve().parents[2]
build = root / 'build'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--caso', choices=['normal', 'firma', 'suma', 'ausente', 'excesivo', 'entrada', 'salida'], default='normal')
parser.add_argument('--profile',choices=['hello','flappy-preview'],default='hello')
args = parser.parse_args()
if args.profile=='flappy-preview' and args.caso!='normal':raise ValueError('Visual preview uses only the normal virtual image case')
source = build / 'disco-fat32-gpt.img'
output = build / f'puente-{args.caso}.img'
if not source.resolve().is_relative_to(build.resolve()) or not output.resolve().is_relative_to(build.resolve()):
    raise ValueError('Las imagenes deben estar dentro de build/')
shutil.copyfile(source, output)
efi = (build / ('Flappy_Metal/PC_PREVIEW/EFI/ORQUESTADOR/FLAPPY.EFI' if args.profile=='flappy-preview' else 'Puente_Metal/EFI/BOOT/BOOTX64.EFI')).read_bytes()
if args.caso == 'salida':
    # Solo la copia de prueba: MapKey cero para provocar INVALID_PARAMETER.
    if efi[0xc90:0xc94] != bytes.fromhex('488b5558'):
        raise ValueError('Cambio el contrato de la inyeccion MapKey')
    efi = efi[:0xc90] + bytes.fromhex('31d29090') + efi[0xc94:]

with output.open('r+b') as disk:
    def read(offset, size):
        disk.seek(offset)
        data = disk.read(size)
        if len(data) != size:
            raise ValueError('Imagen truncada')
        return data

    def write(offset, data):
        if offset < 0 or offset + len(data) > output.stat().st_size:
            raise ValueError('Escritura fuera de la imagen virtual')
        disk.seek(offset)
        disk.write(data)

    primary = bytearray(read(512, 512))
    if primary[:8] != b'EFI PART':
        raise ValueError('La referencia debe ser GPT')
    table_lba = struct.unpack_from('<Q', primary, 72)[0]
    table_count, table_stride = struct.unpack_from('<II', primary, 80)
    if (table_count, table_stride) != (128, 128):
        raise ValueError('Geometria GPT de referencia inesperada')
    table = bytearray(read(table_lba * 512, table_count * table_stride))
    volume_lba = struct.unpack_from('<Q', table, 32)[0]
    bpb = read(volume_lba * 512, 512)
    if bpb[510:] != b'\x55\xaa' or struct.unpack_from('<H', bpb, 11)[0] != 512:
        raise ValueError('Volumen FAT32 de referencia invalido')
    spc, reserved, fat_count = bpb[13], struct.unpack_from('<H', bpb, 14)[0], bpb[16]
    fat_sectors, root_cluster = struct.unpack_from('<I', bpb, 36)[0], struct.unpack_from('<I', bpb, 44)[0]
    if spc not in (1, 2, 4, 8, 16, 32, 64) or fat_count != 2:
        raise ValueError('Geometria FAT32 inesperada')
    cluster_bytes = 512 * spc
    fat_offset = (volume_lba + reserved) * 512
    fat = bytearray(read(fat_offset, fat_sectors * 512))
    data_offset = (volume_lba + reserved + fat_count * fat_sectors) * 512
    cluster_count = (output.stat().st_size - data_offset) // cluster_bytes

    def cluster_offset(cluster):
        if not 2 <= cluster < cluster_count + 2:
            raise ValueError('Cluster fuera de imagen')
        return data_offset + (cluster - 2) * cluster_bytes

    def allocate(count):
        chain = []
        for cluster in range(2, min(len(fat) // 4, cluster_count + 2)):
            if struct.unpack_from('<I', fat, cluster * 4)[0] == 0:
                chain.append(cluster)
                if len(chain) == count:
                    break
        if len(chain) != count:
            raise ValueError('Sin espacio en la imagen virtual')
        for n, cluster in enumerate(chain):
            struct.pack_into('<I', fat, cluster * 4, chain[n + 1] if n + 1 < count else 0x0fffffff)
        return chain

    def entry(name, attr, cluster, size=0):
        record = bytearray(32)
        record[:11] = name
        record[11] = attr
        struct.pack_into('<H', record, 20, cluster >> 16)
        struct.pack_into('<H', record, 26, cluster & 65535)
        struct.pack_into('<I', record, 28, size)
        return record

    root_data = bytearray(read(cluster_offset(root_cluster), cluster_bytes))
    metal = next(root_data[p:p + 32] for p in range(0, cluster_bytes, 32) if root_data[p:p + 11] == b'METAL      ')
    metal_cluster = (struct.unpack_from('<H', metal, 20)[0] << 16) | struct.unpack_from('<H', metal, 26)[0]
    metal_offset = cluster_offset(metal_cluster)
    directory = bytearray(read(metal_offset, cluster_bytes))
    packet_pos = next(p for p in range(0, cluster_bytes, 32) if directory[p:p + 11] == b'INICIO  X86')
    if args.profile=='flappy-preview':directory[packet_pos:packet_pos+11]=b'FLAPPY  X86'
    packet_cluster = (struct.unpack_from('<H', directory, packet_pos + 20)[0] << 16) | struct.unpack_from('<H', directory, packet_pos + 26)[0]
    packet_offset = cluster_offset(packet_cluster)
    if args.caso == 'ausente':
        directory[packet_pos] = 0xe5
    elif args.caso in ('firma', 'suma', 'entrada'):
        delta = {'firma': 0, 'suma': 24, 'entrada': 12}[args.caso]
        changed = bytearray(read(packet_offset, cluster_bytes))
        changed[delta] ^= 0x80
        write(packet_offset, changed)
    elif args.caso == 'excesivo':
        oversized = (build / 'Puente_Metal/METAL/INICIO.X86').read_bytes().ljust(4097, b'\0')
        chain = allocate((len(oversized) + cluster_bytes - 1) // cluster_bytes)
        for n, cluster in enumerate(chain):
            write(cluster_offset(cluster), oversized[n * cluster_bytes:(n + 1) * cluster_bytes].ljust(cluster_bytes, b'\0'))
        directory[packet_pos:packet_pos + 32] = entry(b'INICIO  X86', 0x20, chain[0], len(oversized))
    write(metal_offset, directory)

    efi_dir, boot_dir = allocate(2)
    chain = allocate((len(efi) + cluster_bytes - 1) // cluster_bytes)
    for n, cluster in enumerate(chain):
        write(cluster_offset(cluster), efi[n * cluster_bytes:(n + 1) * cluster_bytes].ljust(cluster_bytes, b'\0'))
    for cluster, parent, child in ((efi_dir, root_cluster, entry(b'BOOT       ', 0x10, boot_dir)),
                                    (boot_dir, efi_dir, entry(b'BOOTX64 EFI', 0x20, chain[0], len(efi)))):
        block = bytearray(cluster_bytes)
        block[:32] = entry(b'.          ', 0x10, cluster)
        block[32:64] = entry(b'..         ', 0x10, parent)
        block[64:96] = child
        write(cluster_offset(cluster), block)
    free = next(p for p in range(0, cluster_bytes, 32) if root_data[p] in (0, 0xe5))
    root_data[free:free + 32] = entry(b'EFI        ', 0x10, efi_dir)
    write(cluster_offset(root_cluster), root_data)
    for n in range(fat_count):
        write(fat_offset + n * len(fat), fat)
    # La misma particion pasa a tipo ESP; mantener ambas tablas/cabeceras GPT.
    table[:16] = uuid.UUID('c12a7328-f81f-11d2-ba4b-00a0c93ec93b').bytes_le
    for header_lba in (1, struct.unpack_from('<Q', primary, 32)[0]):
        header = bytearray(read(header_lba * 512, 512))
        table_at = struct.unpack_from('<Q', header, 72)[0]
        write(table_at * 512, table)
        struct.pack_into('<I', header, 88, zlib.crc32(table))
        struct.pack_into('<I', header, 16, 0)
        struct.pack_into('<I', header, 16, zlib.crc32(header[:92]))
        write(header_lba * 512, header)
print(f'OK: {output.name}: ESP FAT32 con BOOTX64.EFI y paquete externo; caso {args.caso}.')
