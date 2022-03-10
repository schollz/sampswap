local Sample={}

local UI=require("ui")
PROGRESSFILE="/tmp/sampswap/progress"

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
  o.index_cur=0
  o.index_max=0
  o.debounce_index=0
  o.selected=o.id==1
  o.break_options={
    {"amp",25,5},
    {"jump",20,5},
    {"reverse",5,5},
    {"stutter",10,5},
    {"pitch",1,5},
    {"reverb",1,5},
    {"revreverb",5,5},
  }
  local i=o.id
  params:add_group("loop "..i,7+#o.break_options)
  params:add{type='binary',name="make beat",id='break_make'..i,behavior='trigger',action=function(v) sampleswap(i) end}
  params:add_file("break_file"..i,"load sample"..i,_path.audio.."sampswap/amen_resampled.wav")
  params:set_action("break_file"..i,function(x)
    o:update_audio_file()
  end)

  params:add{type="number",id="break_beats"..i,name="beats",min=16,max=128,default=32}
  params:add{type="number",id="break_beatsoffset"..i,name="beat off",min=0,max=16,default=0}
  for _,op in ipairs(o.break_options) do
    params:add{type="number",id="break_"..op[1]..i,name=op[1],min=0,max=100,default=op[2]}
  end
  params:set_action("break_amp"..i,function(x)
    if o.playing then
      engine.amp(i,x/100)
    end
  end)
  params:add_option("break_tapedeck"..i,"tapedeck",{"no","yes"})
  o.retempo_options={"speed","timestretch","none"}
  params:add_option("break_retempo"..i,"tempo changing",o.retempo_options)

  return o
end

function Sample:update_beat(beats)
  if self.beat_num==0 or self.filename==nil or beats==nil then
    do return end
  end
  if (beats-params:get("break_beatsoffset"..self.id))%self.beat_num==0 then
    --print(string.format("sample %d: resetting",self.id))
    engine.tozero(self.id)
  end
end

function Sample:update()
  if self.debounce_analyze~=nil then 
    self.debounce_analyze=self.debounce_analyze-1
    if self.debounce_analyze==0 then 
      self.debounce_analyze=nil 
      self:analyze_audio_file()
    end
  end
  if self.debounce_index~=nil then
    self.debounce_index=self.debounce_index-1
    if self.debounce_index==0 then
      self.debounce_index=nil
      if self.index_cur>0 then
        print(string.format("sample %d: loading %s",self.id,self.filename))
        if util.file_exists(params:get("break_file"..self.id)) then
          engine.load_track(self.id,params:get("break_file"..self.id))
        end
      end
    end
  end
end

function Sample:toggle_playing()
  self.playing=not self.playing
  engine.amp(self.id,self.playing and params:get("break_amp"..self.id) or 0)
  if not self.loaded then
    self.debounce_index=1
  end
end

function Sample:update_audio_file()
  print(self.id,"update_audio_file")
  local fname=params:get("break_file"..self.id)
  if not util.file_exists(fname) then
    do return end
  end
  self.folder,self.filename,_=string.match(fname,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  for token in string.gmatch(self.folder, "[^/]+") do
   self.folderend=token
  end
  self:analyze_audio_file()
end

function Sample:analyze_audio_file()
  print("analyze_audio_file")
  local fname=params:get("break_file"..self.id)

  local s=util.os_capture("sox "..fname.." -n stat 2>&1  | grep Length | awk '{print $3}'")
  local seconds=tonumber(s)
  local closet_bpm={0,100000}
  for bpm=100,200 do 
    local measures=seconds/((60/bpm)*4)
    if util.round(measures)%2==0 then 
      local dif=math.abs(util.round(measures)-measures)
      dif=dif-util.round(measures)/60
      -- print(bpm,math.round(measures),measures,dif)
      if dif<closet_bpm[2] then 
        closet_bpm[2]=dif 
        closet_bpm[1]=bpm
      end
    end
  end
  self.bpm=closet_bpm[1]
  self.beat_num=util.round(seconds/(60/self.bpm))
  if self.playing then
    self.debounce_index=4
  end
  -- find the file index in the list 
  for i, fname_in_list in ipairs(self.file_list) do 
    if fname==fname_in_list then
      self.file_index=i
    end
  end
end

function Sample:option_sel_delta(d)
  self.op=util.clamp(self.op+d,1,12)
  if self.op>6 then 
    self.break_options[13-self.op][3]=5
  end
end

function Sample:option_set_delta(d)
  if self.op==1 then 
    -- TODO: switch loop
  elseif self.op==2 then 
  end
end


function Sample:path_from_index(i)
  if self.filename==nil then
    do return end
  end
  local tempo=math.floor(clock.get_tempo())
  return _path.audio.."sampswap/"..self.filename.."_bpm"..tempo.."_"..i..".wav"
end

function Sample:determine_index_max()
  self.index_max=0
  if self.filename==nil then
    do return end
  end
  local tempo=math.floor(clock.get_tempo())
  for i=1,1000 do
    if not util.file_exists(self:path_from_index(i)) then
      break
    end
    self.index_max=i
  end
end

function Sample:swap()
  if util.file_exists(PROGRESSFILE) or self.filename==nil then
    do return end
  end
  params:write()
  local tempo=math.floor(clock.get_tempo())
  local fname=self:path_from_index(max_index+1)
  local cmd="cd ".._path.code.."sampswap/lib/ && lua mangler.lua --server-started"
  cmd=cmd.." -t "..tempo.." -b "..params:get("break_beats"..self.id)
  cmd=cmd.." -o "..fname.." ".." -i "..params:get("break_file"..self.id)
  for _,op in ipairs(break_options) do
    cmd=cmd.." --"..op[1].." "..params:get("break_"..op[1]..self.id)
  end
  if params:get("break_tapedeck"..self.id)==2 then
    cmd=cmd.." -tapedeck"
  end
  local retempos={"speed","stretch","none"}
  cmd=cmd.." -retempo"..retempos[params:get("break_retempo"..self.id)].." "
  cmd=cmd.." &"
  if self.cmd_clock~=nil then
    clock.cancel(self.cmd_clock)
  end
  self.cmd_clock=clock.run(function()
    os.execute(cmd)
  end)
end

function Sample:cleanup()
  if self.cmd_clock~=nil then
    clock.cancel(self.cmd_clock)
  end
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
  screen.text_center(self.folderend.."/"..self.filename)
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
    local bar=UI.Slider.new(x,y,udsw,64-9*2+1,0,0,100,{},"up")
    bar:set_value(params:get("break_"..self.break_options[i][1]..self.id))
    bar.active=self.op==12-(i-1)
    bar:redraw()
    if self.break_options[i][3]>0 then 
      screen.level(self.break_options[i][3])
      screen.move(x+udsw/2,64)
      screen.text_center(self.break_options[i][1])  
      self.break_options[i][3]=self.break_options[i][3]-1
    end
  end
  
  screen.level(15)
  do
    local y=16
    local lh=9.5
    screen.move(0,y)
    screen.level(self.op==1 and 15 or 5)
    screen.text(self.beat_num.." @ "..self.bpm)
    screen.move(0,y+lh)
    screen.level(self.op==2 and 15 or 5)
    screen.text(params:get("break_beats"..self.id).." @ "..math.floor(clock.get_tempo()))
    screen.move(0,y+lh*2)
    screen.level(self.op==3 and 15 or 5)
    screen.text("off: "..params:get("break_beatsoffset"..self.id))
    screen.move(0,y+lh*3)
    screen.level(self.op==4 and 15 or 5)
    screen.text(self.retempo_options[params:get("break_retempo"..self.id)])
    screen.move(0,y+lh*4)
    screen.level(self.op==5 and 15 or 5)
    screen.text("f+t+l")
    -- screen.move(0,y+lh*5)
    -- screen.text("f+t+l")
  end
  
  
end

return Sample
