import 'package:process_run/shell.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

// Linux only
Future<void> main() async {
  await killIpListener(8180);
}

Future<int?> getIpListenerPid(int port) async {
  var result = await Shell(throwOnError: false).run('lsof -i :$port');

  var lines = result.outLines;
  for (var line in lines) {
    var out = line.split(' ').where((element) => element.isNotEmpty).toList();
    print(out);

    try {
      var pid = int.parse(out[1].toString());
      return pid;
    } catch (_) {
      continue;
    }
  }
  return null;
}

Future<void> killProcessId(int pid) async {
  try {
    // devPrint(pid);
    await Shell().run('kill -9 $pid');
    return;
  } catch (e) {
    print(e);
  }
}

Future<void> killIpListener(int port) async {
  var pid = await getIpListenerPid(port);
  if (pid != null) {
    await killProcessId(pid);
  }
}
