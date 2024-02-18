

-- from dreamsequence
function transpose_string(x)
    local keys = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    return(keys[x+1])
end
-- from dreamsequence
function mode_index_to_name(index)
    return(musicutil.SCALES[index].name)
end


function invert_chord(notes, inversion)
    if inversion == 0 then
        return notes
    elseif inversion == 1 then
        notes[1] = notes[1] + 12
    elseif inversion == 2 then
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
    elseif inversion == 3 then
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
        notes[3] = notes[3] + 12
    end
    return notes
end