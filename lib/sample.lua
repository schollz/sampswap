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
  o.debounce_load=nil
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
    o:load_file(x)
  end)

  params:add_file("ss_file_original"..i,"original file",_path.audio)
  params:add{type="number",id="ss_file_original_beats"..i,name="original beats",min=0,max=300,default=4}
  params:add{type="number",id="ss_file_original_bpm"..i,name="original bpm",min=0,max=300,default=4}
  params:hide("ss_file_original"..i)
  params:hide("ss_file_original_beats"..i)
  params:hide("ss_file_original_bpm"..i)

  params:add_file("ss_file_current"..i,"original file",_path.audio)
  params:add{type="number",id="ss_file_current_beats"..i,name="original beats",min=0,max=300,default=4}
  params:add{type="number",id="ss_file_current_bpm"..i,name="original bpm",min=0,max=300,default=4}
  params:hide("ss_file_current"..i)
  params:hide("ss_file_current_beats"..i)
  params:hide("ss_file_current_bpm"..i)

  params:add{type="number",id="ss_beats"..i,name="beats",min=16,max=128,default=32}
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

function Sample:load_file(path_to_original_file)
  local original_folder,original_filename,original_ext=string.match(path_to_original_file,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  local original_filename_noext=original_filename
  for match in (original_filename..original_ext):gmatch("(.-)"..original_ext) do
    original_filename_noext=match
    break
  end

  print("load_file",original_folder,original_filename,original_ext)
  -- create folder based on the original filename
  local path_sampswap=_path.audio.."sampswap/"..original_filename_noext.."/"
  os.execute(string.format("mkdir -p %s",path_sampswap))

  -- determine the tempo

  -- determine the number of beats

  -- create a file with the original path and bpm / beats info

  file=io.open(filename,"w+")
  io.output(file)
  io.write(data)
  io.close(file)

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
  if self.making_file~=nil and global_progress_file_exists==false then
    if self.debounce_making_file>0 then
      self.debounce_making_file=self.debounce_making_file-1
      if self.debounce_making_file==0 then
        self:determine_index_max()
        params:set("ss_file"..self.id,self.making_file)
        self.making_file=nil
        if self.playing then
          self.debounce_load=4
        end
      end
    end
  end
  if self.debounce_load~=nil and self.making==nil then
    self.debounce_load=self.debounce_load-1
    if self.debounce_load==0 then
      self.debounce_load=nil
      if util.file_exists(params:get("ss_file"..self.id)) then
        print(string.format("%d: loading %s",self.id,params:get("ss_file"..self.id)))
        engine.load_track(self.id,params:get("ss_file"..self.id),params:get("ss_amp"..self.id)/100)
        self.loaded=true
        if self.dont_align==nil then
          self.align_track=true
        end
        self.dont_align=nil
      end
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
  if not self.loaded then
    self.debounce_load=1
  end
end

function Sample:update_audio_file()
  print(self.id,"update_audio_file")
  local fname=params:get("ss_file"..self.id)
  if not util.file_exists(fname) then
    do return end
  end
  self.folder,self.filename,_=string.match(fname,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  for token in string.gmatch(self.folder,"[^/]+") do
    self.folderend=token
  end
  local fname=params:get("ss_file"..self.id)

  self.index_cur=0
  if not string.find(fname,"_sampswap_") then
    local fname_trimmed=silence_trim(fname)
    local s=""
    if util.file_exists(fname_trimmed) then
      s=util.os_capture("sox "..fname_trimmed.." -n stat 2>&1  | grep Length | awk '{print $3}'")
      os.execute("rm -f "..fname_trimmed)
    else
      s=util.os_capture("sox "..fname.." -n stat 2>&1  | grep Length | awk '{print $3}'")
    end
    local file_seconds=tonumber(s)
    local closet_bpm={0,100000}
    for bpm=100,200 do
      local measures=file_seconds/((60/bpm)*4)
      local measured_rounded=util.round(measures)
      local dif=math.abs(measured_rounded-measures)
      dif=dif-(measured_rounded%4==0 and measured_rounded/60 or 0)
      --print(bpm,measured_rounded,measures,dif)
      if dif<closet_bpm[2] then
        closet_bpm[2]=dif
        closet_bpm[1]=bpm
      end
    end
    local bpm=nil
    for word in string.gmatch(fname,'([^_]+)') do
      if string.find(word,"bpm") then
        bpm=word:match("%d+")
      end
    end
    if bpm==nil then
      bpm=closet_bpm[1]
    end
    params:set("ss_originalfile"..self.id,fname)
    params:set("ss_originalbpm"..self.id,bpm)
    params:set("ss_originalbeats"..self.id,util.round(file_seconds/(60/bpm)))
  else
    -- determine current index
    for word in string.gmatch(self.filename,'([^_]+)') do
      local num=string.match(word,"%d+")
      if num~=nil then
        self.index_cur=tonumber(num)
      end
    end
  end
  _,self.filename_original,_=string.match(params:get("ss_originalfile"..self.id),"(.-)([^\\/]-%.?([^%.\\/]*))$")

  self:determine_index_max()
  self.loaded=false
  if self.playing then
    self.debounce_load=4
  end
  -- find the file index in the list
  for i,fname_in_list in ipairs(self.file_list) do
    if fname==fname_in_list then
      self.file_index=i
    end
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
  print(self.filename,d)
  if not string.find(self.filename,"_sampswap_") then
    do return end
  end
  local index_cur=0
  for word in string.gmatch(self.filename,'([^_]+)') do
    local num=string.match(word,"%d+")
    if num~=nil then
      index_cur=tonumber(num)
    end
  end
  if index_cur==0 then
    do return end
  end
  local index_next=index_cur+d
  if index_next>self.index_max or index_next<1 then
    do return end
  end
  local filename_next=self:path_from_index(index_next)
  self.dont_align=true
  params:set("ss_file"..self.id,filename_next)
end

function Sample:path_from_index(i)
  if params:get("ss_originalfile"..self.id)=="" then
    print("no original file!??!?!?")
    do return end
  end
  local filename=""
  _,filename,_=string.match(params:get("ss_originalfile"..self.id),"(.-)([^\\/]-%.?([^%.\\/]*))$")
  -- remove .wav from end
  for match in (filename..".wav"):gmatch("(.-)"..".wav") do
    filename=match
    break
  end
  return _path.audio.."sampswap/"..filename.."_sampswap_bpm"..math.floor(clock.get_tempo()).."_"..i..".wav"
end

function Sample:determine_index_max()
  self.index_max=0
  if self.filename==nil then
    do return end
  end
  local tempo=math.floor(clock.get_tempo())
  for i=1,1000 do
    --print("determine_index_max",self:path_from_index(i))
    local fname=self:path_from_index(i)
    if fname==nil or not util.file_exists(fname) then
      break
    end
    self.index_max=i
  end
end

function Sample:swap()
  if global_progress_file_exists or self.filename==nil or self.making_file~=nil then
    do return end
  end
  params:write()
  local tempo=math.floor(clock.get_tempo())
  self.making_file=self:path_from_index(self.index_max+1)
  if self.making_file==nil then
    do return end
  end
  self.debounce_making_file=10
  local filename=params:get("ss_originalfile"..self.id)
  local cmd="cd ".._path.code.."sampswap/lib/ && lua sampswap.lua --server-started"
  -- TODO: option to change input tempo??
  cmd=cmd.." -filter-in "..params:get("ss_filter_in")
  cmd=cmd.." -filter-out "..params:get("ss_filter_out")
  cmd=cmd.." -t "..tempo.." -b "..params:get("ss_beats"..self.id)
  cmd=cmd.." -o "..self.making_file.." ".." -i "..filename
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
