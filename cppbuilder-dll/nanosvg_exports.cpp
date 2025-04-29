#define NANOSVG_IMPLEMENTATION
#include "nanosvg.h"
#define NANOSVGRAST_IMPLEMENTATION
#include "nanosvgrast.h"

#include <windows.h>
#include <stdlib.h>

extern "C" __declspec(dllexport)
unsigned char* __cdecl rasterize_svg_fit(const char* svgText,
    float targetW, float targetH,
    int* outW, int* outH,
    int convertToBGRA)
{
    static NSVGrasterizer* rast = nullptr;
    if (!rast)
        rast = nsvgCreateRasterizer();

    NSVGimage* image = nsvgParse((char*)svgText, "px", 96);
    if (!image)
        return nullptr;

    float scaleX = targetW / image->width;
    float scaleY = targetH / image->height;
    float scale = (scaleX < scaleY) ? scaleX : scaleY;

    int w = (int)(image->width * scale);
    int h = (int)(image->height * scale);

    unsigned char* img = (unsigned char*)malloc(w * h * 4);
    if (!img) {
        nsvgDelete(image);
        return nullptr;
    }

    nsvgRasterize(rast, image, 0, 0, scale, img, w, h, w * 4);

    if (convertToBGRA) {
        for (int y = 0; y < h; ++y) {
            unsigned char* row = img + y * w * 4;
            for (int x = 0; x < w; ++x) {
                unsigned char* px = row + x * 4;
                unsigned char r = px[0];
                px[0] = px[2]; // B
                px[2] = r;     // R
            }
        }
    }

    nsvgDelete(image);

    *outW = w;
    *outH = h;
    return img;
}

extern "C" __declspec(dllexport)
void __cdecl free_image(unsigned char* ptr)
{
    if (ptr)
        free(ptr);
}

extern "C" __declspec(dllexport)
int __cdecl get_svg_fit_size(const char* svgText,
    float maxW, float maxH,
    int* outW, int* outH)
{
    NSVGimage* image = nsvgParse((char*)svgText, "px", 96);
    if (!image)
        return 0; // failure

    // If both are zero, just return the image’s native size
    if (maxW <= 0 && maxH <= 0) {
        *outW = (int)image->width;
        *outH = (int)image->height;
    }
    else {
        // If one axis is unconstrained, compute it to preserve aspect ratio
        if (maxW <= 0)
            maxW = maxH * (image->width / image->height);
        if (maxH <= 0)
            maxH = maxW * (image->height / image->width);

        float scaleX = maxW / image->width;
        float scaleY = maxH / image->height;
        float scale  = (scaleX < scaleY) ? scaleX : scaleY;

        *outW = (int)(image->width  * scale);
        *outH = (int)(image->height * scale);
    }

    nsvgDelete(image);
    return 1; // success
}

extern "C" __declspec(dllexport)
int __cdecl get_svg_nativesize(const char* svgText,
	int* outW, int* outH)
{
    NSVGimage* image = nsvgParse((char*)svgText, "px", 96);
    if (!image)
        return 0; // failure

	*outW = (int)image->width;
	*outH = (int)image->height;

    nsvgDelete(image);
    return 1; // success
}
