install depends

    sudo pacman -S --needed cuda cmake

create and clone

    mkdir -p ~/.local/src
    git clone https://github.com/ggml-org/llama.cpp.git ~/.local/src/llama.cpp
    cd ~/.local/src/llama.cpp

Build only the server

    cmake -B build \
      -DGGML_CUDA=ON \
      -DCMAKE_BUILD_TYPE=Release

    cmake --build build --config Release -t llama-server -j"$(nproc)"

then;

    ./build/bin/llama-server --version
