local Sample={}

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
  return o
end

function Sample:toggle_playing()
  self.playing=not self.playing
  engine.amp(self.id,self.playing and 1 or 0)
  if not self.loaded then
    self.debounce_index=1
  end
end

function Sample:set_path_to_audio(path)
  self.path=path
  _,self.filename,_=string.match(path,"(.-)([^\\/]-%.?([^%.\\/]*))$")
end

function Sample:path_from_index(i)
  if self.filename==nil then
    do return end
  end
  local tempo=math.floor(clock.get_tempo())
  return _path.audio.."sampswap/"..self.filename.."_bpm"..tempo.."_"..i..".wav"
end

function Sample:determine_index_max()
  if self.filename==nil then
    do return 0 end
  end
  local tempo=math.floor(clock.get_tempo())
  for i=1,1000 do
    if not util.file_exists(self:path_from_index(i)) then
      break
    end
    mi=i
  end
end

function Sample:redraw()

end

return Sample
