---
title: Tuple types, mapped types and some type-level programming in typescript
author: emmanuel
tags: typescript, functional-programming, types, prelude-ts
---

It is easy to treat typescript as a "java" with a couple of bonuses (like 
[or types/union types](https://www.typescriptlang.org/docs/handbook/advanced-types.html#union-types),
[`keyof`{.typescript}](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-1.html#keyof-and-lookup-types)
and [`strictNullChecks`](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-0.html#--strictnullchecks)),
but as this post tries to illustrate, that would be leaving on the table a lot of the
power offered by the language.

This post covers a few use-cases for more advanced type
constructs in typescript which I've met with recently, to illustrate the power
of typescript's type system and give some practical examples to its usefulness.

We'll also make an optional excursion into bizarro world, where we'll abuse
typescript's type system to make it achieve things it was never meant to achieve
(and that, in truth, it can only achieve in trivial examples).

In this blog post we won't be looking at function implementations,
only type signatures. In the end, implementation is a javascript problem, for
this post we're only interested in the type checking, which is typescript's
domain. That's why we have some dummy implementations like `return undefined as any`{.typescript}.

In general in this post, I'll first write down the type definitions, and then
explain then afterwards, so don't worry if something is not clear immediately.

## Tuple types: prelude-ts: Either.lift, Option.lift, Future.lift

### Tuples types, an introduction

Let's start by taking advantage of [tuple types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-0.html),.
Typescript has had tuples
for a long time, and so `[number, string]`{.typescript} is a tuple type, and
`[2,"hello"]`{.typescript} and `[-3, "world"]`{.typescript} are examples of
inhabitants of that type. The type `number[]` (array of numbers) is
quite different from the type `[number]` (a tuple with one element which
is a number).

Tuple types were supercharged with typescript 3.0, when it became
possible to infer the type of parameters of a function as a single tuple type, including
optional parameters and all patterns that can be used in function parameters.

So for instance the parameters of this function:

```typescript
function myFn(name: string, age:number|null, height?: number): void {}
```

Could be expressed by the tuple type `[string, number|null, number?]`{.typescript}. This goes
hand in hand with the option that javascript gives us to interpret function parameters
as an array, using the `...` spread operator, so this definition of `myFn` is
equivalent to the previous one:

```typescript
function myFn(...params: [string, number|null, number?]): void {}
```

### Taking advantage of tuple types

In the [prelude-ts](https://github.com/emmanueltouzery/prelude-ts) functional
programming library, of which I'm the author, we introduce types like [`Option<T>`{.typescript}](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/files/option.html)
(offering a useful compositional API on top of the `T|undefined` concept),
[`Either<L,R>`](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/files/either.html)
(similar to the `L | R` concept) and [`Future<T>`](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/future.html)
(similar to the `Promise<T>` concept).

To allow an easier integration with external code, we
offer some functions to "lift" functions which are not Option-aware:

```typescript
const myFind = Option.lift(_.find);
const value = myFind(list, 3); // value is Option<number>
```

So [Option.lift](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/option.optionstatic.html#lift)
takes a function returning `T|undefined` and returns a new function which returns
`Option<T>`. This is a perfect use-case for tuple types, because we don't change
the function parameters, only its result type. Therefore this is the type
of [Option.lift](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/option.optionstatic.html#lift):

```typescript
lift<T extends any[],U>(fn: (...args: T)=>U|undefined): (...args:T)=>Option<U>;
```

So `lift` takes as a input a function taking parameters, the types of which we collect as
a tuple type `T`, and returning `U|undefined`. And then it returns another
function, taking the same parameters `T`, but returning `Option<U>`.

Note that we must specify `extends any[]` in the generic constraints so that typescript
understands we want tuple type inference. However now we see that not only it
is possible to express the type of function parameters using tuple types, but
on top of that, typescript can infer them, and we can reuse this type in other
parts of the function signature.

## Mapped types: fetch settings

After tuple types, let's now look at [mapped types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-1.html#mapped-types),
which were introduced in Typescript 2.1, through another, more concrete example.

### The problem

Imagine our typescript code runs on the client-side, on a web page, and we need to
fetch setting values from the server. Each setting is referred to by a key and is
of a certain type.

Let's define the list of settings that our server offers:

```typescript
export interface SettingKey {
    General_Language: 'en' | 'fr' | 'sl';
    Map_InitialLongitude: number;
    Map_InitialLatitude: number;
}
```

This simple interface definition lets us define both the key names and their types.
Notice how we use an or-type for the language (`'en'|'fr'|'sl'`{.typescript}),
giving us more information than a simple `string` type.


### Fetch a single setting

Here's how we can leverage mapped types to fetch a single setting:

```typescript
function fetchSetting<K extends keyof SettingKey>(key: K): Promise<SettingKey[K]> {
    return undefined as any; // ...
}
```

The function takes a key from the `SettingKey` interface.
Typescript will resolve it at compile-time, and `keyof SettingKey`{.typescript} is
equivalent in this case to:

```typescript
'General_Language' | 'Map_InitialLongitude' | 'Map_InitialLatitude'
```

So the parameter of the function must be of this or-type. And the function
returns a promise of `SettingKey[K]`. This is a lookup type. And again, at
compile time, there will be substitution. But the important thing is that we capture `K`.
So the function parameter takes a key, but the type it will return will depend
on _which_ is that key... That means that:

```typescript
fetchSetting('General_Language')     // returns a Promise<'en'|'fr'|'sl'>
fetchSetting('Map_InitialLongitude') // returns a Promise<number>
fetchSetting('Mp_InitialLongitude')  // doesn't compile (typo in the key name)

```

Note that we could achieve the same thing with typescript function overloading, however
what we'll do in the next section cannot be achieved with overloading anymore.

### Fetch multiple settings

It feels silly to start two separate HTTP requests to fetch the latitude and
the longitude, so we'd like to fetch both at the same time. This is what we
want to achieve:

```typescript
fetchSettings('General_Language', 'Map_InitialLongitude').then(x => {
    // you can access by name. We got back both language and longitude
    // (and only these two)
    return x.General_Language === 'en'
})
```

It does get interesting
however in terms of the function signature...

```typescript
export interface SettingKey {
    General_Language: 'en' | 'fr' | 'sl';
    Map_InitialLongitude: number;
    Map_InitialLatitude: number;
}

type KeyArray = (keyof SettingKey)[];

type SettingKeyArray<KS extends KeyArray> = {
    [P in KS[number]]: SettingKey[P]
}
export function fetchSettings<KS extends KeyArray>
    (...keys: KS): Promise<SettingKeyArray<KS>> {
        return null as any;
    }
```

OK, this is getting more complicated. So we have the same interface as before.
Then we have `KeyArray`, which is a list of keys from `SettingKey`.

So for instance `['General_Language', 'Map_InitialLatitude']`{.typescript} is an inhabitant
of the type `KeyArray`. And as we can see lower in the code sample, the
`fetchSetting` function takes a `KeyArray` parameter. Well, since it takes it
with the spread operator `...`, it takes it in an expanded form. So this is a valid call:

```typescript
fetchSetting('General_Language', 'Map_InitialLatitude');
```

Let's now look at the `SettingKeyArray` type. First off, it's parametrized on
a type `KS`, which must be a `KeyArray`. This means that we'll get a different
`SettingKeyArray` type depending on the `KS` type parameter.

Second, we use the `T[number]` pattern in that type definition. We can see a
good example for this pattern in the [typescript 2.8 release notes](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-8.html#example-2),
but long story short, `T[number]` refers to the element type of an array. So
`T` must extend `any[]`, and  for instance for `T`=`string[]`, then
`T[number]` will be `string`.

Let's resolve the `SettingKeyArray` type for our previous example of a `KeyArray`
type:

```typescript
SettingKeyArray<['General_Language', 'Map_InitialLatitude']>
↪
{ P in ['General_Language', 'Map_InitialLatitude'][number]: SettingKey[P] }
↪
{ P in ('General_Language'|'Map_InitialLatitude'): SettingKey[P] }
↪
{ 'General_Language': SettingKey['General_Language'],
  'Map_InitialLatitude': SettingKey['Map_initialLatitude']}
↪
{ 'General_Language': 'en'|'fr'|'sl', 'Map_InitialLatitude': number}
```

And that's the shape of the data our function should be returning! (well it
returns a promise of data with this shape, anyway)

So to recap what we achieved, the type of our function `fetchSettings` indicates
that the function takes a list of setting keys, and returns a promise of a
object containing the setting values corresponding to the settings we fetched.

```typescript
export function fetchSettings<KS extends KeyArray>
    (...keys: KS): Promise<SettingKeyArray<KS>>;
```

Credits go to [Titian Cernicova-Dragomir](https://stackoverflow.com/users/125734/titian-cernicova-dragomir)
for [this solution](https://stackoverflow.com/questions/53242568/typescript-mapped-tuple-lookup-types)!

## prelude-ts: Vector.zip

Let's keep going now with tuple types and mapped types. In functional programming,
the `zip` function is a classic. Here's how it looks
in the [prelude-ts](https://www.github.com/emmanueltouzery/prelude-ts) library:

```typescript
Vector.of(1,2,3).zip(["a","b","c"])
// => Vector.of([1,"a"], [2,"b"], [3,"c"])
```

So we take two lists, and combine them to produce a new list which contains
pairs from the original lists.

The type signature is pretty simple:

```typescript
class Vector<T> {
    zip<U>(other: Iterable<U>): Vector<[T,U]>;
}
```

But what if we wanted to zip three lists? Or four? We can write a javascript
function that would support any number of lists, but how could we express that with types...
We could use overloads to express versions up to 5 or 6 lists... But as of
typescript 3.1 we can now express the type of the function supporting any arity.

The insight is to declare (and get typescript to infer) a tuple type describing
the element types of all the iterables that we wish to zip together. So for instance
if we we wish to zip an `Iterable<boolean>` together with a `number[]` and a
`(string|undefined)[]` then the tuple type that we start with would be
`[boolean, number, string|undefined]`.

If we look again at the type signature of `zip`, but as a static function,
not as a member method, it looks like this:

```typescript
function zip<T,U>(it1: Iterable<T>, it2: Iterable<U>): Vector<[T,U]>;
```

Looking this now, our tuple type, the tuple type of the element types of
the collections -- let's call it `A` -- is clearly used for the
result of the zip function: we return `Vector<[T,U]>`, in other words
`Vector<A>`.

But what about the parameters that our function accepts? First off clearly
there are several of them, not just one.. And we'd like to work with one type.
But we can use tuple types and the spread operator for that:

```typescript
function zip<T,U>(...its: [Iterable<T>, Iterable<U>]): Vector<[T,U]>;
```

Ok, so we have the `[T,U]` tuple type, our result type will be `Vector<[T,U]>`,
but we somehow need to get to the spread parameter type, which is
`[Iterable<T>, Iterable<U>]`.

Mapped types can help! In this case we'll need [typescript 3.1 refinements
to mapped types](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-1.html),
and the final type definition comes probably as simple as it could:


```typescript
/**
 * IterableArray can take a type and apply iterable to its "components".
 *
 * `IterableArray<[string,number,string]>`
 * => `[Iterable<string>, Iterable<number>, Iterable<string>]`
 */
export type IterableArray<T> = { [K in keyof T] : Iterable<T[K]> };
```

So we apply mapped types on an array. We say that for each index `K` in the array
`T`, we change the type from `T[K]` to `Iterable<T[K]>`.

And so now we have all the elements to define our new `zip` function:

```typescript
zip<A extends any[]>(...iterables: IterableArray<A>): Vector<A> {
    return undefined as any;
}
```

This is the implementation as it's found in prelude-ts. We specify our type `A`
only once (or ask typescript to infer it), then that type is used for the parameters
in a mapped form, and for the result type as the element type of a `Vector`.

However notice that we
gave up our initial solution, which was a method on `Vector`, in favour of
a standalone function. So, `Vector.zip(a,b)` instead of `a.zip(b)`. In prelude-ts,
we would normally expect the first solution: a member in the `Vector` class,
as the library prefers a fluent API, allowing to chain operations
instead of nesting static calls, so rather `list.filter(..).map(..).find(..)`
instead of `find(map(filter(list, ..), ..), ..)`.
As it is, for `zip`, prelude-ts defines both a member method which accepts only one
other iterable, and a "static" function accepting any number of iterables.

It is in fact technically possible to achieve `a.zib(b,c,d)` and with the proper
types, but it has serious downsides in the current versions of typescript.

To achieve this we need to be able to add an item (the type component of the receiver) to a
type-level list (the tuple type of the parameters to the method). So, in
`a.zip(b,c,d)`, we have `Vector<T>` the type of the receiver, and `A` the tuple type
of `[B,C,D]`. What we want is to prepend `T` to `A`, to get `[T,B,C,D]`. 


It turns out that [\@fightingcat](https://github.com/fightingcat) described  in
a typescript issue discussion [a way to achieve that](https://github.com/Microsoft/TypeScript/pull/24897#issuecomment-400549996)
with the current versions of typescript. Unfortunately the solution abuses the
typescript type inference and in my tests caused an important compile time
regression which made me drop the idea.

I'll still describe it here as an illustration of the power of these mechanisms
in general, though they're not yet really attainable in typescript.
I'll then expand yet further in the domain of type-level programming, which is
also not something that is supported by typescript, but is barely achievable in
small amounts if you're willing to abuse the mechanisms that typescript make
available and sacrifice compilation time.

If you're not interested in these unsupported mechanisms, you can skip the next section.

<div class='bizarro-world' style="margin-top:-5px">
# ⚠ DANGER ZONE
<div class='bizarro-world-inner'>

So we take advantage of `Unshift` that `@fightingcat` described,
and we get this working solution:

```typescript
export type IterableArray<T> = { [K in keyof T] : Iterable<T[K]> };
// don't do this!
export type Unshift<Tuple extends any[], Element> = 
    ((h: Element, ...t: Tuple) => void) extends (...t: infer R) => void ? R : never;

class Vector<T> {
    zip<A extends any[]>(...iterables: IterableArray<A>): Vector<Unshift<A,T>> {
        return undefined as any;
    }
}
```

The way `Unshift` works is that it defines a function taking as first parameter
a value of type `T` and as "rest" parameter the tuple type expanded using the spread
operator: `(h: T, ...t: Tuple)`. So in effect that function takes as parameters
exactly the tuple type we're interested in: the tuple type, with `T` prefixed.

It then uses the `infer` typescript keyword to be able to "capture" this type
which is the tuple type with `T` prefixed: `(...t: infer R)`.

Impressive as it is, this is not something typescript was meant to support, and I could see it clearly
in my experiments, as the typescript compiler did go out of memory compiling
the modified version of prelude.ts (this example works when built independently
in a small file though).

## Going overboard: actual type-level programming

Now we turn it up to 11, and venture well beyond where the typescript designers
had intended the type-checker to go. But keep in mind, this
is purely for fun and this code cannot go in the real prelude-ts library, and you
shouldn't do this in your codebase.

With this caveat emptor out of the way, there are a couple of functions in
prelude-ts for which the typescript type system limits us, for instance the
[Function](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/files/function.html)
types. Here are some examples of their uses:

```typescript
const plus5 = Function2.of((x:number,y:number)=>x+y).apply1(5);
plus5(1);
=> 6
```

So this is partial application. We take a function taking two parameters,
and doing `a + b`. Then we apply only one parameter, giving it the value `5`,
and now we get a new function, which takes a single parameter, and is in effect
`b => 5 + b`.

In that example the type of `plus5` is `Function1<number,number>`, while
the `Function2.of()` call returns a value of type `Function2<number,number,number>`.

What we don't like about this is that we must have `Function2<T1,T2,R>`{.typescript},
 `Function3<T1,T2,T3,R>`{.typescript} and so on. So we must have the arity of the function
in the type. And clearly we don't support all possible arities. Currently prelude-ts
supports up to `Function5`.

Instead of that, we'd like to have a single `Function` type, and that type must
enable us to do recursion in type-level functions. To set us up for that, let's
define these two types:

```typescript
class FunctionX0<R> {}
class FunctionX<T, P extends any[], R> {}
```

So we have a special type for parameterless functions (`FunctionX0`), and another one for functions
with a least one parameter (`FunctionX`).
In the latter case, the first parameter is handled specially (it's `T`), and the
other parameters are stored through a tuple type `P`, which enables us to support any arity.

So, for instance, we have:

```typescript
// covered by FunctionX0<void>
function noParams(): void; 

// covered by FunctionX<string, [number,boolean], string>
function twoParams(name: string, age: number, registered: boolean): string; 
```

With these types, we can apply the function by taking as parameters
`(p1: T, ...rest: P)`. And using this `FunctionX` we can define `apply1()`
(partial application) and `tupled()`, using the `infer` trick we've seen
previously.

You can see their definitions in the [prelude-ts branch](https://github.com/emmanueltouzery/prelude-ts/commit/f05cbf2d3a24c5b96dbda938353806864e98ffe1)
in which I was playing with this concept. But the one which is pushing it one
step further is `curry()`, which actually requires type-level recursion.

`curry` will transform a 2-parameter function into a function of one parameter
returning a function of one parameter returning the result. I think in the
context of typescript and prelude-ts, `apply1` (partial application) is in fact
useful in more cases, but curry is also interesting.

So `Function2.of((a:number,b:number)=>a+b).curry()` is of type 
`Function1<number,Function1<number, number>>` and can be called through
`curried(5)(6)` (which will return 11).

So, we want `curry` for `FunctionX<number,[string,boolean],Result>`{.typescript} to return 
`FunctionX<number, [], FunctionX<string, [], FunctionX<boolean, [], Result>>>`{.typescript}.

And this is how we achieve that:

```typescript
class FunctionX<T, P extends any[], R> {

    curried(): CurryReturnType<T,P,R> {
        return undefined as any;
    }
}
```

Easy right? Well ok, all the fun is in the definition of `CurryReturnType`.

Now, what we'd __like__ to say would be:

```typescript
// this doesn't work!
type CurryReturnType<T,P,R> = P extends [infer T1, ...any[]] ?
    FunctionX<T,[],CurryReturnType<T1,TTail<P>,R>> : FunctionX<T,[],R>;
```

So... in any case we return a function whose first parameter will be `T`.
But the for the remaining parameters, we look at `P`, which are the remaining
parameters besides the first one:

1. if `P` is a non-empty array (`P extends [infer T1, ...any[]]` returns true), then the
extra parameters in our result function must be curried again. We already extracted
the first of them: `T1`. And we wrap the rest in `CurryReturnType` -- and that's the
type-level recursive call right here!

2. If on the other hand the remaining parameters are
the empty array, then there are no extra parameters and we stop the recursion.

But, this doesn't work :-) Typescript complains about circular references in
type aliases.

But this didn't stop [\@tycho1](https://github.com/tycho01) from 
[devising a workaround](https://github.com/Microsoft/TypeScript/issues/14174#issuecomment-411661058)
for this kind of issue. Here is the workaround applied to our case:

```typescript
type CurryReturnType<T,P extends any[],R> = {
    0: FunctionX<T,[],R>,
    1: FunctionX<T,[],CurryReturnType<THead<P>,TTail<P>,R>>
}[P extends [infer T1, ...any[]] ? 1 : 0];
```

At this point we're basically knowingly tricking the typechecker in doing things
it does not want to do:

> The idea is basically to ensure the recursive call is wrapped such that it
> cannot immediately evaluate the whole thing and complain about the recursion.
> 
> This is done by wrapping the call into an object type (traditionally in
> the form `{ 0: ..., 1: ... }`), which you then navigate using a condition
> it is unable to simplify out right away (here using conditional types:
> `B extends [] ? 1 : 0`).

This is very impressive, but as Anders Hejlsberg, the Lead architect of Typescript
emphasized, [don't do it](https://github.com/Microsoft/TypeScript/pull/24897#issuecomment-401418254):

> It's clever, but it definitely pushes things well beyond their intended use.
> While it may work for small examples, it will scale horribly.
> Resolving those deeply recursive types consumes a lot of time and resources
> and might in the future run afoul of the recursion governors we have in the checker.
> ```
> ```
> Don't do it!

But at this point we're really deep down the rabbit hole and it's time to go
back to the real world 😊 (or maybe I should write 😞).

</div>
</div>

## Takeaways

There is a fine line to walk, between using types as a leverage to
assist you with your work, or having sophisticated types just for the sake
of it, [as the clojure community often emphasizes](https://lispcast.com/clojure-and-types/):

> Rich Hickey mentioned puzzles as being addictive, implying that it’s fun to
> do stuff in the type system because it’s like a puzzle. It’s similar to the
> Object-Oriented practice of really puzzling out those isA relationships.
> It very much is like a puzzle: you’ve got some rules and an objective.
> Can you figure out a solution? Meanwhile, it gets you no closer to the goal.

There is also a compromise between documentation through type/readability and type
expressiveness. The ability of a programmer to decipher advanced types does increase
with time, but there is a fine line, especially when you push a language to its
limits in terms of type expressiveness -- if you feel you need this very often
you might consider rather using a more advanced language. In general this should
be used only in select areas in a typescript codebase, where you'll get a high
return on investment.

There is real value though, in limiting the caller of an API, making sure it
just cannot misuse the API, and self-documentation through these limits described
by the types. And in effect the complexity doesn't stem from the types -- the
typescript team implemented tuple types and mapped types to make it possible
to express in typescript patterns which were used in common javascript libraries.

### Credits

I must thank [Titian Cernicova-Dragomir](https://stackoverflow.com/users/125734/titian-cernicova-dragomir)
who keeps answering my really strange and confused stackoverflow typescript
questions, and [\@qm3ster](https://github.com/qm3ster) who brought the power of
tuples types to my attention in a discussion related to [Future](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/classes/future.html) support in prelude-ts.

I hope this blog post doesn't frighten you from FP style or prelude-ts - most
of the types there are simple and all of them are here to help the user!

That's it for today! You can learn more about my typescript functional library prelude-ts
through its [website](https://github.com/emmanueltouzery/prelude-ts), 
[user guide](https://github.com/emmanueltouzery/prelude-ts/wiki/Prelude%E2%88%92ts-user-guide) 
and [apidocs](http://emmanueltouzery.github.io/prelude.ts/latest/apidoc/globals.html).

See also [my other blog on typescript type guards and conditional types in prelude.ts](http://emmanueltouzery.github.io/blog/posts/2018-04-07-prelude-type-guards.html)
