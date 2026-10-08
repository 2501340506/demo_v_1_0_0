"""Read-only FAT32 test-card inspection. Never writes to the volume."""
import argparse
import json
import struct
from pathlib import Path


def inspect(volume):
    with open(volume, "rb", buffering=0) as disk:
        def sector(lba):
            disk.seek(lba * 512)
            data = disk.read(512)
            if len(data) != 512:
                raise ValueError("Short sector read")
            return data
        boot = sector(0)
        u16 = lambda offset: struct.unpack_from("<H", boot, offset)[0]
        u32 = lambda offset: struct.unpack_from("<I", boot, offset)[0]
        if boot[510:512] != bytes([85, 170]) or u16(11) != 512:
            raise ValueError("Expected a FAT32 volume with 512-byte sectors")
        spc, reserved, fats = boot[13], u16(14), boot[16]
        fat_size, flags, root = u32(36), u16(40), u32(44)
        if not spc or not fat_size or u16(17) or u16(22):
            raise ValueError("Not a supported FAT32 BPB")
        hidden = u32(28)
        data_start = reserved + fats * fat_size
        max_cluster = (u32(32) - data_start) // spc + 1
        active = (flags & 15) if flags & 128 else 0
        fat_start = reserved + active * fat_size
        cache = {}
        def next_cluster(cluster):
            lba = fat_start + cluster // 128
            if lba not in cache:
                cache[lba] = sector(lba)
            return struct.unpack_from("<I", cache[lba], (cluster % 128) * 4)[0] & 0x0fffffff
        def chain(first, needed=None):
            result, seen = [], set()
            cluster = first
            while cluster < 0x0ffffff8:
                if not 2 <= cluster <= max_cluster or cluster in seen:
                    raise ValueError("Invalid cluster chain")
                result.append(cluster)
                seen.add(cluster)
                if needed is not None and len(result) >= needed:
                    return result
                cluster = next_cluster(cluster)
            if needed is not None and len(result) < needed:
                raise ValueError("Early end of file chain")
            return result
        root_chain = chain(root)
        files, stop, entry_number = [], False, 0
        for cluster in root_chain:
            if stop:
                break
            for sec in range(spc):
                if stop:
                    break
                relative_lba = data_start + (cluster - 2) * spc + sec
                directory = sector(relative_lba)
                for offset in range(0, 512, 32):
                    entry = directory[offset:offset+32]
                    index = entry_number
                    entry_number += 1
                    if entry[0] == 0:
                        stop = True
                        break
                    if entry[0] == 229 or entry[11] & 24 or entry[11] == 15:
                        continue
                    name = entry[:11].decode("ascii", errors="replace")
                    if name not in [f"PIC{i}    BMP" for i in range(1, 5)]:
                        continue
                    first = ((struct.unpack_from("<H", entry, 20)[0] << 16) | struct.unpack_from("<H", entry, 26)[0]) & 0x0fffffff
                    size = struct.unpack_from("<I", entry, 28)[0]
                    clusters = chain(first, (size + spc*512-1)//(spc*512)) if size else []
                    extents = []
                    for value in clusters:
                        if extents and value == extents[-1][1] + 1:
                            extents[-1][1] = value
                        else:
                            extents.append([value, value])
                    max_used_lba = 0
                    for n, value in enumerate(clusters):
                        used = min(spc, (size-n*spc*512+511)//512)
                        max_used_lba = max(max_used_lba, hidden+data_start+(value-2)*spc+used-1)
                    files.append(dict(name=name, size=size, first_cluster=first,
                        directory_entry_index=index, directory_physical_lba=hidden+relative_lba,
                        directory_cluster=cluster, directory_sector_in_cluster=sec,
                        clusters=clusters, cluster_extents=extents,
                        fragmented=len(extents)>1, max_used_physical_lba=max_used_lba,
                        beyond_old_scan=max_used_lba>131071))
        return dict(volume=volume, partition_lba_from_bpb=hidden,
            bytes_per_sector=512, sectors_per_cluster=spc,
            fat_start_relative_lba=fat_start, data_start_relative_lba=data_start,
            root_cluster=root, root_chain=root_chain, files=files)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("volume", help="Windows raw volume path or FAT32 volume image")
    parser.add_argument("--output", required=True, help="Local JSON report path; not on the test card")
    args = parser.parse_args()
    result = inspect(args.volume)
    Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    for item in result["files"]:
        print(item["name"], "clusters=", len(item["clusters"]), "fragmented=", item["fragmented"],
              "max_LBA=", item["max_used_physical_lba"], "directory_entry=", item["directory_entry_index"])
