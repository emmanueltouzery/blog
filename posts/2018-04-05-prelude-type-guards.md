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

### Predicates

To begin with, predicates are functions returning booleans. For instance,
this implementation of `isPositive` is a predicate:

    function isPositive(x: number): boolean { return x >= 0; }

Type guards, then, are special types of predicates. What they return can be
seen as special kinds of booleans. Type guards live purely in the type world
and have no effect on the runtime at all. You can use type guard to convince
the compiler that code that you know is correct is in fact correct.

### Problem to solve

Let's say we use either inheritance or discriminated unions. For instance:

    class Some<T> {}
    class None<T> {}
    type Option<T> = Some<T> | None<T>;

or:

    abstract class Option<T> {}
    class Some<T> extends Option<T> {}
    class None<T> extends Option<T> {}

An `Option` is a value which is either present, or not present. For instance:

    Option.of(5)          // value is present, dynamic type is Some<number>
    Option.none<number>() // value is not present, dynamic type is None<number>

Trying to read the value of an empty option makes no sense. For that reason,
prelude offers two ways to read the value of an Option: `Some.get` and
`Option.getOrThrow`. The latter is available on both `Some` and `None`, but
`get` is available only on `Some`. Calling `getOrThrow` on a `Some` will return
the value, but it will throw if called on a `None`.

So if you've convinced the compiler that all your uses of the option are safe,
then you should always use `get` (or maybe [getOrElse](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/option.some.html#getorelse)),
but never `getOrThrow`.

So, if we did offer a function `isSome(): boolean`, you could do:

    if (option.isSome()) {
        console.log((<Some<number>>option).get());
    }

That's right, we must cast to Some, how would the compiler know for sure that we are
in fact dealing with a Some?

For that purpose, typescript supports [flow control analysis](https://blog.mariusschulz.com/2016/09/30/typescript-2-0-control-flow-based-type-analysis)
when [type guards](https://www.typescriptlang.org/docs/handbook/advanced-types.html#type-guards-and-differentiating-types)
are present.

In prelude, both `Some` and `None` offer a `isSome` and a `isNone` method. But
instead of returning boolean, they return `x is Some<T>` and `x is None<T>`.

    class Some<T> {
        isSome(): this is Some<T> { return true; }
    }
    class None<T> {
        isSome(): this is Some<T> { return false; }
    }

## Use in `if`

Using this, we can do:

    // here myOption has type Option<number>
    if (myOption.isSome()) {
        // here myOption has type Some<number>
    } else {
        // here myOption has type None<number>
    }

Careful though. We'll get the `None` type in the `else` branch only if we use
the `type Option<T> = Some<T> | None<T>` and NOT if we use the inheritance form
(abstract class `Option`, and `Some` and `None` extending it). The reason is that
inheritance is an "open" relationship: you can add at any time a third class which
would inherit from `Option` and so the typescript compiler cannot say for sure that
if the type is not `Some`, that it then must be `None`. But if we say quite
literally that `Option=Some|None` instead of using inheritance, then the compiler
can do that.

So, no more casts in our `if` and `else`. That's already awesome, but we're just
getting started!

Before we move on further with type guards, note that talking about the `Option`
case in particular, prelude.ts also offers a lpretty nice [match](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/option.some.html#match)
method on Option, enabling to do:

    Option.of(5).match({
        Some: x  => "got " + x,
        None: () => "got nothing!"
    });
    // => "got 5"

Ok, now back to type guards!

## Use in `filter`

Besides "simple" cases like `if` statements, type guards are also applied (even in the typescript
standard library, on `Array`, and also on prelude.ts's collections of course) on `filter`
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

Note that the type of the result is not anymore `Vector<number|string>` but
`Vector<number>`. This is possible because of the type signature of `filter`:

    filter<U extends T>(fn:(v:T)=>v is U): Collection<U>;
    filter(predicate:(v:T)=>boolean): Collection<T>;

As you can see, the type signature is overloaded. The first, more precise,
definition, accepts only type guards and returns collections with another type
(`U`, which must extend `T`). While the second, catch-all type, accepts plain
booleans, and returns a collection of the same type `T` as the input.

## Use in `partition` and conditional types

[partition](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/vector.html#partition)
is a pretty traditional FP function. It allows you to split a collection in two
collections, depending whether or not a condition is met. For instance:

    Vector.of(1,2,3,4).partition(x => x%2===0)
    => [Vector.of(2,4),Vector.of(1,3)]

This can be very handy for instance when you have a list of computations which
may or may not have succeeded, and you would like to split that list in two lists,
one for all the successes, and one for all the failures. But there are plenty of
use-cases.

Using typescript 2.8.1 and older, the best that we can achieve in prelude.ts is:

    Vector.of<number|string>(1,"a",2,3,"b").partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<number|string>("a","b")]

As you can see, the compiler is smart enough to understand that the first
sublist returned by `partition` will contain only `number` elements.
That is because the definition of `partition` takes advantage of type guards:


    partition<U extends T>(predicate:(x:T)=> x is U): [Collection<U>,Collection<T>];
    partition(predicate:(x:T)=>boolean): [Collection<T>,Collection<T>];

Again we see an overloaded definition. If the parameter is a type guard, then
instead of returning `Collection<T>`, we can return `Collection<U>` for the first
sublist.

But if we return to our example, it's tricky to express in types that the
second sublist will contain only `string` elements...
In effect we have to tell the compiler that the type of the second
sublist is the generic type of the input collection, _minus_ the type that we keep for
the first sublist. Type subtraction? Sounds impossible to express right?

Except that [typescript 2.8.1](https://blogs.msdn.microsoft.com/typescript/2018/03/27/announcing-typescript-2-8/)
has added [conditional types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-8.html).
There is actually [a bug](https://github.com/Microsoft/TypeScript/issues/22860)
in 2.8.1 (which is the latest version of typescript as
I'm writing this blog) which prevents prelude.ts from taking advantage of the
feature, but 2.8.2 will have the fix, and that lets us achieve this:


    Vector.of<number|string>(1,"a",2,3,"b").partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<string>("a","b")]

Or even:

    Vector.of<number|string|boolean>(1,"a",2,3,"b",true).partition(typeOf("number"))
    // => [Vector.of<number>(1,2,3), Vector.of<string|boolean>("a","b",true)]

The new type signature that we need to achieve that is now:


    partition<U extends T>(predicate:(v:T)=>v is U): [Collection<U>,Collection<Exclude<T,U>>];
    partition(predicate:(x:T)=>boolean): [Collection<T>,Collection<T>];

Notice that the generic type for the second sublist in the result is `Exclude<T,U>`,
which expresses exactly what we want to say: `T` is the "base type", `U` is the
"more specific" type, give me the types left if you consider all the types matching
`T`, _minus_ the specific type `U`.

Besides `Exclude`, typescript 2.8 [adds a number of such predefined conditional types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-8.html#predefined-conditional-types):
`Extract`, `NonNullable`, `ReturnType`, `InstanceType`.

It is very satisfying to understand that these predefined conditional types are
not each hardcoded in the compiler. The only mechanism known to the compiler is
the ability to say that `T extends U ? X : Y`. Everything else is built upon that,
and the fact that conditional types are distributive. So if we follow the specific
example of `Exclude`.. Its implementation is:

    /**
     * Exclude from T those types that are assignable to U
     */
    type Exclude<T, U> = T extends U ? never : T;

The typescript handbook explains the distributiveness aspect like this:

> Distributive conditional types are automatically distributed over union types
> during instantiation. For example, an instantiation of
>
>     T extends U ? X : Y
>
> with the type argument `A | B | C` for `T` is resolved as
>
>     (A extends U ? X : Y) | (B extends U ? X : Y) | (C extends U ? X : Y).

So, let's try to resolve `Exclude<string|number|boolean, number>`:

    1. Exclude<string|number|boolean, number>

    2. string extends number ? never : string
     | number extends number ? never : number
     | boolean extends number ? never : boolean

    3. false ? never : string
     | true ? never : number
     | false ? never : boolean

    4. string | never | boolean

    5. string | boolean

And that's exactly what the typescript compiler is doing behind the scenes!


## Beyond `Option`

We've talked about discriminated types and type guards in prelude.ts for `Option`.
But this pattern is applied in a number of contexts in prelude.ts, beyond the case of Option.

For instance:

* `LinkedList` can be `ConsLinkedList` or `EmptyLinkedList`. On `ConsLinkedList`,
  [head](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/linkedlist.conslinkedlist.html#head)
  and [last](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/linkedlist.conslinkedlist.html#last)
  return a `Some` instead of a simple `Option`, and these methods return a
  `None`. And the type guard for LinkedList is `isEmpty`;
* `Stream` can be a `ConsStream` or an `EmptyStream`. It behaves the same as
  `LinkedList` with type guards;
* `Either` can be a `Left` or a `Right`. Left has the extra `Left.getLeft` method
   that Right doesn't have. Right has the extra `Right.get` method that Left
   doesn't have. Both branches have `getLeftOrThrow` and `getOrThrow` (plus
   `orElse` variants). The type guard is `isRight`.
