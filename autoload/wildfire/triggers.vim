
let s:triggers = []

fu! wildfire#triggers#All()
    return s:triggers
endfu

fu! wildfire#triggers#Add(trigger, objects)
    let s:triggers = add(s:triggers, a:trigger)
    let objects = substitute(string(a:objects), "|", '\\|', "g")
    exe "nnoremap <silent>" a:trigger ":<C-U>call wildfire#Start(v:count1, ". objects .")<CR>"
    exe "onoremap <silent>" a:trigger ":<C-U>call wildfire#Start(v:count1, ". objects .")<CR>"
    exe "vnoremap <silent>" a:trigger ":<C-U>call wildfire#Fuel(v:count1)<CR>"
endfu

fu! wildfire#triggers#AddQs(trigger, objects)
    let s:triggers = add(s:triggers, a:trigger)
    let objects = substitute(string(a:objects), "|", '\\|', "g")
    exe "nnoremap <silent>" a:trigger ":<C-U>call wildfire#QuickSelect(". objects .")<CR>"
    exe "onoremap <silent>" a:trigger ":<C-U>call wildfire#QuickSelect(". objects .")<CR>"
endfu
