" =============================================================================
" File: wildfire.vim
" Description: Fast selection of the closest text object delimited any of ', ", ), ] or }
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


" INIT
" =============================================================================

if exists("g:loaded_wildfire") || &cp
    finish
endif
let g:loaded_wildfire = 1


let g:wildfire_delimiters =
    \ get(g:, "wildfire_delimiters", ['"', "'", ")", "]", "}"])

let s:_delimiters = {}
for delim in g:wildfire_delimiters
    let s:_delimiters[delim] = 1
endfor

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" FUNCTIONS
" =============================================================================

" variables that provide some sort of statefulness between function calls
let s:delimiters = {}
let s:winners_history = []
let s:origin = []


fu! s:Wildfire(burning, water, repeat)

    if !a:burning || empty(s:origin)
        cal s:init()
    endif

    cal setpos(".", s:origin)

    if a:water
        cal s:prev()
        return
    endif

    let winview = winsaveview()
    let [curline, curcol] = [s:origin[1], s:origin[2]]

    for i in range(1, a:repeat)

        exe "norm! \<ESC>"
        cal setpos(".", s:origin)

        let candidates = {}
        for delim in keys(s:delimiters)

            let selection = "v" . s:delimiters[delim] . "i" . delim
            exe "norm! v\<ESC>" . selection . "\<ESC>"
            let [startline, startcol] = [line("'<"), col("'<")]
            let [endline, endcol] = [line("'>"), col("'>")]

            if startline == endline
                if startcol != endcol && curcol >= startcol && curcol <= endcol
                    let size = strlen(strpart(getline("'<"), startcol, endcol-startcol+1))
                    let cond1 = !s:already_a_winner("v".(s:delimiters[delim]-1)."i".delim, size-2)
                    let cond2 = !s:already_a_winner(selection, size)
                    let cond3 = s:bigger_than_past_winner(startcol, endcol)
                    if cond1 && cond2 && cond3
                        let candidates[size] = [selection, startcol, endcol]
                    endif
                endif
            endif

            cal winrestview(winview)

        endfor
        cal s:next(candidates)

    endfor

endfu

fu! s:init()
    let s:origin = getpos(".")
    let s:delimiters = copy(s:_delimiters)
    let s:winners_history = []
endfu

fu! s:prev()
    if len(s:winners_history) > 1
        " select the previous closest text object
        let exwinner = remove(s:winners_history, -1)
        let s:delimiters[strpart(exwinner[0], len(exwinner[0])-1, 1)] -= 1
        exe "norm! \<ESC>" . get(s:winners_history, -1)[0]
    endif
endfu

fu! s:next(candidates)
    if len(a:candidates)
        " select the next closest text object
        let minsize = min(keys(a:candidates))
        let winner = a:candidates[minsize][0]
        let startcol = a:candidates[minsize][1]
        let endcol = a:candidates[minsize][2]
        let s:winners_history = add(s:winners_history, [winner, minsize, startcol, endcol])
        let s:delimiters[strpart(winner, len(winner)-1, 1)] += 1
        exe "norm! \<ESC>" . winner
    elseif len(s:winners_history)
        " get stuck on the last selection
        exe "norm! \<ESC>" . get(s:winners_history, -1)[0]
    endif
endfu

fu! s:already_a_winner(selection, size)
    for winner in s:winners_history
        if winner[0] == a:selection && winner[1] == a:size
            return 1
        endif
    endfor
    return 0
endfu

fu! s:bigger_than_past_winner(startcol, endcol)
    if len(s:winners_history)
        let lastwinner = get(s:winners_history, -1)
        if  a:startcol < lastwinner[2] && a:endcol > lastwinner[3]
            return 1
        else
            return 0
        endif
    endif
    return 1
endfu


" COMMANDS & MAPPINGS
" =============================================================================

command! -nargs=0 -range WildfireStart call s:Wildfire(0, 0, <line2> - <line1> + 1)
command! -nargs=0 -range WildfireFuel call s:Wildfire(1, 0, 1)
command! -nargs=0 -range WildfireWater call s:Wildfire(1, 1, 1)

exec "nnoremap <silent> " . g:wildfire_fuel_map . " :WildfireStart<CR>"
exec "vnoremap <silent> " . g:wildfire_fuel_map . " :WildfireFuel<CR>"
exec "vnoremap <silent> " . g:wildfire_water_map . " :WildfireWater<CR>"
