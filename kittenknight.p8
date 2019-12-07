pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- core

-- defines --

PHYSICS_CYCLES = 5

GRAVITY = 1
JUMP_BUFFER_LIFETIME = 4
JUMP_GRACE_WINDOW_LIFETIME = 4
MAX_FALL_SPEED = 6

-- constants --

F_SOLID = 0
F_CLIMBABLE = 1

A_JUMP = 0
A_HIT_LEFT = 1
A_HIT_RIGHT = 2
A_HIT_UP = 3
A_HIT_DOWN = 4

KEY_LEFT = 0
KEY_RIGHT = 1
KEY_UP = 2
KEY_DOWN = 3
KEY_JUMP = 4
KEY_HIT = 5

-- globals --

-- TODO set to initial state
update_proc = nil
draw_proc = nil

frame = 0

input_current = { }
for i = 1, 6 do
 add(input_current, false)
end
input_last = input_current

input_buffered_action = -1
input_buffered_action_lifetime = 0

entities = { }

-- player global state

jump_grace_frame = 0
jump_grace_y = 0

can_jump = true
enable_jump_grace = false
can_double_jump = false

-- player stats

has_climb = false
has_double_jump = false

jump_impulse = -6
max_vx = 2
max_vy = 1
d_vx = 0.5
d_vy = 0.5

-- main loop --

function _init()
 game_init()
end

function _update()
 frame += 1
 input_last = input_current
 if input_buffered_action > -1 then
  if (input_buffered_action_lifetime > 0) then
    input_buffered_action_lifetime -= 1
  else
   input_clear_buffer()
  end
 end
 input_current = { }
 for i = 0, 5 do
  add(input_current, btn(i))
 end
 update_proc()
end

function _draw()
 draw_proc()
end

-- physics --

function box_new(x, y, hw, hh)
 return 
 {
  x = x,
  y = y,
  hw = hw,
  hh = hh
 }
end

function overlaps(a, b)
 return abs(flr(a.x) - flr(b.x)) < a.hw + b.hw and abs(flr(a.y) - flr(b.y)) < a.hh + b.hh
end

-- input --

function input_just_pressed(button)
 return input_current[button + 1] and not input_last[button + 1]
end

function input_just_released(button)
 return not input_current[button + 1] and input_last[button + 1]
end

function input_clear_buffer()
 input_buffered_action = -1
 input_buffered_action_lifetime = 0
end

function input_buffer_set(button, lifetime)
 input_buffered_action = button
 input_buffered_action_lifetime = lifetime
end

-- map --

function box_from_map(cx, cy)
 return box_new(cx * 8 + 4, cy * 8 + 4, 4, 4)
end

function has_flag(cx, cy, flag)
  return fget(mget(cx, cy), flag)
end

function overlaps_with_flag(box, cx, cy, flag)
  return overlaps(box, box_from_map(cx, cy)) and has_flag(cx, cy, flag)
end

-- entities --

function entity_new(x, y, sprite, colour, hw, hh, update_proc, collide_proc)
 local entity = box_new(x, y, hw, hh)

 entity.cx = flr(y / 8)
 entity.cy = flr(x / 8)

 entity.sprite = sprite
 entity.colour = colour
 entity.hflip = false
 entity.vflip = false

 entity.vx = 0
 entity.vy = 0

 entity.update_proc = update_proc
 entity.collide_proc = collide_proc

 return entity
end

function entities_update()
 for entity in all(entities) do
  if entity.update_proc then
   entity.update_proc(entity)
  end
 end
 for i = 1, PHYSICS_CYCLES do
  for entity in all(entities) do
   entity.x += entity.vx / PHYSICS_CYCLES
   entity.y += entity.vy / PHYSICS_CYCLES
   entity.cx = flr(entity.x / 8)
   entity.cy = flr(entity.y / 8)
  end
  for entity in all(entities) do
   if entity.collide_proc then
    entity.collide_proc(entity)
   end
  end
 end
end

function entities_draw()
 for entity in all(entities) do
  pal(7, entity.colour)
  spr(entity.sprite, flr(entity.x - 4), flr(entity.y - 4), 1, 1, entity.hflip, entity.vflip)
  pal()
 end
end

-- claws --

function claws_new(character, direction, frame)
  local claws = entity_new(0, 0, 2, 10, 3, 4, claws_update, claws_collide)

  claws.character = character
  claws.born_at = frame
  claws.direction = direction

  add(entities, claws)
  return claws
end

function claws_update(claws)
 if frame - claws.born_at >= 6 then
  del(entities, claws)
  claws.character.claws = nil
  return
 end
 local offset = flr((frame - claws.born_at) / 2)
 if claws.direction == A_HIT_LEFT then
  claws.sprite = 11 + offset
  claws.hflip = true
 elseif claws.direction == A_HIT_RIGHT then
  claws.sprite = 11 + offset
  claws.hflip = false
 elseif claws.direction == A_HIT_UP then
  claws.sprite = 27 + offset
  claws.vflip = true
  claws.hflip = not claws.character.hflip
 elseif claws.direction == A_HIT_DOWN then
  claws.sprite = 27 + offset
  claws.vflip = false
  claws.hflip = claws.character.hflip
 end
end

function claws_collide(claws)
 claws.x = claws.character.x
 claws.y = claws.character.y
 if claws.direction == A_HIT_LEFT then
  claws.x -= (claws.character.hw + 3)
 elseif claws.direction == A_HIT_RIGHT then
  claws.x += (claws.character.hw + 3)
 elseif claws.direction == A_HIT_UP then
  claws.y -= (claws.character.hh + 3)
 elseif claws.direction == A_HIT_DOWN then
  claws.y += (claws.character.hh + 3)
 end
end

-- character states --

function character_jump(character, impulse)
 if not can_jump and not can_double_jump then
  return
 end
 if can_jump then
  can_jump = false
  can_double_jump = has_double_jump
 else
  can_double_jump = false
 end
 if not impulse then
  character.vy = jump_impulse
 else
  character.vy = impulse
 end
 character.update_proc = character_jumping_update
 character.collide_proc = character_jumping_collide
end

function character_ground(character)
 can_jump = true
 can_double_jump = false
 character.vy = 0
 character.update_proc = character_grounded_update
 character.collide_proc = character_grounded_collide
end

function character_fall(character)
 if enable_jump_grace then
  jump_grace_frame = frame + JUMP_GRACE_WINDOW_LIFETIME
  jump_grace_y = character.y
  enable_jump_grace = false 
 end

 character.vy = 0
 character.update_proc = character_falling_update
 character.collide_proc = character_jumping_collide
end

function character_climb(character)
 can_jump = true
 can_double_jump = false
 character.vy = 0
 character.update_proc = character_climbing_update
 character.collide_proc = character_climbing_collide
end

function character_jumping_update(character)
 character_handle_horizontal_movement(character)
 character.vy = min(character.vy + GRAVITY, MAX_FALL_SPEED)
 if input_just_released(KEY_JUMP) or character.vy == 0 then
  character_fall(character)
 end
 character.sprite = 18
 character_handle_hit_state(character, nil)
end

function character_falling_update(character)
 character_handle_horizontal_movement(character)
 character.vy = min(character.vy + GRAVITY, MAX_FALL_SPEED)
 local in_jump_grace_window = frame < jump_grace_frame
 if (can_jump and in_jump_grace_window or can_double_jump) and input_buffered_action == A_JUMP then
  input_clear_buffer()
  if in_jump_grace_window then
   character.y = jump_grace_y
  end
  character_jump(character)
 end
 character.sprite = 17
 character_handle_hit_state(character, nil)
end

function character_jumping_collide(character)
 character_handle_horizontal_collision(character)
 character_handle_vertical_collision(character)
end

function character_grounded_update(character)
 character_handle_horizontal_movement(character)
 character.sprite = 2
 if character.vx != 0 then
  character.sprite = 1 + flr(frame / 4) % 4 
 end
 if (input_buffered_action == A_JUMP) then
  input_clear_buffer()
  character_jump(character)
 end
 character_handle_hit_state(character, A_HIT_DOWN)
end

function character_grounded_collide(character)
 character_handle_horizontal_collision(character)
 character.y += 1
 if not has_solid_vertical(character, 1) then
   enable_jump_grace = true
   character_fall(character)
 end
 character.y -= 1
end

function character_climbing_update(character)
 if btn(KEY_UP) then
  character.vy = max(character.vy - d_vy, -max_vy)
 elseif btn(KEY_DOWN) then
  character.vy = min(character.vy + d_vy, max_vy)
 else
  if character.vy > 0 then
   character.vy -= d_vy
  elseif character.vy < 0 then
   character.vy += d_vy
  end 
 end
 character.sprite = 5
 if character.vy != 0 then
  character.sprite = 5 + flr(frame / 4) % 4 
 end
 if (input_buffered_action == A_JUMP) then
  input_clear_buffer()
  character_jump(character, jump_impulse * 0.8)
 end
 local ignored_hit_direction = A_HIT_RIGHT
 if character.hflip then
  ignored_hit_direction = A_HIT_LEFT
 end
 character_handle_hit_state(character, ignored_hit_direction)
end

function character_climbing_collide(character)
local cx = character.cx
 if character.hflip then
  cx -= 1
 else
  cx += 1
 end
 if not has_flag(cx, character.cy, F_CLIMBABLE) then
  if character.vy > 0 then
   enable_jump_grace = true
   character_fall(character)
  else
   character.vy = 0
   character.y = (character.cy + 1) * 8
  end
 end
 if character.vy > 0 and has_solid_vertical(character, 1) then
  character.vy = 0
  character.y = character.cy * 8 + 8 - character.hh
  character_ground(character)
  return
 end
 if character.vy < 0 and has_solid_vertical(character, -1) then
  character.vy = 0
  character.y = character.cy * 8 + 8 - character.hh
  return
 end
end

function has_solid_vertical(character, dy)
  return overlaps_with_flag(character, character.cx, character.cy + dy, F_SOLID) or
   overlaps_with_flag(character, character.cx - 1, character.cy + dy, F_SOLID) or
   overlaps_with_flag(character, character.cx + 1, character.cy + dy, F_SOLID)
end

function character_handle_vertical_collision(character) 
 if character.vy > 0 and has_solid_vertical(character, 1) then
  character.y = character.cy * 8 + 8 - character.hh
  character_ground(character)
  return
 end
 if character.vy < 0 and has_solid_vertical(character, -1) then
  character.y = character.cy * 8 + 8 - character.hh
  character_fall(character)
  return
 end
end

function character_handle_horizontal_collision(character)
 if character.vx < 0 and overlaps_with_flag(character, character.cx - 1, character.cy, F_SOLID) then
  character.vx = 0
  character.x = (character.cx - 1) * 8 + 8 + character.hw
  if (has_climb and has_flag(character.cx - 1, character.cy, F_CLIMBABLE)) then
    character_climb(character)
  end
  return
 end
 if character.vx > 0 and overlaps_with_flag(character, character.cx + 1, character.cy, F_SOLID) then
  character.vx = 0
  character.x = (character.cx + 1) * 8 - character.hw
  if (has_climb and has_flag(character.cx + 1, character.cy, F_CLIMBABLE)) then
    character_climb(character)
  end
  return
 end
end

function character_handle_horizontal_movement(character)
 if btn(KEY_LEFT) then
  character.hflip = true
  character.vx = max(character.vx - d_vx, -max_vx)
 elseif btn(KEY_RIGHT) then
  character.hflip = false
  character.vx = min(character.vx + d_vx, max_vx)
 else
  if character.vx > 0 then
   character.vx -= d_vx
  elseif character.vx < 0 then
   character.vx += d_vx
  end
 end
end

function character_handle_hit_state(character, ignored_direction)
 if character.claws == nil and input_buffered_action > 0 then
  if input_buffered_action != ignored_direction then
   character.claws = claws_new(character, input_buffered_action, frame)
   input_clear_buffer()
  end
 end
end

-- game scene --

function game_init()
 paw_box = box_from_map(2, 2)
 spring_box = box_from_map(14, 14)

 update_proc = game_update
 draw_proc = game_draw

 player = entity_new(36, 116, 2, 10, 3, 4, character_grounded_update, character_grounded_collide)
 player.claws = nil
 add(entities, player)
end

function game_update()
 if input_just_pressed(KEY_JUMP) then
  input_buffer_set(A_JUMP, JUMP_BUFFER_LIFETIME)
 end
 if input_just_pressed(KEY_HIT) then
  if btn(KEY_LEFT) then
   input_buffer_set(A_HIT_LEFT, JUMP_BUFFER_LIFETIME)
  elseif btn(KEY_RIGHT) then
   input_buffer_set(A_HIT_RIGHT, JUMP_BUFFER_LIFETIME)
  elseif btn(KEY_UP) then
   input_buffer_set(A_HIT_UP, JUMP_BUFFER_LIFETIME)
  elseif btn(KEY_DOWN) then
   input_buffer_set(A_HIT_DOWN, JUMP_BUFFER_LIFETIME)
  else
   if player.hflip then
    input_buffer_set(A_HIT_LEFT, JUMP_BUFFER_LIFETIME)
   else
    input_buffer_set(A_HIT_RIGHT, JUMP_BUFFER_LIFETIME)
   end
  end
 end

 entities_update()

 if overlaps(player, paw_box) and not has_climb then
  show_message("got paws of climbing")
  has_climb = true
  mset(2, 2, 0)
 end

 if overlaps(player, spring_box) and not has_double_jump then
  show_message("got spring of jumping")
  has_double_jump = true
  mset(14, 14, 0)
 end
end

function game_draw()
 clip(0, 0, 127, 127)
 cls()
 map(0, 0, 0, 0, 16, 16)
 entities_draw() 

 game_draw_debug()
end

function game_draw_debug()
 color(10)
 print("fps: "..tostr(stat(7)), 0, 0)
 print("cpu: "..tostr(stat(1) * 100).."%", 0, 6)
 print("x: "..tostr(player.x), 50, 0)
 print("y: "..tostr(player.y), 50, 6)
end

function show_message(message)
 cur_message = " "..message.." "
 message_lifetime = 30 * 3
 update_proc = message_update
 draw_proc = message_draw
end

function message_draw()
 local w = #cur_message * 4 + 6
 local h = 6 + 6
 local x = 64 - w / 2
 local y = 64 - h / 2

 clip(x, y, w, h)
 rectfill(x, y, x + w, y + h, 0)
 color(12)
 rect(x + 2, y + 2, x + w - 2, y + h - 2)
 print(cur_message, x + 3, y + 4)
end

function message_update()
 message_lifetime -= 1
 if (message_lifetime == 0 or input_just_pressed(KEY_JUMP)) then
  update_proc = game_update
  draw_proc = game_draw
 end
end

__gfx__
00000000000000000070007000000000007000700070007000000000007000700000000000000000000000000070000000000000000000000000000000000000
07000070007000700777777000700070077777700777777000700070077777700070007000000000000000000007000000070000000000000606060009999990
00700700077777700777777007777770077777700777777007777770077777700777777000000000000000000007000000070000000000000060606000099000
00077000077777700770707007777770077070700770707007777770077070770777777000000000000000000000700000007000000070000060606000000900
00077000077070700777777007707070077777700777777707707070077777700770707700000000000000000700700000007000000070000066666009999990
00700700077777707077770007777770007777000077770007777777007777000777777000000000000000007000000077070000700700000066666000099000
07000070777777000777770077777700077777000777777707777770077777700777777000000000000000000000000000070000070700000006666000000900
00000000007070000070070000070700707007000700000070000007700000070700000700000000000000000000000000000000007000000000000009999990
00000000007000700070007000000000000000000000000000000000000000000000000000000000000000000007000000070000000700000000000000000000
00000000077777700777777000000000000000000000000000000000000000000000000000000000000000000000700000070000007000000000000000000000
00000000077777700777777000000000000000000000000000000000000000000000000000000000000000000000000700000000700000000000000000000000
00000000077070700770707000000000000000000000000000000000000000000000000000000000000000000000077007700770077000000000000000000000
00000000077777700777777000000000000000000000000000000000000000000000000000000000000000000007700000077000000770000000000000000000
00000000707777000077777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077777000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007000707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7777777777777777b36655555556663b000000000000000000000000555666777766555500000000000000000000000000000000d00000000000000d00000000
76777677767776773665555555666663000000000000000000000000556667777776655500000000000000000000000000000000ddd0000000000ddd00000000
7767677777676777b35555555556663b000000000000000000000000555666677766555500000000000000000000000000000000ddddd000000ddddd00000000
76666677766666773666655555556663000000000000000000000000555566667665555500000000000000000000000000000000dddddd0000dddddd00000000
6666666766666667b36666555555563b000000000000000000000000555556666666555500000000000000000000000000000000dddddd0000dddddd00000000
66666665565666663666555555556663000000000000000000000000555556666665555500000000000000000000000000000000ddddddd00ddddddd00000000
6666655555566666b36555555556663b000000000000000000000000555566666666655500000000000000000000000000000000ddddddd00ddddddd00000000
66655555555566663666555555556663000000000000000000000000555666666666555500000000000000000000000000000000dddddddddddddddd00000000
77777777666655555555555555555555555555555556666655555555555666777766555555556666666555555555555500000000dddddddddddddddddddddddd
767776776665555555555555555555555555555555666666555555555566677777766555555556666666555555555555000000000dddddddddddddd0dddddddd
776767776655555555555555556655555555555555566666555555555556666777665555556656666666555555555555000000000dddddddddddddd0dddddddd
7666667766666555566655555666566555555665555566665666555555556666766555555666666666665665555555550000000000dddddddddddd00dddddddd
6666666666666655666665556666666655556666555556666666655555555665666655556666666666666666555555550000000000dddddddddddd00dddddddd
56566665666655556666555566666666556666665555666666665555555555555665555566666666666666665555555500000000000dddddddddd000dddddddd
5555655566655555666555556666666655566666555666666665555555555555555555556666666666666666555555550000000000000dddddd00000dddddddd
555555556666555566665555666666665555666655556666666655555555555555555555666666666666666655555555000000000000000dd0000000dddddddd
__gff__
0000000000000000000000000000000000000000000000000000000000000000010103030000000101000000000000000101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3433333333333332343333333333333200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500000000000031230000002e3f3f3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35000e002e3f2d31230000003d3f3f3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
27303030303f3e3123000020213d3f3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35002e3f3f3e0031230000222300003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35003f3f3e000031350000222300003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35003f3030303028230000222300003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
35003d3f2d000031230000312300003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500003f3f2d0031232e3f31233f2d3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3500003d3f3f3f31233f3f22233f3f3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
27303030303f3f31353f3e22233d3f3e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
352d00003d3f3f31353e00222300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
353f2d0000000031230000222730302000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
353f3f30303030382300003a3900003100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
353f3f3f3f2d00000000000000000f3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3730303030303030303030383730303800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
