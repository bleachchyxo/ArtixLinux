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

You should also verify CUDA was actually compiled in:

    ./build/bin/llama-server --help | grep -E 'tools|agent'

You should see;

    --tools TOOL1,TOOL2,...
    --agent

Download the model from here; 

https://huggingface.co/dphn/Dolphin3.0-Llama3.1-8B-GGUF/tree/main

    llama.cpp $ mv ~/Downloads/Dolphin3.0-Llama3.1-8B-Q4_K_M.gguf models/

then

    ./build/bin/llama-server \
      -m models/Dolphin3.0-Llama3.1-8B-Q4_K_M.gguf \
      -ngl 999 \
      -c 8192 \
      --host 127.0.0.1 \
      --port 8080 \
      --jinja

you can test it on your browser

    http://127.0.0.1:8080
