-- chord player thing
--
--
-- wayk

include('lib/ui')
include('lib/music_tools')
musicutil = require("musicutil")

local nb = require "nb/lib/nb"


-- mxsamples=include("mx.samples/lib/mx.samples")
-- engine.name="MxSamples"
-- instruments = {}


g = grid.connect()
if type(g.device) == 'table' then
  rows = g.device.rows or 8
  print(rows .. '-row Grid detected')
else
  rows = 8
  print('No Grid detected')
end
 

--position of chord playing buttons
start_x=7
start_y=5

chordname = ""
momentary_inversion = 0
momentary_octave = 4
notes  = {}
prev_chord = {}
chord_playing = false
loading_sequence_step = false
current_step = 1




function add_params()
    -- skeys=mxsamples:new()
    -- instruments = skeys:list_instruments()
    -- params:add_option("mx_ins", "MX.INSTRUMENT", instruments, 10)

    
    params:add_number("transpose", "Key", 0, 11, 0, function(param) return transpose_string(param:get()) end)
    params:add_number('mode', 'Mode', 1, 9, 1, function(param) return mode_index_to_name(param:get()) end)
    params:add_number('octave', 'Octave', 0, 8, 4)
    params:add_number('inversion' , 'Inversion', 0, 2, 0)
    params:add_option('bass_note', 'Bass Note', {'no', 'yes'}, 2)

    params:add_number('alt_mode', 'Secondary Mode', 1, 9, 2, function(param) return mode_index_to_name(param:get()) end)


    params:add{
        type = "control",
        id = "humanize",
        name = "humanize",
        controlspec = controlspec.def{
          min = 0,
          max = 200,
          warp = 'lin',
          step = 1, -- round to nearest whole number
          default = 50,
          units = "ms"
        }
      }

    
end
add_params()




function init()
    nb:init()
    nb:add_param("voice", "voice")
    nb:add_player_params()

    -- set the voice to "resonator"
    params:set("voice", 8)

    grid_dirty = false -- script initializes with no LEDs drawn
    screen_dirty = false
    momentary = {} -- meta-table to track the state of all the grid keys
    basemap = {} -- the background UI to display when no notes are pressed

    
    seq = {}
    -- fill with 16 empty steps
    for i = 1, 16 do
        seq[i]=false
    end

    for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
        momentary[x] = {} -- create a table that holds...
        basemap[x] = {}     
        for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
            momentary[x][y] = false -- the state of each key is 'off'
            basemap[x][y] = 0 -- the background UI is 'off'
        end
    end
    make_ui_basemap(start_x,start_y) -- populate the basemap table
    draw_basemap()
    redraw()
    clock.run(redraw_clock) -- start the grid redraw clock
    clock.run(sequencer)
end

function redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sleep(1/10) -- refresh at 10fps.
        if grid_dirty then -- if a redraw is needed...
            grid_redraw() -- redraw...
            grid_dirty = false -- then redraw is no longer needed.
        end

        if screen_dirty then
            redraw()
            screen_dirty = false
        end
    end
end




function g.key(x,y,z)  -- define what happens if a grid key is pressed or released
    if x == 16 and y == 8 and z == 1 then
        panic()
    end

    -- if a grid key is pressed AND a chord is not currently being held down, flip it's table entry to 'on'
    momentary[x][y] = z == 1 and (not chord_playing) or false 
    

    ---- MODIFIERS ---- 
  -- check the basemap to see if we are on a pressable button
    if basemap[x][y] > 0 then
        -- is x between 1 and 3 inclusive, aka the modifier buttons
        if x >= 1 and x <= 4 then

            if y == 8 then
                -- if holding the middle button, then change the base octave
                if momentary[2][8] then
                    params:set("octave",z==1 and params:get("octave")+(x-2) or params:get("octave"))
                end
                -- otherwise, just do a momentary octave shift
                momentary_octave = z == 1 and params:get("octave") + (x-2) or params:get("octave")

            elseif y ==7 then
                -- momentarily change the inversion, otherwise leave it at the default set in the params
                momentary_inversion = z == 1 and x-1 or params:get("inversion")

            elseif y == 5 then
                -- not sure yet
            end
        end

        ---- CHORD BUTTONS ----
        -- are we on the chord buttons?
        if x >= start_x and x <= start_x+7 and y>=3 then
            -- if releasing the previous chord, then allow to proceed
            if (not chord_playing==false) then

                -- check to see if the key being released is the same as the one that was pressed
                if chord_playing[1] == x and chord_playing[2] == y and z==0 then
                    chord_playing = false

                end
            end

            if (chord_playing==false) then
                play_chord(y-start_y, x - start_x + 1, z)
                chord_playing = z==1 and {x,y} or false
            end
        end

        grid_dirty = true -- flag for redraw
    end


    ---- SEQUENCER ----
    if y == 1 and z == 1 then

        -- if already a step, then clear it. If not, then load most recently played chord
        if seq[x] then
            seq[x] = false
        else
            seq[x] = prev_chord
        end
 
        grid_dirty = true
    end

end



function play_chord(row,degree,z)

    -- if we are letting go of a button, just turn off the current set of notes
    if z == 0 then
        notes_to_engine(notes, z)

    -- if we are pressing a button, figure out the new set of notes
    else
        root = momentary_octave*12 + params:get("transpose")

        -- get the notes for the base chord

        -- main chord row
        if row == 0 then
            notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, false)
        end


        -- secondary dominant row
        if row == -1 then
            -- the root of the secondary dominant the first note in the chord we would be playing
            secondary_dominant_root = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, false)[1]

            -- then we get the five chord in that key
            -- play it down an octave and as a 7th by default
            notes = musicutil.generate_chord_scale_degree(secondary_dominant_root - 12, "Major", 5, true)
        end
        -- seventh chord row
        if row == 1 then
            notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, true)
        end

        -- secondary mode
        if row == 2 then
            notes = musicutil.generate_chord_scale_degree(root, params:get("alt_mode"), degree, false)
        end


        -- modifications -- 
        -- doing the bass note addition in a weird order so it's not affected by inversion, could think of a better way to do this
        bass_note = notes[1]-12

        --invert chord as specified
        notes = invert_chord(notes, momentary_inversion)

        if params:get("bass_note") == 2 then
            notes[#notes+1] = bass_note
        end

        -- sort the notes in ascending order so that a strum will play correctly
        table.sort(notes)
        
        notes_to_engine(notes, z)
        

        chordname = root + degree
    end
    
    screen_dirty = true
end


function notes_to_engine(notes, on_or_off)
    
    if on_or_off == 1 then
        clock.run(function()
            for i = 1, #notes do
                local player = params:lookup_param("voice"):get_player()
                player:note_on(notes[i], 1)
                print(notes[i])
                if params:get("humanize") > 0 then
                    clock.sleep(math.random(math.floor(params:get("humanize")/2),params:get("humanize"))/1000)
                end
            end
        end)
    else
        for i = 1, #notes do
            local player = params:lookup_param("voice"):get_player()
            player:note_off(notes[i])
        end
    end

    

    -- if we just turned off all the notes, then clear the notes table
    if on_or_off == 0 then
        prev_chord = notes
        notes = {}
    end
end


function sequencer()
    while true do
        
        -- every clock step, play the current step and advance current_step
        clock.sync(1)
        -- check to see if the table at the current step is not empty

        -- send off notes from the previous step
        last_step = current_step == 1 and 16 or current_step - 1
        if seq[last_step] then
            notes_to_engine(seq[last_step], 0)
        end


        if seq[current_step] then
            notes_to_engine(seq[current_step], 1)
        end 
        current_step = current_step + 1
        if current_step > 16 then
            current_step = 1
        end
        grid_dirty = true
        
    end
end




function grid_redraw() -- how we redraw
    --g:all(0) -- turn off all the LEDs
    draw_basemap()
    
    -- draw the sequencer steps


    for x = 1,16 do -- for each column...
        for y = 1,8 do -- and each row...
            if momentary[x][y] then -- if the key is held...
                g:led(x,y,15) -- turn on that LED!
            else
                g:led(x,y,basemap[x][y]) -- otherwise, turn it back to the basemap color
            end
        end
    end

    for i = 1, 16 do
        if seq[i] then
            g:led(i,1,15)
        end
        if i == current_step then
            g:led(i,1,15)
        end
    end

    g:refresh() -- refresh the hardware to display the LED state

    
end



function redraw() -------------- redraw() is automatically called by norns
    screen.clear() --------------- clear space
    draw_piano(notes)
    screen.aa(1) ----------------- enable anti-aliasing
    screen.font_face(1) ---------- set the font face to "04B_03"
    screen.font_size(8) ---------- set the size to 8
    screen.level(15) ------------- max
    screen.move(64, 32) ---------- move the pointer to x = 64, y = 32
    screen.text_center(chordname) -- center our message at (64, 32)
    screen.pixel(0, 0) ----------- make a pixel at the north-western most terminus
    screen.pixel(127, 0) --------- and at the north-eastern
    screen.pixel(127, 63) -------- and at the south-eastern
    screen.pixel(0, 63) ---------- and at the south-western
    screen.fill() ---------------- fill the termini and message at once
    screen.update() -------------- update space
  end

function panic()
    print("panic")
    for i = 0, 127 do
        local player = params:lookup_param("voice"):get_player()
        player:note_off(i)
    end
end
