After cloning the repository, clone submodules, for example by using

    git submodule update --init

This will bring in the Syphon framework, some shared code and the Max 6 SDK.

Open the Jitter.xcworkspace and build all. This will produce external mxi files placed in the "Packages" folder, which you can then move to your Max installations "packages" folder, and name it Syphon.