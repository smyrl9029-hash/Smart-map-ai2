import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(SmartMapAI());
}

class SmartMapAI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapHome(),
    );
  }
}

class MapHome extends StatefulWidget {
  @override
  _MapHomeState createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  List<dynamic> results = [];
  MapController mapController = MapController();
  TextEditingController searchController = TextEditingController();

  late stt.SpeechToText speech;
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
  }

  // ذكاء اصطناعي بسيط لتحليل النص
  String aiParser(String text) {
    text = text.toLowerCase();

    if (text.contains("مطعم") && text.contains("رخيص")) {
      return "cheap restaurant";
    }
    if (text.contains("مقهى") && text.contains("هادي")) {
      return "quiet cafe";
    }
    if (text.contains("مقهى")) {
      return "cafe";
    }
    if (text.contains("صيدلية")) {
      return "pharmacy";
    }
    if (text.contains("مستشفى")) {
      return "hospital";
    }
    if (text.contains("موقف")) {
      return "parking";
    }

    return text;
  }

  Future<void> searchOSM(String keyword) async {
    final url =
        "https://nominatim.openstreetmap.org/search?q=$keyword&format=json&limit=10";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    setState(() {
      results = data;
    });

    if (results.isNotEmpty) {
      mapController.move(
        LatLng(
          double.parse(results[0]["lat"]),
          double.parse(results[0]["lon"]),
        ),
        15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Smart Map AI"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // مربع البحث + المايك
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "اكتب أو تكلّم: أقرب مطعم رخيص...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: isListening ? Colors.red : Colors.black54,
                        ),
                        onPressed: () async {
                          if (!isListening) {
                            bool available = await speech.initialize();
                            if (available) {
                              setState(() => isListening = true);
                              speech.listen(onResult: (val) {
                                setState(() {
                                  searchController.text =
                                      val.recognizedWords;
                                });
                              });
                            }
                          } else {
                            setState(() => isListening = false);
                            speech.stop();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () {
                          final parsed = aiParser(searchController.text);
                          searchOSM(parsed);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // الخريطة + قائمة النتائج
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: LatLng(24.7136, 46.6753), // الرياض
                      zoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      ),
                      MarkerLayer(
                        markers: results.map((place) {
                          return Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(
                              double.parse(place["lat"]),
                              double.parse(place["lon"]),
                            ),
                            builder: (ctx) => Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 170,
                  color: Colors.white,
                  child: results.isEmpty
                      ? Center(child: Text("اكتب أو تكلّم للبحث عن مكان"))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final place = results[index];
                            return ListTile(
                              title: Text(
                                place["display_name"] ?? "Unknown",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                mapController.move(
                                  LatLng(
                                    double.parse(place["lat"]),
                                    double.parse(place["lon"]),
                                  ),
                                  17,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
