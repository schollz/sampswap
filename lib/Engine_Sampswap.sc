// Engine_Sampswap

// Inherit methods from CroneEngine
Engine_Sampswap : CroneEngine {

    // Sampswap specific v0.1.0
    var sampleBuffSampswap;
    var playerSampswap;
    var params;
    var mainServer;
    var nrtServer;
    var serverOptions;
    var scoreFn;
    // Sampswap ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Sampswap specific v0.0.1

        mainServer = Server(\sampswap_nrt, NetAddr("127.0.0.1", 47112));
        serverOptions=ServerOptions.new.numOutputBusChannels_(2);
        serverOptions.sampleRate=48000;
        nrtServer = Server(\nrt, NetAddr("127.0.0.1", 47114), options:serverOptions);
        SynthDef("lpf_rampup", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd=LPF.ar(snd,XLine.kr(200,20000,duration));
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.005,dur-0.01,0.005]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);
        SynthDef("lpf_rampdown", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd=LPF.ar(snd,XLine.kr(20000,200,duration));
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.005,dur-0.01,0.005]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);
        SynthDef("dec_ramp", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd=SelectX.ar(Line.kr(0,1,duration/4),[snd,Decimator.ar(snd,8000,8)]);
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.005,dur-0.01,0.005]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);
        SynthDef("dec", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd=Decimator.ar(snd,8000,8);
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.005,dur-0.01,0.005]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);
        SynthDef("reverberate", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd=SelectX.ar(XLine.kr(0,1,duration/4),[snd,Greyhole.ar(snd* EnvGen.ar(Env.new([0, 1, 1, 0], [0.1,dur-0.2,0.1]), doneAction:2))]);
            snd=LeakDC.ar(snd);
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.1,dur-0.2,0.1]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);
        SynthDef("filter_in_out", {
            arg out=0,  dur=30, f1,f2,f3,f4;
            var duration=BufDur.ir(0);
            var snd = PlayBuf.ar(2,0,BufRateScale.kr(0));
            snd = RLPF.ar(snd,
                LinExp.kr(EnvGen.kr(Env.new([0.1, 1, 1, 0.1], [f1,dur-f1-f2,f2])),0.1,1,100,20000),
                0.6);
            snd = snd * EnvGen.ar(Env.new([0, 1, 1, 0], [0.005,dur-0.01,0.005]), doneAction:2);
            Out.ar(out, snd);
        }).load(nrtServer);

        scoreFn={
            arg inFile,outFile,synthDefinition,durationScaling,oscCallbackPort,f1,f2,f3,f4;
            Buffer.read(mainServer,inFile,action:{
                arg buf;
                Routine {
                    var buffer;
                    var score;
                    var duration=buf.duration*durationScaling;

                    "defining score".postln;
                    score = [
                        [0.0, ['/s_new', synthDefinition, 1000, 0, 0, \dur,duration,\f1,f1,\f2,f2,\f3,f3,\f4,f4]],
                        [0.0, ['/b_allocRead', 0, inFile]],
                        [duration, [\c_set, 0, 0]] // dummy to end
                    ];

                    "recording score".postln;
                    Score(score).recordNRT(
                        outputFilePath: outFile,
                        sampleRate: 48000,
                        headerFormat: "wav",
                        sampleFormat: "int24",
                        options: nrtServer.options,
                        duration: duration,
                        action: {
                            Routine {
                                postln("done rendering: " ++ outFile);
                                0.25.wait;
                                NetAddr.new("localhost",oscCallbackPort).sendMsg("/quit");
                            }.play;
                        }
                    );
                }.play;
            });
        };
        mainServer.waitForBoot({
            Routine {
                var oscExit;
                var oscScore;
                "registring osc for score".postln;
                oscScore = OSCFunc({ arg msg, time, addr, recvPort;
                    var inFile=msg[1].asString;
                    var outFile=msg[2].asString;
                    var synthDefinition=msg[3].asSymbol;
                    var durationScaling=msg[4].asFloat;
                    var oscCallbackPort=msg[5].asInteger;
                    var f1=msg[6].asFloat;
                    var f2=msg[7].asFloat;
                    var f3=msg[8].asFloat;
                    var f4=msg[9].asFloat;
                    [msg, time, addr, recvPort].postln;
                    scoreFn.value(inFile,outFile,synthDefinition,durationScaling,oscCallbackPort,f1,f2,f3,f4);
                    "finished".postln;
                }, '/score',recvPort:47113);
                1.wait;
                "writing ready file".postln;
                File.new("/tmp/nrt-scready", "w");
                "ready".postln;
            }.play;
        });


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
            var amp=msg[3];
            Buffer.read(Server.default, fname,action:{ arg buf;
                ["loading",buf].postln;
                if (sampleBuffSampswap.at(key).notNil,{
                    sampleBuffSampswap.at(key).free;
                });
                sampleBuffSampswap.put(key,buf);
                if (playerSampswap.at(key).notNil,{
                    playerSampswap.at(key).set(\bufnum,buf.bufnum,\amp,amp);
                },{
                    playerSampswap.put(key,Synth("playerSampswap",[\bufnum,buf.bufnum,\t_trig,1,\amp,amp]));
                })
            }); 
        });

        this.addCommand("tozero1","i", { arg msg;
            if (playerSampswap.at(msg[1]).notNil,{
                playerSampswap.at(msg[1]).set(\t_trig,1);
            });
        });

        this.addCommand("tozero2","ii", { arg msg;
            if (playerSampswap.at(msg[1]).notNil,{
                playerSampswap.at(msg[1]).set(\t_trig,1);
            });
            if (playerSampswap.at(msg[2]).notNil,{
                playerSampswap.at(msg[2]).set(\t_trig,1);
            });
        });

        this.addCommand("tozero3","iii", { arg msg;
            if (playerSampswap.at(msg[1]).notNil,{
                playerSampswap.at(msg[1]).set(\t_trig,1);
            });
            if (playerSampswap.at(msg[2]).notNil,{
                playerSampswap.at(msg[2]).set(\t_trig,1);
            });
            if (playerSampswap.at(msg[3]).notNil,{
                playerSampswap.at(msg[3]).set(\t_trig,1);
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
        mainServer.quit;
        nrtServer.quit;
	mainServer.free;
	nrtServer.free;
    }
}
