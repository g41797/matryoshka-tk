# Usage any within Inner

```c3
struct Inner
{
    inline any link;
}
```

## What this means

`Inner` contains a normal C3 `any` field named `link`.

Because it is `inline`, the members of `link` are promoted for convenient access.

So the representation is:

```text
Inner
└── link : any
    ├── ptr
    └── type
```

Usage

```c3
inner.link.ptr
inner.link.type
```

It makes the unusual meaning of the builtin `any` visible.

## 3tk example

```c3
module mtk;

struct Inner
{
    inline any link;
}

alias Handle = Inner*;

fn void inner_init(Inner* inner, Inner* next, typeid type)
{
    inner.link.ptr = next;
    inner.link.type = type;
}

fn Inner* inner_next(Inner* inner)
{
    return (Inner*)inner.link.ptr;
}

fn void inner_set_next(Inner* inner, Inner* next)
{
    inner.link.ptr = next;
}

fn typeid inner_type(Inner* inner)
{
    return inner.link.type;
}
```

Usage:

```c3
struct Message
{
    int id;
    Inner node;
    char[64] body;
}

fn void main()
{
    Message message;

    inner_init(
        &message.node,
        null,
        Message::typeid
    );

    Handle handle = &message.node;

    if (handle.link.type == Message::typeid)
    {
        Inner* next = (Inner*)handle.link.ptr;
    }
}
```


## I recommend keeping `link` visible


```c3
handle.link.ptr
handle.link.type
```


It means:

```text
link.ptr = next Inner
link.type = type of outer object
```

Therefore I would write 3tk infrastructure like:

```c3
Inner* next = (Inner*)handle.link.ptr;

handle.link.ptr = next;
handle.link.type = Message::typeid;
```

The `inline` field still has value: it gives `Inner` the builtin `any` representation directly and allows convenient promoted access where appropriate.

So the resulting model is:

```text
Message
┌──────────────────────────────┐
│ id                           │
│                              │
│ node : Inner                 │ ◄── Handle
│ ┌──────────────────────────┐ │
│ │ link : any               │ │
│ │ ├── ptr  = next Inner    │ │
│ │ └── type = Message id    │ │
│ └──────────────────────────┘ │
│                              │
│ body                         │
└──────────────────────────────┘

Message* = (char*)Handle - OFF
```

This keeps exactly your original address-reconstruction design while reusing C3's native `any` representation.
