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

### Install the command cleanly

    mkdir -p ~/.local/bin

then link

    ln -sf ~/.local/src/llama.cpp/build/bin/llama-server \
      ~/.local/bin/llama-server

then make sure

    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc

and check

    which llama-server

### model

    llama-server \
      -m ~/.local/src/llama.cpp/models/Dolphin3.0-Llama3.1-8B-Q4_K_M.gguf \
      -ngl 999 \
      -c 8192 \
      --host 127.0.0.1 \
      --port 8080 \
      --jinja \
      --chat-template chatml

create `ai` command

    mkdir -p ~/.local/bin ~/.local/share/ai

    nvim ~/.local/bin/ai

paste

    #!/usr/bin/env python3
    
    import json
    import os
    import re
    import subprocess
    import sys
    import urllib.request
    import urllib.error
    
    API = "http://127.0.0.1:8080/v1/chat/completions"
    HISTORY = os.path.expanduser("~/.local/share/ai/history.json")
    
    SYSTEM = """You are a local Linux computer assistant.
    
    You can execute commands on the user's computer.
    
    When you need to perform an action, output EXACTLY:
    
    TOOL: exec
    COMMAND: <one shell command>
    
    Do not put the command in markdown fences.
    
    After the command is executed, you will receive its output and can continue.
    
    Use normal text when you do not need to execute anything.
    
    Be concise.
    
    Never use sudo.
    """
    
    def load_history():
        if not os.path.exists(HISTORY):
            return []
    
        try:
            with open(HISTORY, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    
    def save_history(messages):
        os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
        with open(HISTORY, "w", encoding="utf-8") as f:
            json.dump(messages, f, ensure_ascii=False, indent=2)
    
    def ask(messages):
        payload = {
            "messages": messages,
            "stream": False,
            "temperature": 0.2
        }
    
        request = urllib.request.Request(
            API,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
    
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                result = json.load(response)
        except urllib.error.URLError as e:
            print("Could not connect to llama-server.")
            print("Make sure llama-server is running on 127.0.0.1:8080.")
            print(f"Details: {e}")
            sys.exit(1)
    
        return result["choices"][0]["message"]["content"]
    
    def execute(command):
        print(f"\n$ {command}\n")
    
        result = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True
        )
    
        output = result.stdout
    
        if result.stderr:
            output += result.stderr
    
        if not output:
            output = "(command produced no output)"
    
        return result.returncode, output
    
    def main():
        args = sys.argv[1:]
    
        if not args:
            print('Usage: ai "your request"')
            print("       ai --clear")
            print("       ai --history")
            sys.exit(1)
    
        if args[0] == "--clear":
            save_history([])
            print("Conversation cleared.")
            return
    
        if args[0] == "--history":
            print(json.dumps(load_history(), indent=2, ensure_ascii=False))
            return
    
        prompt = " ".join(args)
    
        messages = load_history()
    
        if not messages:
            messages.append({
                "role": "system",
                "content": SYSTEM
            })
    
        messages.append({
            "role": "user",
            "content": prompt
        })
    
        for _ in range(8):
            answer = ask(messages)
    
            match = re.search(
                r"TOOL:\s*exec\s*\nCOMMAND:\s*(.+)",
                answer,
                re.IGNORECASE
            )
    
            if not match:
                print(answer)
                messages.append({
                    "role": "assistant",
                    "content": answer
                })
                save_history(messages)
                return
    
            command = match.group(1).strip()
    
            dangerous = re.search(
                r"\b(rm|rmdir|chmod|chown|mv|dd|mkfs|sudo|systemctl)\b",
                command
            )
    
            if dangerous:
                print(f"\nThe assistant wants to execute:\n\n  {command}\n")
                confirm = input("Execute? [y/N] ").strip().lower()
    
                if confirm != "y":
                    messages.append({
                        "role": "assistant",
                        "content": answer
                    })
                    messages.append({
                        "role": "user",
                        "content": "Do not execute that command. Explain what you would have done instead."
                    })
                    continue
    
            code, output = execute(command)
    
            messages.append({
                "role": "assistant",
                "content": answer
            })
    
            messages.append({
                "role": "user",
                "content": (
                    f"Tool execution result:\n"
                    f"exit_code: {code}\n"
                    f"output:\n{output}"
                )
            })
    
        print("Maximum tool-call steps reached.")
        save_history(messages)
    
    if __name__ == "__main__":
        main()


make executable

    chmod +x ~/.local/bin/ai

test

    ai "hello"

lol

```python
#!/usr/bin/env python3
import json, os, re, subprocess, sys, urllib.request

API = "http://127.0.0.1:8080/v1/chat/completions"
HIST = os.path.expanduser("~/.local/share/ai/history.json")

SYSTEM = """You are a Linux computer agent.

If the user asks you to perform an action, USE THE TOOL. Do not explain how.

Tool format:
TOOL: exec
COMMAND: <one single-line shell command>

Rules:
- COMMAND is exactly one line.
- Never use sudo.
- Never claim success without execution results.
- For shell scripts ALWAYS create valid scripts.
- When writing a script, ALWAYS use:
  printf '%s\\n' '#!/bin/bash' 'command' > file.sh
- NEVER use echo with \\n to create files.
- NEVER put literal \\n inside a script unless explicitly requested.
- Use && when multiple commands must succeed.
- After execution, inspect the result.
- If it failed, fix it.
- Be concise."""

def load():
    try:
        with open(HIST) as f:
            return json.load(f)
    except:
        return [{"role": "system", "content": SYSTEM}]

def save(m):
    os.makedirs(os.path.dirname(HIST), exist_ok=True)
    with open(HIST, "w") as f:
        json.dump(m[-50:], f, ensure_ascii=False)

def ask(m):
    data = json.dumps({
        "messages": m,
        "stream": False,
        "temperature": 0.1
    }).encode()

    r = urllib.request.Request(
        API, data=data,
        headers={"Content-Type": "application/json"}
    )

    with urllib.request.urlopen(r, timeout=300) as x:
        return json.load(x)["choices"][0]["message"]["content"]

def command(text):
    m = re.search(
        r"(?im)^TOOL:\s*exec\s*\nCOMMAND:\s*(.+)$",
        text
    )
    if not m:
        return None

    c = m.group(1).splitlines()[0].strip()

    # Fix the common model mistake: literal "\n" inside shell strings.
    c = c.replace(r"\n", "\n")

    return c

def run(c):
    p = subprocess.run(
        c,
        shell=True,
        text=True,
        capture_output=True
    )
    out = (p.stdout + p.stderr).strip()
    return p.returncode, out or "(no output)"

def dangerous(c):
    return re.search(
        r"\b(rm|rmdir|mv|dd|mkfs|sudo|systemctl|kill|pkill|reboot|shutdown)\b",
        c,
        re.I
    )

def main():
    args = sys.argv[1:]

    if not args:
        print('usage: ai "request"')
        return

    if args[0] == "--clear":
        try:
            os.remove(HIST)
        except FileNotFoundError:
            pass
        print("cleared")
        return

    if args[0] == "--history":
        print(json.dumps(load(), indent=2))
        return

    m = load()
    m.append({"role": "user", "content": " ".join(args)})

    previous = None

    for _ in range(6):
        a = ask(m)
        c = command(a)

        if not c:
            m += [
                {"role": "assistant", "content": a},
                {"role": "user", "content":
                 "Execute the request now. Reply ONLY with:\n"
                 "TOOL: exec\n"
                 "COMMAND: <one single-line shell command>"}
            ]
            continue

        if c == previous:
            m.append({
                "role": "user",
                "content":
                "That exact command already failed. Do not repeat it. "
                "Generate a different correct command."
            })
            continue

        previous = c
        print(f"$ {c}")

        if dangerous(c):
            if input("Execute? [y/N] ").strip().lower() != "y":
                m.append({
                    "role": "user",
                    "content": "Command cancelled. Generate another approach."
                })
                continue

        code, out = run(c)
        print(out)

        m += [
            {"role": "assistant", "content": a},
            {"role": "user", "content":
             f"Tool result:\nexit_code={code}\n{out}"}
        ]

        if code == 0:
            continue

    save(m)
    print("maximum tool steps reached")

if __name__ == "__main__":
    main()
```

