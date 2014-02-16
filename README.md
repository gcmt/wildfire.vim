## wildfire.vim

With *Wildfire* you can quickly select the closest text object among a group of candidates. By
default candidates are `i'`, `i"`, `i)`, `i]`, `i}` and `ip`.

Learn more about text objects with `:help text-objects`.

![Live preview](_assets/preview.gif "Live preview.")

### Usage

Press `<ENTER>` in normal mode to select the closest text object. Keep pressing for selecting the
**next** closest text object. To go the other way round, that is, to select the **previously**
selected text object, press `<BS>`.

To speed things up, if you want to select the `n`th closest text object you can press a number
followed by `<ENTER>` (e.g. pressing `2<ENTER>` will select the second closest text
object).

To change default mappings use the following options:

```vim
let g:wildfire_fuel_map = "<ENTER>"  " This selects the next closest text object.

let g:wildfire_water_map = "<BS>"  " This selects the previous closest text object.
```

By default, *Wildfire* selects the text objects `i'`, `i"`, `i)`, `i]`, `i}` and `ip`, but you can
customize which text objects are considered with the following option

```vim
let g:wildfire_objects = ["i'", 'i"', "i)", "i]", "i}", "ip"]
```

### Tip

If you often work with Html you certainly know about the ability of Vim to select tag objects with
the commands `vat` and `vit`. When dealing with Html files you may find useful to set the
following variable in your `.virmc`

```                                    vim
let g:wildfire_objects = ["it"]  " or `at`
```




