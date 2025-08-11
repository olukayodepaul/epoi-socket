## run a proto buf file and compile it

```bash
mix deps.get
```

```bash
protoc --elixir_out=lib/message_protocol --proto_path=priv/protos priv/protos/presence.proto
```

---

### 🔹 `protoc`

m
This is the **Protocol Buffers compiler**.
It takes your `.proto` definition and generates code for a target language (in this case Elixir).

---

### 🔹 `--elixir_out=lib`

- `--elixir_out` tells `protoc` to generate **Elixir code**.
- `lib` is the folder where the generated code will be placed.

So your `.proto` turns into something like:
`lib/presence/presence.pb.ex`

---

### 🔹 `--proto_path=priv/protos`

- This tells `protoc` **where to look for `.proto` files**.
- It’s like setting the “root” directory for imports.

If later you `import "common.proto"` inside `presence.proto`, `protoc` will search inside `priv/protos/`.

---

### 🔹 `priv/protos/presence.proto`

- This is the actual **file to compile**.
- It contains your message definitions (like `IndividualPresence`).

---

✅ So in plain English:

> “Take `priv/protos/presence.proto`, look for imports in `priv/protos/`, compile it into Elixir code, and put the generated `.ex` file inside `lib/`.”

---

Do you want me to also show you how to **automate this** in your Mix project (so you don’t need to run the `protoc` command manually each time)?
