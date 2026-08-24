Correct. `DestructorEntry` is unnecessary: the destructor descriptor itself can be an `any`.

```c3
alias Destructor = fn void(void*);
```

For a type `T`, create an `any` whose:

- `type` is `T::typeid`;
- `ptr` points to the destructor function for `T`.

```c3
fn void destroy_message(void* ptr)
{
    Message* message = (Message*)ptr;
    io::printfn("destroying: %s", message.text);
}

fn any message_destructor()
{
    return {
        ptr = (void*)&destroy_message,
        type = Message::typeid
    };
}
```

Then the registry is simply an array of `any` values:

```c3
fn void destroy_any(any object, any[] destructors)
{
    for (usz i = 0; i < destructors.len; i++)
    {
        any destructor = destructors[i];

        if (destructor.type != object.type)
        {
            continue;
        }

        Destructor destroy = (Destructor)destructor.ptr;
        destroy(object.ptr);
        return;
    }

    io::printfn("no destructor for type");
}
```

Example:

```c3
struct Message
{
    char[] text;
}

fn void main()
{
    any[] destructors = {
        {
            ptr = (void*)&destroy_message,
            type = Message::typeid
        }
    };

    Message message = {
        text = "hello"
    };

    any object = (any)&message;

    destroy_any(object, destructors);
}
```

The essential operation is:

```c3
if (object.type == destructor.type)
{
    Destructor function = (Destructor)destructor.ptr;
    function(object.ptr);
}
```

So the two `any` values have different meanings despite having the same representation:

```text
object:
    ptr  -> Message instance
    type -> Message::typeid

destructor:
    ptr  -> destroy_message function
    type -> Message::typeid
```

A second example makes the distinction clearer:

```c3
struct File
{
    void* handle;
}

fn void destroy_file(void* ptr)
{
    File* file = (File*)ptr;
    io::printfn("closing file handle: %p", file.handle);
}

fn void main()
{
    any[] destructors = {
        {
            ptr = (void*)&destroy_message,
            type = Message::typeid
        },
        {
            ptr = (void*)&destroy_file,
            type = File::typeid
        }
    };

    File file = {
        handle = null
    };

    destroy_any((any)&file, destructors);
}
```

This is effectively a type-indexed function table:

```c3
typeid -> void* containing fn void(void*)
```

One caveat: this assumes C3 permits converting a function pointer to `void*` and back on the target platforms. If C3 distinguishes data pointers and function pointers in a way that disallows that conversion, the same conceptual design cannot be represented literally by `any.ptr`; then the registry would need a typed function-pointer field.

