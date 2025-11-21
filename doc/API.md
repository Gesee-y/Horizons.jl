# CRHorizons Rendering Engine API Documentation

The **CRHorizons** module provides a highly decoupled and extensible framework for managing rendering backends, resources, and drawing commands.

## I. Core Types and Abstractions

These abstract types and generic structures are the foundation for creating any concrete rendering backend (Style) in CRHorizons.

| Export | Type / Structure | Description |
| :--- | :--- | :--- |
| `AbstractRenderer` | `abstract type` | The required supertype for the concrete **Backend Dispatcher** (e.g., `SDLRender`). |
| `RendererData` | `abstract type` | The supertype for structs holding API-specific context (e.g., `SDLRenderData`). Parameterizes the generic `HRenderer`. |
| `AbstractResource` | `abstract type` | Base type for all GPU-managed data (Textures, Buffers, etc.). |
| `TextureData` | `abstract type` | Supertype for structs holding API-specific texture handles (e.g., `SDLTextureData`). |
| `ObjectData` | `abstract type` | Supertype for structs holding API-specific object state (e.g., vertex buffer IDs). |
| `Texture` | `mutable struct` | Generic resource container parameterized by `TextureData`. Includes generic metadata like `rect` and `static`. |
| `Object` | `mutable struct` | Generic drawable item parameterized by `ObjectData` and dimension (`N`). Holds `transform` and `rect`. |
| `Object2D`, `Object3D` | `const alias` | Aliases for 2D and 3D objects, respectively. |
| `HRenderer` | `struct` | The generic, immutable container holding the `RendererData`, `CommandBuffer`, and `ResourcePool`. |
| `HRenderer2D`, `HRenderer3D` | `const alias` | Aliases for 2D and 3D renderers. |
| `HViewport` | `mutable struct` | Container managing scene objects (`objects`), subviews (`subview`), and the render target screen (`screen`). |
| `TextureAccess` | `@enum` | Defines the intended usage pattern for a texture (`TEXTURE_STATIC`, `TEXTURE_STREAMING`, `TEXTURE_TARGET`). |
| `Color8`, `Color` | `struct` | Structures for defining colors using 8-bit integers or 32-bit floats. |

---

## II. Backend Lifecycle and State Management

These functions are the primary dispatch points used to initialize, update, and shut down the rendering backend. They **must be overloaded** by any concrete backend implementation (e.g., `SDLHorizons`).

| Export | Signature | Description |
| :--- | :--- | :--- |
| `InitBackend` | `InitBackend(::Type{AbstractRenderer}, win, args...)` | Initializes the rendering API and creates the backend context. **Emits `HORIZON_BACKEND_INITED`.** |
| `DestroyBackend` | `DestroyBackend(backend::HRenderer)` | Cleans up and destroys all resources associated with the backend. **Emits `HORIZON_BACKEND_DESTROYED`.** |
| `UpdateRender` | `UpdateRender(backend::HRenderer)` | The main rendering pipeline function. Executes commands, renders the viewport, and calls `PresentRender`. (Usually not overloaded). |
| `PresentRender` | `PresentRender(backend::HRenderer)` | **Crucial dispatch point.** Swaps the front/back buffers or presents the final frame to the screen. Overloaded by the backend. |
| `ClearScreen` | `ClearScreen(ren::HRenderer)` | Clears the main render target (the final display buffer). |
| `ConvertAccess` | `ConvertAccess(::Type{AbstractRenderer}, a::TextureAccess)` | Translates the abstract `TextureAccess` enum into the native API's format/flags. |

---

## III. Resource and Object Management

These functions manage the creation, destruction, and lookup of GPU resources and drawable objects.

### A. Resource Lookups & Registration

| Export | Signature | Description |
| :--- | :--- | :--- |
| `get_commandbuffer` | `get_commandbuffer(h::HRenderer)` | Returns the `CommandBuffer` instance for recording drawing instructions. |
| `get_resourcefromid` | `get_resourcefromid(ren::HRenderer, id)` | Retrieves a resource (Texture, etc.) from the pool using its unique ID. |
| `register_resource` | `register_resource(ren::HRenderer, res::AbstractResource)` | Adds a newly created resource to the renderer's `ResourcePool`. |
| `get_name` | `get_name(::Type{<:AbstractResource})` | Must be overloaded for each concrete resource type (e.g., `get_name(::Type{MyTexture}) = :texture`). |
| `get_resourcenames` | `get_resourcenames(::Type{<:RendererData})` | Must be overloaded to return a tuple of all supported resource names (e.g., `(:texture, :shader)`). |
| `get_texture` | `get_texture(obj::Object)` | Must be overloaded for each concrete object type to return its associated `Texture`. |

### B. Texture Management

| Export | Signature | Description |
| :--- | :--- | :--- |
| `CreateTexture` | `CreateTexture(ren::AbstractRenderer, w, h, args...)` | **Mandatory dispatch.** Allocates the GPU texture resource. **Emits `HORIZON_TEXTURE_CREATED`.** |
| `DestroyTexture` | `DestroyTexture(tex::Texture)` | **Mandatory dispatch.** Frees the GPU texture resource. **Emits `HORIZON_TEXTURE_DESTROYED`.** |
| `ClearTexture` | `ClearTexture(ren::HRenderer, tex::Texture)` | Clears the content of a specific texture (when used as a render target). |

### C. Object Management

| Export | Signature | Description |
| :--- | :--- | :--- |
| `RenderObject` | `RenderObject(b::AbstractRenderer, obj::Object, parent=nothing)` | **Mandatory dispatch.** Translates the object's properties (`rect`, `transform`) into drawing commands added to the `CommandBuffer`. |
| `DestroyObject` | `DestroyObject(r::AbstractRenderer, obj::Object)` | **Mandatory dispatch.** Cleans up object-specific resources (e.g., vertex buffers). |

---

## IV. Viewport Management

| Export | Signature | Description |
| :--- | :--- | :--- |
| `CreateViewport` | `CreateViewport(r::AbstractRenderer, args...)` | **Mandatory dispatch.** Creates a new `HViewport` instance, including its render target screen texture. |
| `ClearViewport` | `ClearViewport(ren::HRenderer)` | Clears the viewport's screen render target. |
| `SetViewportPosition` | `SetViewportPosition(r::HRenderer, x::Int, y::Int)` | Sets the position of the viewport on the final screen. |
| `SetViewportSize` | `SetViewportSize(r::HRenderer, w::Int, h::Int)` | Sets the size of the viewport. |
| `SwapViewport` | `SwapViewport(r::HRenderer, v::HViewport)` | Changes the currently active viewport for the renderer. Returns the old viewport. |
| `SwapScreen` | `SwapScreen(v::HViewport, nscreen::Object)` | Changes the render target object (`screen`) of the given viewport. |
| `AddObject` | `AddObject(v::HViewport, obj::Object)` | Adds a root object to the viewport's scene graph. |
| `AddChildObject` | `AddChildObject(parent::Object, obj::Object)` | Adds an object as a child of an existing scene object. |

---

## V. Notifications (EventNotifiers)

These are the signals emitted by the `CRHorizons` module to notify listeners of state changes, resource lifecycle events, and errors.

| Export | Signature | Description |
| :--- | :--- | :--- |
| `HORIZON_BACKEND_INITED` | `(renderer)` | Emitted when a backend is successfully initialized. |
| `HORIZON_BACKEND_DESTROYED`| `(renderer)` | Emitted when a backend is successfully shut down. |
| `HORIZON_TEXTURE_CREATED` | `(ren, tex)` | Emitted when a texture resource is successfully created. |
| `HORIZON_TEXTURE_DESTROYED`| `(tex)` | Emitted when a texture resource is destroyed. |
| `HORIZON_ERROR` | `(mes::String, error::String)` | Emitted for **severe errors** that prevent continued operation. |
| `HORIZON_WARNING` | `(mes::String, warning::String)` | Emitted for **recoverable issues** or potential problems. |
| `HORIZON_INFO` | `(mes::String, info::String)` | Emitted for general information (e.g., driver details). |