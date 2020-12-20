
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'library.dart' as lib;

typedef PlayerCpuListener = Function(double cpu);
typedef PlayerDataListener = Function(double pos, double dur);
typedef PlayerStateListener = Function(bool isLoaded, bool isPlaying, bool isPaused, bool isStopped);

/// Modified from <pre>flutter_audio_desktop</pre> using dart ffi,
/// and better adaption for ANSI code.
class AudioPlayer {
  int id = 0;
  final bool debug;
  int deviceIndex = -1;
  bool isLoaded = false;
  bool isPlaying = false;
  bool isPaused = false;
  bool isStopped = true;
  int volume = 50;
  double waveAmplitude = 0.1;
  double waveFrequency = 440;
  int waveSampleRate = 44100;
  int waveType = 0;
  List<bool> _playerState = [false, false, false, true];
  Map<dynamic, dynamic> devices = new Map<dynamic, dynamic>();

  PlayerCpuListener cpuListener;
  PlayerDataListener posListener;
  PlayerStateListener stateListener;
  int callbackRate = 20; // 20ms

  AudioPlayer({this.deviceIndex = -1,
    this.waveSampleRate = 44100,
    this.stateListener,
    this.posListener,
    this.cpuListener,
    this.debug = false}) {
    lib.init(deviceIndex, waveSampleRate);
    setCpuListener(cpuListener);

    // 解决Hot Restart后音频没有停止播放的Bug
    lib.freeStream();
  }

  dynamic getDevices() {
    Pointer<Pointer<lib.DeviceInfo>> devList = lib.getDevices();
    int devCount = lib.getDeviceCount();

    devices = {};
    for (int i = 0; i < devCount; i++) {
      lib.DeviceInfo info = devList[i].ref;
      devices[i + 1] = {
        'name': lib.translateStr(info.name),
        'driver': lib.translateStr(info.driver),
        'flags': info.flags,
        'isDefault': info.isDefault
      };
      free(devList[i]);
      if (info.isDefault == 1) {
        devices['default'] = devices[i + 1];
      }
    }

    if (debug) {
      print('Devices: $devices');
    }
    free(devList);
    return devices;
  }

  void setDevice({int deviceIndex = 0}) {
    this.deviceIndex = deviceIndex;
    lib.setDevice(this.deviceIndex);
    volume = lib.getVolume();
  }

  int load(String fileLocation) {
    File audioFile = File(fileLocation);
    int result = 0;
    if (this._playerState[1]) {
      lib.pause();
    }
    if (this._playerState[0]) {
      lib.stop();
    }
    if (audioFile.existsSync()) {
      Pointer ptr = lib.translatePtr(fileLocation);
      result = lib.loadFile(ptr);
      free(ptr);

      this._setPlayerState(true, false, true, true);
      setVolume(volume);
      if (debug) {
        print('load file: $result');
      }
      return result;
    } else {
      if (debug) {
        print('load file error: not exists');
      }
      this._setPlayerState(false, false, false, true);
      return result;
    }
  }

  bool play() {
    bool success;
    if (this._playerState[1]) {
      success = false;
    } else {
      if (this._playerState[0]) {
        lib.play();
        success = true;
        this._setPlayerState(true, true, false, false);
      } else {
        success = false;
      }
    }
    if (debug) {
      print('play: $success');
    }
    if (posListener != null) {
      Timer.periodic(Duration(milliseconds: callbackRate), (timer) {
        double pos = getPosition();
        double dur = getDuration();

        int posB = getPositionB();
        int durB = getDurationB();
        if (_playerState[1]) {
          posListener(pos, dur);
          if (posB >= durB) {
            timer.cancel();
            stop();
          }
        } else {
          timer.cancel();
        }
      });
    }
    return success;
  }

  double _abs(double a) => a > 0 ? a : -a;

  bool pause() {
    if (this._playerState[2]) {
      return false;
    } else {
      if (this._playerState[0]) {
        this._setPlayerState(true, false, true, false);
        int res = lib.pause();

        if (debug) {
          print('pause: $res');
        }

        return true;
      } else {
        return false;
      }
    }
  }

  bool stop() {
    if (this._playerState[3]) {
      this._setPlayerState(false, false, false, true);
      return false;
    } else {
      if (this._playerState[0]) {
        this._setPlayerState(false, false, false, true);
        lib.stop();
        return true;
      } else {
        this._setPlayerState(false, false, false, true);
        return false;
      }
    }
  }

  double getDuration() {
    return lib.getDuration();
  }

  double getPosition() {
    if (this._playerState[3]) {
      return 0;
    }
    if (this._playerState[0] &&
        (this._playerState[1] || this._playerState[2])) {
      return lib.getPosition();
    }
    return 0;
  }

  int getDurationB() {
    return lib.getDurationB();
  }

  int getPositionB() {
    return lib.getPositionB();
  }

  bool setPosition(double seconds) {
    if (this._playerState[0]) {
      lib.setPosition(seconds);
      return true;
    } else {
      return false;
    }
  }

  /// [volume] range from [0..100]
  void setVolume(int volume) {
    int res = lib.setVolume(volume);
    this.volume = volume;
    if (debug) {
      print('actual volume: $res, player volume: $volume');
    }
  }

  void _setPlayerState(
      bool isLoaded, bool isPlaying, bool isPaused, bool isStopped) {
    this._playerState = [isLoaded, isPlaying, isPaused, isStopped];
    this.isLoaded = isLoaded;
    this.isPlaying = isPlaying;
    this.isPaused = isPaused;
    this.isStopped = isStopped;
    if (stateListener != null) {
      stateListener(_playerState[0], _playerState[1], _playerState[2], _playerState[3]);
    }
    if (posListener != null) {
      posListener(getPosition(), getDuration());
    }
  }

  void close() {
    // 在native的close()实现中已经做了free stream的操作
    lib.close();
  }

  double getCpu() {
    return lib.getCpu();
  }

  void setStateListener(PlayerStateListener listener) {
    this.stateListener = listener;
  }

  void setCpuListener(PlayerCpuListener listener) {
    if (cpuListener != null) {
      this.cpuListener = listener;
      Timer.periodic(Duration(milliseconds: 20), (timer) {cpuListener(getCpu());});
    }
  }

  void setPositionListener(PlayerDataListener listener) {
    this.posListener = listener;
  }

  Map audioTags(String fileLocation) {
    Pointer ptr = lib.translatePtr(fileLocation);
    Pointer res = lib.audioTags(ptr);
    String str = Utf8.fromUtf8(res.cast<Utf8>());
    free(ptr);
    free(res);
    if (str.isEmpty) {
      return {};
    } else {
      return jsonDecode(str);
    }
  }

  Map audioProperties(String fileLocation) {
    Pointer ptr = lib.translatePtr(fileLocation);
    Pointer res = lib.audioProperties(ptr);
    String str = Utf8.fromUtf8(res.cast<Utf8>());
    free(ptr);
    free(res);
    if (str.isEmpty) {
      return {};
    } else {
      return jsonDecode(str);
    }
  }

  /// 若[cacheDir]不为空，则返回一个JsonArray
  /// {"count": 1, "list": [ { "type": 3, "file": "/cache/dir/img.jpg", "comment": "", "mime": "image/png" } ]}
  /// 否则
  /// [mode] 0    返回第一个封面图片的二进制
  ///             return List<int>
  ///        1    返回第一个封面图片的Base64
  ///             return String
  ///        其它  将图片Base64作为JSON item
  ///             return List
  dynamic audioArts(String fileLocation, String cacheDir, int mode) {
    Pointer ptrLoc = lib.translatePtr(fileLocation);
    if (cacheDir == null || cacheDir.isEmpty) {
      Pointer empty = lib.translatePtr("");
      Pointer res = lib.audioArts(ptrLoc, empty, mode);

      dynamic result;
      if (mode == 0) {
        // no implementation
      } else if (mode == 1) {
        result = Utf8.fromUtf8(res.cast<Utf8>());
      } else {
        result = jsonDecode(Utf8.fromUtf8(res.cast<Utf8>()));
      }
      free(ptrLoc);
      free(empty);
      free(res);
      return result;
    } else {
      Pointer ptrCache = lib.translatePtr(cacheDir);
      Pointer res = lib.audioArts(ptrLoc, ptrCache, mode);
      dynamic json = jsonDecode(Utf8.fromUtf8(res.cast<Utf8>()));
      free(ptrLoc);
      free(ptrCache);
      free(res);
      return json;
    }
  }
}
