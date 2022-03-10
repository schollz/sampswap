local Sample={}

local UI=require("ui")
PROGRESSFILE="/tmp/sampswap/progress"

function Sample:new (o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o.id=o.id or 1
  o.playing=false
  o.loaded=false
  o.beat_num=0
  o.beat_offset=0
  o.index_cur=0
  o.index_max=0
  o.debounce_index=0
  o.selected=o.id==1
  local break_options={
    {"jump",20},
    {"reverse",5},
    {"stutter",10},
    {"pitch",1},
    {"reverb",1},
    {"revreverb",5},
  }
  local i=o.id
  params:add_group("loop "..i,6+#break_options)
  params:add{type='binary',name="make beat",id='break_make'..i,behavior='trigger',action=function(v) sampleswap(i) end}
  params:add_file("break_file"..i,"load sample"..i,_path.audio.."sampswap/amen_resampled.wav")
  params:set_action("break_file"..i,function(x)
    o:update_audio_file()
  end)
  params:add_control("break_amp"..i,"amp",controlspec.new(0,1,"lin",0.01,0.25,"",0.01/1))
  params:set_action("break_amp"..i,function(x)
    if o.playing then
      engine.amp(i,x)
    end
  end)
  params:add{type="number",id="break_beats"..i,name="beats",min=16,max=128,default=32}
  for _,op in ipairs(break_options) do
    params:add{type="number",id="break_"..op[1]..i,name=op[1],min=0,max=100,default=op[2]}
  end
  params:add_option("break_tapedeck"..i,"tapedeck",{"no","yes"})
  params:add_option("break_retempo"..i,"tempo changing",{"speed","timestretch","none"})

  return o
end

function Sample:update(beats)
  if self.beat_num==0 or self.filename==nil or beats==nil then
    do return end
  end
  if (beats-self.beat_offset)%self.beat_num==0 then
    print(string.format("sample %d: resetting",self.id))
    engine.tozero(self.id)
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
  print(self.id)
  if not util.file_exists(params:get("break_file"..self.id)) then
    do return end
  end
  _,self.filename,_=string.match(params:get("break_file"..self.id),"(.-)([^\\/]-%.?([^%.\\/]*))$")
  local s=util.os_capture("sox "..params:get("break_file"..self.id).." -n stat 2>&1  | grep Length | awk '{print $3}'")
  local seconds=tonumber(s)
  self.beat_num=seconds/(60/clock.get_tempo())
  if self.playing then
    self.debounce_index=4
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

function Sample:redraw()
  local x=128/3*(self.id-1)
  if self.selected then 
    screen.level(2)
    print(x,0,x+128/3,65)
    screen.rect(x,0,128/3-2,65)
    screen.fill()
  end


  local icon=UI.PlaybackIcon.new(x+128/3/2+1,1,6,4)
  screen.level(self.selected and 15 or 4)
  icon.status=self.playing and 1 or 4
  icon:redraw()
  screen.level(self.selected and 15 or 4)
  screen.text_center_rotate(x+5,32,self.filename:gsub("%.wav",""),270)
  screen.move(x+128/3/2+3,15)
  screen.text_center(""..(self.index_cur==0 and "none" or self.index_cur))
  screen.move(x+128/3/2+3,25)
  screen.text_center(params:get("break_amp"..self.id))
end

return Sample
