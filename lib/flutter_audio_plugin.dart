
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

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
  int waveSampleRate = 44800;
  int waveType = 0;
  List<bool> _playerState = [false, false, false, true];
  Map<dynamic, dynamic> devices = new Map<dynamic, dynamic>();

  PlayerCpuListener cpuListener;
  PlayerDataListener posListener;
  PlayerStateListener stateListener;
  int callbackRate = 20; // 20ms

  AudioPlayer({this.deviceIndex = -1,
    this.waveSampleRate = 44800,
    this.stateListener,
    this.posListener,
    this.cpuListener,
    this.debug = false}) {
    lib.init(deviceIndex, waveSampleRate);
    volume = lib.getVolume();
    setCpuListener(cpuListener);
  }

  dynamic getDevices() {
    Pointer<Pointer<lib.DeviceInfo>> devList = lib.getDevices();
    int devCount = lib.getDeviceCount();

    devices = {};
    for (int i = 0; i < devCount; i++) {
      lib.DeviceInfo info = devList[i].ref;
      devices[i] = {
        'name': lib.translateStr(info.name),
        'driver': lib.translateStr(info.driver),
        'isDefault': info.isDefault == 1
      };
    }

    if (debug) {
      print('Devices: $devices');
    }
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
      result = lib.loadFile(lib.translatePtr(fileLocation));
      this._setPlayerState(true, false, true, true);
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
        if (_playerState[1]) {
          posListener(pos, dur);
          if (_abs(dur - pos) <= 0.0001) {
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
    lib.freeStream();
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
      print(getDuration());
      posListener(getPosition(), getDuration());
    }
  }

  void close() {
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
}
