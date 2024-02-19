---- GRID UI ----

function make_ui_basemap(x_start, y_start)
    lev1 = 3
    lev2 = 6
    lev3 = 9

    -- sequencer
    for x = 1, 16 do
        basemap[x][1] = lev1
        
    end


    -- main keyboard region
    for x = (x_start),(x_start+6) do
        basemap[x][y_start-2] = lev1
        basemap[x][y_start-1] = lev1
        basemap[x][y_start] = lev3
        basemap[x][y_start+1] = lev1
        basemap[x][y_start+2] = lev1

    end

    -- modifyer area

    -- modulation 
    basemap[1][5] = lev3
    basemap[2][5] = 1
    basemap[3][5] = lev3


    -- inversions
    basemap[1][7] = lev1
    basemap[2][7] = lev2
    basemap[3][7] = lev3
    basemap[4][7] = lev3 + 3

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


---- NORNS UI ----

-- adapted from arcologies
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

    
    if (#notes > 0) and math.min(table.unpack(notes)) < 24 then
            note_offset = 0
    else
        note_offset = 23
    end

    -- Mark the selected notes in the keys table
    for _, note in ipairs(notes) do

            selected = note - note_offset
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


end

function rect(x, y, w, h, level)
    screen.level(level or 15)
    screen.rect(x, y, w, h)
    screen.fill()
end