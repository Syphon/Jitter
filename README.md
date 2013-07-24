Syphon for Jitter, Public Beta 2

===

About

Syphon is a system for sending video between applications. You can use it to send high resolution and high frame rate video, 3D textures and synthesized content between Max 5 / Jitter and other applications.

Syphon for Jitter includes two externals, jit.gl.syphonclient & jit.gl.syphonserver. 

jit.gl.syphonclient - brings frames from other applications into Jitter.

jit.gl.syphonserver - allows jit.matrices and jit.gl.textures to be named and published to the system, so that other applications which support Syphon can use them.

Licensing

Syphon for Jitter is published under a Simplified BSD license. See the included License.txt file.

Requirements

Mac OS X 10.6.4 or greater
Max 5.1.4 or greater

Installation

Jit.gl.syphonclient.mxo & jit.gl.syphonserver.mxo and included help files (.maxhelp) should all be installed into a file path that Max 5 can see. Normally this means ensuring that you have a file path entry in the Max 5 Options -> File Preferences menu option.

It is recommended to make a new folder for 3rd party externals, so as to not contaminate the existing Max 5 patches and examples folder.

Instructions

Syphon for Jitter relies on OpenGL, since the Syphon Framework is hardware (GPU) accelerated. These are the same requirements when using any standard jitter opengl object. When using both the client and the server:

1. You need to ensure you have a properly set up jit.gl.render and destination (usually a jit.window) to ensure a valid rendering context

2. You need to ensure that your syphon object (both client and server) are set to use this context.

Changes since Public Beta 1
- Fixes and improvements to the underlying Syphon framework.

Credits

Syphon for Jitter - Tom Butterworth (bangnoise) and Anton Marini (vade)

http://syphon.v002.info