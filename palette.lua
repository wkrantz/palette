-- chord player thing
--
--
-- wayk
musicutil = require("musicutil")


mxsamples=include("mx.samples/lib/mx.samples")
engine.name="MxSamples"
instruments = {}
chordname = ""

-- if mxsamples~=nil then
--     table.insert(self.engine_options,"MxSamples")
--  end
-- table.insert(self.engine_options,"MollyThePoly")

g = grid.connect() -- 'g' represents a connected grid


 
inversion = 0
octave = 1
baseroot = 36
root = baseroot
notes  = {}
chord_playing = false
steps_in_scale = {0,2,4,5,7,9,11}
add_bass = true

--scale_shape = [lev1,lev2]

function add_params()
    skeys=mxsamples:new()
    instruments = skeys:list_instruments()
    params:add_option("mx_ins", "MX.INSTRUMENT", instruments, 10)

    
    -- self.engine_params={}
    -- self.engine_params["MxSamples"]={"mx_instrument","mx_velocity","mx_amp","mx_pan","mx_release","mx_attack"}
    -- self.engine_params["MollyThePoly"]={"osc_wave_shape","pulse_width_mod","pulse_width_mod_src","freq_mod_lfo","freq_mod_env","mtp_glide","main_osc_level","sub_osc_level","sub_osc_detune","noise_level","hp_filter_cutoff","lp_filter_cutoff","lp_filter_resonance","lp_filter_type","lp_filter_env","lp_filter_mod_env","lp_filter_mod_lfo","lp_filter_tracking","lfo_freq","lfo_fade","lfo_wave_shape","env_1_attack","env_1_decay","env_1_sustain","env_1_release","env_2_attack","env_2_decay","env_2_sustain","env_2_release","mtp_amp","mtp_amp_mod","ring_mod_freq","ring_mod_fade","ring_mod_mix","chorus_mix"}

    params:add_number("transpose", "Key", 0, 11, 0, function(param) return transpose_string(param:get()) end)
    params:add_number('mode', 'Mode', 1, 9, 1, function(param) return mode_index_to_name(param:get()) end)
    --params:add_number('mode', 'Mode', 1, 9, 1)

    params:add{
        type = "control",
        id = "humanize",
        name = "humanize",
        controlspec = controlspec.def{
          min = 0,
          max = 200,
          warp = 'lin',
          step = 1, -- round to nearest whole number
          default = 100,
          units = "ms"
        }
      }



    
end
add_params()


function transpose_string(x)
    local keys = {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}
    return(keys[x+1])
end

function mode_index_to_name(index)
    return(musicutil.SCALES[index].name)
end

function init()

    grid_dirty = false -- script initializes with no LEDs drawn

    momentary = {} -- meta-table to track the state of all the grid keys
    basemap = {} -- the background UI to display when no notes are pressed

    for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
        momentary[x] = {} -- create a table that holds...
        basemap[x] = {}     
        for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
            momentary[x][y] = false -- the state of each key is 'off'
            basemap[x][y] = 0 -- the background UI is 'off'
        end
    end
    make_ui_basemap()
    draw_basemap()
    redraw()
    clock.run(grid_redraw_clock) -- start the grid redraw clock
end

function grid_redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sleep(1/30) -- refresh at 30fps.
        if grid_dirty then -- if a redraw is needed...
            grid_redraw() -- redraw...
            grid_dirty = false -- then redraw is no longer needed.
        end
    end
end

function grid_redraw() -- how we redraw
    --g:all(0) -- turn off all the LEDs
    draw_basemap()
    for x = 1,16 do -- for each column...
        for y = 1,8 do -- and each row...
            if momentary[x][y] then -- if the key is held...
                g:led(x,y,15) -- turn on that LED!
            else
                g:led(x,y,basemap[x][y]) -- otherwise, turn it back to the basemap color
            end
        end
    end
    g:refresh() -- refresh the hardware to display the LED state

    
end


function g.key(x,y,z)  -- define what happens if a grid key is pressed or released


  -- check the basemap to see if we are on a pressable button
    if basemap[x][y] > 0 then



        -- is x between 1 and 3 inclusive, aka the modifier buttons?
        if x >= 1 and x <= 3 then

            -- check to see if a key is already being held down, only allow to proceed if not


            if y == 8 then

                -- if holding the middle button, then change the base octave
                if momentary[2][8] then
                    baseroot = z==1 and baseroot + (12*(x-2)) or baseroot
                end
                
                -- otherwise, just do a momentary octave shift
                root = z == 1 and baseroot+(12*(x-2)) or baseroot 
            elseif y ==7 then
                inversion = z == 1 and x-1 or 0


                


            elseif y == 5 then

                -- if holding the middle button, then change the base octave
                if momentary[2][5] then
                    baseroot = z==1 and baseroot + (4*(x-2)) or baseroot
                end
                
                -- otherwise, just do a momentary octave shift
                root = z == 1 and baseroot+(4*(x-2)) or baseroot 

            end


        end


        -- is x between 6 and 12 inclusive, aka the chord buttons?
        if x >= 5 and x <= 11 then
            -- if releasing the previous chord, then allow to proceed
            if (not chord_playing==false) then

                -- check to see if the key being released is the same as the one that was pressed
                if chord_playing[1] == x and chord_playing[2] == y and z==0 then
                    chord_playing = false

                end
            end

            if (chord_playing==false) then
                
                -- tritone substitution
                if y == 3 then
                    play_chord(root+1, x-4, true, false,inversion,z)
                
                -- secondary dominant
                elseif y == 4 then
                    play_chord(root - 12 + steps_in_scale[(x-4)], 5, true, false,inversion,z)
                
                -- main chord
                elseif y == 5 then
                        play_chord(root, x-4, false, false, inversion,z)

                -- seventh chord
                elseif y ==6 then
                    play_chord(root, x-4, true, false, inversion,z)
                
                    -- minor
                elseif y ==7 then
                    play_chord(root, x-4, false, true, inversion,z)                    


                    end

                    chord_playing = z==1 and {x,y} or false
            end
            
        end


        
        momentary[x][y] = z == 1 and true or false -- if a grid key is pressed, flip it's table entry to 'on'


  -- what ^that^ did was use an inline condition to assign our momentary state.
  -- same thing as: if z == 1 then momentary[x][y] = true else momentary[x][y] = false end
        grid_dirty = true -- flag for redraw
    end
end




function play_chord(root, degree, seventh, minor, inversion, on_or_off)
    root = root + params:get("transpose")
    notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, seventh)

    if minor then
        -- check if major or minor
        if notes[2] - notes[1] == 3 then
            notes[2] = notes[2] + 1
        else    
            notes[2] = notes[2] - 1
        end
    end

    -- if inversion is 1, then move the root note up one octave
    if inversion == 0 then
        notes[#notes+1] = notes[1] - 12
    elseif inversion == 1 then
        notes[#notes+1] = notes[1]- 12
        notes[1] = notes[1] + 12
    elseif inversion == 2 then
        notes[#notes+1] = notes[1]- 12
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
    end
        
    -- randomly shuffle the order of the notes
    -- for i = 1, #notes do
    --     j = math.random(i, #notes)
    --     notes[i], notes[j] = notes[j], notes[i]
    -- end

    if on_or_off == 1 then
        clock.run(function()
            for i = 1, #notes do
                skeys:on({name=instruments[params:get("mx_ins")],midi=notes[i],velocity = 70, release=0.5})

                
                -- if notes[i]-baseroot > 0 then
                --     momentary[notes[i]-baseroot][2] = true
                -- end

                -- wait between 1 and 100 ms
                if params:get("humanize") > 0 then
                    clock.sleep(math.random(math.floor(params:get("humanize")/2),params:get("humanize"))/1000)
                end
            end
            -- grid_dirty = true
        end)
    else
        for i = 1, #notes do
            skeys:off({name=instruments[params:get("mx_ins")],midi=notes[i]})

            -- if notes[i]-baseroot > 0 then
            --     momentary[notes[i]-baseroot][2] = false
            -- end

        end
        -- grid_dirty = true
    end

    -- update the piano drawing
    if on_or_off == 1 then
        redraw()
    else
        notes = {}
        redraw()
    end

    
    -- trigger a screen update
    chordname = transpose_string(params:get("transpose")+degree)
    screen.update()


end







function make_ui_basemap()
    lev1 = 3
    lev2 = 6
    lev3 = 9

    -- main keyboard region
    for x = 5,11 do
        basemap[x][3] = lev1
        basemap[x][4] = lev1
        basemap[x][5] = lev3
        basemap[x][6] = lev1
        basemap[x][7] = lev1
        basemap[x][8] = lev1
    end

    -- modifyer area

    -- modulation 
    basemap[1][5] = lev3
    basemap[2][5] = 1
    basemap[3][5] = lev3


    -- inversions
    basemap[2][7] = lev3
    basemap[3][7] = lev3

    -- octaves
    basemap[1][8] = lev3
    basemap[2][8] = 1
    basemap[3][8] = lev3




end

function draw_basemap()
    for x = 1,16 do
        for y = 1,8 do
        g:led(x,y,basemap[x][y])
        end
    end
    g:refresh()
end

function redraw()
    screen.clear()


    --screen.aa(1)
    --screen.font_size(10)
    --screen.move(1,20)
    --screen.text(chordname)
    draw_piano(notes)
    screen.update()

end





function draw_piano(notes)
    local x = 0
    local y = 50
    local key_width = 4
    local key_height = 14
    local num_octaves = 5
    local selected = 0

    --[[ have to draw the white keys first becuase the black are then drawn on top
    so this is a super contrived way of drawing a piano with two loops...
    the only alternative i could think of was to elegantly draw all the keys
    in one pass but then make all these ugly highlights on top for the selected
    with a second pass. this route was the most maintainable and dynamic...
    here, "index" is where the piano key is on the the white or black color index]]
    local keys = {}
    for i = 1,12 do keys[i] = {} end
    keys[1]  = { ["color"] = 1, ["index"] = 1 } -- c
    keys[2]  = { ["color"] = 0, ["index"] = 1 } -- c#
    keys[3]  = { ["color"] = 1, ["index"] = 2 } -- d
    keys[4]  = { ["color"] = 0, ["index"] = 2 } -- d#
    keys[5]  = { ["color"] = 1, ["index"] = 3 } -- e
    keys[6]  = { ["color"] = 1, ["index"] = 4 } -- f
    keys[7]  = { ["color"] = 0, ["index"] = 3 } -- f#
    keys[8]  = { ["color"] = 1, ["index"] = 5 } -- g
    keys[9]  = { ["color"] = 0, ["index"] = 4 } -- g#
    keys[10] = { ["color"] = 1, ["index"] = 6 } -- a
    keys[11] = { ["color"] = 0, ["index"] = 5 } -- a#
    keys[12] = { ["color"] = 1, ["index"] = 7 } -- b


    -- copy the first 12 keys num_octaves times
    for i = 1,num_octaves do
        for j = 1,12 do
            -- the index needs to be offset by 7 for each octave for keys with color=1 and by 5 for keys with color=0
            index_shift = keys[j]["color"] == 1 and 7 or 5
            keys[j + (i * 12)] = { ["color"] = keys[j]["color"], ["index"] = keys[j]["index"] }
        end
    end

    -- Mark the selected notes in the keys table
    for _, note in ipairs(notes) do
            selected = note - 23
            keys[selected]["selected"] = true
    end
  
    for o = 0,(num_octaves-1) do
        local start_x = x + (7 * key_width * o)
        
        -- white keys
        for i = 1,12 do
            if keys[i]["color"] == 1 then
                --rect(start_x + ((keys[i + 12*o]["index"] - 1) * key_width+1), y, key_width-1, key_height, 6)
                rect(start_x + ((keys[i + 12*o]["index"] - 1) * key_width) + 1, y + 1, key_width - 1, key_height - 2, keys[i + 12*o]["selected"] and 5 or 15)
            end
        end
  
    -- black keys

        for i = 1,12 do
            if keys[i]["color"] == 0 then

                -- shift the start x by seven key widths for each octave


                local adjust = keys[i]["index"] > 2 and 1 or 0 -- e# doesn't exist! yeah yeah...
                rect(start_x + ((keys[i + 12*o]["index"] - 1 + adjust) * key_width) + (key_width*.7), y, key_width-1, key_height*0.5, 0)
                
                if keys[i + 12*o]["selected"] then
                    rect(start_x + ((keys[i + 12*o]["index"] - 1 + adjust) * key_width) + (key_width*.7), y, key_width-1, key_height*0.5, 5)
                end
            end
        end
    end
    --rect(x + (7 * key_width), y, 2, key_height, 3) -- end
  
    -- note readout
    --screen.font_size(30)
    -- text_center(64, 64, keeper.selected_cell:get_note_name(i), 15, 10)
    -- reset_font()

end


function rect(x, y, w, h, level)
    screen.level(level or 15)
    screen.rect(x, y, w, h)
    screen.fill()
end

function text_center(x, y, string, level)
    screen.level(level or 15)
    screen.move(x, y)
    screen.text_center(string)
  end
  