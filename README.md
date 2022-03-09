# sampswap

swap samples within loops to make new loops.

![img](https://user-images.githubusercontent.com/6550035/156637615-a0363244-2186-4604-b75f-4c1936982e24.png)

this script is forked from [makebreakbeat](https://github.com/schollz/makebreakbeat). the *makebreakbeat* also worked to create mangled loops. however, *makebreakbeat* works by extract audio onset positions and then rebuilds the audio one piece at a time, by selecting an onset and adding effects to it and then appending it to the file. in contrast, *sampswap* first repeats the original audio and then copies random regions, adds effects to that copy, and then pastes the effected copy to a random position along the loop (editing the file in-place essentially).


# Requirements

- norns

# Documentation



## notes

this script generates beats *slowly*. to get around this I suggest generating short beats (8-16 beats) continuously (beats continue to play when generating).

# Install

install with

```
;install https://github.com/schollz/sampswap
```

once you start the script for the first time it will install `aubio`, `sox`, and `PortedPlugins`, and `sendosc` (~8 MB total).
