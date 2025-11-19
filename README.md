# Horizons.jl: A 2D/3D Game Rendering Engine for Julia

**Horizons.jl** is a modular and backend-agnostic rendering engine optimized for 2D and 3D game development.  
It provides high-performance abstractions for real-time rendering, scene management, and custom shaders, all with a clean, command-buffer-driven API.

---

## Installation

```julia
julia> ]add Horizons
# or for the development version
julia> ]add https://github.com/Gesee-y/Horizons.jl
```

---

## Features

### Architecture

* **Command Buffer Pipeline**: Rendering commands are recorded and batched before dispatch, enabling backend-independent optimization and minimal draw overhead.
* **Multi-Backend**:

  * **SDL** (software, CPU shaders)
  * **OpenGL** (in progress)


### Shaders


* **Custom Shader Support**: Hook into the pipeline to define your own rendering effects.

---

## License

This package is licensed under the MIT License.


