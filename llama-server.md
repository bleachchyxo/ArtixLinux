Install important stuff

    sudo pacman -S cuda cmake
    
Then verify

    nvcc --version

Clone the repo 

    git clone https://github.com/ggml-org/llama.cpp.git

- Still need to check a fancy place where to put it

Build the repo

    cd llama.cpp

    cmake -B build \
      -DGGML_CUDA=ON \
      -DCMAKE_BUILD_TYPE=Release

    cmake --build build --config Release -t llama-server

Then check:

    ./build/bin/llama-server --version
