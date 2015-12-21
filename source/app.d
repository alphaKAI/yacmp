/*
  Yet Another Console Music Player
  Support formats are based on that of libsndfile.
  Copyright (C) 2015 alphaKAI
  The MIT License
*/

import core.thread,
       std.stdio,
       std.string,
       std.conv;
import deimos.portaudio;
import derelict.sndfile.sndfile;

static this(){
  DerelictSndFile.load;
}

struct PlayData{
  SNDFILE* sndFile;
  SF_INFO sfInfo;
  int position;
}

extern(C) int Callback(
      const(void)* input,
      void* output,
      ulong frameCount,
      const(PaStreamCallbackTimeInfo)* timeInfo,
      PaStreamCallbackFlags statusFlags,
      void *userData
    ){

  if (Thread.getThis() is null) 
    thread_attachThis();

  PlayData* data = cast(PlayData*)userData;

  int* cursor;
  int* _out = cast(int*)output;
  int thisSize = cast(int)frameCount;
  ulong thisRead;

  cursor = _out;

  while(thisSize > 0){
    sf_seek(data.sndFile, data.position, SEEK_SET);

    if(thisSize > (data.sfInfo.frames - data.position)){
      thisRead = data.sfInfo.frames - data.position;
      data.position = 0;
    } else {
      thisRead = thisSize;
      data.position += thisRead;
    }

    sf_readf_int(data.sndFile, cursor, thisRead);
    cursor += thisRead;
    thisSize -= thisRead;
  }

  return paContinue;
}

shared static bool playing;
shared static bool resume;
shared static int position;

void musicPlay(string fileName) {

  PaStream* stream;
  PaError error;
  PaStreamParameters outputParameters;
PlayData* data = new PlayData;
  data.position = resume ? position : 0;
  data.sfInfo.format = 0;
  data.sndFile = sf_open(fileName.toStringz, SFM_READ, &data.sfInfo);

  if(!data.sndFile){
    writeln("error opening file\n");
    return;
  }

  Pa_Initialize;

  outputParameters.device = Pa_GetDefaultOutputDevice;
  outputParameters.channelCount = data.sfInfo.channels;
  outputParameters.sampleFormat = paInt32;
  outputParameters.suggestedLatency = 0.2;
  outputParameters.hostApiSpecificStreamInfo = null;

  PaStreamParameters inputParameters;

  error = Pa_OpenStream(
      &stream,
      null,
      cast(const(PaStreamParameters*))&outputParameters,
      cast(double)data.sfInfo.samplerate,
      cast(ulong)paFramesPerBufferUnspecified,
      paNoFlag,
      &Callback,
      cast(void*)data
      );

  if(error){
    writeln("error opening output, error code = ", error);
    Pa_Terminate;
    return;
  }

  playing = true;
  Pa_StartStream(stream);
  while(true){
    Thread.sleep(dur!"msecs"(100));
    if(!playing)
      break;
  }

  Pa_StopStream(stream);
  Pa_CloseStream(stream);
  Pa_Terminate;

  position = data.position;

  return;
}


int main(){
  string fileName;
  bool endFlag;

  writeln("Yet Another Console Music Player");
  writeln("Support formats are based on that of libsndfile.");
  writeln("Copyright (C) 2015 alphaKAI");
  writeln("The MIT License");
  
  write("please input filename:");
  fileName = readln.chomp.to!string;
  new Thread(() => musicPlay(fileName)).start;

  while(!endFlag){
    writeln("coomand: 1 -> quit, 2 -> stop, 3 -> continue, 4 -> change");
    int input = readln.chomp.to!int;
    if(input == 1){
      playing = false;
      endFlag = true;
    } else if(input == 2){
      playing = false;
      writeln("STOP , playing:", playing);
    } else if(input == 3){
      resume = true;
      new Thread(() => musicPlay(fileName)).start;
    } else if(input == 4){
      playing = false;
      write("please input filename:");
      fileName = readln.chomp.to!string;
      resume = false;
      new Thread(() => musicPlay(fileName)).start;
    }
  }

  return 0;
}
