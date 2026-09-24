import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Coklu oyunculu sunucuya olan tekil (singleton) soket baglantisini
/// yonetir. Uygulama boyunca tek bir soket olmasini saglar; sunucu
/// adresi degistiginde (orn. kullanici deploy edilen adresi girdiginde)
/// eski soket kapatilip yenisi acilir.
class SocketService {
  static final SocketService instance = SocketService._internal();
  factory SocketService() => instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _connectedUrl;

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;
  String? get connectedUrl => _connectedUrl;

  /// Sunucuyu Render (veya baska bir servise) deploy ettikten sonra
  /// oradan aldiginiz https://... adresini buraya yazarsaniz, uygulama
  /// her acildiginda varsayilan olarak bu adrese baglanir (kullanici
  /// yine de lobi ekranindan farkli bir adrese gecebilir). Bos
  /// birakilirsa [defaultLocalUrl] kullanilir.
  static const String productionUrl = 'https://kart-oyunu-server.onrender.com';

  /// Android emulatorunde "localhost" bilgisayarin kendisi degil,
  /// emulatorun kendi sanal makinesidir; bilgisayara ulasmak icin
  /// ozel adres 10.0.2.2 kullanilir. Gercek bir telefondan test
  /// ederken bunun yerine bilgisayarinizin yerel agdaki IP adresini
  /// (orn. 192.168.1.34) kullanmaniz gerekir — bkz. lobi ekranindaki
  /// "Sunucu Adresi" alani.
  static String get defaultLocalUrl {
    if (kIsWeb) return 'http://localhost:3000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  /// Verilen adrese baglanir. Zaten ayni adrese bagliysa yeni bir soket
  /// acmaz, mevcut olani (kopmussa) yeniden baglar.
  io.Socket connect(String url) {
    if (_socket != null && _connectedUrl == url) {
      if (!_socket!.connected) _socket!.connect();
      return _socket!;
    }

    _socket?.dispose();
    _connectedUrl = url;
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    return _socket!;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedUrl = null;
  }
}
