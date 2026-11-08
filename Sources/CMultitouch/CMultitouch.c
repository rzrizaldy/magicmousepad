#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>

#define MM_FRAMEWORK_PATH "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
#define MM_MAX_DEVICES 16

// ---------------------------------------------------------------------------
// Raw MultitouchSupport types (layout reverse-documented by the community,
// stable since macOS 10.5).
// ---------------------------------------------------------------------------

typedef void *MTDeviceRef;

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalized;
    float size;
    int32_t zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;
    int32_t zero2;
    int32_t zero3;
    float density;
} MTTouch;

typedef int (*MTContactCallback)(MTDeviceRef, MTTouch *, int, double, int);

typedef CFMutableArrayRef (*MTDeviceCreateListFn)(void);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int);
typedef void (*MTDeviceStopFn)(MTDeviceRef);
typedef uint32_t (*MTDeviceGetServiceFn)(MTDeviceRef);

static MTDeviceCreateListFn               pCreateList;
static MTRegisterContactFrameCallbackFn   pRegister;
static MTUnregisterContactFrameCallbackFn pUnregister;
static MTDeviceStartFn                    pStart;
static MTDeviceStopFn                     pStop;
static MTDeviceGetServiceFn               pGetService;

static pthread_once_t   gLoadOnce = PTHREAD_ONCE_INIT;
static bool             gLoaded = false;
static pthread_mutex_t  gLock = PTHREAD_MUTEX_INITIALIZER;

static CFMutableArrayRef gList = NULL;
static MTDeviceRef       gDevices[MM_MAX_DEVICES];
static bool              gRunning[MM_MAX_DEVICES];
static int32_t           gCount = 0;
static MMFrameCallback   gCallback = NULL;

static void mm_load(void) {
    void *handle = dlopen(MM_FRAMEWORK_PATH, RTLD_NOW);
    if (!handle) return;
    pCreateList = (MTDeviceCreateListFn)dlsym(handle, "MTDeviceCreateList");
    pRegister   = (MTRegisterContactFrameCallbackFn)dlsym(handle, "MTRegisterContactFrameCallback");
    pUnregister = (MTUnregisterContactFrameCallbackFn)dlsym(handle, "MTUnregisterContactFrameCallback");
    pStart      = (MTDeviceStartFn)dlsym(handle, "MTDeviceStart");
    pStop       = (MTDeviceStopFn)dlsym(handle, "MTDeviceStop");
    pGetService = (MTDeviceGetServiceFn)dlsym(handle, "MTDeviceGetService");
    gLoaded = pCreateList && pRegister && pUnregister && pStart && pStop && pGetService;
}

bool MMMultitouchAvailable(void) {
    pthread_once(&gLoadOnce, mm_load);
    return gLoaded;
}

// Frame callback from MultitouchSupport → simplified MMTouch array → Swift.
static int mm_contact_callback(MTDeviceRef device, MTTouch *touches, int count, double timestamp, int frame) {
    (void)frame;
    MMFrameCallback cb = gCallback;
    if (!cb) return 0;

    int32_t index = -1;
    for (int32_t i = 0; i < gCount; i++) {
        if (gDevices[i] == device) { index = i; break; }
    }
    if (index < 0) return 0;

    enum { kMaxTouches = 16 };
    MMTouch out[kMaxTouches];
    int32_t n = count < kMaxTouches ? (int32_t)count : kMaxTouches;
    for (int32_t i = 0; i < n; i++) {
        out[i].identifier = touches[i].identifier;
        out[i].state      = touches[i].state;
        out[i].x          = touches[i].normalized.position.x;
        out[i].y          = touches[i].normalized.position.y;
        out[i].size       = touches[i].size;
    }
    cb(index, out, n, timestamp);
    return 0;
}

static void mm_stop_locked(void) {
    for (int32_t i = 0; i < gCount; i++) {
        if (gRunning[i]) {
            pUnregister(gDevices[i], mm_contact_callback);
            pStop(gDevices[i]);
            gRunning[i] = false;
        }
        gDevices[i] = NULL;
    }
    gCount = 0;
    if (gList) {
        CFRelease(gList);
        gList = NULL;
    }
}

void MMStopAllDevices(void) {
    if (!MMMultitouchAvailable()) return;
    pthread_mutex_lock(&gLock);
    mm_stop_locked();
    pthread_mutex_unlock(&gLock);
}

int32_t MMRefreshDevices(void) {
    if (!MMMultitouchAvailable()) return 0;
    pthread_mutex_lock(&gLock);
    mm_stop_locked();
    gList = pCreateList();
    if (gList) {
        CFIndex total = CFArrayGetCount(gList);
        for (CFIndex i = 0; i < total && gCount < MM_MAX_DEVICES; i++) {
            gDevices[gCount] = (MTDeviceRef)CFArrayGetValueAtIndex(gList, i);
            gRunning[gCount] = false;
            gCount++;
        }
    }
    int32_t count = gCount;
    pthread_mutex_unlock(&gLock);
    return count;
}

uint32_t MMDeviceService(int32_t index) {
    if (!MMMultitouchAvailable()) return 0;
    pthread_mutex_lock(&gLock);
    uint32_t service = (index >= 0 && index < gCount) ? pGetService(gDevices[index]) : 0;
    pthread_mutex_unlock(&gLock);
    return service;
}

bool MMStartDevice(int32_t index, MMFrameCallback callback) {
    if (!MMMultitouchAvailable()) return false;
    pthread_mutex_lock(&gLock);
    bool ok = false;
    if (index >= 0 && index < gCount) {
        gCallback = callback;
        if (!gRunning[index]) {
            pRegister(gDevices[index], mm_contact_callback);
            pStart(gDevices[index], 0);
            gRunning[index] = true;
        }
        ok = true;
    }
    pthread_mutex_unlock(&gLock);
    return ok;
}
