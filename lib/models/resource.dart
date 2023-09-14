class Resource {
  late int memoryFree;
  late int totalMemory;
  late int memoryByOs;
  late double cpuInUseByApp;
  late double memoryInUseByApp;

  Resource.fromMap(Map map) {
    memoryFree = map['memoryFree'];
    totalMemory = map['totalMemory'];
    cpuInUseByApp = map['cpuInUseByApp'];
    memoryInUseByApp = map['memoryInUseByApp'];
    memoryByOs = map['memeoryInUseByOs'];
  }
}
