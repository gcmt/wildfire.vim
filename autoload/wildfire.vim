" =============================================================================
" File: wildfire.vim
" Description: Smart selection of the closest text object
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


" Init
" =============================================================================

if exists("g:loaded_wildfire")
    finish
endif
let g:loaded_wildfire = 1

let s:pathsep = has("win32") ? "\\" : "/"
let s:logfile = expand("<sfile>:p:h") . s:pathsep . "wildfire.log"
if get(g:, "wildfire_debug", 0)
    cal writefile([], s:logfile)
endif

let s:save_cpo = &cpo
set cpo&vim


" Settings
" =============================================================================

let g:wildfire_objects =
    \ get(g:, "wildfire_objects", ["ip", "i)", "i]", "i}", "i'", 'i"', "it"])

" force `g:wildfire_objects` to be a dictionary
if type(g:wildfire_objects) == 3  " list
    let s:objects = g:wildfire_objects
    unlet g:wildfire_objects
    let g:wildfire_objects = {"*": s:objects}
    unlet s:objects
endif

" split filetypes that share the same text objects
let s:objects = g:wildfire_objects
let g:wildfire_objects = {}
for [ftypes, objects] in items(s:objects)
    for ft in split(ftypes, ",")
        let g:wildfire_objects[ft] = objects
    endfor
endfor
unlet s:objects

let g:wildfire_fuel_map =
    \ get(g:, "wildfire_fuel_map", "<ENTER>")

let g:wildfire_water_map =
    \ get(g:, "wildfire_water_map", "<BS>")


" Internal variables
" =============================================================================

let s:objects = [
    \ "(", ")", "{", "}","[", "]", "<", ">", "b", "B",
    \ "'", '"', "`", "t", "w", "W", "p", "s"]

let s:vim_objects = {}
for kind in s:objects
    let s:vim_objects = extend(s:vim_objects, {"a".kind : 1, "i".kind : 1})
endfor
unlet s:objects

let s:counts = {}
let s:selections_history = []
let s:origin = []


" Functions
" =============================================================================

fu! s:Init()
    let s:origin = getpos(".")
    let s:selections_history = []
    let s:counts = {}
    for object in get(g:wildfire_objects, &ft, get(g:wildfire_objects, "*", []))
        let s:counts[object] = 1
    endfor
endfu

fu! s:Start(repeat)
    cal s:Init()
    cal s:Fuel(a:repeat)
endfu

fu! s:Water()
    cal setpos(".", s:origin)
    if len(s:selections_history) > 1
        let object = remove(s:selections_history, -1).object
        let s:counts[object] -= 1
        cal s:Select(get(s:selections_history, -1))
    endif
endfu

fu! s:Fuel(repeat)

    if !a:repeat
        return
    endif

    cal setpos(".", s:origin)

    let winview = winsaveview()

    cal s:log(repeat("=", 100))
    cal s:log("selections history: " . string(s:selections_history))

    let candidates = {}
    for object in keys(s:counts)

        let to = {"object": object, "count": s:counts[object]}

        let [startline, startcol, endline, endcol] = s:Edges(to)
        let to = extend(to, {"startline": startline, "startcol": startcol,
            \ "endline": endline, "endcol": endcol })

        cal s:log("considering candidation for: " . string(to))

        cal winrestview(winview)

        " The selection failed with the candidate text object
        if startline == endline && startcol == endcol
            cal s:log(" ` failed: no selection can be performed")
            continue
        endif

        " Sometimes Vim selects text objects even if the cursor is outside the
        " them (e.g. `it`, `i"`, etc). We don't want this.
        let cursor_col = s:origin[2]
        if startline == endline && (cursor_col < startcol || cursor_col > endcol)
            cal s:log(" ` failed: does not enclose the cursor")
            let s:counts[object] += 1
            continue
        endif

        let size = s:Size(startline, startcol, endline, endcol)

        " This happens when the _count is incremented but the selection remains still
        let _to = extend(copy(to), {"count": to.count-1})
        if s:AlreadySelected(_to)
            cal s:log(" ` failed: already selected")
            continue
        endif

        " Special case
        if object =~ "a\"\\|i\"\\|a'\\|i'" && startline == endline
            let _to = extend(copy(to), {"count": to.count-1, "startcol": to.startcol+1, "endcol": to.endcol-1})
            if s:AlreadySelected(_to)
                " When there is no more string to select on the same line, vim
                " selects the outer string text object. This is far from the
                " desired behavior
                continue
            endif
            let _to = extend(copy(to), {"count": to.count-1, "startcol": to.startcol+1})
            if s:AlreadySelected(_to)
                " This follows the previous check. When the string ends the
                " line, the size of the text object is just one character less
                continue
            endif
            let quote = strpart(object, 1)
            let [before, after] = [getline("'<")[:startcol-3], getline("'<")[endcol+1:]]
            if s:odd_quotes(quote, before) || s:odd_quotes(quote, after)
                continue
            endif
        endif

        cal s:log(" ` success: text object size is " . size)
        let candidates[size] = to

    endfor

    cal s:log("candidates: " . string(candidates))
    cal s:SelectBestCandidate(candidates)

    cal s:Fuel(a:repeat-1)

endfu

" To select the closest text object among the candidates
fu! s:SelectBestCandidate(candidates)
    if len(a:candidates)
        let to = a:candidates[min(keys(a:candidates))]
        cal s:log("winner: " . string(to))
        let s:selections_history = add(s:selections_history, to)
        let s:counts[to.object] += 1
        cal s:Select(to)
    elseif len(s:selections_history)
        " get stuck on the last selection
        cal s:Select(get(s:selections_history, -1))
    else
        " do nothing
        exec "sil! norm! \<ESC>"
    endif
endfu

" To retrun the edges of a text object
fu! s:Edges(to)
    cal s:Select(a:to)
    exe "sil! norm! \<ESC>"
    return [line("'<"), col("'<"), line("'>"), col("'>")]
endfu

" To select a text object
fu! s:Select(to)
    exe "sil! norm! \<ESC>v\<ESC>v"
    if get(s:vim_objects, a:to.object)
        " use counts when selecting vim text objects
        exe "sil! norm! " . a:to.count . a:to.object
    else
        " counts might not be suported by non-defautl text objects
        for n in range(a:to.count)
            exe "sil! norm " . a:to.object
        endfor
    endif
endfu

" To check if a text object has been already selected
fu! s:AlreadySelected(to)
    return index(s:selections_history, a:to) >= 0
endfu

" To return the size of a text object
fu! s:Size(startline, startcol, endline, endcol)
    if a:startline == a:endline
        return strlen(strpart(getline("'<"), a:startcol, a:endcol-a:startcol+1))
    endif
    let size = strlen(strpart(getline("'<"), a:startcol))
    let size += strlen(strpart(getline("'>"), 0, a:endcol))
    let size += winwidth(0) * abs(a:startline - a:endline)  " good enough
    return size
endfu

" To check if in a strings there is an odd number of quotes
fu! s:odd_quotes(quote, s)
    let n = 0
    for i in range(0, strlen(a:s))
        if a:s[i] == a:quote && !(i > 0 && a:s[i-1] == "\\")
            let n += 1
        endif
    endfor
    return n % 2 != 0
endfu

" Debug helpers
" =============================================================================

fu! s:log(msg)
    if get(g:, "wildfire_debug", 0)
        cal writefile(readfile(s:logfile) + split(a:msg, "\n"), s:logfile)
    endif
endfu

" Commands and Mappings
" =============================================================================

fu! s:safenet(count)
    if a:count > &maxfuncdepth-2
        echohl WarningMsg | echom "[wildfire] Cannot select that much." | echohl None
        return 0
    endif
    return a:count
endfu

exe "nnoremap <silent> " . g:wildfire_fuel_map . " :<C-U>call <SID>Start(<SID>safenet(v:count1))<CR>"
exe "vnoremap <silent> " . g:wildfire_fuel_map . " :<C-U>call <SID>Fuel(<SID>safenet(v:count1))<CR>"
exe "vnoremap <silent> " . g:wildfire_water_map . " :<C-U>call <SID>Water()<CR>"


" Autocommands
" =============================================================================

augroup wildfire
    au!

    " Disable Wildfire inside help or quickfix buffers
    au BufReadPost,CmdWinEnter * if !empty(&bt) |
        \ sil! exec "nnoremap <buffer> " . g:wildfire_fuel_map . " " . g:wildfire_fuel_map |
        \ endif

augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
