// Engine_Sampswap

// Inherit methods from CroneEngine
Engine_Sampswap : CroneEngine {

    // Sampswap specific v0.1.0
    var sampleBuffSampswap;
    var playerSampswap;
    var params;
    // Sampswap ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Sampswap specific v0.0.1
        playerSampswap=Dictionary.new;
        sampleBuffSampswap=Dictionary.new;

        // two players per buffer (4 players total)
        SynthDef("playerSampswap",{ 
            arg out=0, bufnum=0, rate=1, start=0, end=1, t_trig=0,
            loops=1000000,amp=1,lpf=18000,lpfqr=1.0;
            var sndfinal,snd,snd2,pos,pos2,frames,duration,env;
            var startA,endA,startB,endB,crossfade,aOrB;

            // latch to change trigger between the two
            aOrB=ToggleFF.kr(t_trig);
            startA=Latch.kr(start,aOrB);
            endA=Latch.kr(end,aOrB);
            startB=Latch.kr(start,1-aOrB);
            endB=Latch.kr(end,1-aOrB);
            crossfade=Lag.ar(K2A.ar(aOrB),0.05);

            rate = rate*BufRateScale.kr(bufnum);
            frames = BufFrames.kr(bufnum);

            pos=Phasor.ar(
                trig:aOrB,
                rate:rate,
                start:(((rate>0)*startA)+((rate<0)*endA))*frames,
                end:(((rate>0)*endA)+((rate<0)*startA))*frames,
                resetPos:(((rate>0)*startA)+((rate<0)*endA))*frames,
            );
            snd=BufRd.ar(
                numChannels:2,
                bufnum:bufnum,
                phase:pos,
                interpolation:4,
            );

            // add a second reader
            pos2=Phasor.ar(
                trig:(1-aOrB),
                rate:rate,
                start:(((rate>0)*startB)+((rate<0)*endB))*frames,
                end:(((rate>0)*endB)+((rate<0)*startB))*frames,
                resetPos:(((rate>0)*startB)+((rate<0)*endB))*frames,
            );
            snd2=BufRd.ar(
                numChannels:2,
                bufnum:bufnum,
                phase:pos2,
                interpolation:4,
            );

            sndfinal=(crossfade*snd)+((1-crossfade)*snd2) * Lag.kr(amp);

            sndfinal=RLPF.ar(sndfinal,Lag.kr(lpf),Lag.kr(lpfqr));

            Out.ar(out,sndfinal);
        }).add; 

        this.addCommand("load_track","isf", { arg msg;
            var key=msg[1];
            var fname=msg[2];
            Buffer.read(Server.default, fname,action:{ arg buf;
                ["loading",buf].postln;
                if (sampleBuffSampswap.at(key).notNil,{
                    sampleBuffSampswap.at(key).free;
                });
                sampleBuffSampswap.put(key,buf);
                if (playerSampswap.at(key).notNil,{
                    playerSampswap.at(key).set(\bufnum,buf.bufnum);
                },{
                    playerSampswap.put(key,Synth("playerSampswap",[\bufnum,buf.bufnum,\t_trig,1,\amp,msg[3]]));
                })
            }); 
        });

        this.addCommand("tozero","i", { arg msg;
            var key=msg[1].asInteger;
            if (playerSampswap.at(key).notNil,{
                playerSampswap.at(key).set(\t_trig,1);
            });
        });

        params = Dictionary.newFrom([
            \amp, 1,
            \lpf, 18000,
            \lpfqr, 1,
        ]);

        params.keysDo({ arg key;
            this.addCommand(key, "if", { arg msg;
                var playerKey=msg[1].asInteger;
                if (playerSampswap.at(playerKey).notNil,{
                    playerSampswap.at(playerKey).set(key,msg[2]);
                });
            });
        });

        // ^ Sampswap specific

    }

    free {
        // Sampswap Specific v0.0.1
        playerSampswap.keysValuesDo({ arg key, value; ["freeing",key].postln; value.free; });
        sampleBuffSampswap.keysValuesDo({ arg key, value;  ["freeing",key].postln; value.free; });
        // ^ Sampswap specific
    }
}
