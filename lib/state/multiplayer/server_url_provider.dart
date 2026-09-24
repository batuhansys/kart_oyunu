import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/socket_service.dart';

/// Kullanicinin lobi ekraninda gorup degistirebildigi sunucu adresi.
/// Varsayilan olarak deploy edilen production sunucusu (bkz.
/// SocketService.productionUrl) kullanilir; kullanici yerelde test
/// etmek isterse lobi ekranindan SocketService.defaultLocalUrl'e
/// (veya baska bir adrese) manuel gecebilir.
final serverUrlProvider = StateProvider<String>(
  (ref) => SocketService.productionUrl,
);
