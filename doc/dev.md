# Comprehensive Guide: Implementing a Custom Rendering Backend for CRHorizons

This guide synthesizes the architectural requirements of the `CRHorizons` module, using the provided **SDLHorizons** example as a concrete template. The goal is to provide a complete, step-by-step roadmap for developers to integrate any low-level graphics API (Vulkan, DirectX, etc.) as a new **Horizon Backend**.

We will emphasize the **Command Pattern** as the key to extensibility, enabling custom rendering actions without modifying the core engine.

## I. Setup and Core Backend Abstraction

### Step 1: Define Concrete Types

Create your module (e.g., `VulkanHorizons`) and define the following structs based on your chosen API, inheriting from the core `CRHorizons` abstract types.

| Abstract Type | Your Concrete Type Example | Role |
| :--- | :--- | :--- |
| `RendererData` | `VulkanRenderData` | Holds the API pointers (Instance, Device, Queue, etc.). Stored inside `HRenderer`. |
| `AbstractResource` | `VulkanTexture` (Alias) | Base type for all resources. |
| `TextureData` | `VulkanTextureHandle` | Holds the GPU handles for textures (e.g., Image View, Sampler). |
| `ObjectData` | `VulkanObjectState` | Holds object-specific data (e.g., Vertex Buffer ID, Material Index). |

**Define Aliases:** Create clear aliases for use in application code.

```julia
# 1. Define your data storage types
struct VulkanRenderData <: CRHorizons.RendererData; ... end
struct VulkanObjectState <: CRHorizons.ObjectData; ... end
struct VulkanTextureHandle <: CRHorizons.TextureData; ... end

# 2. Define the generic container aliases
const VulkanTexture = CRHorizons.Texture{VulkanTextureHandle}
const VulkanObject = CRHorizons.Object2D{VulkanObjectState}
const VulkanRenderer = CRHorizons.HRenderer2D{VulkanRenderData, VulkanObjectState}
```

### Step 2: Implement Initialization and Cleanup (Lifecycle)

You must overload `CRHorizons.InitBackend` and `CRHorizons.DestroyBackend` to manage the API's global state.

  * **Initialization (`InitBackend`)**:
      * Call the native API setup functions (e.g., create device, renderer context).
      * Instantiate your `VulkanRenderData`.
      * Wrap the data in the generic `VulkanRenderer`.
      * **Crucially, emit:** `CRHorizons.HORIZON_BACKEND_INITED.emit = renderer`.
  * **Cleanup (`DestroyBackend`)**:
      * Destroy all remaining global resources (Renderer, Device, etc.).
      * **Crucially, emit:** `CRHorizons.HORIZON_BACKEND_DESTROYED.emit = backend`.

-----

## II. Texture and Viewport Management

### Step 3: Implement Texture Creation and Access

Overload these functions, dispatching on your `VulkanRenderer` type, following the pattern shown in `SDLHorizons`.

| Function | Role in Backend | Template Reference |
| :--- | :--- | :--- |
| `CRHorizons.CreateTexture` | Allocates GPU memory for the texture resource. | `BlankTexture(ren, w, h, ...)` |
| `CRHorizons.DestroyTexture` | Frees the GPU texture handle. **Emits `HORIZON_TEXTURE_DESTROYED`.** | `SDLHorizons.DestroyTexture(tex::SDLTexture)` |
| `CRHorizons.ConvertAccess` | **MANDATORY.** Translates the abstract `TextureAccess` (`STATIC`, `STREAMING`, `TARGET`) into your API's native access flags (e.g., Vulkan usage bits). | `SDLHorizons.ConvertAccess(::Type{SDLRender}, a::TextureAccess)` |

### Step 4: Implement Viewport and Render Target Setup

The `HViewport` is typically managed using a **Render Target** texture.

  * **`CRHorizons.CreateViewport`**: Should create a special `VulkanTexture` with `TEXTURE_TARGET` access. This texture acts as the viewport's **screen**. You must then set this texture as the current **Render Target**.
  * **Render Target Switching**: Implement functions like `SetRenderTarget(ren, texture)` to direct drawing commands to a specific texture or the main screen.
  * **Cleanup**: Implement `CRHorizons.ClearTexture(ren, texture)` and `CRHorizons.ClearViewport(ren)` which internally switch the render target and issue a clear command.

-----

## III. Object Abstraction and Command System (The Core of Extensibility)

The **Command Buffer** is the central feature enabling seamless extensibility and API decoupling. Instead of calling API-specific draw functions directly in the main loop, you record abstract commands.

### Step 5: Define Object-Texture Linking

Your custom `Object` must be able to retrieve its assigned texture.

```julia
# Overload the generic getter function
CRHorizons.get_texture(obj::VulkanObject) = obj.data.texture
```

### Step 6: Create and Define Custom Commands

The core rendering logic is implemented via custom `CommandAction` structs. This allows the application layer to call high-level functions (like `ApplySDLShader`) which translate into recorded commands, deferring the actual API calls until the `ExecuteCommands` phase.

1.  **Define the Command Struct**: Inherit from the `@commandaction` macro.
    ```julia
    @commandaction MyCustomDrawCmd begin
        vertex_count :: Int
        shader_id :: UInt32
    end
    ```
2.  **Define the Command API**: Create a user-facing function that adds your command to the queue.
    ```julia
    function DrawCustomObject(ren::VulkanRenderer, object::VulkanObject)
        cb = CRHorizons.get_commandbuffer(ren)
        action = MyCustomDrawCmd(get_vertex_count(object), get_shader_id(object))
        
        # Add command to the target (the viewport's screen texture ID)
        target_id = CRHorizons.get_id(CRHorizons.get_texture(CRHorizons.get_viewport(ren).screen))
        CRHorizons.add_command!(cb, target_id, 0, CRHorizons.get_id(object), action)
    end
    ```

### Step 7: Implement Command Execution (`execute_command`)

This is the only place where your concrete backend interacts with the recorded commands and executes the low-level API calls.

  * You must overload `CRHorizons.execute_command` for each custom command type you define.
  * The function receives a list of commands (`Vector{...Cmd}`) for a specific target and caller resource.

<!-- end list -->

```julia
function CRHorizons.execute_command(
    ren::VulkanRenderer, 
    targetid, 
    callerid, 
    commands::Vector{MyCustomDrawCmd}
)
    # 1. Get the current Render Target and Caller resource handles
    target = CRHorizons.get_resourcefromid(ren, targetid)
    caller = CRHorizons.get_resourcefromid(ren, callerid)
    
    # 2. Set the Render Target (API-specific call)
    SetVulkanRenderTarget(ren, target)
    
    # 3. Process all queued commands of this type
    for cmd in commands
        # Example: Bind buffers, set pipeline state, and call draw
        VulkanAPI.bind_pipeline(cmd.shader_id)
        VulkanAPI.draw_vertices(cmd.vertex_count)
    end
    
    # 4. Reset the Render Target (API-specific call)
    VulkanAPI.reset_render_target() 
end
```

### Step 8: Implement Final Presentation

Finally, implement the function that makes the rendered frame visible. This is called automatically by `UpdateRender`.

```julia
# Overload this to perform the final swapchain/buffer presentation.
CRHorizons.PresentRender(backend::VulkanRenderer) = VulkanAPI.present_swapchain(backend.data)
```
