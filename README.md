
Syphon for Jitter
===

Syphon is a system for sending video between applications. You can use it to send high resolution and high frame rate video, 3D textures and synthesized content between Max 5 / Jitter and other applications.

Syphon for Jitter includes two externals, jit.gl.syphonclient & jit.gl.syphonserver. 

* jit.gl.syphonclient - brings frames from other applications into Jitter.

* jit.gl.syphonserver - allows jit.matrices and jit.gl.textures to be named and published to the system, so that other applications which support Syphon can use them.

Licensing
====

Syphon for Jitter is published under a Simplified BSD license. See the included License.txt file.

Requirements
====

Mac OS X 10.6.4 or greater
Max 6.1 or greater

Installation
====

We now distribute the externals as a Package for Max 6, so simply move the "Syphon" package folder to your Max Applications "packages" and all help files, examples, and externals will be automatically added to the Max search path.

Instructions
====

Syphon for Jitter relies on OpenGL, since the Syphon Framework is hardware (GPU) accelerated. These are the same requirements when using any standard jitter opengl object. When using both the client and the server:

1. You need to ensure you have a properly set up jit.gl.render and destination (usually a jit.window) to ensure a valid rendering context

2. You need to ensure that your syphon object (both client and server) are set to use this context.

Changes since r2
- Support for latest versions of Max, including 64-bit support.

Changes since Public Beta 2
- Fix for crash when excluding servername attribute
- Fix for visible 0 contexts on init not working
- Various small fixes to codebase

Changes since Public Beta 1
- Fixes and improvements to the underlying Syphon framework.

Credits
====

Syphon for Jitter - Tom Butterworth (bangnoise) and Anton Marini (vade)

http://syphon.v002.info