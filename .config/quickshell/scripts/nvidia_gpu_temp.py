#!/usr/bin/env python3
import pynvml
import json
import sys

def _safe(fn, *args, default=None):
    """Call a pynvml function and return default on any NVMLError."""
    try:
        return fn(*args)
    except pynvml.NVMLError:
        return default

def _decode(value):
    """Decode bytes → str if needed (pynvml returns bytes on older versions)."""
    return value.decode('utf-8') if isinstance(value, bytes) else str(value)

def get_gpu_info():
    gpus = []
    init_error = None

    try:
        pynvml.nvmlInit()
    except pynvml.NVMLError as e:
        return {"gpus": [], "error": str(e)}

    try:
        device_count = pynvml.nvmlDeviceGetCount()

        for i in range(device_count):
            handle = _safe(pynvml.nvmlDeviceGetHandleByIndex, i)
            if handle is None:
                continue

            # ── Identity ──────────────────────────────────────────────────────
            name     = _decode(_safe(pynvml.nvmlDeviceGetName, handle, default=b"Unknown"))
            pci_info = _safe(pynvml.nvmlDeviceGetPciInfo, handle)
            pci_id   = _decode(pci_info.busId) if pci_info else ""

            # ── Temperature ───────────────────────────────────────────────────
            temperature = _safe(pynvml.nvmlDeviceGetTemperature,
                                handle, pynvml.NVML_TEMPERATURE_GPU, default=0)

            # ── Memory ────────────────────────────────────────────────────────
            mem = _safe(pynvml.nvmlDeviceGetMemoryInfo, handle)
            memory_used       = mem.used   if mem else 0
            memory_total      = mem.total  if mem else 0
            memory_free       = mem.free   if mem else 0
            memory_used_mb    = memory_used  // (1024 * 1024)
            memory_total_mb   = memory_total // (1024 * 1024)
            memory_free_mb    = memory_free  // (1024 * 1024)

            # ── Utilization ───────────────────────────────────────────────────
            util = _safe(pynvml.nvmlDeviceGetUtilizationRates, handle)
            gpu_usage    = util.gpu    if util is not None else -1
            memory_usage = util.memory if util is not None else -1

            # ── Power ─────────────────────────────────────────────────────────
            power_draw_mw  = _safe(pynvml.nvmlDeviceGetPowerUsage, handle, default=None)
            power_limit_mw = _safe(pynvml.nvmlDeviceGetEnforcedPowerLimit, handle, default=None)
            power_draw_w   = round(power_draw_mw  / 1000.0, 1) if power_draw_mw  is not None else None
            power_limit_w  = round(power_limit_mw / 1000.0, 1) if power_limit_mw is not None else None

            # ── Clocks ────────────────────────────────────────────────────────
            clock_graphics = _safe(pynvml.nvmlDeviceGetClockInfo,
                                   handle, pynvml.NVML_CLOCK_GRAPHICS, default=None)
            clock_mem      = _safe(pynvml.nvmlDeviceGetClockInfo,
                                   handle, pynvml.NVML_CLOCK_MEM, default=None)
            clock_sm       = _safe(pynvml.nvmlDeviceGetClockInfo,
                                   handle, pynvml.NVML_CLOCK_SM, default=None)

            # ── Fan ───────────────────────────────────────────────────────────
            fan_speed = _safe(pynvml.nvmlDeviceGetFanSpeed, handle, default=None)

            # ── Throttle reasons ──────────────────────────────────────────────
            throttle_reasons = _safe(pynvml.nvmlDeviceGetCurrentClocksThrottleReasons,
                                     handle, default=None)
            is_throttled = bool(throttle_reasons) and throttle_reasons != \
                pynvml.nvmlFlagDefault if throttle_reasons is not None else None

            gpus.append({
                "index":          i,
                "name":           name,
                "displayName":    name,
                "fullName":       name,
                "pciId":          pci_id,
                "vendor":         "NVIDIA",
                "driver":         "nvidia",

                # Thermals
                "temperature":    temperature,
                "fanSpeed":       fan_speed,       # % or None if passive cooling

                # Memory
                "memoryUsed":     memory_used,
                "memoryTotal":    memory_total,
                "memoryFree":     memory_free,
                "memoryUsedMB":   memory_used_mb,
                "memoryTotalMB":  memory_total_mb,
                "memoryFreeMB":   memory_free_mb,

                # Utilization
                "gpuUsage":       gpu_usage,       # % or -1 if unavailable
                "memoryUsage":    memory_usage,    # % or -1 if unavailable

                # Power
                "powerDraw":      power_draw_w,    # watts or None
                "powerLimit":     power_limit_w,   # watts or None

                # Clocks (MHz)
                "clockGraphics":  clock_graphics,
                "clockMemory":    clock_mem,
                "clockSM":        clock_sm,

                # Throttle
                "isThrottled":    is_throttled,
            })

    except pynvml.NVMLError as e:
        init_error = str(e)
    finally:
        try:
            pynvml.nvmlShutdown()
        except pynvml.NVMLError:
            pass

    result = {"gpus": gpus}
    if init_error:
        result["error"] = init_error
    return result


if __name__ == "__main__":
    print(json.dumps(get_gpu_info()))
