" =============================================================================
" File: wildfire.vim
" Description: Smart selection of the closest text object
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


let s:save_cpo = &cpo
set cpo&vim


" Settings
" =============================================================================

let g:wildfire_objects =
    \ get(g:, "wildfire_objects", ["ip", "i)", "i]", "i}", "i'", 'i"', "it"])

" force `g:wildfire_objects` to be a dictionary
let s:wildfire_objects = type(g:wildfire_objects) == type([]) ?
      \ {"*": g:wildfire_objects} : g:wildfire_objects

" split filetypes that share the same text objects
for [ftypes, objects] in items(s:wildfire_objects)
    for ft in split(ftypes, ",")
        let s:wildfire_objects[ft] = objects
    endfor
endfor


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
    for object in get(s:wildfire_objects, &ft, get(s:wildfire_objects, "*", []))
        let s:counts[object] = 1
    endfor
endfu

fu! wildfire#start(repeat)
    cal s:Init()
    cal wildfire#fuel(a:repeat)
endfu

fu! wildfire#water(repeat)
  for i in range(a:repeat)
    cal wildfire#_water()
  endfor
endfu

fu! wildfire#_water()
    cal setpos(".", s:origin)
    if len(s:selections_history) > 1
        let s:counts[remove(s:selections_history, -1).object] -= 1
        cal s:Select(get(s:selections_history, -1))
    endif
endfu

fu! wildfire#fuel(repeat)
  for i in range(a:repeat)
    cal wildfire#_fuel()
  endfor
endfu

fu! wildfire#_fuel()

    cal setpos(".", s:origin)

    let winview = winsaveview()

    let candidates = {}
    for object in keys(s:counts)

        let to = {"object": object, "count": s:counts[object]}

        let [startline, startcol, endline, endcol] = s:Edges(to)
        let to = extend(to, {"startline": startline, "startcol": startcol,
            \ "endline": endline, "endcol": endcol })

        cal winrestview(winview)

        " The selection failed with the candidate text object
        if to.startline == to.endline && to.startcol == to.endcol
            continue
        endif

        " Sometimes Vim selects text objects even if the cursor is outside the
        " them (e.g. `it`, `i"`, etc). We don't want this.
        let cursor_col = s:origin[2]
        if to.startline == to.endline && (cursor_col < to.startcol || cursor_col > to.endcol)
            let s:counts[object] += 1
            continue
        endif

        let size = s:Size(to)

        " This happens when the _count is incremented but the selection remains still
        let _to = extend(copy(to), {"count": to.count-1})
        if s:AlreadySelected(_to)
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
            let [before, after] = [getline("'<")[:to.startcol-3], getline("'<")[to.endcol+1:]]
            if s:OddQuotes(quote, before) || s:OddQuotes(quote, after)
                continue
            endif
        endif

        let candidates[size] = to

    endfor

    cal s:SelectBestCandidate(candidates)

endfu

" To select the closest text object among the candidates
fu! s:SelectBestCandidate(candidates)
    if len(a:candidates)
        let to = a:candidates[min(keys(a:candidates))]
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
fu! s:Size(to)
    if a:to.startline == a:to.endline
        let line = getline(a:to.startline)
        return strlen(strpart(line, a:to.startcol, a:to.endcol-a:to.startcol+1))
    endif
    let size = strlen(strpart(getline(a:to.startline), a:to.startcol))
    let size += strlen(strpart(getline(a:to.endline), 0, a:to.endcol))
    let size += winwidth(0) * abs(a:to.startline - a:to.endline)  " good enough
    return size
endfu

" To check if in a strings there is an odd number of quotes
fu! s:OddQuotes(quote, s)
    let n = 0
    for i in range(0, strlen(a:s))
        if a:s[i] == a:quote && !(i > 0 && a:s[i-1] == "\\")
            let n += 1
        endif
    endfor
    return n % 2 != 0
endfu


let &cpo = s:save_cpo
unlet s:save_cpo
