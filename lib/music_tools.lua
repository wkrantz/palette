

-- from dreamsequence
function transpose_string(x)
    local keys = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    return(keys[x+1])
end
-- from dreamsequence
function mode_index_to_name(index)
    return(musicutil.SCALES[index].name)
end