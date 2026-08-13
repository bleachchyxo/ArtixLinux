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

```python
#!/usr/bin/env python3
import json, os, re, subprocess, sys, urllib.request

API = "http://127.0.0.1:8080/v1/chat/completions"
HIST = os.path.expanduser("~/.local/share/ai/history.json")

SYSTEM = """You are a Linux computer agent.

You have ONE tool: exec.

If the user asks you to DO, CREATE, CHANGE, RUN, DELETE, INSTALL,
WRITE, MOVE, COPY, EDIT, CHECK, or otherwise perform an action,
you MUST use the tool.

NEVER explain how to do the action instead of doing it.

Tool syntax MUST be exactly:
TOOL: exec
COMMAND: <one single-line shell command>

The COMMAND must be one line.
Do not use markdown.
Do not write anything before TOOL.
Do not write anything after COMMAND.

After execution, inspect the result and continue if necessary.
Never claim something happened unless the tool result proves it.
Never invent output.
Never use sudo.

If the user only asks a question, answer normally.
Be concise."""

def load():
    try:
        with open(HIST) as f: return json.load(f)
    except:
        return [{"role":"system","content":SYSTEM}]

def save(m):
    os.makedirs(os.path.dirname(HIST), exist_ok=True)
    with open(HIST, "w") as f: json.dump(m[-60:], f, ensure_ascii=False)

def ask(m):
    data = json.dumps({
        "messages": m,
        "stream": False,
        "temperature": 0.1
    }).encode()
    r = urllib.request.Request(
        API, data=data,
        headers={"Content-Type":"application/json"}
    )
    with urllib.request.urlopen(r, timeout=300) as x:
        return json.load(x)["choices"][0]["message"]["content"]

def run(cmd):
    p = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return p.returncode, (p.stdout + p.stderr).strip() or "(no output)"

def tool(a):
    x = re.search(r"(?im)^TOOL:\s*exec\s*\nCOMMAND:\s*(\S.*)$", a)
    return x.group(1).splitlines()[0].strip() if x else None

def main():
    if not sys.argv[1:]:
        print('usage: ai "request"')
        return

    if sys.argv[1] == "--clear":
        try: os.remove(HIST)
        except FileNotFoundError: pass
        print("cleared")
        return

    if sys.argv[1] == "--history":
        print(json.dumps(load(), indent=2))
        return

    m = load()
    m.append({"role":"user","content":" ".join(sys.argv[1:])})

    for _ in range(8):
        a = ask(m)
        cmd = tool(a)

        if not cmd:
            # Force the model back into tool mode.
            m.append({"role":"assistant","content":a})
            m.append({
                "role":"user",
                "content":
                "ACTION REQUIRED. Do not explain. Do not give instructions. "
                "Execute the requested action now. Reply ONLY with:\n"
                "TOOL: exec\n"
                "COMMAND: <one single-line shell command>"
            })
            a = ask(m)
            cmd = tool(a)

        if not cmd:
            print(a)
            m.append({"role":"assistant","content":a})
            save(m)
            return

        print(f"$ {cmd}")

        if re.search(
            r"\b(rm|rmdir|mv|chmod|chown|dd|mkfs|sudo|systemctl|"
            r"kill|pkill|reboot|shutdown)\b", cmd
        ):
            if input("Execute? [y/N] ").strip().lower() != "y":
                m += [
                    {"role":"assistant","content":a},
                    {"role":"user","content":"Command cancelled. Do not claim it ran."}
                ]
                continue

        code, out = run(cmd)
        print(out)

        m += [
            {"role":"assistant","content":a},
            {"role":"user","content":f"Tool result:\nexit_code={code}\n{out}"}
        ]

    print("maximum tool steps reached")
    save(m)

if __name__ == "__main__":
    main()
```

