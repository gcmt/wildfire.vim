" =============================================================================
" File: wildfire.vim
" Description: Smart selection of the closest text object
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


" Init
" =============================================================================

if exists("g:loaded_wildfire") || &cp
    finish
endif
let g:loaded_wildfire = 1


" Settings
" =============================================================================

let g:wildfire_objects =
    \ get(g:, "wildfire_objects", ["ip", "i)", "i]", "i}", "i'", 'i"'])

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" Functions
" =============================================================================

let s:objects = {}
let s:winners_history = []
let s:origin = []


fu! s:Wildfire(burning, water, repeat)

    if !a:repeat
        return
    endif

    if !a:burning || empty(s:origin)
        cal s:init()
    endif

    cal setpos(".", s:origin)

    if a:water
        cal s:select_smaller_block()
        return
    endif

    let winview = winsaveview()

    let candidates = {}
    for object in keys(s:objects)

        let selection = "v" . s:objects[object] . object
        exe "sil! norm! \<ESC>v\<ESC>" . selection . "\<ESC>"
        let [startline, startcol, endline, endcol] = s:get_visual_block_edges()

        cal winrestview(winview)

        if startline != endline || startcol != endcol

            let size = s:get_visual_block_size(startline, startcol, endline, endcol)

            if (object =~ "'" || object =~ "\"") && startline == endline
                let [before, after] = [getline("'<")[:startcol-3],  getline("'<")[endcol+1:]]
                let cond1 = index(s:winners_history, "v".(s:objects[object]-1).object) == -1
                let cond2 = !s:odd_quotes(object, before) && !s:odd_quotes(object, after)
                if cond1 && cond2
                    let candidates[size] = selection
                endif
            else
                let candidates[size] = selection
            endif

        endif

    endfor

    cal s:select_bigger_block(candidates)

    cal s:Wildfire(1, 0, a:repeat-1)

endfu


" Helpers
" =============================================================================

" to initialize state variables
fu! s:init()
    let s:origin = getpos(".")
    let s:winners_history = []
    for object in g:wildfire_objects
        let s:objects[object] = 1
    endfor
endfu

fu! s:select_smaller_block()
    if len(s:winners_history) > 1
        let last_winner = remove(s:winners_history, -1)
        let s:objects[strpart(last_winner, len(last_winner)-2)] -= 1
        exe "norm! \<ESC>" . get(s:winners_history, -1)
    endif
endfu

fu! s:select_bigger_block(candidates)
    if len(a:candidates)
        let minsize = min(keys(a:candidates))
        let winner = a:candidates[minsize]
        let [startcol, endcol] = [a:candidates[minsize], a:candidates[minsize]]
        let s:winners_history = add(s:winners_history, winner)
        let s:objects[strpart(winner, len(winner)-2)] += 1
        exe "norm! \<ESC>" . winner
    elseif len(s:winners_history)
        " get stuck on the last selection
        exe "norm! \<ESC>" . get(s:winners_history, -1)
    else
        exe "norm! \<ESC>"
    endif
endfu

fu! s:odd_quotes(quote, s)
    let n = 0
    for i in range(0, strlen(a:s))
        if a:s[i] == a:quote && !(i > 0 && a:s[i-1] == "\\")
            let n += 1
        endif
    endfor
    return n % 2 != 0
endfu

fu! s:get_visual_block_edges()
    return [line("'<"), col("'<"), line("'>"), col("'>")]
endfu

fu! s:get_visual_block_size(startline, startcol, endline, endcol)
    if a:startline == a:endline
        return strlen(strpart(getline("'<"), a:startcol, a:endcol-a:startcol+1))
    endif
    let size = strlen(strpart(getline("'<"), a:startcol))
    let size += strlen(strpart(getline("'>"), 0, a:endcol))
    let size += winwidth(0) * abs(a:startline - a:endline)  " good enough
    return size
endfu


" Commands and Mappings
" =============================================================================

command! -nargs=0 -range WildfireStart call s:Wildfire(0, 0, <line2> - <line1> + 1)
command! -nargs=0 -range WildfireFuel call s:Wildfire(1, 0, 1)
command! -nargs=0 -range WildfireWater call s:Wildfire(1, 1, 1)

exec "nnoremap <silent> " . g:wildfire_fuel_map . " :WildfireStart<CR>"
exec "vnoremap <silent> " . g:wildfire_fuel_map . " :WildfireFuel<CR>"
exec "vnoremap <silent> " . g:wildfire_water_map . " :WildfireWater<CR>"
