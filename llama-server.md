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

## chatbot

    mkdir -p ~/.local/bin

    ln -sf ~/.config/llama.cpp/build/bin/llama-server ~/.local/bin/llama-server

    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    source ~/.bashrc

check

        which llama-server

should output

    /home/$USER/.local/bin/llama-server

or check

    llama-server --version

create

    mkdir -p ~/.local/share/ai

    vim ~/.local/bin/ai

and paste

    #!/usr/bin/env bash

    set -euo pipefail

    HISTORY="$HOME/.local/share/ai/history.json"
    API="http://127.0.0.1:8080/v1/chat/completions"

    if [[ ! -f "$HISTORY" ]]; then
        printf '%s\n' '{"messages":[]}' > "$HISTORY"
    fi

    case "${1:-}" in
        --clear)
            printf '%s\n' '{"messages":[]}' > "$HISTORY"
            echo "Conversation cleared."
            exit 0
            ;;

        --history)
            cat "$HISTORY"
            exit 0
            ;;

        --help)
            cat <<'EOF'
    Usage:
      ai "your question"
      ai your question

    Commands:
      ai --clear       Clear conversation
      ai --history     Show conversation history
      ai --help        Show help
    EOF
            exit 0
            ;;
    esac

    if [[ $# -eq 0 ]]; then
        echo 'Usage: ai "your question"'
        exit 1
    fi

    PROMPT="$*"

    python - "$HISTORY" "$API" "$PROMPT" <<'PY'
    import json
    import sys
    import urllib.request
    import urllib.error

    history_file = sys.argv[1]
    api = sys.argv[2]
    prompt = sys.argv[3]

    with open(history_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    messages = data.get("messages", [])

    messages.append({
        "role": "user",
        "content": prompt
    })

    payload = {
        "messages": messages,
        "stream": False
    }

    request = urllib.request.Request(
        api,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            result = json.load(response)

    except urllib.error.URLError as e:
        messages.pop()
        print("Could not connect to llama-server.", file=sys.stderr)
        print("Make sure llama-server is running on 127.0.0.1:8080.", file=sys.stderr)
        print(f"Details: {e}", file=sys.stderr)
        sys.exit(1)

    except Exception as e:
        messages.pop()
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        answer = result["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        messages.pop()
        print("Unexpected response from llama-server:", file=sys.stderr)
        print(json.dumps(result, indent=2), file=sys.stderr)
        sys.exit(1)

    messages.append({
        "role": "assistant",
        "content": answer
    })

    with open(history_file, "w", encoding="utf-8") as f:
        json.dump(
            {"messages": messages},
            f,
            ensure_ascii=False,
            indent=2
        )

    print(answer)
    PY

make it executable

    chmod +x ~/.local/bin/ai

