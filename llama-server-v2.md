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

````python
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

SYSTEM = r"""You are a local Linux computer assistant.

You can execute shell commands on the user's computer.

IMPORTANT RULES:

1. When the user asks you to DO something on the computer, you MUST use the exec tool.
2. You are NOT allowed to claim that an action was completed unless the tool execution result proves it.
3. Never invent command output.
4. After executing a command, carefully inspect its exit code and output.
5. If a command failed, tell the user it failed and explain why.
6. If you need to perform multiple operations, combine them into ONE shell command using &&, ;, printf, heredocs, etc.
7. When creating a text file, actually write its contents. Do NOT use `touch` unless the user specifically asks only to create an empty file.
8. When creating an executable script, write the script contents and then chmod it executable.
9. You may use normal shell commands such as ls, cat, printf, mkdir, cp, mv, chmod, grep, find, etc.
10. NEVER use sudo.
11. Do not pretend that a command was executed if it was not.
12. After a successful tool execution, answer based only on the actual result.

TOOL FORMAT:

When you need to execute a command, output EXACTLY:

TOOL: exec
COMMAND: <one shell command>

Do not put TOOL or COMMAND inside markdown fences.

Example:

TOOL: exec
COMMAND: printf '%s\\n' '#!/bin/bash' 'echo "Hello, World!"' > script.sh && chmod +x script.sh

Then wait for the tool execution result.

For a request such as "make a script called script.sh that prints hello world", you MUST actually create the file and make it executable. Do not merely run `touch script.sh`.

Be concise.
"""

def load_history():
    if not os.path.exists(HISTORY):
        return []

    try:
        with open(HISTORY, "r", encoding="utf-8") as f:
            data = json.load(f)

        if isinstance(data, list):
            return data

    except Exception:
        pass

    return []


def save_history(messages):
    os.makedirs(os.path.dirname(HISTORY), exist_ok=True)

    # Keep history from growing forever.
    # Always preserve the system message.
    if len(messages) > 80:
        messages = [messages[0]] + messages[-79:]

    tmp = HISTORY + ".tmp"

    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(
            messages,
            f,
            ensure_ascii=False,
            indent=2
        )

    os.replace(tmp, HISTORY)


def ask(messages):
    payload = {
        "messages": messages,
        "stream": False,
        "temperature": 0.1
    }

    request = urllib.request.Request(
        API,
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
        print("Could not connect to llama-server.")
        print("Make sure llama-server is running on 127.0.0.1:8080.")
        print(f"Details: {e}")
        sys.exit(1)

    except Exception as e:
        print(f"Invalid response from llama-server: {e}")
        sys.exit(1)

    try:
        return result["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        print("Unexpected response from llama-server:")
        print(json.dumps(result, indent=2))
        sys.exit(1)


def execute(command):
    print(f"\n$ {command}\n")

    try:
        result = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True
        )

    except Exception as e:
        return 1, f"Failed to execute command: {e}"

    output = ""

    if result.stdout:
        output += result.stdout

    if result.stderr:
        if output and not output.endswith("\n"):
            output += "\n"
        output += result.stderr

    output = output.rstrip()

    if not output:
        output = "(command produced no output)"

    return result.returncode, output


def needs_confirmation(command):
    """
    Commands that deserve explicit user confirmation.

    This is NOT a security sandbox.
    """

    patterns = [
        r"\brm\b",
        r"\brm\s+-",
        r"\brmdir\b",
        r"\bmv\b",
        r"\bchmod\b",
        r"\bchown\b",
        r"\bdd\b",
        r"\bmkfs\b",
        r"\bsudo\b",
        r"\bsystemctl\b",
        r"\bkill\b",
        r"\bpkill\b",
        r"\breboot\b",
        r"\bshutdown\b",
        r"\bpoweroff\b",
        r"\biptables\b",
        r"\bnft\b",
        r"\buserdel\b",
        r"\bpasswd\b",
    ]

    return any(
        re.search(pattern, command, re.IGNORECASE)
        for pattern in patterns
    )


def extract_tool_call(answer):
    """
    Extract:

    TOOL: exec
    COMMAND: something

    The command can contain shell syntax.
    """

    match = re.search(
        r"TOOL:\s*exec\s*\nCOMMAND:\s*(.+)",
        answer,
        re.IGNORECASE | re.DOTALL
    )

    if not match:
        return None

    command = match.group(1).strip()

    # Remove accidental markdown fencing.
    command = re.sub(
        r"^```(?:bash|sh|shell)?\s*",
        "",
        command,
        flags=re.IGNORECASE
    )

    command = re.sub(
        r"\s*```$",
        "",
        command
    )

    return command.strip()


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
        print(
            json.dumps(
                load_history(),
                indent=2,
                ensure_ascii=False
            )
        )
        return

    prompt = " ".join(args)

    messages = load_history()

    if not messages or messages[0].get("role") != "system":
        messages = [
            {
                "role": "system",
                "content": SYSTEM
            }
        ]

    messages.append(
        {
            "role": "user",
            "content": prompt
        }
    )

    for step in range(8):
        answer = ask(messages)

        command = extract_tool_call(answer)

        if command is None:
            print(answer)

            messages.append(
                {
                    "role": "assistant",
                    "content": answer
                }
            )

            save_history(messages)
            return

        # Show exactly what will be executed.
        print("\nAssistant wants to execute:")
        print(f"  {command}")

        if needs_confirmation(command):
            confirm = input("\nExecute this command? [y/N] ").strip().lower()

            if confirm != "y":
                print("Command cancelled.")

                messages.append(
                    {
                        "role": "assistant",
                        "content": answer
                    }
                )

                messages.append(
                    {
                        "role": "user",
                        "content": (
                            "The command was NOT executed because the user "
                            "cancelled it. Do not claim it succeeded."
                        )
                    }
                )

                continue

        code, output = execute(command)

        print(f"\nExit code: {code}")
        print(output)

        # Tell the model exactly what happened.
        messages.append(
            {
                "role": "assistant",
                "content": answer
            }
        )

        messages.append(
            {
                "role": "user",
                "content": (
                    "EXECUTION RESULT\n"
                    f"exit_code: {code}\n"
                    f"output:\n{output}\n\n"
                    "IMPORTANT: The command above is the ONLY command "
                    "that was executed. Do not claim that anything else "
                    "was done. Base your next response only on this result."
                )
            }
        )

    print("\nMaximum tool-call steps reached.")
    save_history(messages)


if __name__ == "__main__":
    main()
````
