// CMultitouch — a tiny bridge to Apple's private MultitouchSupport.framework.
//
// The framework is loaded with dlopen() at runtime, so nothing links against a
// private framework at build time. If Apple ever removes or changes it, the app
// keeps running and simply reports that no devices are available.

#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

#include <stdbool.h>
#include <stdint.h>

/// Touch states reported by MultitouchSupport.
typedef enum {
    MMTouchStateNotTracking   = 0,
    MMTouchStateStartInRange  = 1,
    MMTouchStateHoverInRange  = 2,
    MMTouchStateMakeTouch     = 3,
    MMTouchStateTouching      = 4,
    MMTouchStateBreakTouch    = 5,
    MMTouchStateLingerInRange = 6,
    MMTouchStateOutOfRange    = 7,
} MMTouchState;

/// A simplified, stable touch record handed to Swift.
typedef struct {
    int32_t identifier;
    int32_t state;
    float x;   ///< normalized 0…1, left → right
    float y;   ///< normalized 0…1, back (palm) → front
    float size;
} MMTouch;

/// Called on MultitouchSupport's own thread for every frame of every started device.
typedef void (*MMFrameCallback)(int32_t deviceIndex, const MMTouch *touches, int32_t count, double timestamp);

/// True when MultitouchSupport could be loaded and all required symbols resolved.
bool MMMultitouchAvailable(void);

/// Stops any running devices and builds a fresh device list. Returns the device count.
int32_t MMRefreshDevices(void);

/// IOKit service (io_service_t) of the device at `index`, or 0.
uint32_t MMDeviceService(int32_t index);

/// Starts delivering frames for the device at `index` to `callback`.
bool MMStartDevice(int32_t index, MMFrameCallback callback);

/// Stops all devices and releases the device list.
void MMStopAllDevices(void);

#endif /* CMULTITOUCH_H */
