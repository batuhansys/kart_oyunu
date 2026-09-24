import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/socket_service.dart';

/// Kullanicinin lobi ekraninda gorup degistirebildigi sunucu adresi.
/// Varsayilan, platforma gore yerel test adresidir (bkz.
/// SocketService.defaultLocalUrl); sunucu Render/vb. bir yere deploy
/// edildiginde kullanici buraya gercek https://... adresini yazar.
final serverUrlProvider = StateProvider<String>(
  (ref) => SocketService.productionUrl ?? SocketService.defaultLocalUrl,
);
