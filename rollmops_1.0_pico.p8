pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- rollmops v1.0
-- 2025 phil norton
-- init -----------------------
function _init()
 extcmd("set_title","rollmops")
 version = "1.0"
 debug = false
 debug_end = false
 debug_brakes = false
 debug_single_frame = false
 state = "intro"
	start_height = 10000
	-- system constants
	fps = 60 --don't change in pico
	-- physics variables
	ga = 0.08 --gravitational acc (ay)
	max_vx_p = 1.2
	max_vy_p = 2
	dash_time = 10
	dash_cooldown = 25
	v_dash = 4
 cloud_vx =	-0.125
	cloud_vy = 0.5
	title_vy = 0.35
	-- game variables
	--states:intro,title,ready,set,play,limbo,respawn,pause,over,end,outro,restart
	cam_y_intro = -170 + 70
	cam_y_set = -27 --where the game starts (when mops lands on first platform)
	cam_y_end=start_height+cam_y_set
	ground_y = cam_y_end+128-13  --where mops lands
	--cam_y_intro = -200 + 70
	speeds = {0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7}
	--the following numbers refer to "score", roughly the number of pixels fallen (minus cam_y_set)
	--pre-0.1.9: levels = {800,1700,2700,3800,5000,6300,7700,9200,10800} --~250 sec bis 20.000
	levels = {500,1100,1800,2600,3500,4500,5600,6800,8100,9500} --~250 sec bis 20.000
	levels = {800,1300,1900,2600,3400,4300,5300,6400,7600,8900} --~250 sec bis 20.000
	levels = {500,900,1400,2000,2700,3500,4400,5400,6500,7700} --~250 sec bis 20.000
	life_spawn = {300, 800,1400,2200,3200,4400,5800,7500, 9500}
	pckl_spawn = {550,1100,1800,2700,3800,5100,6650,8500}
	--debug test: life_spawn = {200}
	pf_w = 36 --platform width
	--p_spike = 0.2
	p_spike = 0.2 --probability for deadly platforms
	pf_dist = 24 --vertical distance
	max_off = 45 --pf spawn x offset
	min_frames_limbo = 50 --timeout after death
	frames_respawn = 9
	title_duration = 2
	-- draw variables
	rad_p = 3.5 --mops radius
	base_spr_p = 0 --first mops sprite (rot=0)
	puff_spr = 22 --first puff sprite
	hart_spr = 39 --first sprite of breaking heart
	soul_spr = 56 
	shadow_spr = 57 --dashing "shadow"
	dur_blink = 0.15 * fps
 dur_puff = 0.07
 dur_hart = 0.09
 lat_blink = (0.5+rnd(4)) * fps
 --sync head bob to music
 lat_head_bob = 50 * fps/60 / 2
	-- set up high score
	cartdata("highscore_rollmops")
	--run once with the following line uncommented to reset highscore (low score)
	--dset(0, start_height) 
	t_intro = 0
	music_toggle = true
	create_menu()
	initialize(true)
	-- prepare intro
end

function initialize(reset_title)
	level = 1
	score = 0 --todo: remove in favor of height
 height =	start_height --score
	speed = speeds[level]
	lives = 2
	pickles = 2
	i_life_spawn = 1
	i_pckl_spawn = 1
	need_life = false --true: look for suitable pf to create life on
	need_pckl = false --true: look for suitable pf to create pckl on
	-- draw variables
	cam_y = 0
	other_frame = false
	-- timers
 t_puff = new_timer()
 t_hart = new_timer()
 t_outro = new_timer()
 -- load highscore
	highscore = dget(0)
 -- create platforms
	pf_hist = {} --rolling history of platforms
	pf = {}
	update_platforms("no_spikes") --todo: no spikes
	-- create clouds
 clouds = {new_cloud(rndi(20,70)+30,cam_y_intro+150),
           new_cloud(rndi(70,120)+60,cam_y_intro+150+1*70),
           new_cloud(rndi(20,70)+90,cam_y_intro+150+2*70)}
 last_cloud_was_left=false
 if reset_title then
 	t_title = new_timer()
  -- title cloud "rollmops"
  title_y = cam_y_intro+57 --tracks title for animations
  --miniclouds for title animation
  minicloud = {new_sprite(15,cam_y_intro+74,148),
   new_sprite(15,cam_y_intro+56,149),
   new_sprite(100,cam_y_intro+59,150),
   new_sprite(105,cam_y_intro+77,166),
   new_sprite(37,cam_y_intro+54,180),
   new_sprite(75,cam_y_intro+58,164),
   new_sprite(48,cam_y_intro+76,165)}
  v=0.7
  a=0.05
  vx_minicloud = {-v,-v,v,v,-.2*v,.1*v,0}
  vy_minicloud = {v,-v,-v,v,-1.2*v,-v,1.3*v}
  ax_minicloud = {a,a,-a,-a,.2*a,-.1*a,0}
  ay_minicloud = {-a,a,a,-a,a,a,-a}
 end
 -- create player mops
	mops = {} -- keeps history
	start_x = pf[1].x+pf_w/2
	start_y = cam_y_intro - 7
	end_music_playing = false
	--start_y = cam_y_intro - 82
	--start_y = pf[4].y-rad_p-1
	p1 = new_mops(start_x,start_y,
			ga,rad_p,base_spr_p)
	p1.controllable = false
	p1.falls = true
	add(mops, p1) --add to history
	mops_x_final = 83
	oma = new_oma(mops_x_final+12,ground_y)
	cane = new_cane(oma.x-4,oma.y-oma.h+8,oma.spr_cane,3.5,ga)
 --place holder for objects
	life = false 
	pckl = false
	puff = false
	hart = false  --breaking heart
	soul = false
	hart_oma = false --above head
	--keep track for end variation
	deaths = 0
 pckl_collected = 0
 life_collected = 0
	if debug_end then
	 p1.y = 9300
	 cam_y = 9500
	 level = 9
	 state="play"
	 deaths = -1
  pckl_collected = #pckl_spawn
  life_collected = #life_spawn
	end
end

function create_menu()
 --from manual
 menuitem(1, "music: on",
  function()
    music_toggle = not music_toggle
    menuitem(nil, "music: "..(music_toggle and "on" or "off"))
    --stop music
    if not music_toggle then
     music(-1)
    end
    return true -- don't close
  end
 )
end
-->8
-- update ---------------------
function _update60()
	handle_input()
	-- advance state
	if state == "restart" then
	 restart()
	end
	if state == "title" then
	 if tim_dur(t_title) 
	    > title_duration then
	  state = "ready"
	 end
	end
	if state == "ready" and
	   p1.y+p1.rad>=pf[1].y-2 then
	  -- when p1 touches first pf
	  state = "set"
	  --debug:to check correct start y:
	  --score = cam_y --(unrounded)
	  p1.controllable = true
	end
	if state == "outro" then
	 animate_outro()
	end
	-- update movement
	if state == "play" or
	   state == "ready" or
	   state == "end" or
	   state == "outro" then
  --for debug: 
  --or state == "pause" then
		update_movement()
	end
	--update sprites,cam,level,...
	if state == "end" or 
	   state == "outro" then
	 update_sprite_mops(p1)
  update_sprite_cane(cane)
	 update_animation()
		update_clouds()
 elseif state == "play" or
	   state == "ready" or
	   state == "limbo" or
	   state == "respawn" then
	 update_sprite_mops(p1)
	 update_animation()
		update_camera()
		update_level()
		update_platforms()
		update_clouds()
		if height <= speed then
		 handle_end()
		end
	end
	if state == "ready" then
	 update_title()
	end
	if state == "limbo" or
	   state == "respawn" then
	 handle_respawn()
	end
	if state == "over" then
	 if soul then
	  soul.y -= 0.5
	  if soul.y < cam_y - 20 then
	   soul = false
	  end
	 end
	end
	if need_life then
	 create_life()
	end
	if need_pckl then
	 create_pckl()
	end
	-- special cases for ending
	if state == "play" and 
	   height < 42 then
	 if deaths == 0 then
	  oma.spr_glas_org = 30
	  oma.spr_glas = oma.spr_glas_org
	 end
	end
	--debug: remove
	if debug_single_frame then
	 state = "pause"
	 debug_single_frame = false
	end
end -- _update60()

function update_camera()
 cam_y += speed
 if state == "play" or
    state == "limbo" or
    state == "respawn" then
	 score = flr(cam_y)
  --todo: height as score
  height = start_height
  		- flr(cam_y) + cam_y_set
	end
 camera(0,cam_y)
end

function update_sprite_mops(t)
 -- player spr (rotate,blink..)
 -- sprites must be sequential, in order of
 -- clockwise rotation, starting at t.base_spr
 n_s = 8 --number of rotated sprites
 base = t.base_spr
 f_rot = fract(t.rot)
 if t.rot >= 0 then
  t.spr = round(base+f_rot*n_s+1/(n_s*2))
 else
  t.spr = round(base+(1-f_rot)*n_s+1/(n_s*2))
 end
 if t.spr == base + n_s then
  t.spr = base
 end
 --if dead, take exquiv. from next 8 sprites
 if p1.died_by_spike then
  t.spr = t.spr + 8
 end
 --if blinking, shift to eyes closed sprites
 if state == "play" or 
    state == "outro" then
  if p1.has_cane then
   t.spr += 128
  elseif p1.is_blinking then
   t.spr += 48
  end
 end
 if state=="outro" and t.barks then
  t.spr = 37
 end
end

function update_sprite_cane(t)
 -- cane spr rotation
 -- sprites must be sequential, in order of
 -- clockwise rotation, starting at t.base_spr
 n_s = 8 --number of rotated sprites
 base = t.base_spr
 f_rot = fract(t.rot)
 if t.rot >= 0 then
  t.spr = round(base+f_rot*n_s+1/(n_s*2))
 else
  t.spr = round(base+(1-f_rot)*n_s+1/(n_s*2))
 end
 if t.spr == base + n_s then
  t.spr = base
 end
end

function update_title()
 title_y += title_vy
end
-->8
-- draw -----------------------
function _draw()
 palt(12,true) --blue transp
 palt(0,false) --black opaque
	cls(12) --clear screen (color)
 -- draw clouds
 for i = 1,#clouds do
  draw_cloud(clouds[i])
 end
 -- draw  ground
 map(0,0,0,cam_y_end+40)
 -- draw platforms
	draw_platforms()
	-- draw extra life and pickles
	if life then
 	spr(life.spr,life.x-life.rad,
 	    life.y-life.rad-1)
 end
	if pckl then
 	spr(pckl.spr,pckl.x-pckl.rad,
 	    pckl.y-pckl.rad-1)
 end
 if puff then
  spr(puff.spr, puff.x-puff.rad,
      puff.y-puff.rad,1,1,puff.flip_x,puff.flip_y)
 end
 if hart then
  spr(hart.spr, hart.x-hart.rad,
      hart.y-hart.rad,1,1,hart.flip_x,hart.flip_y)
 end
 if soul then
  spr(soul.spr, soul.x-soul.rad,
      soul.y-soul.rad)
 end
 if hart_oma then
  spr(hart_oma.spr, hart_oma.x-hart_oma.rad,
      hart_oma.y-hart_oma.rad,1,1)
 end
 -- draw bench
 spr(144,10,ground_y-42,4,3)
 -- draw tree
 tr_x = 64
 tr_y = ground_y-92
 spr(182,tr_x+4*8,tr_y+0*8,4,1)
 spr(136,tr_x+0*8,tr_y+1*8,8,3)
 spr(186,tr_x+2*8,tr_y+4*8,6,1)
 spr(205,tr_x+5*8,tr_y+5*8,3,4)
 -- draw oma
 draw_oma()
 -- draw player
 if p1.visible then
  -- "dash shadow"
  if p1.is_dashing then
   spr(shadow_spr,p1.x-p1.rad,
       p1.y-p1.rad-2)
  end
  if p1.faces_left then
   spr(p1.spr,p1.x-p1.rad,
       p1.y-p1.rad,1,1,true)
  else
   spr(p1.spr,p1.x-p1.rad,
       p1.y-p1.rad)
  end
 end
 --draw cane (outro)
 if cane.visible then
  spr(cane.spr,cane.x,cane.y)
 end
 --draw puff animation for title
 th_tmp = 32 --title height
 px = 18 --p1 position aove title bottom in pixel to trigger puff
 spr_cur = puff_spr
 if state == "ready" then
  if p1.y > title_y+th_tmp-px and
     p1.y < title_y+th_tmp-px+10 then
   if not puff then
    puff = new_sprite(p1.x,title_y+th_tmp-8,puff_spr,3.5,false,true)
    tim_start(t_puff)
    --sfx(3)
   end
  end
  if puff then
   --draw again over player
   spr(puff.spr, puff.x-puff.rad,
       puff.y-puff.rad,1,1,puff.flip_x,puff.flip_y)
  end
 end
 draw_title()
 -- display lives
 --todo: get score print width (w=print.. outside cam)
 --      to center it
 score_x = 54
 if state ~= "title" and 
    state ~= "ready" then
  for l = 1,lives do
   if l < 8 then
    spr(36,128-l*6,cam_y-1)
   else
    spr(36,128-(l-7)*6,cam_y+7)
   end
  end
  for p = 1,pickles do
   if p < 8 then
    spr(38,-5+p*6,cam_y)
   else
    spr(38,-5+(p-7)*6,cam_y+8)
   end
  end
  -- debug level
  --print(state,0,cam_y+12,8)
  --print(p1.x,0,cam_y+21,8)
  --print(p1.rot,0,cam_y+28,8)
  --print(p1.falls,0,cam_y+35,8)
  --print(tim_dur(t_outro),0,cam_y+42,8)
  -- old lives text
  --color(2) --shadow color
  --print("lives: "..tostr(lives),92-1,cam_y+1+1)
  --color(3) --shadow color
  --print("pickles: "..pickles,1+1,cam_y+1+1)
  color(2) --shadow color
  print(""..height,score_x+1,cam_y+1+1)
  --color(8) --text color
  --print("lives: "..tostr(lives),92,cam_y+1)
  --color(11) --text color
  --print("pickles: "..pickles,1,cam_y+1)
  color(14) --text color
  print(""..height,score_x,cam_y+1)
 end
 if state == "set" then
  col_help1 = 2
  col_help2 = 14
  pprint("   roll   ",p1.x-20,p1.y-16,col_help1,col_help2)
  print("⬅️      ➡️",p1.x-20,p1.y-16,col_help1)
  pprint("press    to dash down",p1.x-42,p1.y-42,col_help1,col_help2)
  print("      ❎",p1.x-42,p1.y-42,2,col_help1)
  pprint("while falling",p1.x-26,p1.y-34,col_help1,col_help2)
  pprint("press    to start",p1.x-34,p1.y+15,col_help1,col_help2)
  print("      🅾️         ",p1.x-34,p1.y+15,col_help1)
  print("V"..version,3,cam_y+121,6)
  print("PHIL",127-17,cam_y+116,6)
  print("NORTON",127-25,cam_y+121,6)
 end
  --print("highscore: "..highscore,1,cam_y+10)
 if debug then
  print("cam_y: "..cam_y,0,cam_y+20)
  print("state: "..state,0,cam_y+30)
  print("speed: "..speed,0,cam_y+40)
  print("level: "..level,0,cam_y+50)
  print("has_rot: "..p1.has_rot,0,cam_y+60)
  --print("cont_rot_for: "..p1.cont_rot_for,0,cam_y+70)
  print("t_blink: "..p1.t_blink,0,cam_y+70)
  print(#pf,0,cam_y+80)
  print("p1 spr: "..tostr(p1.spr),0,cam_y+90)
  print("p1 rot: "..p1.rot,0,cam_y+100)
  print("p1 vrot: "..p1.vrot,0,cam_y+110)
  print("p1 falls: "..tostr(p1.falls).." was: "..tostr(p1.was_falling),0,cam_y+120)
  print(time(),score_x,cam_y+11)
  if debug_brakes then
   print("brakes!",64,cam_y+64)
  end
 end
 if state == "intro" then
  cls(0)
  if time() > 1.333 then
   draw_intro() --runs only once
  end
 end
 -- old mops phase out, new in
 if state == "respawn" then
  color(4) --circle color
  if p1.t_respawn < 4 then
   old = mops[#mops-1]
   circfill(p1.x, p1.y, 1)
   if old.died_by_spike then
    circfill(old.x,old.y,3) end
  elseif p1.t_respawn < 7 then
   circfill(p1.x, p1.y, 2)
   if old.died_by_spike then
    circfill(old.x,old.y,2) end
  elseif p1.t_respawn <= frames_respawn then
   circfill(p1.x, p1.y, 3)
   if old.died_by_spike then
    circfill(old.x,old.y,1) end
  end
 end
 if state == "over" then
  --print("\^d5game over", 50, cam_y+64)
  c1 = 2--text colors
  c2 = 14
  pprint("game over", 45, cam_y+50,c1,c2)
  pprint("press    to restart",25,cam_y+100,c1,c2)
  print("      🅾️           ",25,cam_y+100,c1)
  if height < highscore then
   pprint("new low score! "..height, 30, cam_y+70,c1,c2)
   pprint("old: "..highscore, 48, cam_y+80,c1,c2)
  else
   pprint("low score: "..highscore, 33, cam_y+70,c1,c2)
  end
 end
 if state == "outro" and
    tim_dur(t_outro) > 11.2 then
  c1 = 2--text colors
  c2 = 14
  pprint("press    to restart",25,cam_y+16,c1,c2)
  print("      🅾️           ",25,cam_y+16,c1)
 end  
end -- _draw()

function draw_platforms()
	for p in all(pf) do
	 if p.exists then
 		--number of middle tiles
 		n_mids = ceil((p.w-16)/8)
 		--check if is spike
 		if p.kills then
 			sprite = {19,20,21} --org col
 			--sprite = {35,36,37}
 		else
 			sprite = {16,17,18}
 		end
 		spr(sprite[1], p.x, p.y)
 		for m=1,n_mids do
 			spr(sprite[2], p.x + m * 8, p.y)
 		end
 		spr(sprite[3], p.x + p.w - 8, p.y)
  end --if p.exists
	end
 if debug then --print pf number
  for p = 1,#pf do
 	 print(p, pf[p].x, pf[p].y)
  end
 end
end

function draw_cloud(c)
 for i = 1,count(c.gx) do
  circfill(c.wx[i]+c.x,
           c.wy[i]+c.y+3,c.wr[i]-2,6)
  circfill(c.gx[i]+c.x,
           c.gy[i]+c.y,c.gr[i],6)
  circfill(c.wx[i]+c.x,
           c.wy[i]+c.y,c.wr[i],7)
 end
-- rectfill(c.left,c.bottom-3,
--  c.right,c.bottom+3,7)
-- line(c.left-1,c.bottom+3,
--  c.right+3,c.bottom+3,6)
end

function draw_oma()
 spr(oma.spr_arm_b,oma.x-2+oma.spr_arm_b_xoff,oma.y-oma.h+3+oma.spr_arm_b_yoff)
 if pckl_collected == #pckl_spawn then
  pal(0,11)
 end
 if life_collected == #life_spawn then
  pal(2,8)
 end
 spr(oma.spr_body,oma.x, oma.y-oma.h,2,2)
 pal(0,0)
 pal(2,2)
 spr(oma.spr_head,oma.hx,oma.hy-oma.h+oma.head_bob,2,2)
 spr(oma.spr_glas,oma.hx,oma.hy-oma.h+oma.head_bob+8,2,1)
 spr(oma.spr_arm_f,oma.x+5+oma.spr_arm_f_xoff,oma.y-oma.h+3+oma.spr_arm_f_yoff)
end

function draw_intro()
 cam_y = cam_y_intro
 cy = cam_y --short
 camera(0,cam_y_intro)
 cls(0)
 color(7)
 soon = stat(80)+2
 d = "\^d4" --print delay. number at the end is frames
 -- blinking cursor
 b_on = true
 --todo: blink in realtime w/anim timers
 for blnk=1,6 do --even to end on black
  for t=1,20 do
   if b_on then
    print("_",10,cy+10,7)--black
   else
    print("_",10,cy+10,0)--white
   end
   if btn(🅾️,0) then
    goto title
   end
   flip() -- draw frame
  end
  if b_on then
   b_on = false
  else
   b_on = true
  end
 end
 print("_",10,cy+10,0) --black
 sfx(0,0)
 print(d.."in the dystopian future of  ",
       10,cy+10,7)
 --sleep + check if interrupted
 --debug: jump to title, take out, or find a way to interrupt printing with \^d
 --if (sleep(0.2,🅾️)) goto title
 sfx(-1,0)
 sfx(1,0)
 print(d..""..soon.." a.d.",
       47,cy+20,8)
 sfx(-1,0)
 sleep(1.2,🅾️)
 sfx(0,0)
 print(d.."where gray herrings and  ",
       10,cy+35,7)
 sfx(-1,0)
 sfx(1,0)
 print(d.."wooden spikes fill the sky",
       10,cy+45)
 sfx(-1,0)
 sleep(0.6,🅾️)
 sfx(1,0)
 print(d.."and dogs are born  ",
       10,cy+60)
 sfx(-1,0)
 sfx(0,0)
 print(d.."10000 pixels above ground...",
       10,cy+70)
 sfx(-1,0)
 sleep(1.2,🅾️)
 sfx(1,0) --todo: better sfx
 print("\^d4you",
       55,cy+90,8)
 sfx(-1,0)
 sleep(1,🅾️)
 sfx(0,0) --todo: better sfx
 print("\^d4are",
       55,cy+105,8)
 sfx(-1,0)
 sleep(1,🅾️)
 --fade
 ::title::
 col = {0,1,12}
 for i=1,#col do
  cls(col[i])
  sleep(0.12,false)
 end
 sleep(0.12,false)
 state="title"
 tim_start(t_title)
end

function draw_title()
 --title
 dur_title = tim_dur(t_title)
 sprite_col = 8
 --col = {13,14, 8} --candy string
 col = {6, 7, 7} --cloudy
 --col = {2, 14, 8} --red
 --col = {10, 9, 8} --sunny
 edge_col = col[1]
 mid_col = col[2]
 face_col = col[3]
 fade_colors = {5,6}
 y = title_y --test
 if state == "intro" or
    state == "title" then
  x = 10
  --y = title_y --defined in initialize()
 elseif state == "ready" then
  --move title like clouds
  --x += cloud_vx
  --y += title_vy
  if puff then
   puff.y += title_vy
  end
  for i = 1,#minicloud do
   minicloud[i].y += title_vy
  end
 end
 --draw mini clouds
 if dur_title > 0.4 then
  --start music if not playing
  if state == "title" and
     not stat(57) and 
     music_toggle then
   music(63)
  end
  for i = 1,#minicloud do
   m = minicloud[i]
   m.x += vx_minicloud[i]
   m.y += vy_minicloud[i]
   vx_minicloud[i]+=ax_minicloud[i]
   vy_minicloud[i]+=ay_minicloud[i]
   -- stop v at zero and on grid
   --(align w/ title cloud for 
   --smooth animation)
   if abs(vx_minicloud[i]) <=
      abs(ax_minicloud[i]) then
    vx_minicloud[i] = 0
    --m.x = round(m.x)
   end
   if abs(vy_minicloud[i]) <=
      abs(ay_minicloud[i]) then
    vy_minicloud[i] = 0
    --m.y = round(m.y)
   end
   spr(m.spr,m.x,m.y)
  end --for
 end
 -- draw title with offsets
 if dur_title > 0.5 then
  --print offset in each dir X2
  pal(sprite_col,edge_col)
  sspr(0,96,103,32,x,y+2)
  --sspr(0,96,103,32,x+2,y)
  sspr(0,96,103,32,x,y-2)
  sspr(0,96,103,32,x-2,y)
  pal(sprite_col,mid_col)
  sspr(0,96,103,32,x,y+1)
  sspr(0,96,103,32,x+1,y)
  sspr(0,96,103,32,x,y-1)
  sspr(0,96,103,32,x-1,y)
  --diagonal
  sspr(0,96,103,32,x+1,y+1)
  sspr(0,96,103,32,x-1,y+1)
  --sspr(0,96,103,32,x-1,y-1)
  sspr(0,96,103,32,x+1,y-1)
 elseif dur_title > 0.4 then
  --print offset in each dir
  pal(sprite_col,edge_col)
  sspr(0,96,103,32,x,y+1)
  sspr(0,96,103,32,x+1,y)
  sspr(0,96,103,32,x,y-1)
  sspr(0,96,103,32,x-1,y)
  --print centered
  pal(sprite_col,face_col)
  sspr(0,96,103,32,x,y)
 elseif dur_title > 0.3 then
  --print centered
  pal(sprite_col,edge_col)
  sspr(0,96,103,32,--sprite sheet
       x,y)--screen
 end
 pal(sprite_col,sprite_col)
 title_y = y --track for animations
end
-->8
-- things ---------------------
function new_platform(x,y,w,is_spike)
 it = {}
 it.x = x --position
 it.y = y
 it.w = w --width in pixels
 it.kills = is_spike
 it.exists=true --for draw & physics
 add(pf_hist,it) --update history
 if #pf_hist > 3 then
 	deli(pf_hist,1)
 end
 return it
end

function new_mops(x,y,ay,rad,spr_)
 it = {}
	it.x = x --position
	it.y = y
	it.vx = 0 --velocity
	it.vy = 0
	it.ax = 0 --acceleration
	it.ay = ay
	it.spr = spr_ --current sprite (changes)
	it.base_spr = spr_ --0 rot sprite
	it.rad = rad --radius
	it.circ = 2 * 3.1416 * rad --circumference
	it.rot = 0 --rotation
	it.vrot = 0 --rotational velocity
	it.controllable = false
	it.visible = true
	it.t_limbo = 0 --counts up when dead
	it.t_respawn = 0 --counts up when created
	it.t_blink = 0 --counts up each time eyes close or open
	it.faces_left = false --for outro
	it.has_cane = false --for outro
 it.is_blinking = false
	it.is_dashing = false
	it.can_dash = true
	it.dash_dir = false
	it.dash_t = 0 -- timer for dash
	it.cooldown_t = 0 -- dash cooldown
	it.falls = false
	it.barks = false
	it.was_falling = false --last frame
	it.has_rot = 0 --has rotated this fall
	it.cont_rot_for = 0 --needs to rotate this much before breaking
	it.died_by_spike = false
	return it
end

function new_life(x,y)
 it = {}
 it.x = x --position
 it.y = y
 it.spr = 32
 it.rad = 3.5
 return it
end

function new_pckl(x,y)
 it = {}
 it.x = x --position
 it.y = y
 it.spr = 35
 it.rad = 3.5
 return it
end

function new_oma(x,y)
 it = {}
 it.x = x --position
 it.y = y
 it.h = 16 --body height pxl
 it.hx = x  --head position
 it.hy = y-13
 -- head bob
 it.bobs_head = true
 it.head_bob = 0 --offset y
 it.t_bob = 0 --timer head bob
 -- sprites
 it.spr_body = 96
 it.spr_head = 64
 it.spr_cane = 120
 it.spr_glas_org = 66 --glasses
 it.spr_glas = it.spr_glas_org
 it.spr_arm_d = 98   --down
 it.spr_arm_dl = 99  --down left
 it.spr_arm_l = 100  --right
 it.spr_arm_ul = 114 --up left
 it.spr_arm_u = 115  --up
 -- back (b) and front (f) arm
 it.spr_arm_b = it.spr_arm_dl
 it.spr_arm_f = it.spr_arm_d
 it.spr_arm_b_xoff=0--draw offset
 it.spr_arm_b_yoff=0
 it.spr_arm_f_xoff=0
 it.spr_arm_f_yoff=0
 return it
end

function new_sprite(x,y,_spr,rad,...)
 it = {}
 it.x = x --position
 it.y = y
 it.spr = _spr
 it.rad = rad
 -- optionally flip sprite
 opt_args = {...}
 it.flip_x = false
 it.flip_y = false
 if (opt_args[1]==true) it.flip_x = true
 if (opt_args[2]==true) it.flip_y = true
 return it
end

function new_cane(x,y,_spr,rad,ay)
 it = {}
 it.x = x --position
 it.y = y
 it.spr = _spr
	it.base_spr = _spr --0 rot sprite
 it.rad = rad --radius
	it.vx = 0 --velocity
	it.vy = 0
	it.ax = 0 --acceleration
	it.ay = ay
	--todo remove it.circ = 2 * 3.1416 * rad --circumference
	it.rot = 0 --rotation
	it.vrot = 0 --rotational velocity
	it.is_flying = false
	it.visible = true
 return it
end

function new_cloud(x_spawn,
                   y_spawn)
 -- width of cloud in circles
 minx = 3
 maxx = 5
 gap = 10 -- space btwn circles
 n_x = 3 + flr(rnd(maxx-minx+1))
 c = {} -- cloud
 c.gx = {} -- gray circle pos
 c.gy = {}
 c.wx = {} -- white circle pos
 c.wy = {}
 c.gr = {} -- circle radius
 c.wr = {}
 for y=1,n_x-1 do--layers from top
  xl = (n_x + 2 - 1.5*y) / 2
  for x=xl,xl+y do
   radc = rndi(5,11)-2+y
   gapc = gap+y
	  add(c.gx, x*gapc)
	  add(c.gy, y*gap)
	  add(c.gr, radc)
	  add(c.wx, x*gapc+rndi(2,3))
	  add(c.wy, y*gap+rndi(2,3))
	  add(c.wr, radc+rndi(2,2))
	 end
 end
 -- left-/right-most circ center
 c.left = 1.5*gap
 c.right = n_x*gap+gap -- todo
 c.bottom = (n_x-1)*gap+gap-5 -- todo
 c.vx = cloud_vx --velocity in x-dir
 c.vy = cloud_vy --velocity in y-dir
 c.x = x_spawn --x-pos on screen
 c.y = y_spawn --y-pos on screen
 return c
end

function update_platforms(flag)
 max_y = 0
 gone_pfs = {}
 -- if no platforms, create one
 if #pf == 0 then
 	first_x = (127-pf_w)/2
 	first_y = pf_dist + 59
  add(pf,new_platform(first_x,
 			first_y,pf_w,false))
	end
 -- loop through all platforms
 for p = 1,#pf do
 	-- get y of lowest platform
 	if pf[p].y > max_y then
 		max_y = pf[p].y
 		low_x = pf[p].x
 	end
 	-- mark platforms above screen
 	if pf[p].y < cam_y - 16 then
 	 add(gone_pfs,p)
 	end
 	-- remove ones close to ground
 	if pf[p].y > cam_y_end-8 and
 	   pf[p].y < cam_y_end+128+8 then
 	 pf[p].exists = false
  end
 end
 -- delete marked platforms
 for p in all(gone_pfs) do
  deli(pf,p)
 end
 -- if lowest platform on screen
 while (max_y < cam_y + 127) do
 	-- create one below
 	offset=rndi(-max_off,max_off)
 	new_x = low_x + offset
 	-- determine if will be spike
 	if flag == "no_spikes" then
 	 is_spike = false
 	elseif #pf_hist > 1 and
 			pf_hist[#pf_hist].kills and
 			pf_hist[#pf_hist-1].kills then
 		is_spike = false
 	else
	 	is_spike = rnd() <= p_spike
	 end
 	-- correct x if outside screen
 	if new_x < 0 then
 		new_x += 127 - pf_w
 	elseif new_x > 127 - pf_w then
 		new_x -= 127 - pf_w
 	end
 	-- create new platform
 	add(pf,new_platform(new_x,
 			max_y+pf_dist,pf_w,is_spike))
 	max_y += pf_dist
 end
end

function update_clouds()
 for i = 1,#clouds do
  --move cloud
  clouds[i].x += clouds[i].vx
  clouds[i].y += clouds[i].vy
  --in outro respawn when left
  --otherwise when above screen
  if state == "outro" then
   --if cloud is left of screen,
   --create new one on the right
   if clouds[i].x < -82 then
    y_tmp = clouds[i].y
    clouds[i] = new_cloud(130,y_tmp)
    clouds[i].vy = 0
   end 
  else
   --when cloud is above screen, 
   --create new one below screen
   if clouds[i].y < cam_y-70 then
    if last_cloud_was_left then
     clouds[i] = new_cloud(rndi(70,120),cam_y+2*70)
     last_cloud_was_left = false
    else
     clouds[i] = new_cloud(rndi(20,70),cam_y+2*70)
     last_cloud_was_left = true
    end
   end
  end -- if state == ...
 end
end
-->8
-- physics --------------------
function update_movement()
	--player movement
	if p1.is_dashing then
	 dash(p1)
	else
 	move(p1,max_vx_p,max_vy_p)
 	collision_platform(p1)
	end
	--check collisions
	if state == "play" then
 	collision_walls(p1)
 	collision_hilo(p1)
 	collision_life(p1)
 	collision_pckl(p1)
 end
	if state == "end" then
 	collision_walls(p1)
 end
 --handle cane physics
 if state == "outro" and
    cane.is_flying then
  move(cane,max_vx_p,max_vy_p)
  cane.rot += cane.vrot
	 if collision_ground(cane) then
	  cane.vx = 0
	  cane.vrot = 0
   cane.rot = 0.75
   cane.is_flying = false
   cane.x = flr(cane.x)
	 end
 end
 --check ground collision (game end)
	collision_ground(p1)
	--let's roll
	rotate(p1)
end

function move(t,max_vx,max_vy)
 -- update & limit velocity
 t.vx += t.ax
 t.vy += t.ay
 t.vx,t.vy=limit(t.vx,t.vy,
              max_vx,max_vy)
 -- move
 t.prevx = t.x --todo: needed?
 t.prevy = t.y
 t.x += t.vx
 t.y += t.vy
end -- move()

function dash(t)
 -- no acc
 t.x += t.vx
 t.y += t.vy
 t.dash_t += 1
 -- end dash
 if t.dash_t >= dash_time then
  t.dash_t = 0
  t.is_dashing = false
 	t.dash_dir = false
 	t.vx = 0
 	t.vy = max_vy_p
 end
end

function collision_walls(t)
 -- check collision with wall
 if t.x < t.rad then
  t.x = t.rad
  --todo: set v to zero?
  --pong: t.vx *= -0.9
  return true
 elseif t.x > 127 - t.rad then
  t.x = 127 - t.rad
  --todo: set v to zero?
  --pong: t.vx *= -0.9
  return true
 else
  return false
 end
end

function collision_hilo(t)
 -- check coll with floor
 if t.y > cam_y+127 + t.rad then
  handle_death()
  sfx(10,2)
  return true
 -- check coll with ceiling
	elseif t.y < cam_y - t.rad then
  --todo: ceil movable (top of camera view?)
  handle_death()
  sfx(10,2)
  return true
 else
  return false
 end
end

function collision_ground(t)
 -- check coll with ground
 if t.y >= ground_y - t.rad then
  -- reset movement variables
  t.y = ground_y - t.rad
  t.vy = 0
		t.falls = false
		t.has_rot = 0
		t.cont_rot_for = 0
		-- start outro animation
  if state == "end" then
   state = "outro"
			sfx(6,2)
			tim_start(t_outro)
			p1.controllable = false
  end
  return true
 end
 return false
end

function collision_platform(t)
	-- check collision w/ platforms
 t.was_falling = t.falls	
	t.falls = true
	for p = 1,#pf do
	 if pf[p].exists then
 		--todo: could jump up on pf if coming from side? -> check prevx?
 		yp = pf[p].y-1--platform top
 		xpl = pf[p].x+1 --pf left
 		xpr = pf[p].x+pf[p].w-2--right
 		ym = t.y+t.rad --mops bottom
 		xml = t.x-t.rad --mops left
 		xmr = t.x+t.rad --mops right
 		if ym>yp and ym<yp+3 and
 			  xmr>xpl and xml<xpr then
 			--todo:check if prevx was over in platform
 			t.y = yp - t.rad
 			t.vy = 0
 			t.falls = false
 			debug_brakes = false --todo: remove
 			t.has_rot = 0
 			t.cont_rot_for = 0
 			-- check if platform kills
 			if pf[p].kills then
 			 handle_death("spike")
 			 sfx(6,2)
 		 elseif t.was_falling then
 	   --sfx(8+flr(rnd(2)),2)
     sfx(9,2)
 			end
 		end
 	end --if pf[p].exists
	end --for p = 1,#pf
end --collision_platform()

function collision_life(t)
 l = life
 if l then 
  if t.x + t.rad > l.x - l.rad and
     t.x - t.rad < l.x + l.rad and
     t.y + t.rad > l.y - l.rad and
     t.y - t.rad < l.y + l.rad then
   life = false
   lives += 1
   life_collected += 1
   sfx(4,3)
  end
 end
end

function collision_pckl(t)
 d = pckl
 if d then 
  if t.x + t.rad > d.x - d.rad and
     t.x - t.rad < d.x + d.rad and
     t.y + t.rad > d.y - d.rad and
     t.y - t.rad < d.y + d.rad then
   pckl = false
   pickles += 1
   pckl_collected += 1
   sfx(5,3)
  end
 end
end

function rotate(t)
 -- rotate
 f_rot = fract(t.rot)
 vrot_0 = max_vx_p / t.circ
 if t.falls then
  -- assure rotation at beginning
  -- of fall (won't rotate if a
  -- single frame of movement led to fall)
  if t.was_falling == false and
     t.vrot == 0 then
   t.vrot = t.vx / t.circ
  end
  -- if fall just started and if
  -- < minrot rot until upright, 
  -- continue rolling (avoid very short rolls in air)
  minrot = 0.7 --rot minimum for (btw. 0 & 1)
  if t.was_falling == false then
   if t.vrot>0 then 
    if t.rot>0 and f_rot>1-minrot then
     t.cont_rot_for = 1-f_rot+0.05
    elseif t.rot<0 and f_rot<minrot then
     t.cont_rot_for = f_rot+0.05
    end
   elseif t.vrot<0 then
    if t.rot>0 and f_rot<minrot then
     t.cont_rot_for = f_rot+0.05
    elseif t.rot<0 and f_rot>1-minrot then
     t.cont_rot_for = 1-f_rot+0.05
    end
   end
  end
  -- brake rotation up to upright
  --(make sure it doesn't do less than 0.x rotations during fall)
  if t.has_rot>t.cont_rot_for then
   if t.vrot > 0.015 then --clockwise
    if (t.rot>0 and f_rot>1-minrot) or
       (t.rot<0 and f_rot<minrot) then
     -- > half-way to upright -> bremsweg (1-f_rot)
     t.vrot -= vrot_0*vrot_0/(2*minrot)
     debug_brakes = true 
    end
   elseif t.vrot < -0.015 then --counter-clockwise
    if (t.rot>0 and f_rot<minrot) or
       (t.rot<0 and f_rot>1-minrot) then
     -- > half-way to upright
     debug_brakes = true 
     t.vrot += vrot_0*vrot_0/(2*minrot)
    end
   else
    debug_brakes = false
    t.vrot = 0
    t.rot = 0
   end
  end
  t.has_rot += abs(t.vrot)
 else  -- (if not t.falls)
  t.vrot = t.vx / t.circ
 end
 t.rot += t.vrot
end

-->8
-- util and timers ------------
function limit(x,y,xlim,ylim)
 --limits vector to values
 if x > xlim then
  x = xlim
 elseif x < -xlim then
  x = -xlim
 end
 if y > ylim then
  y = ylim
 elseif y < -ylim then
  y = -ylim
 end
 return x, y
end

function rndi(min_i,max_i)
 -- random integer incl. min,max
 return min_i + flr(rnd(max_i-min_i+1))
end -- rndi()

function round(x)
 -- round to nearest integer
 if x > 0 then
  flr_x = flr(x)
  if x - flr_x > 0.5 then
   rounded = ceil(x)
  else
   rounded = flr_x
  end
 elseif x < 0 then
  if fract(x) > 0.5 then
   rounded = flr(x)
  else
   rounded = ceil(x)
  end
 else
  rounded = 0
 end
 return rounded
end -- round(x)

function fract(x)
 -- get fractional part of x
 abs_x = abs(x)
 integer_part = flr(abs_x)
 frc = abs_x - integer_part
 return frc 
end

-- pretty print
function pprint(string,x,y,col1,col2)
 --todo: get width and center align optionally
 color(col2)
 print(string, x-1, y+1)
 color(col1)
 print(string, x, y) 
end

function sleep(sec,interrupt_key)
 -- interrupt_key example: 🅾️
 was_interrupted = false
 while sec > 0 do
  if interrupt_key and
     btn(interrupt_key,0) then
   was_interrupted = true
   sec = 0
  end
  sec -= 1/fps
  flip() -- see manual
 end
 return was_interrupted
end
-- timers ---------------------
function new_timer(t)
 -- cumulative duration, updated
 -- w/ t_last_start at each
 -- restart/pause/start
 t = {}
 t.dur = 0
 t.start = time() --last start
 t.paused = true
 return t
end

function tim_start(t)
 if t.paused then
  t.start = time()
  t.paused = false
 end
end

function tim_pause(t)
 if not t.paused then
  t.dur += time() - t.start
  t.paused = true
 end
end

function tim_restart(t)
 if t.paused then
  dur_now = dur
 else
  dur_now = time()-t.start+t.dur
 end
 t.paused = false
 t.start = time()
 t.dur = 0
 return dur_now
end

function tim_dur(t)
 if t.paused then
  return t.dur
 else
  return time()-t.start+t.dur
 end
end

function tim_reset(t)
 t.dur = 0
 t.paused = true
end

-->8
-- input ----------------------
function handle_input()
	-- pause / play
	if btnp(🅾️,0) then
 	--todo: no pause during respawn => make respawn flag instead of state?
  if state == "intro" then
   --state = "pause" --todo title
  end
 	if state == "over" or
 	   state == "outro" then
 	 state = "restart"
 	end
		if state == "pause" then
			state = "play"
		elseif state == "play" then
			--state = "pause" todo: remove pause mode (menu -enter instead)
		end
		if state == "set" then
		 -- start game
			state = "play"
			--reserve channels 0-2 (binary:0111) for music, see manual
			if music_toggle then
			 music(0,nil,7)
			end
		end
	end
	-- player movement
 if p1.controllable then
  p1.cooldown_t -= 1
  if p1.cooldown_t <= 0 then 
   p1.cooldown_t = 0
   p1.can_dash = true
  end
  if not p1.is_dashing
     and p1.can_dash 
     and pickles > 0 then
   -- initiate dash
   if btn(❎,0) and p1.falls
      and state == "play" then
    p1.is_dashing = true
    sfx(3,2)
    --omnidirectional dash removed in v0.1.1
    p1.dash_dir = "down" --todo: can be removed
    p1.vx = 0
    p1.vy = v_dash
    pickles -= 1
    p1.can_dash = false
    p1.cooldown_t = dash_cooldown
    puff = new_sprite(p1.x,p1.y-5,puff_spr,3.5)
    tim_start(t_puff)
   end --if btn(❎,0)
  end --if not p1.is_dashing
	 -- accelerate x
	 if not p1.is_dashing then
 	 if (btn(⬅️,0) and 
 	 	  not btn(➡️,0)) then
 	  p1.vx=-max_vx_p
 	 elseif (btn(➡️,0) and
 	 	  not btn(⬅️,0)) then
 	 	p1.vx=max_vx_p
 	 else
 	  p1.vx = 0
 	 end
 	end
 	--also start game if not running
 	if state == "set" then
 	 --if (btn(⬅️,0) and 
 	 --	  not btn(➡️,0)) then
			-- state = "play"
 	 -- p1.vx=-max_vx_p
 	 --elseif (btn(➡️,0) and
 	 --	  not btn(⬅️,0)) then
			-- state = "play"
 	 --	p1.vx=max_vx_p
 	 --else
 	  p1.vx = 0
 	 --end
 	end
	end -- if p1.controllable
 -- decelerate / stop x
 if not (btn(⬅️,0) or btn(➡️,0))
    or not p1.controllable then
  if abs(p1.vx) > 0.5 then
	  p1.ax = -sgn(p1.vx) * 1
	 else
	  p1.ax = 0
	  p1.vx = 0
	 end
 end
 -- debug todo: remove
 if debug then
 -- if btn(❎,0) then
 -- 	deli(pf,1)
 -- end
 -- if btn(⬆️,0) then
 --  p1.rot += 0.01
 -- end
 end
 if btn(❎,0) and state== "pause" then
  --debug: pause after single frame
  --todo: remove!
  state = "play"
  debug_single_frame = true
 end
end
-->8
-- game state -----------------
function handle_death(cause)
	-- update lives
	deaths += 1
	if lives > 0 then
		lives -= 1
		state = "limbo"
		hart = new_sprite(p1.x,p1.y-1,hart_spr,3.5)
  tim_start(t_hart)
	else
	 -- game over
	 state = "over"
	 music(-1)
	 if height < highscore then
	  dset(0, height)
	 end
 	puff = false
	 soul = new_sprite(p1.x,p1.y,soul_spr,p1.rad)
	end
	-- remove current mops
	p1.controllable = false
	if cause and cause=="spike" then
	 --todo stretch out over mult. frames (3?)
	 p1.y += 2 -- impaled!
	 p1.died_by_spike = true
  update_sprite_mops(p1)
	else
 	p1.visible = false
 end
end

function handle_respawn()
 p1.t_limbo += 1
 -- wait min_frames_limbo
 if p1.t_limbo > min_frames_limbo then
 	-- find safe platform
 	-- but not the lowest ones
 	if not pf[#pf-1].kills and
 	   pf[#pf-1].y < cam_y_end-20 then
  	start_x = pf[#pf-1].x+pf_w/2-rad_p
  	start_y = pf[#pf-1].y-rad_p
  	--create new mops, respawn
  	p1 = new_mops(start_x,start_y,
  			ga,rad_p,base_spr_p)
   p1.visible = false
   add(mops, p1)
   state = "respawn"
  end
 end
 -- countdown respawn animation
 if state == "respawn" then
  p1.t_respawn += 1
  if p1.t_respawn > frames_respawn then
  	p1.controllable = true
  	p1.visible = true
   state = "play"
  end
 end
end --handle_respawn()

function handle_end()
 if state ~= "end" then
  height = 0
  cam_y = cam_y_end
  --stop cloud movement in y-dir
  for i = 1,#clouds do
   clouds[i].vy = 0
  end
  if state == "limbo" or
     state == "respawn" then
  	p1 = new_mops(30,
  	  ground_y - 130,
  			ga,rad_p,base_spr_p)
   add(mops, p1)
  end
  state = "end"
  --update highscore
  dset(0, height)
 end
end --handle_end()

function create_life()
 	if not pf[#pf].kills then
  	life_x = pf[#pf].x+pf_w/2
  	life_y = pf[#pf].y-rad_p
  	life = new_life(life_x,life_y)
  	need_life = false
  end 
end

function create_pckl()
 	if not pf[#pf].kills then
  	pckl_x = pf[#pf].x+pf_w/2
  	pckl_y = pf[#pf].y-rad_p
  	pckl = new_pckl(pckl_x,pckl_y)
  	need_pckl = false
  end 
end

function update_level()
 --increase difficulty (level)
 if level <= #levels and
    score > levels[level] then
  level += 1
  speed = speeds[level]
 end
 --generate lives
 if i_life_spawn <= #life_spawn and
   score > life_spawn[i_life_spawn] then
  i_life_spawn += 1
  need_life = true
 end
 --generate pickles
 if i_pckl_spawn <= #pckl_spawn and
   score > pckl_spawn[i_pckl_spawn] then
  i_pckl_spawn += 1
  need_pckl = true
 end
end

function restart()
 initialize(false)
 p1.y = pf[1].y-rad_p-1
 cam_y = cam_y_set
	camera(0,cam_y)
 state = "set"
 p1.controllable = true
	if music_toggle then
  music(63)
 end
 -- todo: set title to "set" position
end
-->8
-- animation ------------------
function update_animation()
 -- puff
 if puff and
    tim_dur(t_puff)>=dur_puff then
  tim_restart(t_puff)
  --if state == "play" then --todo: animation timer paused when "puase"?
   if puff.spr < puff_spr+4 then
    puff.spr += 1
   else
    puff = false
    tim_reset(t_puff)
   end
  --end
 end
 -- breaking heart
 if hart then
  hart.y -= 0.5 --move up
  if hart.spr == hart_spr then
   --delay breaking
   dur_tmp = 2 * dur_hart
  else
   dur_tmp = dur_hart
  end
  if tim_dur(t_hart)>=dur_tmp then
   tim_restart(t_hart)
   --if state == "play" then --todo: animation timer paused when "puase"?
   if hart.spr < hart_spr+3 then
    hart.spr += 1
   else
    hart = false
    tim_reset(t_hart)
   end
  end
 end
 if state == "play" or
    state == "outro" then
  -- blinking
  p1.t_blink += 1
  if not p1.is_blinking and
    p1.t_blink>lat_blink then
   p1.is_blinking = true
   p1.t_blink = 0
  elseif p1.is_blinking and
         p1.t_blink>dur_blink then
   p1.is_blinking = false
   p1.t_blink = 0
   lat_blink = (0.5+rnd(4)) * fps
  end
 end
 -- animate oma
 oma.t_bob += 1
 if oma.t_bob > lat_head_bob then
  if oma.bobs_head == true then
   if oma.head_bob == 1 then
    oma.head_bob = 0
   else
    oma.head_bob = 1
   end
  end
  oma.t_bob = 0
 end
end

function animate_outro()
 t_cur = tim_dur(t_outro)
 if t_cur > 15 then
  --	
 elseif t_cur > 14.5 then
  --give cane
  p1.has_cane = false
  cane.visible = true
  cane.x = oma.x-4
  cane.y = oma.y-oma.h+8
  cane.rot = 0
  oma.spr_arm_b=oma.spr_arm_dl
  --move away a bit
  if p1.x > mops_x_final-10+max_vx_p then
   tim_pause(t_outro)
   p1.vx = -max_vx_p
  else
   tim_start(t_outro)
   p1.x = mops_x_final-10
   p1.vx = 0
   p1.ax = 0
  end
 elseif t_cur > 13.5 then
  --return cane
  if p1.x < oma.x - 1 then
   tim_pause(t_outro)
   p1.vx = max_vx_p
  else
   tim_start(t_outro)
   p1.x = oma.x - 1
   p1.rot = 0
   p1.vx = 0
   p1.ax = 0
  end
 elseif t_cur > 11.6 then
  if oma.bobs_head == false then
   oma.bobs_head = true
   oma.t_bob = 0
		end
  oma.spr_arm_b=oma.spr_arm_d
  --fetch cane
  if p1.x > cane.x + 4 then
   tim_pause(t_outro)
   p1.vx = -max_vx_p
  else
   tim_start(t_outro)
   p1.x = cane.x + 4
   p1.vx = 0
   p1.ax = 0
  end
  if t_cur > 12 then
   p1.rot = 0
  end
  --grab cane
  if t_cur > 12.5 then
   cane.visible = false
   p1.has_cane = true
  end
 elseif t_cur > 9.5 then
  --move arm to pet
  if t_cur > 11.1 then
   oma.spr_arm_b_yoff = 0
  elseif t_cur > 10.8 then
   oma.spr_arm_b_yoff = 1
  elseif t_cur > 10.5 then
   oma.spr_arm_b_yoff = 0
  elseif t_cur > 10.2 then
   oma.spr_arm_b_yoff = 1
  elseif t_cur > 9.9 then
   oma.spr_arm_b_yoff = 0
  elseif t_cur > 9.6 then
   oma.spr_arm_b_yoff = 1
  end  
 elseif t_cur > 8 then
  hart_oma = false
  --roll towards oma
  if t_cur > 8.6 then
   if p1.x < oma.x-1 then
    p1.x += 0.3
    p1.rot = 0
   else
    p1.x = oma.x-1
    p1.vx = 0
    p1.ax = 0
   end
  end
  --arms down
  if t_cur > 8.5 then
   oma.spr_arm_f=oma.spr_arm_d
  elseif t_cur > 8.4 then
   oma.spr_arm_f=oma.spr_arm_dl
   oma.spr_arm_b=oma.spr_arm_dl
   oma.spr_arm_f_yoff = 0
   oma.spr_arm_b_yoff = 0
  elseif t_cur > 8.3 then
   oma.spr_arm_f=oma.spr_arm_l
   oma.spr_arm_b=oma.spr_arm_l
   oma.spr_arm_f_yoff = -1
   oma.spr_arm_b_yoff = -1
  elseif t_cur > 8.2 then
   oma.spr_arm_b=oma.spr_arm_ul
  end 
 elseif t_cur > 6 then
  --both arms up
  oma.head_bob = 0
  oma.bobs_head = false
  if t_cur > 6.4 then
   --oma.spr_arm_f=oma.spr_arm_u
   oma.spr_arm_b=oma.spr_arm_u
  elseif t_cur > 6.3 then
   oma.spr_arm_f=oma.spr_arm_ul
   oma.spr_arm_b=oma.spr_arm_ul
   oma.spr_arm_f_yoff = -2
   oma.spr_arm_byoff = -2
  elseif t_cur > 6.2 then
   oma.spr_arm_f=oma.spr_arm_l
   oma.spr_arm_b=oma.spr_arm_l
   oma.spr_arm_f_yoff = -1
   oma.spr_arm_b_yoff = -1
   --throw cane
   cane.vx = -1.8
   cane.vy = -1.8
   cane.vrot = 0.04
   cane.is_flying = true
  elseif t_cur > 6.1 then
   oma.spr_arm_f=oma.spr_arm_dl
   oma.spr_arm_b=oma.spr_arm_dl
  end
  --heart above head
  if not hart_oma then
   hart_oma = new_sprite(oma.hx+7,oma.hy-oma.h+9,hart_spr,3.5)
  end
  if t_cur > 6.2 and t_cur < 7 then
   hart_oma.y -= 0.3
  end
 elseif t_cur > 5 then
  --move arm down
  if t_cur > 5.5 then
   oma.spr_arm_f=oma.spr_arm_d
   oma.spr_arm_f_yoff = 0
  elseif t_cur > 5.4 then
   oma.spr_arm_f=oma.spr_arm_dl
   oma.spr_arm_f_yoff = 0
  elseif t_cur > 5.3 then
   oma.spr_arm_f=oma.spr_arm_l
   oma.spr_arm_f_yoff = -1
  elseif t_cur > 5.2 then
   oma.spr_arm_f=oma.spr_arm_ul
   oma.spr_arm_f_yoff = -2
  end
 elseif t_cur > 4 then
  --adjust glasses
  oma.head_bob = 1
  oma.bobs_head = false
  if t_cur > 4.8 then
   oma.spr_glas = oma.spr_glas_org
  elseif t_cur > 4.6 then
   oma.spr_glas = oma.spr_glas_org+16
  elseif t_cur > 4.4 then
   oma.spr_glas = oma.spr_glas_org
  elseif t_cur > 4.2 then
   oma.spr_glas = oma.spr_glas_org+16
   --start end music
   if not end_music_playing and
      music_toggle then
    music(22)
    end_music_playing = true
   end
  end
 elseif t_cur > 3 then
  --head down
  oma.head_bob = 1
  oma.bobs_head = false
  --move arm up to glasses
  if t_cur > 3.8 then
   oma.spr_arm_f=oma.spr_arm_u
   oma.spr_arm_f_yoff = -2
  elseif t_cur > 3.6 then
   oma.spr_arm_f=oma.spr_arm_ul
   oma.spr_arm_f_yoff = -2
  elseif t_cur > 3.4 then
   oma.spr_arm_f=oma.spr_arm_l
   oma.spr_arm_f_yoff = -1
  elseif t_cur > 3.2 then
   oma.spr_arm_f=oma.spr_arm_dl
  end
 elseif t_cur > 2.5 then
  --bark
  if t_cur < 2.6 then
   if not p1.barks then
    sfx(10)
    p1.barks = true
   end
  elseif t_cur > 2.8 and
         t_cur < 2.9 then
   if not p1.barks then
    sfx(10)
    p1.barks = true
   end
  else
   p1.spr = 7
   p1.barks = false
  end
 elseif t_cur > 2 then
  --look up
  --p1.rot = 0.875
 elseif t_cur > 1.5 then
  --rotate upright
  --todo: right dir from anti_end
  rot_end = 0.875
  anti_end = fract(rot_end+.5)
  if fract(p1.rot) < rot_end+.05 and
     fract(p1.rot) > rot_end-.05 then
   --already upright
   p1.rot = rot_end
   tim_start(t_outro)
  else
   --todo: fix (see above)
   if p1.rot>0 then
    p1.rot += 0.025
   else
    p1.rot -= 0.025
   end
   tim_pause(t_outro)
  end
 elseif t_cur > 1 then
  --roll to correct position
  if p1.x < mops_x_final-max_vx_p then
   tim_pause(t_outro)
   p1.vx = max_vx_p
  elseif p1.x > mops_x_final+max_vx_p then
   tim_pause(t_outro)
   p1.vx = -max_vx_p
  else
   tim_start(t_outro)
   p1.x = mops_x_final
   p1.vx = 0
   p1.ax = 0
  end
 end
end
__gfx__
cc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4704cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cc
c470470cc444704cc444444cc444444cc444444cc444044cc704444cc440044cc444444cc444044cc444444cc444444cc444444cc444044cc404444cc444004c
44004004444400444404470444440444440400444440444440044044470444444400400444440044440440444444044444080044404084444404404444044444
44444444440444704404400440404444444044447044044444440444400440444444444444044444440440444080444444404444404404444444084440044044
44440444444044004440444444044704444444440044404447044044444404044444044444404404448044444404400444444444444440444404404444440804
44004044444404444404470444444004470470444470444440044044444044444400804444480404440440444444404440040044440044444404404444404444
c444444cc440444cc444400cc447044cc004004cc400444cc444444cc444444cc444444cc440444cc444404cc400444cc444444cc440444cc444444cc444444c
cc4444cccc4444cccc4444cccc4004cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cc
555cc55555555555555555ccc9ccc9ccc9ccc9ccc9ccc9cccccccccccccccccccc7776ccc67c766c6c6ccc66ccccccccccccccccc88888cccccccccccccccccc
c5555555555555555655505cc9ccc9ccc9ccc9ccc9ccc9ccccccccccccc766ccc77776776777cc66c6cccccccccccccccc444ccc8800888ccccccccccccccccc
cc5555555555555555655555c9ccc9ccc9ccc9ccc9ccc9cccccccccccc77767c77776676c767c6ccccc6c6c6cc44ccccc47447cc8808088c050000500000cccc
c555d555555555555655555dc9ccc9ccc9ccc9ccc9ccc9ccccccccccc777677c77777776c7c677c6c6ccc6ccc4040ccc4404404c8800888c0000c0000ccccccc
555ccdddddddddddddddddcc999c999c999c999c999c9999ccc666cccc7777ccc677767c667cc67ccc7c6ccc444444cc4444444c8808088cc00ccc00cccccccc
cccccccccccccccccccccccc999999999999999999999999cc6766cccc6776cccc6776cccc6776cccccccccc440044cc4400044c8800088ccccccccccccccccc
ccccccccccccccccccccccccc9999999999999999999999ccc6666cccc6766cccc6766cccccc6cccccccccccc4444cccc44444ccc88888cccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccc66cccccc66cccccc66ccccccccccccccccccccc44cccccc444ccccccccccccccccccccccccccc
ccccccccc88cc88ccccccccccccccccccccccccccc4704cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccbbbbbcccccccccccccccccc
c88cc88c87888888ccccccccccccccccccccccccc440044ccbbbcccccccccccccccccccccccccccccccccccccccccccccc444cccbb000bbcc5000050000ccccc
8788888888888888cccccccccbccccbccccccccc47044444bb3bcccccc8c8cccc8ccc8cccccccccccccccccccc747cccc470470cb0bbb0bcc000c0000cc0cccc
8888888888888888cbccccbcb3bccbbbc8c8cccc40044044bbbcccccc87888cc878cc88c8cccc88ccccccc8cc4040ccc4400400cb00000bccc0ccc00cccccccc
8888888828888882b3bccbbbbbbbb3bb87888ccc44440004b3bcccccc88888cc88cc888c88ccc8888cccc8c8444444cc4444444cb0bbb0bccccccccccccccccc
c888888cc288882cbbbbb3bbbb3bbbb388888ccc44400844bbbbcccccc888cccc88cc8ccc8cc888ccccccc8c440044cc4400044cbbbbbbbccccccccccccccccc
cc8888cccc2882cccb3bbbbccbbbbb3cc888ccccc444444ccbb3bcccccc8cccccccc8cccccccccccccccccccc4444cccc44444cccbbbbbcccccccccccccccccc
ccc88cccccc22cccccbbbbcccc3333cccc8ccccccc4444ccccbbcccccccccccccccccccccccccccccccccccccc44cccccc444ccccccccccccccccccccccccccc
cc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444ccccffffcccc4444cccccccccccc4444cccc4444ccc00000ccc00000cccccccccc
c444444cc444044cc444444cc444444cc444444cc444044cc404444cc444004ccffffffcc444444ccc77777cc470470cc470470c0000000c0000000ceeeceeec
4400400444440044440440444444044444040044404044444404404444044444ff55f55f44444444c777777744004004440040040770770c0770070ceaaaeaea
4444444444044444440440444040444444404444404404444444044440044044ffffffff44444444c777b77744444444444444440707070c0707070ceaeceaea
4444044444404404444044444404400444444444444440444404404444440404ffff5fff44444444c777777744440444444404440700070c0700770ceaaaeaea
4400404444440404440440444444404440040044440044444404404444404444ff55f5ff44444444cc77777c44008044440080440000000c0000000ceaeaeeea
c444444cc440444cc444404cc400444cc444444cc440444cc444444cc444444ccffffffcc444444cccccccccc444844cc444444cc00000ccc00000cccaaacaaa
cc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444ccccffffcccc4444cccccccccccc4444cccc4444cccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc333333333333333b33333333333333333333666666665663cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccc333377333333b3b3333333333333333333666656655666633333ccccccccccccccccccccccccccccccccccccccc33333
ccccccc6666ccccccccccccccc99cccc3337aa7333333bb3333333333333333366666666666666333333333ccccccccccccccccccccccccccccccc3333333333
cccccc666666ccccc999999999cccccc3337aa7333333bb3333333333333333666655666666663333333333333cccccccccccccccccccccccc33333333333333
ccccccddd666ccccc99cc9ff9ccccccc333b77bb33333bb333333333333333666665666666663333333333333333cccccccccccccccccccc3333333333333333
cccccc666d6ccccccccccc99cccccccc3333bb33333333333333333333333666666666655666333333333333333333cccccccccccccccc333333333333333333
cccc6ddd666ccccccccccccccccccccc33333b3333333333333333333333666666666666566333333333333333333333ccccccccccc333333333333333333333
ccc66666d666cccccccccccccccccccc33333b3333333333333333333336655666555666666333333333333333333333333ccccc333333333333333333333333
ccfff6666666cccccccccccccccccccc333333333333333333333333336656666666566666333333cccccccccccccccccccccccccccccccccccccccccccccccc
cffffffff666cccccccccccccccccccc3333333333b3333333333333366666666666666666333333ccccc77777cccccccccc6cc6cccc6ccccccc70cccc0ccccc
cf0fff0fffffccccc99999999999cccc33333333333b333333333333366666666666666666333333ccc777777777cccccccc6c66ccc66cccc0c9090ccc700ccc
cffffffffffffcccc99cc9ff9ccccccc3333b333333b333333333333666666666666666666333333cc77777777777ccccccc6c66ccc66ccccc00999ccc990ccc
cfffffffffffcccccccccc99cccccccc33b3b3333333333333333333666655566666665556333333c777777b777777cccccc6666ccc66cccccc099ccccc990cc
ccfffffffffccccccccccccccccccccc333b33333333333333333336666556666666556656333333c7777777777677ccccccc66cccc66ccccccc0ccccccccccc
ccccfffffccccccccccccccccccccccc333b33333333333333333336666666666666566666333333c7776777776777ccccccc66cccc66ccccccccccccccccccc
cccccccccccccccccccccccccccccccc333333333333333333333366666666666666666666333333cc77766666777cccccccc66ccccc6ccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccc0000000033333366666666666666666666333333ccc777777777ccccccccc44cccc44ccccccccccccccccccc
cccccc22222cccccccccc55cccccc55ccccccccc0000000033333666666666666566666666333333ccccc77777ccccccccccc44cccc44ccccccccccccccccccc
ccccc2222222cccccccc5555cccc5555cc55555c0000000033333666666666655656666666333333ccccccccccccccccccccc44cccc44ccccccccccccccccccc
cccc222222222ccccccc5555ccc55555cf5555550000000033336666665566666666666666333333ceceeeceeeceeeccccccc44cccc44ccccccc6ccccccccccc
cccc2222222222cccccc5555cc55555ccf5555550000000033336666655656666666665556333333ceceeecececececcccccc44cccc44cccccc09cccccc06ccc
cccc2222222222cccccc5555ccf555cccc55555c0000000033336666556666666666655666333333cecececeeeceeeccccccc44cccc44ccccccccccccccccccc
ccc222a2222222cccccc5555ccff5ccccccccccc0000000033366666666666666666666666333333cececececececcccccccc44cccc44ccccccccccccccccccc
ccc222222222222ccccccffccccccccccccccccc0000000033366666666666666666666666633333cccccccccccccccccccccccccccccccccccccccccccccccc
ccc222222222222ccccccccccccccffc33366666666666666655666666633333cccccccccccccccccccccccccccccccccccc9ccccccccccccccccccccccccccc
ccc2222a2222222cccff5ccccccc555533366666555566666556566666633333ccc9cccccccc9cccccccccccc9cccccccccc9ccccccccc9ccc9ccccccccc9ccc
ccc222222222222cccf555cccccc555533366665566556666566656666633333ccc9999cccc99ccccccccccccc9ccccccccc9cccccccc9cccc9cccccccc9cccc
ccc222222222222ccc55555ccccc555533666665666666666666655666663333cccc9ccccccc99ccccccc99cccc9c9cccccc9cccc9cc9ccccc999999c999cccc
ccc222222222222cccc55555cccc555533666656666666666666666666663333cccc9cccccc9cc9c999999cccccc999ccccc9ccccc99ccccc99ccccccc9c9ccc
ccccc77cccc77ccccccc5555cccc555533666666666655555666666666666333cccc9ccccc9cccccccccc9cccccc9ccccc9999ccccc99cccccccccccccccc9cc
cccc0000cc0000ccccccc55cccccc55c33666666666656665566666555666333cccc9cccc9ccccccccccc9ccccc9ccccccccc9ccccc9cccccccccccccccccc9c
ccc000c0c000c0cccccccccccccccccc36666666666666666666665666556333cccc9ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc4444cccc4444cccc4444cccc4494cccc4444cccc4444cccc4449cccc4704cccccccccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbcc
c470470cc444704cc944444cc449944cc444499cc494444cc704494cc440044ccccccccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc
4400400444940044499947044444994499999944444944444004494447044494ccccccccccccccccccccccccccccccbbbb3bbbbbbb3bbbb3bbbbbbbbbbbbbbbb
4444444499944470449440044449444444404944704494944444094440044944ccccccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3bbb
4494044449494400449044444494470444444444004449994704494444449444cccccccccccbbbbbbbcccccccccbbbbbbbbbbbbb3bb3bbbbbbbbbbb3b3bbbbbb
4499999944449444449447044944400447047044447049444004999444994444cccccccccbbbbbbbbbbcbbccccbbbbbbbbbbbbbbbbb3bbbbbbbbbbbbbbbbbbb3
c994444cc444494cc494400cc447044cc004004cc400444cc444449cc449944ccccccccbbbbbbbbbbbbbbbbcccbbbb3bbbbbbb3b3bb3cbbbbbbbbbbbbbbb333b
cc4444cccc4444cccc9444cccc4004cccc4444cccc4444cccc4444cccc4944ccccccccbbbbbbbbbbbbbbbbbccbbbbbbbbbbbbbbbbb3cccbbbbb3bbbbb33cccbb
cccccccccccccccccccccccccccccccccccccccccccccccccccccccc00000000cccccbbbbb3bbbbbbbbbbbbbcbbbbbbbbb3bc333344cccccbbbbb333cccccbbb
cccccccccccccccccccccccccccccccccccccccccccccccccccccccc00000000cccccbbbbbbbbbbb3bbbbbb3cbbbbbbbbbbbccccc4445cccc3333cccbbccbbb3
cccccccccccccccccccccccccccccccccc7c77ccccc77cccccc7cccc00000000ccccbbbbbbbbbbbbbbbbb3b3cbbbbbb3bbb3bbccccc4445bbc445ccbbb3bbbbb
ccccccccccccccccccccccccccccccccc677777ccc7777cccc677ccc00000000ccccbbbbbbbbbbbbbb3bbbb3cbb3bbbbbbb3bbbbcccc4444bb445ccbbb3bbbbb
ccccccccccccccccccccccccccccccccc677777ccc6776ccccc67ccc00000000cccbbbbbbbbb3bbbbb3bbbb3ccbbbb3bbbb3bbbbb44444445b4445ccb5bbbbbb
cccccccccccccc444444444ccccccccccc6777ccccc67ccccccccccc00000000cccbbbbbbbbbbbbbb3bb3b3cccbbbbbb3b3bbb3bb3444444444445cc44bbbbbb
cc4444444444444444454444ccccccccccc66ccccccccccccccccccc00000000cccbbbb3bbbbbb3bb3bbbb3ccccbbbbbbb3bbbbbb5ccc554444445ccc4bbb3bb
c24454444444444444444444cccccccccccccccccccccccccccccccc00000000cccbbbbbbbbbbbbb3bbbb3cbbcccbbbbb3bbb3bbbccc5444444445ccc4bbbbbb
c24444444444444444445444cccccccccccccccccccccccccccccccc00000000cccbbbbbb3bbb3b3ccbb5cbbb3ccc4b3cbbbbbbb3cccc554444444cc44bbbbbb
c24444444444444444444444cccccccccccccccccccccccccc677ccc00000000ccccbbbbbbbbbb3ccc45ccc3344c44cccccbbb33cccccccc4444444c444bbbbb
cc244544444444444ccc67cccccccccccc7777ccc777c77cc67777cc00000000ccccbbbbbbbbb3444c45ccbbbc4445cccccccccccccccccc44444444444bbbbb
cc2444444444cccccccc44444cccccccc677777c67777777c777777c00000000cccccbbb3bbb35444445cbbbbbc45cccccccccccccccccccc44444444445bbbb
ccc4467ccccccccc44444544444cccccc677777c677777776777677c00000000ccccccbbbbb33ccc5444cb3bb3c45cccccccccccccccccccc44444444445cbbb
ccccc67cc4444444444444454444cccccc67776cc677777c6777c66c00000000cccccccc333cccccc5444bbb3c444cccccccccccccccccccc4444444445ccc4b
cc44444444444444444444444222ccccccc666cccc6666ccc66ccccc00000000ccccccccccccccccccc5444444444444ccccccccccccccccc444444445cccc45
cc24445444444444444222222ccccccccccccccccccccccccccccccc00000000ccccccccccccccccccccc55544444444444444cccccccccc4444444445ccc445
ccc2444444444422222cc667cccccccccccccccc00000000cccccccccccccccbbbbbccccccccccccccccccccc5555444444444445ccccccc4444444445cc445c
cccc2444542222ccccccc667cccccccccccccccc00000000cccccccccccccbbbbbbbbbbbcccccccccccccccccccccc5544444444445ccccc4444444445c444cc
ccccc22222ccccccccccc667cccccccccccccccc00000000cccccccccccbbbbbbbbbbbbbbcccccccccccccccccccccccc554444444445cbb44444444444445cc
cccccc6667cccccccccccc67ccccccccccc677cc00000000cccccccccccbbbbbbbbbb3bbbbbccccccccccccccccccccccccc54444444445b5554444444445ccc
cccccc6667cccccccccccccccccccccccc67777c00000000ccccccccccbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccc55444444444445544444445cccc
cccccc6667cccccccccccccccccccccccc67776c00000000cccbbbbcccbbb3bbbbbbbbbbbbbbbcccccccccccccccccccccccccc55444444444454444445ccccc
ccccccc667ccccccccccccccccccccccccc666cc00000000ccbbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccccccccccccccccccccccc54444444445444445cccccc
cccccccccccccccccccccccccccccccccccccccc00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccc544444445444445cccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc4444444444445cccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc444454444445cccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc444444444445cccccc
ccccccccccc8888cccccccccccccccccc8888cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44444444444cccccc
ccccccccc88cccc8cccccccccccccccc88cc8cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44444444445cccccc
cccccccc8ccccccc8ccccccccccccccc8ccc8cc888ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc444444444545ccccc
cccccccc8cccccccc8cccccccccccccc8ccc8c8ccc8ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44444444544ccccc
cccccccc8cccccccc8cccccccccccccc8ccc8c8ccc8ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44444444444ccccc
cccccccc8ccccccccc8ccccccccccccc8ccc8c8ccc8ccccccccccccccccccccccccccccccccccccccccccccccc8ccccccccccccccccccccc4444444445cccccc
cccccccc8ccccccccc8ccccccccccccc88c8cc8ccc8ccccccccccccccccccccccccccccccccccccccccccccccc88ccccccccccccccccccccc444444445cccccc
cccccccc8ccccccccc8cccccccccccccc88ccc8ccc8cccccccccccccccccccccccccccccccc88cc88888cccccc88ccccccccccccccccccccc444444445cccccc
ccccccc8ccccccccc8ccccccccc88cccc88ccc8ccc8cccccc88ccccccccccccccccccccccc88c888ccc8cccccc888cccccccccccccccccccc444444445cccccc
ccccccc8888888888cccccccc88888ccc8cccc8ccc8cccc88c8ccccccccccccccccccccccc8cc88ccccc8ccccc8c88c888ccccccccccccccc444444445cccccc
ccccccc8cccc88cccccccccc8cccc888888cccc8cc8cccc8ccc88888ccc88cccccccccccc8ccc88ccccc8ccccc8cc888c88cccccccccccccc444444445cccccc
ccccccc8cccccc8cccccccc88cccc8cccc8cccc8cc8ccc88ccc88ccc8c8888cccccc888888cccc8ccccc8cccc88ccccccc8cccccccccccccc4444444445ccccc
ccccccc8ccccccc8ccccccc8cccc88cccc8ccccc8c8ccc8cccc88ccc888cc8ccccc8cc888ccccc8ccccc8cccc8cccccccc88ccccccccccccc4444444445ccccc
ccccccc8ccccccc8cccccc8ccccc8ccccc8ccccc88cccc8cccc88ccc88cccc8ccc8cccc8cccccc88cccc8cccc8ccccccccc8ccccccccccccc44444444445cccc
ccccccc8cccccccc8ccccc8ccccc8ccccc8ccccc88ccc88ccccc8cccc8cccc8ccc8cccc8cccccc88cccc8ccc8cccccccccc8cccccccccccc444444444445cccc
ccccccc8cccccccc8ccccc8cccc8ccccccc8cccc88ccc8cccccc8cccc8cccc8ccc8ccccc8ccccc88cccc8cc88cccccccccc8cccccccccccc4444444444445ccc
ccccccc8cccccccc8ccccc888cc8ccccccc88ccc888cc8cccccc8cccc8cccc8ccc8ccccc8ccccc88ccc88cc8cccccccccc88cccccccccccc44444444444445cc
cccccc8ccccccccc8ccccccc8888cccccccc8ccc8c8888cccccc88ccc8ccccc8cc8cccc88ccccc88ccc88888cccccccccc8cccccccccccc4444444443444445c
cccccccccccccccc8888cccc88cccccccccc88cc8ccccccccccc88ccc8ccccc88c8cccc8cccccc888cccc88cccccccccc8ccccccccccccc44444443434444445
cccccccccccccccccccc8888cccccccccccccc88ccccccccccccc8ccc8cccccc8888cc8cccccccc88ccccccccccc888888cccccccccccc444444444344444444
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8888cccccccc88ccccccccc888cccccccccccccccc4444444443355544444
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8ccccccccccccccccccccccccccc44444444444ccccc4444
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8ccccccccccccccccccccccccc44444555c4444ccccccc44
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8cccccccccccccccccccccccc44455ccccc44445ccccccc4
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8cccccccccccccccccccccccc45ccccccccc4445cccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc88cccccccccccccccccccccccccccccccccccc4445ccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8cccccccccccccccccccccccccccccccccccccc445ccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc45ccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc5cccccccc
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccc677ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc67777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccc67776cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc77cccccccccccccccccccccccc666ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccc6776cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccc67cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc677777cccccccccccccccccccccccccc7ccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc677777ccccccccccccccccccccccccc677cccccccccccccccccc
ccccccccccccccccccccc6666cccccccccccccccccc6666cccccccccccccccccccccccccccccc67776cccccccccccccccccccccccccc67cccccccccccccccccc
ccccccccccccccccccc6677777cccccccccccccccc677777cccccccccccccccccccccccccccccc666ccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccc677777777cccccccccccccc6777777c666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccc67777777777cccccccccccc6777777767777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccc6777776677777ccccccccccc67777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccc67776cccc7777ccccccccccc67776777777777cccccccccccccccccccccccccccccccccccccccccccccc6ccccccccccccccccccccccccccc
cccccccccccccccc6777ccccc67777cccccccccc67776777776777cccccccccccccccccccccccccccccccccccccccccccccc77cccccccccccccccccccccccccc
cccccccccccccccc6777cccccc7777cccccccccc67777777776777ccccccccccccccccccccccccccccccc66cc66666cccc67777ccccccccccccccccccccccccc
cccccccccccccccc6777cccccc6777ccccccc66c67777777776777ccccc66ccccccccccccccccccccccc67776777777ccc67777ccccccccccccccccccccccccc
cccccccccccccccc67776666666777ccccc66777c7777777776777ccc66777ccccccccccccccccccccc677777777777ccc677777c666cccccccccccccccccccc
ccccccccccccccc677777777777777cccc67777776777767776777ccc777776666ccc66ccccccccccc67777777777777cc67777777777ccccccccccccccccccc
ccccccccccccccc67777777777777cccc677777777777767777777c677777777777c6777cccccc666667777777767777cc677777777777cccccccccccccccccc
ccccccccccccccc6777777777777cccc67777777777777c7777777c677777777777777777cccc6777777777777cc6777cc677777777777cccccccccccccccccc
ccccccccccccccc677766777777cccc677776677777777c67777776777767777777777777ccc677777777c7777cc6777c67777777777777ccccccccccccccccc
ccccccccccccccc6777ccc67777cccc677776777766777cc77777767777677776777777777c6777777777c67777c6777c67777c66667777ccccccccccccccccc
ccccccccccccccc6777cccc67777cc67777c67777c6777cc6777776777c6777767777777776777777777cc67777c6777c6777cccccc7777ccccccccccccccccc
ccccccccccccccc6777ccccc7777cc67776c6777cc67777c6777767777cc7777c7777c67776777c67777cc67777c677767777cccccc6777ccccccccccccccccc
ccccccccccccccc6777ccccc6777cc6777777777ccc777776777777777cc6777c6777c67776777cc7777cc67777c67777777ccccccc6777ccccccccccccccccc
ccccccccccccccc6777ccccc677766677777777cccc67777677777777ccc677776777c67777777cc6777cc67777677777777cccccc67777ccccccccccccccccc
cccccccccccccc67777ccccc677777777777777ccccc7777777777777ccc677776777cc7777777c67777cc6777777777777ccc666667777ccccccccccccccccc
ccccccccccccccc777cccccc677777777777777ccccc6777777777777ccc677776777cc6777777767777cc6777777777777c6677777777cccccccccccccccccc
cccccccccccccccc6cccccccc7777777777776ccccccc77777776666ccccc77776777ccc77777777777cccc77777c67777cc777777777ccccccccccccccccccc
cccccccccccccccccccccccccc6667777776cccccccccc67777ccccccccccc777c777cccc777777777ccccc67777ccc66c67777777777ccccccccccccccccccc
ccccccccccc7c77ccccccccccccccc6666cccccccccccccc66ccccccccccccc6ccc6cccccc66777777cccccc7777ccccccc777776666cccccccccccccccccccc
cccccccccc677777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc6666ccccccc6777cccccccc666ccccccccccccccccccccccccc
cccccccccc677777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc6777cccccccccccccccccccc677ccccccccccccc
ccccccccccc6777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc6777ccccccccccccccccccc67777cccccccccccc
cccccccccccc66ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc67777ccccccccccccccccccc777777ccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc67777cccccccccccccccccc6777677ccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccc777c77ccccccccccccccccccccccccccccccccc777ccccccccccccccccccc6777c66ccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccc67777777ccccccccccccccccccccccccccccccccc6ccccccccccccccccccccc66ccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccc67777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccc677777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccc6666cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc4444cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc470470ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44004004cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44444444cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44440444cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44004044cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc444444ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc4444cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccc555cc55555555555555555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccc5555555555555555555555555555655505cccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccc5555555555555555555555555555655555ccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccc555d555555555555555555555555655555dccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccc555ccdddddddddddddddddddddddddddddccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000004d4e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4d4e4f46464a4b4c004d4e4f4646464600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4644464655464748494655464646464600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4646464646565758594646464646464600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5446464546666768694646464646444600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4646464646747576775446464546464600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
6f0700000565006650056500560005600056500565005600056000665006600066500665006600066500660006650066000665006650066000565005600046500465003600036000365003650036000465004600
6e0700000565006650056000565005600056000565005600056500665006600066500660006650066500660006650066500660006650066000565005600046000465003600036500365003600036500465004600
151a18000904300000096000962500000090330904309600000000962500000000000904300000000000962500000090330000000000090330962509033000000000000000000000000000000000000000000000
900100000e6200e6300f6400f6401064013640116401164013640116401463010630106301063010630106300f62010620106200e6200e6200e6100e6100e6100f6100f600106000000000000000000000000000
a00300001a52426540285302a5152a5052a5002a5001e5001a500135000f500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
940100002e63436637256372362719617126150b60704607006070060700607006070060700607006070060700607006070060700607006070060700607006070060700607006070060700607006070060700000
960100003861038620386203962039630386403865037670316002960031600316003160026500295002850029500085002950008500295000850029500005000050000000000000000000000000000000000000
a01a002025735287252d70525735287252d725257052872526720297202e72032725307202e720297202b7252d73528725257252d7352872525725287352a7251f72423724267242a7242b7242a7242672423725
01340000090300903507625150350a0300a035130350e03509030090300d03609033130201a0221f02218020090430000009625150350000016035076250e03509027090300d0360902300000000000000000000
960100001154009530025200151000510005001b50016500115000a50004500005002a500275002a500285002a500285002950029500265002950028500295000850029500085002950008500295000050000500
480100003254035540305402b54029530255202650016500115000a50004500005002a500275002a500285002a500285002950029500265002950028500295000850029500085002950008500295000050000500
a91a00001b50016500115000a50004500005002a500275002a500285002a500285002950029500265002950028500295000850029500085002950008500295001552015525155201552515520155251552015525
a91a0000155201552515520155251552015525155201552515520155251552015525155201552515520155251552015525155201552515520155251552015525155201552015520155251a5201a5201a5201a525
a91900001a5201a5201a5201a52504500005002a50027500185201852018520185251852018520185201852518520185201852018525085002950008500295001652016520165201652516520165201652016525
a91900001652016520165201652504500005002a5002750015520155201552015525155201552015520155251552015520155201552508500295001a5201a525195201952519520195251a5201a5251a5201a525
a91800001c5201c5201c5201c52504500005001a5201a525195201952519520195251a5201a5251a5201a5251c5201c5201c5201c525085002950008500295000000000000000000000000000000000000000000
a9180000000050000500000000000000000000000000000000000000000000000000000000000000000000001d5201d5201d5201d5251c5201c5201c5201c5251a5201a525215202152021520215251f5201f520
a91700001f5201f5201f5201f5251e5201e5201e5201e5251d5201d5201d5201d5251b5201b5201b5201b5201b5201b5251a5201a5251e5201e52524520245202452024525225202152022520225252252022520
a917000021520215202152021525265202652524520245252252022525215202152522520225251e5201e5251f5201f5251e5201e5251f5201f52521520215252252022525215202152522520225251e5201e525
a91600001f5202252021520225201f520215201d5201f5201c52024520225202452021520225201f520215201d520265202452026520225202452021520225201f52028520265202852024520265202252024520
a916000021520215251d5201d52522520215201f5201d5201f520225201f5201d5201c5201f5201c5201a520185201a5201c5201d5201f5201f5251c5201c5251d5201d5201d5201d52500000000000000000000
a91600002952027520265202452026520245202252021520225202652022520215201f520225201f5201d5201c5201d5201f52021520225202652024520225202152021520215202152524520245252252022520
a915000021520215251f5201f5252152021525225202252524520245251c5201c5251d5201d5251f5201f52521520215251f5201f525215202152522520225252452022520215201f5201d5201b5201a52018520
a9150000265202452022520215201f5201d5201c5201a52028520265202452022520215201f5201d5201c5202952028520265202452022520215201f5201d5202b5202952028520265202452022520215201f520
a91400002d520295202852029520245202952028520295202d520295202852029520245202952028520295202b520285202652028520245202852026520285202b52028520265202852024520285202652028520
a9130000295202b520295202852026520245202352021520235201f5202352026520295202d5202952026520235101f5102351026510295102d5102951026510225201f5202252024520285202b5202852024520
a9130000225101f5102251024510285102b5102851024510215201d520215202452026520295202652022520215101d5102151024510265102951026510225101f5201c5201f5202252025520285202552022520
a91200001f5101c5101f5102251025510285102551022510000002d5202b5202d520295202d520285202d520265202d520255202d520265202d520285202d520295202d520215202d520235202d520255202d520
a9120000265202d520255202d52026520265252852028525265202652524520245252252022525215202152522520215201f5201d5201c5201a52019520175201552015520155201552015520155201552015525
611200000000000000000000000000000215201f52021520000001e5201c5201e520000001a520185201a520165201852016520155201352011520105200e5200d5200d5200d5200d5200d5200d5200d5200d525
611b180021500215201f520215201d520215201c520215201a5202152019520215201a520215201c520215201d520215201552021520175202152019520215200000000000000000000000000000000000000000
611b00001a5202152019520215201a520215201c520215201d5201d5251e5201e5251f5201f525185201852516520165251552015525165201652518520185251a5201a525125201252513520135251552015525
611b00001652016525155201552516520165251252012525135201f520135201f5201a5201f5201a5201f520185201b520185201b520185201b520185201b520185201d520185201d520185201d520185201d520
611b0000165201a520165201a520165201a520165201a520165201c520165201c520165201c520165201c5201552019520155201952015520195201552019520115201a520115201a520115201a520115201a520
611a000010520165201052016520105201652010520165200e520155200e520155200e520155200e520155201052013520105201352010520135201052013520115201152510520105250e5200e5251352013525
611a00001152011525105201052511520115250d5200d5250e5200e5250d5200d5250e5200e52510520105251152011525105201052511520115250d5200d5250e5200e5200e5200e52511520115201152011525
6119000013520135201352013525000000000000000000000c5200c5200c5200c5251052010520105201052511520115201152011525000000000000000000000a5200a5200a5200a5250e5200e5200e5200e525
611900001052010520105201052500000000000000000000095200952009520095250d5200d5200d5200d5250e5200e5200e5200e525000000000011520115251652016525165201652515520155251552015525
611800001352013520135201352500000000001552015525165201652516520165251552015525155201552514520145201452014525000000000000000000002452024520245202452500000000000000000000
611800001d5201d5201d5201d5251a5201a5201a5201a52515520215201f52021520195201f5201d5201c520000001a520195201a52015525155201352015520125201a520195201a520135201d5201b5201a520
61170000195201c52015520195200e5201b5201a52018520175201a52013520175200c5201a5201852016520155201852012520155200e52018520165201552016520215201f5201e5201f520165201552013520
611700001a5201a5201a5201a52500000000001a5201a5251a5201a5251a5201a5251a5201a525185201852516520165251a5201a5251a5201a525185201852516520165251a5201a5251a5201a5251852018525
611600001652016520165201652500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
611600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018520165201852015520185201352018520
61150000115201852010520185201152018520135201852015520185200c520185200e52018520105201852011520185201052018520115201852013520185201552015520155201552500000000000000000000
61150000165201652016525000000000000000000000000018520185201852500005000000000000000000001a5201a5201a52500000000000000000000000001c5201c5201c5250000000000000000000000000
611400001d5101d5150000000000245102451500000000001d5101d5150000000000245102451500000000001c5101c5150000000000245102451500000000001c5101c515000000000024510245150000000000
6112000000000000000000000000000000000000000000002151021515255202552526520265251f5201f5251d5201d5252152021525235202352525520255252652026525255202552526520265252852028525
611200002952029525285202852529520295252552025525265202652521520215251f5201f5251e5201e52500000000000000000000000000000000000000000952009520095200952009520095200952009525
c1170000000000e5300c5300e5300a5300e530095300e530075300e530065300e530075300e530095300e5300a5300e530025300e530045300e530065300e530075300e530065300e530075300e530095300e530
c11600000a5300a5300a5300a53500000000000b535000000c5300c5300c5300c53500000000000d535000000e5300e5300e5300e53500000000000e535000001053010530105301053500000000001053500000
c1160000115301153509530095350a5300a5350e5300e5350753007530075300753500000000000a5300a5300a5300a535095300953507530075350c5300c5350553005530055300553500000000000000000000
a91b00001f500265001e500265001f50026500215000000000000265202452026520225202652021520265201f520265201e520265201f52026520215202652022520265201a520265201c520265201e52026520
a91b00001f520265201e520265201f520265202152026520225250000026525000002252500000265250000027520275251f5201f52527520275251f5201f5252452500000215250000024525000002152500000
a91b000026520265251d5201d52526520265251d5201d52522525005001f5250050022525005001f5250050025520255251c5201c52525520255251c5201c52521525005001d5250050021525005001d52500500
a91a00001f5201f52519520195251f5201f52519520195251d525000001a525000001d525000001a525000001c5201c52516520165251c5201c5251652016525000002d5202b5202d520295202d520285202d520
a91a0000265202d520255202d520265202d520285202d520295202d520215202d520235202d520255202d520265202d520255202d520265202d520285202d520295202d520285202d520265202d520245202d520
a9190000225202d520245202d520265202b520225202b520285202b520265202b520245202b520225202b520215202b520225202b520245202952021520295202652029520245202952022520295202152029520
a91900001f52029520215202952022520285201f520285202552028520225202852021520285201f520285201d520285201f5202852021520265201d520265201c520285201c520285201d520265201d52026520
a91800002252025520225202552021520265201d520265201c520285201c520285201d520265201d52026520000002652025520265202352026520255202352000000215201f520215201c5201f5201d5201c520
a91800000000026520255202652029520265202552023520245202452024520245252852028520285202852028520285252652026520265202652525520255252452024520245202452522520225202252022525
a917000021520215202152021525215202152021520215251f5201f5201f5201f5251f5201f5201f5201f5251e5201e5252152021520215202152527520275252652026520265202652500000000002b5202b520
a91700002b5202b5252a5202a5252b5202b5202b5202b525000000000026520265252652026525265202652526520265252652026525265202652526520265252652026525265202652526520265252652026525
a9160000265202b520295202b52028520295202652028520245202d5202b5202d520295202b5202852029520265202e5202d5202e5202b5202d520295202b52028520305202e520305202d5202e5202b5202d520
__music__
01 1e744344
00 1f344344
00 20354344
00 21364344
00 22370b44
00 23380c44
00 24390d44
00 253a0e44
00 263b0f44
00 273c1044
00 283d1144
00 293e1231
00 2a3f1332
00 2b151433
00 2c16545b
00 2d17545b
00 2e18545b
00 2e18545b
00 6f19545b
00 6c1a545b
00 2f1b545b
04 301c1d5b
00 07424344
03 07084344
00 47484344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
03 024e4f50

