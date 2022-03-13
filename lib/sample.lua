local Sample={}

WORKDIR="/tmp/sampswap/"

function Sample:new (o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o.id=o.id or 1
  o.file_list=o.file_list or {}
  o.file_index=o.file_index or 1
  o.op=1
  o.playing=false
  o.loaded=false
  o.beat_num=0
  o.index_max=0
  o.selected=o.id==1
  o.ss_options={
    {"amp",25,100,0},
    {"jump",20,50,0},
    {"reverse",5,15,0},
    {"stutter",10,30,0},
    {"pitch",1,10,0},
    {"reverb",1,10,0},
    {"revreverb",5,10,0},
  }
  local i=o.id
  params:add_group("loop "..i,13+#o.ss_options)
  -- TODO: hook this up
  params:add{type='binary',name="make beat",id='ss_make'..i,behavior='trigger',action=function(v) sampleswap(i) end}
  params:add_file("ss_file_load"..i,"load file",_path.audio)
  params:set_action("ss_file_load"..i,function(x)
    o:load_file_original(x)
  end)

  params:add_file("ss_file_original"..i,"original file",_path.audio)
  params:add_text("ss_file_original_noext"..i,"no ext","")
  params:add{type="number",id="ss_file_original_beats"..i,name="original beats",min=0,max=300,default=4}
  params:add{type="number",id="ss_file_original_bpm"..i,name="original bpm",min=0,max=300,default=4}
  params:add_control("ss_file_original_sec","sec",controlspec.new(0,640000,'lin',0.001,0,'sec'))
  params:hide("ss_file_original"..i)
  params:hide("ss_file_original_noext"..i)
  params:hide("ss_file_original_beats"..i)
  params:hide("ss_file_original_bpm"..i)
  params:hide("ss_file_original_sec"..i)

  params:add{type="number",id="ss_index"..i,name="index",min=0,max=300000,default=0}
  params:set_action("ss_index"..i,function(x)
    o.debounce_index_load=4
  end)
  params:hide("ss_index"..i)

  params:add{type="number",id="ss_input_tempo"..i,name="bpm",min=30,max=300,default=128}
  params:add{type="number",id="ss_target_beats"..i,name="beats",min=16,max=128,default=32}
  params:add{type="number",id="ss_beatsoffset"..i,name="offset",min=0,max=16,default=0}
  for _,op in ipairs(o.ss_options) do
    params:add{type="number",id="ss_"..op[1]..i,name=op[1],min=0,max=op[3],default=op[2]}
  end
  params:set_action("ss_amp"..i,function(x)
    if o.playing then
      engine.amp(i,x/100)
    end
  end)
  params:add{type="number",id="ss_filter_in"..i,name="filter in",min=0,max=16,default=4}
  params:add{type="number",id="ss_filter_out"..i,name="filter out",min=0,max=16,default=4}
  o.retempo_options={"repitch","stretch","none"}
  params:add_option("ss_retempo"..i,"tempo changing",o.retempo_options)

  o:determine_index_max()
  return o
end

function Sample:engine_load_track(path_to_file)
  engine.load_track(self.id,path_to_file,self.playing and params:get("ss_amp"..self.id)/100 or 0)
end

function Sample:save_file_index(path_to_file,tempo,i)
  local path_sampswap=_path.audio.."sampswap/"..params:get("original_filename_noext").."/"
  local path_to_index_folder=path_sampswap..tempo.."/"
  os.execute("mkdir -p "..path_to_index_folder)

  -- save the number of seconds
  local data={seconds=audio.seconds(path_to_file)}
  data.beats=data.seconds/(60/tempo)
  json_dump(path_to_index_folder..i..".json",data)

  -- move the file
  os.execute(string.format("mv %s %s",path_to_file,path_to_index_folder..i..".wav"))
end

function Sample:load_file_index(tempo,i)
  local path_sampswap=_path.audio.."sampswap/"..params:get("original_filename_noext").."/"
  local path_to_index_folder=path_sampswap..tempo.."/"

  -- check if it exists
  if not util.file_exists(path_to_index_folder..i..".wav") then
    do return end
  end

  -- load data
  local data=json_load(path_to_index_folder..i..".json")
  if data==nil then
    do return end
  end

  -- reset parameters
  params:set("ss_target_beats",data.beats)

  -- load it into the engine
  self:engine_load_track(path_to_index_folder..i..".wav")

  -- reload the current max index
  self:determine_index_max()
end

function Sample:load_file_original(path_to_original_file)
  if os.is_dir(path_to_original_file) then
    do return end
  end

  -- initialize save data
  local data={path=path_to_original_file}

  -- split into pieces
  local original_folder,original_filename,original_ext=string.match(path_to_original_file,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  data.noext=original_filename
  for match in (original_filename..original_ext):gmatch("(.-)"..original_ext) do
    data.noext=match
    break
  end
  print("load_file",original_folder,original_filename,original_ext)

  -- create folder based on the original filename
  local path_sampswap=_path.audio.."sampswap/"..data.noext.."/"
  os.execute(string.format("mkdir -p %s",path_sampswap))

  -- determine the tempo
  data.tempo,data.beats,data.seconds=audio.determine_tempo(path_to_original_file)

  -- create a file with the original path and bpm / beats info
  json_dump(path_sampswap.."original.json",data)

  -- update parameters
  params:set("ss_file_original",data.path)
  params:set("ss_file_original_noext",data.noext)
  params:set("ss_file_original_bpm",data.tempo)
  params:set("ss_file_original_beats",data.beats)
  params:set("ss_file_original_sec",data.seconds)
  params:set("ss_input_tempo",data.tempo)

  -- reset the load file to the folder containing the file
  -- so it can't be triggered
  params:set("ss_file_load",original_folder)

  -- load it into the engine (with volume if playing)
  self:engine_load_track(path_to_original_file)

  -- reload the current max index
  self:determine_index_max()
end

function Sample:update_beat(beats)
  if self.filename==nil or beats==nil then
    do return end
  end
  if self.align_track then
    self.align_track=nil
    engine.tozero1(self.id)
  end
  if (beats-params:get("ss_beatsoffset"..self.id))%params:get("ss_beats"..self.id)==0 then
    --print(string.format("sample %d: resetting",self.id))
    do return true end
  end
end

function Sample:update()
  if self.making_index~=nil and global_progress_file_exists==false then
    if self.debounce_making_index~=nil and self.debounce_making_index>0 then
      self.debounce_making_index=self.debounce_making_index-1
      if self.debounce_making_index==0 then
        self.index_max=self.making_index
        self.making_index=nil
        params:set("ss_index"..self.id,self.making_index)
      end
    end
  end
  if self.debounce_index_load~=nil and self.debounce_index_load>0 then
    self.debounce_index_load=self.debounce_index_load-1
    if self.debounce_index_load==0 then
      self.debounce_index_load=nil
      self:load_file_index(clock.get_tempo(),params:get("ss_index"))
    end
  end
end

function Sample:toggle_playing()
  print(self.id,"toggle_playing")
  self.playing=not self.playing
  engine.amp(self.id,self.playing and params:get("ss_amp"..self.id)/100 or 0)
  if self.playing then
    params:write()
  end
end

function Sample:option_sel_delta(i,d)
  self.op=util.clamp(self.op+d,1,13)
  if self.op>6 and self.id==i then
    self.ss_options[14-self.op][4]=5
  end
end

function Sample:option_set_delta(d)
  if self.op==1 then
    -- TODO: switch loop based on the produced loops
    self:option_set_delta_index(d)
  elseif self.op==2 then
    params:delta("ss_beats"..self.id,d)
  elseif self.op==3 then
    params:delta("clock_tempo",d)
  elseif self.op==4 then
    params:delta("ss_beatsoffset"..self.id,d)
  elseif self.op==5 then
    params:delta("ss_retempo"..self.id,d)
  elseif self.op==6 then
  else
    params:delta("ss_"..self.ss_options[14-self.op][1]..self.id,d)
    self.ss_options[14-self.op][4]=5
  end
end

function Sample:option_set_delta_index(d)
  local index_cur=params:get("ss_index"..self.id)
  local index_new=util.clamp(index_cur+d,0,self.index_max)
  if index_new~=index_cur then
    params:set("ss_index",index_new)
  end
end

function Sample:path_from_index(i)
  local path_sampswap=_path.audio.."sampswap/"..params:get("original_filename_noext").."/"
  return path_sampswap..clock.get_tempo().."/"..i..".wav"
end

function Sample:determine_index_max()
  self.index_max=0
  for i=1,1000 do
    if not util.file_exists(self:path_from_index(i)) then
      break
    end
    self.index_max=i
  end
end

function Sample:swap()
  if global_progress_file_exists or self.filename==nil or self.making_index~=nil then
    do return end
  end
  params:write()
  local tempo=math.floor(clock.get_tempo())
  self.making_index=self:path_from_index(self.index_max+1)
  if self.making_index==nil then
    do return end
  end
  self.debounce_making_index=10
  local filename=params:get("ss_originalfile"..self.id)
  local cmd="cd ".._path.code.."sampswap/lib/ && lua sampswap.lua --server-started"
  -- TODO: option to change input tempo??
  cmd=cmd.." -filter-in "..params:get("ss_filter_in")
  cmd=cmd.." -filter-out "..params:get("ss_filter_out")
  cmd=cmd.." -t "..tempo.." -b "..params:get("ss_beats"..self.id)
  cmd=cmd.." -o "..self.making_index.." ".." -i "..filename
  for _,op in ipairs(self.ss_options) do
    cmd=cmd.." --"..op[1].." "..params:get("ss_"..op[1]..self.id)
  end
  cmd=cmd.." --retempo"..self.retempo_options[params:get("ss_retempo"..self.id)].." "
  cmd=cmd.." &"
  print(cmd)
  if self.cmd_clock~=nil then
    clock.cancel(self.cmd_clock)
  end
  self.cmd_clock=clock.run(function()
    os.execute(cmd)
  end)
end

function Sample:redraw(smp,progress_val)
  if self.filename==nil then
    do return end
  end
  progress_val=progress_val or 100
  local slider=UI.Slider.new(0,0,128,9,0,0,100,{},"right")
  slider.label="progress"
  screen.level(15)
  slider.active=self.op==1
  slider:set_value(progress_val)
  slider:redraw()
  screen.fill()
  screen.update()
  screen.blend_mode(1)
  screen.level(15)
  screen.move(64,7)
  local filename=self.filename_original
  filename=filename:gsub("_sampswap","")
  filename=filename:gsub(".wav","")
  screen.text_center(filename.." ("..(self.index_cur==0 and "" or self.index_cur)..")")
  screen.update()
  screen.blend_mode(0)
  local sw=14
  for i=1,3 do
    local selected=self.id==i
    local x=128-sw
    local y=9+sw*(i-1)+i*2
    local iconsw=7
    local icon=UI.PlaybackIcon.new(x+sw/2-iconsw/2,y+sw/2-iconsw/2,6,6)
    icon.status=smp[i].playing and 1 or 4
    icon.active=selected
    icon:redraw()
    screen.level(selected and 10 or 5)
    screen.rect(x,y,sw,sw)
    screen.stroke()
  end

  local udsw=9
  for i=1,7 do
    local x=128-sw-(i*udsw)-i-1
    local y=10
    local bar=UI.Slider.new(x,y,udsw,64-9*2+1,0,0,self.ss_options[i][3],{},"up")
    bar:set_value(params:get("ss_"..self.ss_options[i][1]..self.id))
    bar.active=self.op==13-(i-1)
    bar:redraw()
    if self.ss_options[i][4]>0 then
      screen.level(self.ss_options[i][4])
      screen.move(x+udsw/2,63)
      screen.text_center(self.ss_options[i][1])
      self.ss_options[i][4]=self.ss_options[i][4]-1
    end
  end

  screen.level(15)
  do
    local y=16
    local lh=9.5
    screen.move(0,y)
    screen.level(5)
    screen.text(params:get("ss_originalbeats"..self.id).."qn")
    screen.move(40,y)
    screen.text_right(params:get("ss_originalbpm"..self.id))

    screen.move(0,y+lh)
    screen.level(self.op==2 and 15 or 5)
    screen.text(params:get("ss_beats"..self.id).."qn")
    screen.move(40,y+lh)
    screen.level(self.op==3 and 15 or 5)
    screen.text_right(math.floor(clock.get_tempo()))

    screen.move(0,y+lh*2)
    screen.level(self.op==4 and 15 or 5)
    screen.text("off: "..params:get("ss_beatsoffset"..self.id))
    screen.move(0,y+lh*3)
    screen.level(self.op==5 and 15 or 5)
    screen.text(self.retempo_options[params:get("ss_retempo"..self.id)])
    screen.move(0,y+lh*4)
    screen.level(self.op==6 and 15 or 5)
    -- TODO: allow selecting multiple options screen.text("f+t+l")
  end

end

return Sample
