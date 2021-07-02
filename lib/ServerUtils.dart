import 'dart:io';
import 'dart:convert';

class SocketUtils{
  late Socket _socket;
  static const String SERVER_IP = "127.0.0.1";
  static const int SERVER_PORT = 6000;

  Future<bool> sendMessage(String message, Function connectionListener, Function messageListener) async {
    try {
      _socket = await Socket.connect(SERVER_IP, SERVER_PORT);
      connectionListener(true);
      _socket.listen((List<int> event) {
        String message = utf8.decode(event);
        print('Message: $message');
        messageListener(message);
      });
      _socket.add(utf8.encode(message));
      _socket.close();
    } catch (e) {
      connectionListener(false);
      return false;
    }
    return true;
  }

  void cleanUp() {
    if (null != _socket) {
      _socket.destroy();
    }
  }
}