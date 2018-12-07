stack build
stack exec site rebuild
cp _site/tags/prelude-ts.html _site/tags/prelude.ts.html
rm -Rf ~/home/emmanueltouzery.github.io/blog/
cp -R _site/ ~/home/emmanueltouzery.github.io/blog/
