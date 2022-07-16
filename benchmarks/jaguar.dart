import 'package:jaguar/jaguar.dart';

main() async {
  final server = Jaguar(port: 3004);
  server.staticFiles('/*', './');
  await server.serve();
}

// http://127.0.0.1:3004/index.html
