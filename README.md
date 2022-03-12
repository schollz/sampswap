# sampswap

swap samples within loops to make new loops.

![sampswap-01](https://user-images.githubusercontent.com/6550035/157546058-96e5c62b-410a-4426-80b6-90976b9d70c4.jpg)


this script is forked from [makebreakbeat](https://github.com/schollz/makebreakbeat). the *makebreakbeat* also worked to create mangled loops. however, *makebreakbeat* works by extract audio onset positions and then rebuilds the audio one piece at a time, by selecting an onset and adding effects to it and then appending it to the file. in contrast, *sampswap* first repeats the original audio and then copies random regions, adds effects to that copy, and then pastes the effected copy to a random position along the loop (editing the file in-place essentially).


# Requirements

- norns

# Documentation

how it works

![howitworks](https://user-images.githubusercontent.com/6550035/157556885-5b99578c-b68e-4253-8dfb-6e95278e2b58.jpg)

## notes

this script generates beats *slowly*. to get around this I suggest generating short beats (8-16 beats) continuously (beats continue to play when generating).

# Install

install with

```
;install https://github.com/schollz/sampswap
```

once you start the script for the first time it will install `aubio`, `sox`, and `sendosc` (~8 MB total).
