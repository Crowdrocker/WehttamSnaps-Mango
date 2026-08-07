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

def get_amd_gpus():
    gpus = []

    drm_cards = glob.glob('/sys/class/drm/card*')
    for card_path in drm_cards:
        card_name = os.path.basename(card_path)
        device_path = os.path.join(card_path, 'device')

        if not os.path.exists(device_path):
            continue

        vendor = read_sysfs_file(os.path.join(device_path, 'vendor'))
        device_id = read_sysfs_file(os.path.join(device_path, 'device'))

        if vendor and vendor.lower() in ['0x1002', '1002']:
            display_name = "AMD GPU"
            try:
                pci_addr = read_sysfs_file(os.path.join(device_path, 'uevent'))
                if pci_addr:
                    for line in pci_addr.split('\n'):
                        if line.startswith('PCI_SLOT_NAME='):
                            pci_slot = line.split('=', 1)[1]
                            try:
                                lspci_output = subprocess.check_output(['lspci', '-s', pci_slot, '-d', '1002:'],
                                                                     universal_newlines=True).strip()
                                if lspci_output:
                                    parts = lspci_output.split(':', 2)
                                    if len(parts) > 2:
                                        display_name = parts[2].split('[')[0].strip()
                            except subprocess.CalledProcessError:
                                pass
                            break
            except:
                pass

            temperature = 0
            hwmon_dirs = glob.glob(os.path.join(device_path, 'hwmon', 'hwmon*'))
            for hwmon_dir in hwmon_dirs:
                # Prefer temp1_input (edge/die temp) — temp2 is junction and temp3 is hotspot/mem,
                # both of which run significantly hotter and are not the "GPU temp" users expect.
                edge_temp_file = os.path.join(hwmon_dir, 'temp1_input')
                temp_raw = read_sysfs_file(edge_temp_file)
                if temp_raw and temp_raw.isdigit():
                    temp_celsius = int(temp_raw) / 1000.0
                    if 0 < temp_celsius < 150:
                        temperature = temp_celsius
                        continue

                # Fallback: scan all temp sensors and pick the one labelled "edge"
                temp_files = glob.glob(os.path.join(hwmon_dir, 'temp*_input'))
                for temp_file in temp_files:
                    label_file = temp_file.replace('_input', '_label')
                    label = read_sysfs_file(label_file)
                    if label and label.lower() != 'edge':
                        continue
                    temp_raw = read_sysfs_file(temp_file)
                    if temp_raw and temp_raw.isdigit():
                        temp_celsius = int(temp_raw) / 1000.0
                        if 0 < temp_celsius < 150:
                            temperature = temp_celsius
                            break

            memory_used = 0
            memory_total = 0

            vram_used = read_sysfs_file(os.path.join(device_path, 'mem_info_vram_used'))
            vram_total = read_sysfs_file(os.path.join(device_path, 'mem_info_vram_total'))

            if vram_used and vram_used.isdigit():
                memory_used = int(vram_used)

            if vram_total and vram_total.isdigit():
                memory_total = int(vram_total)

            if memory_total == 0:
                mem_used_kb = read_sysfs_file(os.path.join(device_path, 'mem_info_vis_vram_used'))
                mem_total_kb = read_sysfs_file(os.path.join(device_path, 'mem_info_vis_vram_total'))

                if mem_used_kb and mem_used_kb.isdigit():
                    memory_used = int(mem_used_kb) * 1024

                if mem_total_kb and mem_total_kb.isdigit():
                    memory_total = int(mem_total_kb) * 1024

            memory_used_mb = memory_used // (1024 * 1024) if memory_used > 0 else 0
            memory_total_mb = memory_total // (1024 * 1024) if memory_total > 0 else 0

            pci_id = ""
            try:
                pci_id = f"{vendor}:{device_id}"
            except:
                pci_id = card_name

            gpu_info = {
                "index": len(gpus),
                "name": display_name,
                "displayName": display_name,
                "fullName": display_name,
                "pciId": pci_id,
                "temperature": temperature,
                "memoryUsed": memory_used,
                "memoryTotal": memory_total,
                "memoryUsedMB": memory_used_mb,
                "memoryTotalMB": memory_total_mb,
                "vendor": "AMD",
                "driver": "amdgpu"
            }

            gpus.append(gpu_info)

    return {"gpus": gpus}

if __name__ == "__main__":
    print(json.dumps(get_amd_gpus()))