

-- from dreamsequence
function transpose_string(x)
    local keys = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    return(keys[x+1])
end


function mode_index_to_name(index)
  local modes = {'Major', 'Dorian', 'Phrygian', 'Lydian', 'Mixolydian', 'Minor', 'Locrian'}
    return(modes[index])
end



function get_short_chord_name(n)
  -- check to see if musicutil.CHORDS[n] has an alt_name entry
  if musicutil.CHORDS[n]["alt_names"] then
      return musicutil.CHORDS[n]["alt_names"][1]
  else
      return musicutil.CHORDS[n]["name"]
  end
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




-- borrowed from dreamsequence
-- lookup for chord degrees and qualities, mirroring MusicUtil.SCALE_CHORD_DEGREES with added chord "quality"
chord_lookup = {
    {
      name = "Major",
      chords = {
        "I",  "ii",  "iii",  "IV",  "V",  "vi",  "vii\u{B0}",
        "IM7", "ii7", "iii7", "IVM7", "V7", "vi7", "vii\u{F8}7"
      },
      quality = {
        "",  "m",  "m",  "",  "",  "m",  "\u{B0}",
        "M7", "m7", "m7", "M7", "7", "m7", "\u{F8}7"
      }
    },
    {
      name = "Dorian",
      chords = {
        "i",  "ii",  "III",  "IV",  "v",  "vi\u{B0}",  "VII",
        "i7", "ii7", "IIIM7", "IV7", "v7", "vi\u{F8}7", "VIIM7"
      },
      quality = {
        "m",  "m",  "",  "",  "m",  "\u{B0}",  "",
        "m7", "m7", "M7", "7", "m7", "\u{F8}7", "M7"
      }
    },
    {
      name = "Phrygian",
      chords = {
        "i",  "II",  "III",  "iv",  "v\u{B0}",  "VI",  "vii",
        "i7", "IIM7", "III7", "iv7", "v\u{F8}7", "VIM7", "vii7"
      },
      quality = {
        "m",  "",  "",  "m",  "\u{B0}",  "",  "m",
        "m7", "M7", "7", "m7", "\u{F8}7", "M7", "m7"
      }
    },
    {
      name = "Lydian",
      chords = {
        "I",  "II",  "iii",  "iv\u{B0}",  "V",  "vi",  "vii",
        "IM7", "II7", "iii7", "iv\u{F8}7", "VM7", "vi7", "vii7"
      },
      quality = {
        "",  "",  "m",  "\u{B0}",  "",  "m",  "m",
        "M7", "7", "m7", "\u{F8}7", "M7", "m7", "m7"
      }
    },
    {
      name = "Mixolydian",
      chords = {
        "I",  "ii",  "iii\u{B0}",  "IV",  "v",  "vi",  "VII",
        "I7", "ii7", "iii\u{F8}7", "IVM7", "v7", "vi7", "VIIM7"
      },
      quality = {
        "",  "m",  "\u{B0}",  "",  "m",  "m",  "",
        "7", "m7", "\u{F8}7", "M7", "m7", "m7", "M7"
      }
    },
    {
      name = "Minor",
      chords = {
        "i",  "ii\u{B0}",  "III",  "iv",  "v",  "VI",  "VII",
        "i7", "ii\u{F8}7", "IIIM7", "iv7", "v7", "VIM7", "VII7"
      },
      quality = {
        "m",  "\u{B0}",  "",  "m",  "m",  "",  "",
        "m7", "\u{F8}7", "M7", "m7", "m7", "M7", "7"
      }
    },
    {
      name = "Locrian",
      chords = {
        "i\u{B0}",  "II",  "iii",  "iv",  "V",  "VI",  "vii",
        "i\u{F8}7", "IIM7", "iii7", "iv7", "VM7", "VI7", "vii7"
      },
      quality = {
        "\u{B0}",  "",  "m",  "m",  "",  "",  "m",
        "\u{F8}7", "M7", "m7", "m7", "M7", "7", "m7"
      }
    },
  }