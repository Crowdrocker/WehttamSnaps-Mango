#!/usr/bin/env python3
import json
import os
import glob
import subprocess

def read_sysfs_file(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except (OSError, IOError):
        return None

def get_short_intel_name(full_name):
    """Create a short display name for Intel GPUs"""
    name = full_name

    if name.startswith('Intel(R)'):
        name = name[8:].strip()
    elif name.startswith('Intel '):
        name = name[6:].strip()

    suffixes_to_remove = [
        'Processor Graphics',
        'Graphics',
        'UHD Graphics',
        'HD Graphics',
    ]
    for suffix in suffixes_to_remove:
        if name.endswith(suffix):
            name = name[:-len(suffix)].strip()

    if len(name) > 20:
        platforms = ['TigerLake', 'AlderLake', 'RaptorLake', 'MeteorLake',
                     'IceLake', 'CometLake', 'KabyLake', 'SkyLake',
                     'Broadwell', 'Haswell', 'Apollo']
        for platform in platforms:
            if platform.lower() in full_name.lower():
                return 'Intel ' + platform

    if not name or len(name) < 3:
        return "Intel Graphics"

    return name


# ── Temperature ────────────────────────────────────────────────────────────────

def get_igpu_temperature():
    """
    Intel iGPUs do not expose their own hwmon temperature node in most kernels.
    The GPU shares the package thermal domain with the CPU, so we read:
      1. The i915/xe hwmon node directly under the DRM device (rare, newer kernels)
      2. coretemp hwmon — "Package id 0" label is the package temp the iGPU lives in
      3. acpi_thermal / acpitz as a last resort
    Returns temperature in °C as a float, or 0 if nothing found.
    """
    # 1. i915 / xe hwmon attached directly to the DRM device
    for card in sorted(glob.glob('/sys/class/drm/card*')):
        vendor = read_sysfs_file(os.path.join(card, 'device', 'vendor'))
        if not vendor or vendor.lower() not in ['0x8086', '8086']:
            continue
        for hwmon_dir in glob.glob(os.path.join(card, 'device', 'hwmon', 'hwmon*')):
            hwmon_name = read_sysfs_file(os.path.join(hwmon_dir, 'name')) or ''
            if any(x in hwmon_name.lower() for x in ('i915', 'xe', 'intel')):
                for temp_file in sorted(glob.glob(os.path.join(hwmon_dir, 'temp*_input'))):
                    raw = read_sysfs_file(temp_file)
                    if raw and raw.isdigit():
                        t = int(raw) / 1000.0
                        if 0 < t < 150:
                            return t

    # 2. coretemp — "Package id 0" shares the thermal domain with the iGPU
    for hwmon_dir in glob.glob('/sys/class/hwmon/hwmon*'):
        hwmon_name = read_sysfs_file(os.path.join(hwmon_dir, 'name')) or ''
        if 'coretemp' not in hwmon_name.lower():
            continue
        for label_file in glob.glob(os.path.join(hwmon_dir, 'temp*_label')):
            label = read_sysfs_file(label_file) or ''
            if 'package' in label.lower():
                input_file = label_file.replace('_label', '_input')
                raw = read_sysfs_file(input_file)
                if raw and raw.isdigit():
                    t = int(raw) / 1000.0
                    if 0 < t < 150:
                        return t

    # 3. acpitz fallback
    for hwmon_dir in glob.glob('/sys/class/hwmon/hwmon*'):
        hwmon_name = read_sysfs_file(os.path.join(hwmon_dir, 'name')) or ''
        if 'acpitz' not in hwmon_name.lower():
            continue
        raw = read_sysfs_file(os.path.join(hwmon_dir, 'temp1_input'))
        if raw and raw.isdigit():
            t = int(raw) / 1000.0
            if 0 < t < 150:
                return t

    return 0


# ── VRAM / shared memory ───────────────────────────────────────────────────────

def get_igpu_memory(device_path):
    """
    iGPUs use system RAM carved out as VRAM (stolen memory / UMA).
    sysfs does not expose this directly for iGPUs the same way dGPUs do.

    Priority:
      1. mem_info_vram_* — present on Intel Arc dGPUs and some iGPU configs
      2. mem_info_gtt_*  — GTT (Graphics Translation Table) aperture, reflects
                           system RAM the GPU can address; best proxy for iGPU
      3. /proc/driver/i915/<minor>/clients — per-process GPU memory (usage only)
      4. lspci -v "prefetchable" region size — reflects stolen/UMA VRAM size
    """
    memory_used = 0
    memory_total = 0

    # 1. Dedicated VRAM (Arc / some iGPU with stolen mem exposed)
    vram_used  = read_sysfs_file(os.path.join(device_path, 'mem_info_vram_used'))
    vram_total = read_sysfs_file(os.path.join(device_path, 'mem_info_vram_total'))
    if vram_total and vram_total.isdigit() and int(vram_total) > 0:
        memory_used  = int(vram_used)  if (vram_used  and vram_used.isdigit())  else 0
        memory_total = int(vram_total)
        return memory_used, memory_total

    # 2. GTT memory — best available proxy for iGPU shared memory
    gtt_used  = read_sysfs_file(os.path.join(device_path, 'mem_info_gtt_used'))
    gtt_total = read_sysfs_file(os.path.join(device_path, 'mem_info_gtt_total'))
    if gtt_total and gtt_total.isdigit() and int(gtt_total) > 0:
        memory_used  = int(gtt_used)  if (gtt_used  and gtt_used.isdigit())  else 0
        memory_total = int(gtt_total)
        return memory_used, memory_total

    # 3. Sum active client memory from /proc/driver/i915 (used only, no total)
    try:
        proc_clients = glob.glob('/proc/driver/i915/*/clients')
        total_client_bytes = 0
        for client_file in proc_clients:
            content = read_sysfs_file(client_file)
            if content:
                for line in content.splitlines()[1:]:  # skip header
                    parts = line.split()
                    if len(parts) >= 5:
                        try:
                            total_client_bytes += int(parts[4])
                        except ValueError:
                            pass
        if total_client_bytes > 0:
            memory_used = total_client_bytes
    except Exception:
        pass

    # 4. lspci — read the prefetchable BAR size as a proxy for UMA/stolen size
    if memory_total == 0:
        try:
            uevent = read_sysfs_file(os.path.join(device_path, 'uevent')) or ''
            pci_slot = ''
            for line in uevent.splitlines():
                if line.startswith('PCI_SLOT_NAME='):
                    pci_slot = line.split('=', 1)[1]
                    break
            if pci_slot:
                lspci_out = subprocess.check_output(
                    ['lspci', '-v', '-s', pci_slot],
                    universal_newlines=True, stderr=subprocess.DEVNULL
                )
                for line in lspci_out.splitlines():
                    if 'prefetchable' in line.lower() and 'size=' in line.lower():
                        # e.g. "... size=256M ..."
                        for part in line.split():
                            if part.startswith('size='):
                                size_str = part[5:]
                                multiplier = 1
                                if size_str.endswith('G'):
                                    multiplier = 1024 * 1024 * 1024
                                    size_str = size_str[:-1]
                                elif size_str.endswith('M'):
                                    multiplier = 1024 * 1024
                                    size_str = size_str[:-1]
                                elif size_str.endswith('K'):
                                    multiplier = 1024
                                    size_str = size_str[:-1]
                                try:
                                    memory_total = int(size_str) * multiplier
                                except ValueError:
                                    pass
                                break
                        if memory_total > 0:
                            break
        except Exception:
            pass

    return memory_used, memory_total


# ── GPU engine usage ───────────────────────────────────────────────────────────

def get_igpu_usage(card_path):
    """
    Read render engine busyness from:
      1. /sys/class/drm/cardN/gt/gt0/engines/rcs0/busy  (i915, kernel 5.19+)
         alongside the total time to compute a percentage
      2. intel_gpu_top via subprocess as a last resort (requires root / CAP_PERFMON)
    Returns usage as a float 0–100, or -1 if unavailable.
    """
    # 1. gt engine busyness counters (nanoseconds, two reads needed for delta)
    rcs_busy_file  = os.path.join(card_path, 'gt', 'gt0', 'engines', 'rcs0', 'busy')
    rcs_total_file = os.path.join(card_path, 'gt', 'gt0', 'engines', 'rcs0', 'total')

    # Some kernels expose it under the device gt path
    if not os.path.exists(rcs_busy_file):
        rcs_busy_file  = os.path.join(card_path, 'device', 'gt0', 'engines', 'rcs0', 'busy')
        rcs_total_file = os.path.join(card_path, 'device', 'gt0', 'engines', 'rcs0', 'total')

    if os.path.exists(rcs_busy_file) and os.path.exists(rcs_total_file):
        busy  = read_sysfs_file(rcs_busy_file)
        total = read_sysfs_file(rcs_total_file)
        if busy and total and busy.isdigit() and total.isdigit():
            total_ns = int(total)
            if total_ns > 0:
                return round(int(busy) / total_ns * 100.0, 1)

    return -1  # not available without a two-sample delta or elevated privileges


# ── Main ───────────────────────────────────────────────────────────────────────

def get_intel_gpus():
    gpus = []

    drm_cards = sorted(glob.glob('/sys/class/drm/card*'))
    for card_path in drm_cards:
        card_name  = os.path.basename(card_path)
        device_path = os.path.join(card_path, 'device')

        if not os.path.exists(device_path):
            continue

        vendor    = read_sysfs_file(os.path.join(device_path, 'vendor'))
        device_id = read_sysfs_file(os.path.join(device_path, 'device'))

        if not vendor or vendor.lower() not in ['0x8086', '8086']:
            continue

        # ── Name ──────────────────────────────────────────────────────────────
        display_name = "Intel GPU"
        try:
            uevent = read_sysfs_file(os.path.join(device_path, 'uevent')) or ''
            for line in uevent.splitlines():
                if line.startswith('PCI_SLOT_NAME='):
                    pci_slot = line.split('=', 1)[1]
                    try:
                        lspci_output = subprocess.check_output(
                            ['lspci', '-s', pci_slot, '-d', '8086:'],
                            universal_newlines=True, stderr=subprocess.DEVNULL
                        ).strip()
                        if lspci_output:
                            parts = lspci_output.split(':', 2)
                            if len(parts) > 2:
                                display_name = parts[2].split('[')[0].strip()
                    except subprocess.CalledProcessError:
                        pass
                    break
        except Exception:
            pass

        # ── Temperature ───────────────────────────────────────────────────────
        temperature = get_igpu_temperature()

        # ── Memory ────────────────────────────────────────────────────────────
        memory_used, memory_total = get_igpu_memory(device_path)
        memory_used_mb  = memory_used  // (1024 * 1024) if memory_used  > 0 else 0
        memory_total_mb = memory_total // (1024 * 1024) if memory_total > 0 else 0

        # ── Usage ─────────────────────────────────────────────────────────────
        usage = get_igpu_usage(card_path)

        # ── Driver ────────────────────────────────────────────────────────────
        driver = "xe" if ("arc" in display_name.lower() or "xe" in display_name.lower()) else "i915"

        pci_id = f"{vendor}:{device_id}" if vendor and device_id else card_name
        short_name = get_short_intel_name(display_name)

        gpus.append({
            "index":        len(gpus),
            "name":         short_name,
            "displayName":  short_name,
            "fullName":     display_name,
            "pciId":        pci_id,
            "temperature":  temperature,
            "usage":        usage,          # -1 = not available
            "memoryUsed":   memory_used,
            "memoryTotal":  memory_total,
            "memoryUsedMB":  memory_used_mb,
            "memoryTotalMB": memory_total_mb,
            "vendor":  "Intel",
            "driver":  driver,
            "isIGPU":  memory_total == 0 or "integrated" in display_name.lower()
                       or driver == "i915",
        })

    return {"gpus": gpus}


if __name__ == "__main__":
    print(json.dumps(get_intel_gpus()))
