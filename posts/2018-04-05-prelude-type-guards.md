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
