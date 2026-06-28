import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MaterialApp(home: DlmsHomeScreen(), theme: ThemeData.dark(), debugShowCheckedModeBanner: false));

class DlmsController {
  static const _channel = MethodChannel('com.example.dlms/audiofx');
  static const eventChannel = EventChannel('com.example.dlms/rta_stream');

  static Future<void> setGeq(int bandIndex, double gain) async {
    try { await _channel.invokeMethod('setGeq', {'band': bandIndex, 'gain': gain}); } catch (e) { debugPrint(e.toString()); }
  }

  static Future<void> setPeq(int ch, int band, double freq, double gain) async {
    try { await _channel.invokeMethod('setPeq', {'channel': ch, 'band': band, 'freq': freq, 'gain': gain}); } catch (e) { debugPrint(e.toString()); }
  }

  static Future<void> setCrossover(int ch, int band, double cutoff) async {
    try { await _channel.invokeMethod('setCrossover', {'channel': ch, 'band': band, 'cutoff': cutoff}); } catch (e) { debugPrint(e.toString()); }
  }

  static Future<void> setLimiter(int ch, bool enabled, double thresh) async {
    try { await _channel.invokeMethod('setLimiter', {'channel': ch, 'enabled': enabled, 'thresh': thresh}); } catch (e) { debugPrint(e.toString()); }
  }

  static Future<void> setMatrix(int inputCh, int outputCh, double gain) async {
    try { await _channel.invokeMethod('setMatrix', {'input': inputCh, 'output': outputCh, 'gain': gain}); } catch (e) { debugPrint(e.toString()); }
  }
}

class DlmsHomeScreen extends StatefulWidget {
  @override
  _DlmsHomeScreenState createState() => _DlmsHomeScreenState();
}

class _DlmsHomeScreenState extends State<DlmsHomeScreen> {
  int activeChannel = 0; 
  List<double> geqGains = List.filled(10, 0.0);
  List<int> geqFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  double peqFreq = 1000.0;
  double peqGain = 0.0;
  double xOverFreq = 120.0;
  double limiterThresh = -1.0;

  List<List<double>> matrixGains = [
    [1.0, 0.0], 
    [0.0, 1.0], 
  ];

  List<double> rtaData = List.filled(16, 0.0);

  @override
  void initState() {
    super.initState();
    DlmsController.eventChannel.receiveBroadcastStream().listen((event) {
      if (event != null) {
        final List<dynamic> rawList = event;
        setState(() {
          rtaData = List<double>.from(rawList.map((e) => (e as num).toDouble()));
        });
      }
    }, onError: (err) {
      debugPrint("RTA Stream Error: $err");
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🔴 DLMS VIRTUAL PRO + RTA'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.grid_on), text: "Matrix Input"),
              Tab(icon: Icon(Icons.equalizer), text: "Master GEQ"),
              Tab(icon: Icon(Icons.tune), text: "Parametric EQ"),
              Tab(icon: Icon(Icons.call_split), text: "Crossover"),
              Tab(icon: Icon(Icons.gpp_good), text: "Limiter"),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildRtaDisplay(),
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('🔊 OUTPUT CH 1 (LEFT)'),
                    selected: activeChannel == 0,
                    onSelected: (_) => setState(() => activeChannel = 0),
                  ),
                  const SizedBox(width: 15),
                  ChoiceChip(
                    label: const Text('🔊 OUTPUT CH 2 (RIGHT)'),
                    selected: activeChannel == 1,
                    onSelected: (_) => setState(() => activeChannel = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMatrixView(),
                  _buildGeqView(),
                  _buildPeqView(),
                  _buildCrossoverView(),
                  _buildLimiterView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRtaDisplay() {
    return Container(
      height: 100,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[800]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REAL-TIME ANALYZER (RTA) - CH ${activeChannel + 1}', style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(rtaData.length, (index) {
                double val = activeChannel == 0 ? rtaData[index] : rtaData[(index + 3) % rtaData.length];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: max(3.0, val * 80),
                    decoration: BoxDecoration(
                      color: val > 0.7 ? Colors.redAccent : (val > 0.4 ? Colors.orangeAccent : Colors.greenAccent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMatrixView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INPUT MATRIX ROUTING & GAIN MIXER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 20),
          Table(
            border: TableBorder.all(color: Colors.grey[700]!),
            children: [
              TableRow(children: [
                Container(padding: const EdgeInsets.all(12), color: Colors.black32, child: const Text('Input / Output', style: TextStyle(fontWeight: FontWeight.bold))),
                Container(padding: const EdgeInsets.all(12), color: Colors.black32, child: const Text('CH 1 (Left)', textAlign: TextAlign.center)),
                Container(padding: const EdgeInsets.all(12), color: Colors.black32, child: const Text('CH 2 (Right)', textAlign: TextAlign.center)),
              ]),
              _buildMatrixRow(0, "IN 1 (Main L)"),
              _buildMatrixRow(1, "IN 2 (Main R)"),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildMatrixRow(int inIdx, String label) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(12.0), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      _buildMatrixSliderCell(inIdx, 0),
      _buildMatrixSliderCell(inIdx, 1),
    ]);
  }

  Widget _buildMatrixSliderCell(int inIdx, int outIdx) {
    return Column(
      children: [
        Text('${(matrixGains[inIdx][outIdx] * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
        Slider(
          value: matrixGains[inIdx][outIdx],
          min: 0.0, max: 1.0,
          onChanged: (val) {
            setState(() => matrixGains[inIdx][outIdx] = val);
            DlmsController.setMatrix(inIdx, outIdx, val);
          },
        ),
      ],
    );
  }

  Widget _buildGeqView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: geqFreqs.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              Text('${geqGains[index].toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: geqGains[index],
                    min: -12.0, max: 12.0,
                    onChanged: (val) {
                      setState(() => geqGains[index] = val);
                      DlmsController.setGeq(index, val);
                    },
                  ),
                ),
              ),
              Text('${geqFreqs[index]}\nHz', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeqView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Parametric EQ - Band 1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Text('Center Frequency: ${peqFreq.toInt()} Hz'),
          Slider(
            value: peqFreq, min: 20.0, max: 20000.0,
            onChanged: (val) {
              setState(() => peqFreq = val);
              DlmsController.setPeq(activeChannel, 0, peqFreq, peqGain);
            },
          ),
          const SizedBox(height: 20),
          Text('Gain: ${peqGain.toStringAsFixed(1)} dB'),
          Slider(
            value: peqGain, min: -12.0, max: 12.0,
            onChanged: (val) {
              setState(() => peqGain = val);
              DlmsController.setPeq(activeChannel, 0, peqFreq, peqGain);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCrossoverView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_split, size: 60, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text('Linkwitz-Riley Sub/Mid Crossover', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          Text('Cutoff Point: ${xOverFreq.toInt()} Hz', style: const TextStyle(fontSize: 22, color: Colors.blueAccent)),
          Slider(
            value: xOverFreq, min: 40.0, max: 250.0,
            onChanged: (val) {
              setState(() => xOverFreq = val);
              DlmsController.setCrossover(activeChannel, 0, xOverFreq);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLimiterView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gpp_good, size: 60, color: Colors.redAccent),
          const SizedBox(height: 20),
          const Text('Brickwall Speaker Protection', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 30),
          Text('Threshold Ceiling: ${limiterThresh.toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 22, color: Colors.redAccent)),
          Slider(
            value: limiterThresh, min: -20.0, max: 0.0,
            onChanged: (val) {
              setState(() => limiterThresh = val);
              DlmsController.setLimiter(activeChannel, true, limiterThresh);
            },
          ),
        ],
      ),
    );
  }
}
