#!/usr/bin/env python3
import json
import ctypes
import fcntl
import os
import sys
from pathlib import Path
from collections import namedtuple

DRM_DIR = Path("/sys/class/drm")
CONNECTOR_TYPES = (
    "Unknown",
    "VGA",
    "DVI-I",
    "DVI-D",
    "DVI-A",
    "Composite",
    "SVIDEO",
    "LVDS",
    "Component",
    "DIN",
    "DP",
    "HDMI-A",
    "HDMI-B",
    "TV",
    "eDP",
    "Virtual",
    "DSI",
    "DPI",
    "Writeback",
    "SPI",
    "USB",
)

EdidCaps = namedtuple("EdidCaps", ["ten_bit", "hdr"])


def IOWR(t, nr, size):
    return (3 << 30) | (size << 16) | (t << 8) | nr


DRM_IOCTL_BASE = ord("d")


class _CardRes(ctypes.Structure):
    _fields_ = [
        ("fb_id_ptr", ctypes.c_uint64),
        ("crtc_id_ptr", ctypes.c_uint64),
        ("connector_id_ptr", ctypes.c_uint64),
        ("encoder_id_ptr", ctypes.c_uint64),
        ("count_fbs", ctypes.c_uint32),
        ("count_crtcs", ctypes.c_uint32),
        ("count_connectors", ctypes.c_uint32),
        ("count_encoders", ctypes.c_uint32),
        ("min_width", ctypes.c_uint32),
        ("max_width", ctypes.c_uint32),
        ("min_height", ctypes.c_uint32),
        ("max_height", ctypes.c_uint32),
    ]


class _GetConnector(ctypes.Structure):
    _fields_ = [
        ("encoders_ptr", ctypes.c_uint64),
        ("modes_ptr", ctypes.c_uint64),
        ("props_ptr", ctypes.c_uint64),
        ("prop_values_ptr", ctypes.c_uint64),
        ("count_modes", ctypes.c_uint32),
        ("count_props", ctypes.c_uint32),
        ("count_encoders", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
        ("connector_id", ctypes.c_uint32),
        ("connector_type", ctypes.c_uint32),
        ("connector_type_id", ctypes.c_uint32),
        ("connection", ctypes.c_uint32),
        ("mm_width", ctypes.c_uint32),
        ("mm_height", ctypes.c_uint32),
        ("subpixel", ctypes.c_uint32),
    ]


class _GetProperty(ctypes.Structure):
    _fields_ = [
        ("values_ptr", ctypes.c_uint64),
        ("enum_blob_ptr", ctypes.c_uint64),
        ("prop_id", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("name", ctypes.c_char * 32),
        ("count_values", ctypes.c_uint32),
        ("count_enum_blobs", ctypes.c_uint32),
    ]


DRM_GETRESOURCES = IOWR(DRM_IOCTL_BASE, 0xA0, ctypes.sizeof(_CardRes))
DRM_GETCONNECTOR = IOWR(DRM_IOCTL_BASE, 0xA7, ctypes.sizeof(_GetConnector))
DRM_GETPROPERTY = IOWR(DRM_IOCTL_BASE, 0xAA, ctypes.sizeof(_GetProperty))
DRM_CONNECTED = 1


def find_primary_card():
    try:
        cards = sorted(
            e
            for e in DRM_DIR.iterdir()
            if e.name.startswith("card") and "-" not in e.name
        )
    except OSError:
        return None
    for entry in cards:
        try:
            if (entry / "device" / "boot_vga").read_text().strip() == "1":
                return entry.name
        except OSError:
            continue
    return cards[0].name if cards else None


def read_edid_caps(edid_data):
    if len(edid_data) < 128:
        return EdidCaps(False, False)
    ten_bit = False
    if edid_data[18] >= 1 and edid_data[19] >= 4:
        depth_code = (edid_data[20] >> 4) & 0x07
        ten_bit = depth_code >= 3
    num_ext = edid_data[126]
    for ext_idx in range(num_ext):
        offset = 128 * (ext_idx + 1)
        if offset + 128 > len(edid_data):
            break
        ext = edid_data[offset : offset + 128]
        if ext[0] != 0x02:
            continue
        dtd_start = min(ext[2], len(ext))
        pos = 4
        while pos < dtd_start - 1:
            header = ext[pos]
            tag = (header >> 5) & 0x07
            length = header & 0x1F
            if tag == 7 and length >= 1:
                ext_tag = ext[pos + 1]
                if ext_tag == 6:
                    return EdidCaps(ten_bit=ten_bit, hdr=True)
            pos += length + 1
    return EdidCaps(ten_bit=ten_bit, hdr=False)


def get_connector_ids(fd):
    res = _CardRes()
    fcntl.ioctl(fd, DRM_GETRESOURCES, res)
    if res.count_connectors == 0:
        return []
    connector_ids = (ctypes.c_uint32 * res.count_connectors)()
    res2 = _CardRes()
    res2.connector_id_ptr = ctypes.addressof(connector_ids)
    res2.count_connectors = res.count_connectors
    fcntl.ioctl(fd, DRM_GETRESOURCES, res2)
    return list(connector_ids)


def check_vrr(fd, conn):
    if conn.count_props == 0:
        return False
    props = (ctypes.c_uint32 * conn.count_props)()
    prop_vals = (ctypes.c_uint64 * conn.count_props)()
    modes_buf = ctypes.create_string_buffer(68 * max(conn.count_modes, 1))
    enc_buf = (ctypes.c_uint32 * max(conn.count_encoders, 1))()
    conn2 = _GetConnector()
    conn2.encoders_ptr = ctypes.addressof(enc_buf)
    conn2.modes_ptr = ctypes.addressof(modes_buf)
    conn2.props_ptr = ctypes.addressof(props)
    conn2.prop_values_ptr = ctypes.addressof(prop_vals)
    conn2.count_modes = conn.count_modes
    conn2.count_props = conn.count_props
    conn2.count_encoders = conn.count_encoders
    conn2.connector_id = conn.connector_id
    fcntl.ioctl(fd, DRM_GETCONNECTOR, conn2)
    for j in range(conn.count_props):
        prop = _GetProperty()
        prop.prop_id = props[j]
        fcntl.ioctl(fd, DRM_GETPROPERTY, prop)
        if prop.name == b"vrr_capable":
            return prop_vals[j] == 1
    return False


def get_capabilities(name):
    card = find_primary_card()
    if not card:
        return None
    entry = DRM_DIR / f"{card}-{name}"
    try:
        if not entry.is_dir():
            return None
        if (entry / "status").read_text().strip() != "connected":
            return None
    except OSError:
        return None
    edid_caps = EdidCaps(False, False)
    try:
        edid_data = (entry / "edid").read_bytes()
        edid_caps = read_edid_caps(edid_data)
    except OSError:
        pass
    vrr = False
    try:
        fd = os.open(f"/dev/dri/{card}", os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
        try:
            for conn_id in get_connector_ids(fd):
                conn = _GetConnector()
                conn.connector_id = conn_id
                fcntl.ioctl(fd, DRM_GETCONNECTOR, conn)
                ct = conn.connector_type
                type_name = (
                    CONNECTOR_TYPES[ct] if ct < len(CONNECTOR_TYPES) else str(ct)
                )
                drm_name = f"{type_name}-{conn.connector_type_id}"
                if drm_name != name or conn.connection != DRM_CONNECTED:
                    continue
                vrr = check_vrr(fd, conn)
        finally:
            os.close(fd)
    except OSError:
        pass
    return {"hdr": edid_caps.hdr, "ten_bit": edid_caps.ten_bit, "vrr": vrr}


def list_monitors():
    card = find_primary_card()
    if not card:
        return []
    prefix = card + "-"
    monitors = []
    for entry in sorted(DRM_DIR.iterdir()):
        if not entry.name.startswith(prefix):
            continue
        name = entry.name.removeprefix(prefix)
        try:
            if (entry / "status").read_text().strip() == "connected":
                monitors.append(name)
        except OSError:
            continue
    return monitors


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "list"
    if mode == "list":
        print(json.dumps({"monitors": list_monitors()}))
    elif mode == "caps":
        names = sys.argv[2:] if len(sys.argv) > 2 else []
        result = {}
        for name in names:
            caps = get_capabilities(name)
            if caps is not None:
                result[name] = caps
        print(json.dumps(result))
    else:
        print(json.dumps({"error": f"Unknown mode: {mode}"}))
