## wildfire.vim

Fast selection of the closest text object delimited by any of the pairs
`''`,`""`,`()`,`[]` or `{}`.

### Usage

Press `<ENTER>` in normal mode to select the closest text object delimited by any of the characters
`"` `'`, `"`, `)`, `]` or `}`.Keep pressing for selecting the **next** closest text object.  To come
back, that is, to select the **previous** text object, press `<BS>`.

To speed things up,if you want to select the `n`th closest text object you can press a number
followed by `<ENTER>` (e.g. pressing `2<ENTER>` will select the second closest text
object).

Change the default mappings with the following options:

```vim
let g:wildfire_fuel_map = "<ENTER>"
" This option select the next closest text object.

let g:wildfire_water_map = "<BS>"
" This option select the previous closest text object.
```
