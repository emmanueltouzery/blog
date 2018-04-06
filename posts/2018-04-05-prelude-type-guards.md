---
title: Prelude.ts - pattern matching, type guards and conditional types
author: emmanuel
---
<span class="tech-tag">prelude.ts</span>
<span class="tech-tag">typescript</span>
<span class="tech-tag">functional-programming</span>

One of the hallmarks of functional programming is pattern matching. 
[For now](https://github.com/tc39/proposal-pattern-matching), javascript doesn't
offer special syntax to achieve it, and therefore also typescript doesn't.

When implementing [prelude.ts](https://github.com/emmanueltouzery/prelude.ts), I
put some thought how to offer the features I'm used to from more traditional
FP languages, while keeping a light-handed approach. A more complex approach would
better fit in a standalone, separate library.

Prelude tackles the issue from two point of views:

1. generic handling
2. custom handling for prelude builtin types

## What are type guards

To begin with, predicates are functions returning booleans. For instance:

    function isPositive(x: number): boolean { return x >= 0; }

Type guards, then, are special types of predicates. What they return can be
seen as special kinds of booleans. Type guards live purely in the type world
and have no effect on the runtime at all. You can use type guard to convince
that code that you know is correct is in fact correct.

## Problem to solve

We use either inheritance or discriminated unions. For instance:

    type Option<T> = Some<T> | None<T>;

So now if we are given an `Option<T>`, and we need to do something in case it's
a `Some`, and something else in case it's a `None`, what can we do?

For that purpose, typescript supports [flow control analysis](https://blog.mariusschulz.com/2016/09/30/typescript-2-0-control-flow-based-type-analysis)
when [type guards](https://www.typescriptlang.org/docs/handbook/advanced-types.html#type-guards-and-differentiating-types)
are present.

In prelude, both `Some` and `None` offer a `isSome` and a `isNone` method. But
instead of returning boolean, they return `x is Some<T>` and `x is None<T>`.

## Use in `if`

Using this, we can do:

    // here myOption has type Option<number>
    if (myOption.isSome()) {
        // here myOption has type Some<number>
    } else {
        // here myOption has type None<number>
    }

That's already awesome, but we're just getting started!

Note that prelude.ts offers a less advanced, but also pretty nice [match](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/option.some.html#match)
method on Option, enabling to do:

    Option.of(5).match({
        Some: x  => "got " + x,
        None: () => "got nothing!"
    });
    // => "got 5"
    
## Use in `filter`

But to get back to type guards, they are also applied (even in the typescript
standard library, on Array, and also on prelude.ts's collections) on `filter` 
for instance.

    Vector.of(Option.of(2),Option.none<number>(), Option.of(3)).filter(Option.isSome)
    // => Vector.of(Option.of(2),Option.of(3)) of type Vector<Some<number>>
    
Notice that the type of the result is not anymore `Vector<Option<number>>` but
`Vector<Some<number>>`.

Prelude.ts also offers [typeOf](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/files/comparison.html#typeof) 
and [instanceOf](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/files/comparison.html#instanceof)
helpers, so that we can do:

    Vector.of<number|string>(1,"a",2,3,"b").filter(typeOf("number"))
    // => Vector.of<number>(1,2,3)

Notice that the type of the result is not anymore `Vector<number|string>` but
`Vector<number>`.

## Use in `partition`

[partition](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/vector.html#partition)
is a pretty traditional FP function. It allows you to split a collection in two
collections, depending whether or not a condition is met. For instance:

    Vector.of(1,2,3,4).partition(x => x%2===0)
    => [Vector.of(2,4),Vector.of(1,3)]

This can be very handy for instance when you have a list of computations which
may or may not have succeeded, and you would like to split that list in two lists,
one for all the successes, and one for all the failures. But there are plenty of
use-cases.

Using typescript 2.8.1 and less, the best that we can achieve in prelude.ts is:

    Vector.of<number|string>(1,"a",2,3,"b").partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<number,string>("a","b")]

As you can see, the compiler is smart enough to understand that the first
sublist returned by `partition` will contain only `number` elements. But it's
complicated to explain to it that the second sublist will contain only `string`
elements... In effect we have to tell the compiler that the type of the second
sublist is the type of the input collection, _minus_ the type that we keep for
the first sublist. Type subtraction? Sounds impossible to express right?

Except that [typescript 2.8.1](https://blogs.msdn.microsoft.com/typescript/2018/03/27/announcing-typescript-2-8/)
has added [conditional types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-8.html).
There is actually a bug in 2.8.1 (which is the latest version of typescript as
I'm writing) which prevents prelude.ts from taking advantage of the feature,
but 2.8.2 will have the fix, and that lets us get:


    Vector.of<number|string>(1,"a",2,3,"b").partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<string>("a","b")]

Or even:

    Vector.of<number|string|boolean>(1,"a",2,3,"b",true).partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<string|boolean>("a","b",true)]
