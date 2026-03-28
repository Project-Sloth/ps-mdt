# esrap

Parse in reverse. AST goes in, code comes out.

## Usage

```js
import { print } from 'esrap';

const { code, map } = print({
  type: 'Program',
  body: [
    {
      type: 'ExpressionStatement',
      expression: {
        callee: {
          type: 'Identifier',
          name: 'alert'
        },
        arguments: [
          {
            type: 'Literal',
            value: 'hello world!'
          }
        ]
      }
    }
  ]
});

console.log(code); // alert('hello world!');
```

If the nodes of the input AST have `loc` properties (e.g. the AST was generated with [`acorn`](https://github.com/acornjs/acorn/tree/master/acorn/#interface) with the `locations` option set), sourcemap mappings will be created.

## Options

You can pass the following options:

```js
const { code, map } = print(ast, {
  // Populate the `sources` field of the resulting sourcemap
  // (note that the AST is assumed to come from a single file)
  sourceMapSource: 'input.js',

  // Populate the `sourcesContent` field of the resulting sourcemap
  sourceMapContent: fs.readFileSync('input.js', 'utf-8'),

  // Whether to encode the `mappings` field of the resulting sourcemap
  // as a VLQ string, rather than an unencoded array. Defaults to `true`
  sourceMapEncodeMappings: false,

  // String to use for indentation — defaults to '\t'
  indent: '  ',

  // Whether to wrap strings in single or double quotes — defaults to 'single'.
  // This only applies to string literals with no `raw` value, which generally
  // means the AST node was generated programmatically, rather than parsed
  // from an original source
  quotes: 'single'
});
```

## TypeScript

`esrap` can also print TypeScript nodes, assuming they match the ESTree-like [`@typescript-eslint/types`](https://www.npmjs.com/package/@typescript-eslint/types).

## Why not just use Prettier?

Because it's ginormous.

## Developing

This repo uses [pnpm](https://pnpm.io). Once it's installed, do `pnpm install` to install dependencies, and `pnpm test` to run the tests.

## License

[MIT](LICENSE)
