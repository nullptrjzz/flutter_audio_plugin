// Api of flyaudio.dll
// /* Player control */
// FLYAUDIO_API void init(int, int);
// FLYAUDIO_API DEVICE_INFO** getDevices();
// FLYAUDIO_API int getDeviceCount();
// FLYAUDIO_API bool setDevice(int);
// FLYAUDIO_API int loadFile(const char*);
//
// FLYAUDIO_API bool fa_play();
// FLYAUDIO_API bool fa_pause();
// FLYAUDIO_API bool fa_stop();
//
// FLYAUDIO_API double getDuration();
//
// FLYAUDIO_API double getPosition();
// FLYAUDIO_API void setPosition(double);
//
// FLYAUDIO_API unsigned long long getDurationB();
// FLYAUDIO_API unsigned long long getPositionB();
// FLYAUDIO_API void setPositionB(unsigned long long);
//
// FLYAUDIO_API int setVolume(int);
// FLYAUDIO_API int getVolume();
//
// FLYAUDIO_API float getCpu();
//
// FLYAUDIO_API void freeStream();
// FLYAUDIO_API void fa_close();
//
// FLYAUDIO_API const char* audioTags(const char* file);
// FLYAUDIO_API const char* audioProperties(const char* file);
// FLYAUDIO_API const char* audioArts(const char* file, const char* cacheDir, int bin);

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_audio_plugin/ext/gbk.dart';

final _lib = Platform.isWindows ? DynamicLibrary.open('flyaudio.dll')
    : DynamicLibrary.open('libflyaudio.so');

class DeviceInfo extends Struct {
  Pointer name;

  Pointer driver;

  @Uint64()
  int flags;

  @Int8()
  int isDefault;

  factory DeviceInfo.allocate(Pointer name, Pointer driver, int flags, int isDefault) =>
      allocate<DeviceInfo>().ref
      ..name = name
      ..driver = driver
      ..flags = flags
      ..isDefault = isDefault;
}

class AudioMeta extends Struct {
  @Int32()
  int sampleRate;
  @Int32()
  int channels;
  @Int32()
  int length;
  @Int32()
  int bitRate;

  factory AudioMeta.allocate(int sampleRate, int channels, int length, int bitRate) =>
      allocate<AudioMeta>().ref
      ..sampleRate = sampleRate
      ..channels = channels
      ..length = length
      ..bitRate = bitRate;
}

typedef Init = void Function(int, int);
typedef InitFunc = Void Function(Int32, Int32);

typedef GetDevices = Pointer<Pointer<DeviceInfo>> Function();
typedef GetDevicesFunc = Pointer<Pointer<DeviceInfo>> Function();

typedef GetDeviceCount = int Function();
typedef GetDeviceCountFunc = Int32 Function();

typedef SetDevice = int Function(int);
typedef SetDeviceFunc = Int8 Function(Int32);

typedef LoadFile = int Function(Pointer);
typedef LoadFileFunc = Int32 Function(Pointer);

typedef Control = int Function();
typedef ControlFunc = Int8 Function();

typedef GetDuration = double Function();
typedef GetDurationFunc = Double Function();

typedef GetDurationB = int Function();
typedef GetDurationBFunc = Uint64 Function();

typedef SetPosition = void Function(double);
typedef SetPositionFunc = Void Function(Double);

typedef SetPositionB = void Function(int);
typedef SetPositionBFunc = Void Function(Uint64);

typedef GetVolume = int Function();
typedef GetVolumeFunc = Int32 Function();

typedef SetVolume = int Function(int);
typedef SetVolumeFunc = Int32 Function(Int32);

typedef GetCpu = double Function();
typedef GetCpuFunc = Float Function();

typedef Close = void Function();
typedef CloseFunc = Void Function();

typedef AudioTags = Pointer Function(Pointer);
typedef AudioTagsFunc = Pointer Function(Pointer);

typedef AudioArts = Pointer Function(Pointer, Pointer, int);
typedef AudioArtsFunc = Pointer Function(Pointer, Pointer, Int32);

typedef AudioMetaF = Pointer<AudioMeta> Function(Pointer);
typedef AudioMetaFunc = Pointer<AudioMeta> Function(Pointer);

final Init init = _lib.lookup<NativeFunction<InitFunc>>('init').asFunction();
final GetDevices getDevices = _lib.lookup<NativeFunction<GetDevicesFunc>>('getDevices').asFunction();
final GetDeviceCount getDeviceCount = _lib.lookup<NativeFunction<GetDeviceCountFunc>>('getDeviceCount').asFunction();
final SetDevice setDevice = _lib.lookup<NativeFunction<SetDeviceFunc>>('setDevice').asFunction();
final LoadFile loadFile = _lib.lookup<NativeFunction<LoadFileFunc>>('loadFile').asFunction();
final Control play = _lib.lookup<NativeFunction<ControlFunc>>('fa_play').asFunction();
final Control pause = _lib.lookup<NativeFunction<ControlFunc>>('fa_pause').asFunction();
final Control stop = _lib.lookup<NativeFunction<ControlFunc>>('fa_stop').asFunction();
final GetDuration getDuration = _lib.lookup<NativeFunction<GetDurationFunc>>('getDuration').asFunction();
final GetDuration getPosition = _lib.lookup<NativeFunction<GetDurationFunc>>('getPosition').asFunction();
final SetPosition setPosition = _lib.lookup<NativeFunction<SetPositionFunc>>('setPosition').asFunction();
final GetDurationB getDurationB = _lib.lookup<NativeFunction<GetDurationBFunc>>('getDurationB').asFunction();
final GetDurationB getPositionB = _lib.lookup<NativeFunction<GetDurationBFunc>>('getPositionB').asFunction();
final SetPositionB setPositionB = _lib.lookup<NativeFunction<SetPositionBFunc>>('setPositionB').asFunction();
final GetVolume getVolume = _lib.lookup<NativeFunction<GetVolumeFunc>>('getVolume').asFunction();
final SetVolume setVolume = _lib.lookup<NativeFunction<SetVolumeFunc>>('setVolume').asFunction();
final GetCpu getCpu = _lib.lookup<NativeFunction<GetCpuFunc>>('getCpu').asFunction();
final Close freeStream = _lib.lookup<NativeFunction<CloseFunc>>('freeStream').asFunction();
final Close close = _lib.lookup<NativeFunction<CloseFunc>>('fa_close').asFunction();

/* 以下三个函数都是Utf8的返回值，无需进行ANSI转换*/
final AudioTags audioTags = _lib.lookup<NativeFunction<AudioTagsFunc>>('audioTags').asFunction();
final AudioTags audioProperties = _lib.lookup<NativeFunction<AudioTagsFunc>>('audioProperties').asFunction();
final AudioArts audioArts = _lib.lookup<NativeFunction<AudioArtsFunc>>('audioArts').asFunction();
final AudioMetaF audioMeta = _lib.lookup<NativeFunction<AudioMetaFunc>>('audioMeta').asFunction();

Pointer translatePtr(String s) {
  return Platform.isWindows ? Gbk.toGbk(s)
      : Utf8.toUtf8(s);
}

String translateStr(Pointer p) {
  if (Platform.isWindows) {
    String str = "";
    try {
      str = Utf8.fromUtf8(p.cast<Utf8>());
    } catch (err) {
      str = Gbk.fromGbk(p.cast<Gbk>());
    }
    return str;
  } else {
    return Utf8.fromUtf8(p.cast<Utf8>());
  }
}

class LibraryTest {

  void test() {
    init(-1, 44800);
    Pointer<Pointer<DeviceInfo>> devList = getDevices();
    int devCount = getDeviceCount();

    var devices = {};
    for (int i = 0; i < devCount; i++) {
      DeviceInfo info = devList[i].ref;
      devices[i] = {
        'name': translateStr(info.name),
        'driver': translateStr(info.driver),
        'isDefault': info.isDefault == 1
      };
      free(devList[i]);
    }
    print(devices);

    free(devList);
    close();
  }

}