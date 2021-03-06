import 'dart:io';
import 'dart:convert';
import 'package:anna_comic/screen/chapter_screen.dart';
import 'package:anna_comic/screen/read_screen.dart';
import 'package:anna_comic/state/state_manager.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'model/comic.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FirebaseApp app = await Firebase.initializeApp(
      name: 'Anna Comic',
      options: Platform.isMacOS || Platform.isIOS
          ? FirebaseOptions(
              appId: 'IOS KEY',
              apiKey: 'AIzaSyBT3k2LkauPaUIQtEArBcwWhLyIBknjm0U',
              projectId: 'anna-comic',
              messagingSenderId: '215652368323',
              databaseURL: 'https://anna-comic-default-rtdb.firebaseio.com')
          : FirebaseOptions(
              appId: '1:215652368323:android:01f4e50eafffaf32e58776',
              apiKey: 'AIzaSyBT3k2LkauPaUIQtEArBcwWhLyIBknjm0U',
              projectId: 'anna-comic',
              messagingSenderId: '215652368323',
              databaseURL: 'https://anna-comic-default-rtdb.firebaseio.com'));

  runApp(ProviderScope(child: MyApp(app: app)));
}

// ignore: must_be_immutable
class MyApp extends StatelessWidget {
  FirebaseApp app;
  MyApp({this.app});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      routes: {
        '/chapters': (context) => ChapterScreen(),
        '/read': (context) => ReadScreen()
      },
      theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity),
      home: MyHomePage(title: 'Anna Comic App', app: app),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.app}) : super(key: key);

  final FirebaseApp app;
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DatabaseReference bannerRef, comicRef;
  List<Comic> listComicFromFirebase = <Comic>[];

  @override
  void initState() {
    super.initState();
    final FirebaseDatabase database = FirebaseDatabase(app: widget.app);
    bannerRef = database.reference().child('Banners');
    comicRef = database.reference().child('Comic');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, _) {
      var searchEnable = watch(isSearch).state;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: searchEnable
              ? TypeAheadField(
                  textFieldConfiguration: TextFieldConfiguration(
                    decoration: InputDecoration(
                        hintText: 'Comic name or category',
                        hintStyle: TextStyle(color: Colors.white60)),
                    autofocus: false,
                    style: DefaultTextStyle.of(context).style.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                        color: Colors.white),
                  ),
                  suggestionsCallback: (searchString) async {
                    return await searchComic(searchString);
                  },
                  itemBuilder: (context, comic) {
                    return ListTile(
                      leading: Image.network(comic.image),
                      title: Text('${comic.name}'),
                      subtitle: Text(
                          '${comic.category == null ? '' : comic.category}'),
                    );
                  },
                  onSuggestionSelected: (comic) {
                    context.read(comicSelected).state = comic;
                    Navigator.pushNamed(context, '/chapters');
                  },
                )
              : Text(widget.title, style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () =>
                  context.read(isSearch).state = !context.read(isSearch).state,
            ),
          ],
        ),
        body: FutureBuilder<List<String>>(
            future: getBanners(bannerRef),
            builder: (context, snapshot) {
              if (snapshot.hasData)
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CarouselSlider(
                      items: snapshot.data
                          .map((e) => Builder(
                                builder: (context) {
                                  return Image.network(e, fit: BoxFit.cover);
                                },
                              ))
                          .toList(),
                      options: CarouselOptions(
                          autoPlay: true,
                          enlargeCenterPage: true,
                          viewportFraction: 1,
                          initialPage: 0,
                          height: MediaQuery.of(context).size.height / 3),
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: Colors.red,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'NEW COMIC',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.black,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(''),
                            ),
                          ),
                        ),
                      ],
                    ),
                    FutureBuilder(
                        future: getComics(comicRef),
                        builder: (context, snapshot) {
                          if (snapshot.hasError)
                            return Center(
                              child: Text('${snapshot.error}'),
                            );
                          else if (snapshot.hasData) {
                            listComicFromFirebase = <Comic>[];
                            snapshot.data.forEach((item) {
                              var comic = Comic.fromJson(
                                  json.decode(json.encode(item)));
                              listComicFromFirebase.add(comic);
                            });
                            return Expanded(
                              child: GridView.count(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                padding: const EdgeInsets.all(4),
                                mainAxisSpacing: 1,
                                crossAxisSpacing: 1,
                                children: listComicFromFirebase.map((comic) {
                                  return GestureDetector(
                                    onTap: () {
                                      context.read(comicSelected).state = comic;
                                      Navigator.pushNamed(context, '/chapters');
                                    },
                                    child: Card(
                                      elevation: 12,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            comic.image,
                                            fit: BoxFit.cover,
                                          ),
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                color: Color(0xAA434343),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${comic.name}',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }
                          return Center(child: CircularProgressIndicator());
                        })
                  ],
                );
              else if (snapshot.hasError)
                return Center(
                  child: Text('${snapshot.error}'),
                );
              return Center(child: CircularProgressIndicator());
            }),
      );
    });
  }

  Future<List<dynamic>> getComics(DatabaseReference comicRef) {
    return comicRef.once().then((snapshot) => snapshot.value);
  }

  Future<List<String>> getBanners(DatabaseReference bannerRef) {
    return bannerRef
        .once()
        .then((snapshot) => snapshot.value.cast<String>().toList());
  }

  Future<List<Comic>> searchComic(String searchString) async {
    return listComicFromFirebase
        .where((comic) =>
                comic.name
                    .toLowerCase()
                    .contains(searchString.toLowerCase()) //Name first
                //If name not contains
                ||
                (comic.category != null &&
                    comic.category.toLowerCase().contains(searchString
                        .toLowerCase())) //Then we search by category

            )
        .toList();
  }
}
