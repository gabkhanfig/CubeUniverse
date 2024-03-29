// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

#include "../imgui.h"
#include "imgui_impl_sdlrenderer2.h"

#include <stdio.h>

// Wrap this in a namespace to keep it separate from the C++ API
namespace cimgui
{
#include "cimgui_impl_sdlrenderer2.h"
}

// By-value struct conversions

// Function stubs

#ifndef IMGUI_DISABLE

CIMGUI_API bool cimgui::cImGui_ImplSDLRenderer2_Init(cimgui::SDL_Renderer* renderer)
{
    return ::ImGui_ImplSDLRenderer2_Init(reinterpret_cast<::SDL_Renderer*>(renderer));
}

CIMGUI_API void cimgui::cImGui_ImplSDLRenderer2_Shutdown(void)
{
    ::ImGui_ImplSDLRenderer2_Shutdown();
}

CIMGUI_API void cimgui::cImGui_ImplSDLRenderer2_NewFrame(void)
{
    ::ImGui_ImplSDLRenderer2_NewFrame();
}

CIMGUI_API void cimgui::cImGui_ImplSDLRenderer2_RenderDrawData(ImDrawData* draw_data)
{
    ::ImGui_ImplSDLRenderer2_RenderDrawData(draw_data);
}

CIMGUI_API bool cimgui::cImGui_ImplSDLRenderer2_CreateFontsTexture(void)
{
    return ::ImGui_ImplSDLRenderer2_CreateFontsTexture();
}

CIMGUI_API void cimgui::cImGui_ImplSDLRenderer2_DestroyFontsTexture(void)
{
    ::ImGui_ImplSDLRenderer2_DestroyFontsTexture();
}

CIMGUI_API bool cimgui::cImGui_ImplSDLRenderer2_CreateDeviceObjects(void)
{
    return ::ImGui_ImplSDLRenderer2_CreateDeviceObjects();
}

CIMGUI_API void cimgui::cImGui_ImplSDLRenderer2_DestroyDeviceObjects(void)
{
    ::ImGui_ImplSDLRenderer2_DestroyDeviceObjects();
}

#endif // #ifndef IMGUI_DISABLE
