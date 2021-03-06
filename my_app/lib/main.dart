import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  final myData = await rootBundle.loadString("assets/ingredients.csv");
  List<List<dynamic>> csvTable = CsvToListConverter().convert(myData);
  List<String> stuffs = csvTable[0][0].split('\n');

  runApp(
    MaterialApp(
      title: 'Custom Fonts',
      // Set Raleway as the default app font.
      theme: ThemeData (
        fontFamily: 'Raleway',
        primaryColor: new Color(0xffbda0bc),
        accentColor: new Color (0xff824670),
      ),

      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
        stuff: stuffs,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final List<String> stuff;

  const TakePictureScreen({
    Key key,
    @required this.camera,
    @required this.stuff,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture')),
      // Wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner
      // until the controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Construct the path where the image should be saved using the
            // pattern package.
            final path = join(
              // Store the picture in the temp directory.
              // Find the temp directory using the `path_provider` plugin.
              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.png',
            );

            // Attempt to take a picture and log where it's been saved.
            await _controller.takePicture(path);

            // If the picture was taken, display it on a new screen.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath: path,
                stuffs : widget.stuff,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final List<String> stuffs;

  const DisplayPictureScreen({Key key, this.imagePath, this.stuffs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Captured Image')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: _buildImage(context),
    );
  }

  bool checkVegan(String ingredient) {
    for(String non_vegan in stuffs) {
      if(ingredient.toLowerCase().compareTo(non_vegan.toLowerCase()) == 0){
        return false;
      }
    }
    return true;
  }

  Future<VisionText> getVisionText() async {
    final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFile(File(imagePath));
    final TextRecognizer cloudTextRecognizer = FirebaseVision.instance.cloudTextRecognizer();
    final VisionText visionText = await cloudTextRecognizer.processImage(visionImage);
    return visionText;
  }

  Widget _buildChild(){
    return FutureBuilder<VisionText>(
        future: getVisionText(),
        builder: (context, AsyncSnapshot<VisionText> snapshot) {
          if (snapshot.hasData) {
            VisionText visionText = snapshot.data;
            String text = visionText.text;
            for (TextBlock block in visionText.blocks) {
                  final Rect boundingBox = block.boundingBox;
                  final List<Offset> cornerPoints = block.cornerPoints;
                  final String text = block.text;
                  final List<RecognizedLanguage> languages = block.recognizedLanguages;

                  for (TextLine line in block.lines) {
                    // Same getters as TextBlock
                  for (TextElement element in line.elements) {
                      // Same getters as TextBlock
                      String word  = element.text.replaceAll(new RegExp(r"[^A-Za-z0-9]+"), "");
                      if(!checkVegan(word)) {
                        return new NonVegan(ingredient: word);
                    }
                    }
                  }
                }
                return new Vegan();
          } else {
            return CircularProgressIndicator();
          }
        }
    );
  }

  Widget _buildImage(BuildContext context) {
    return Stack(
      children: <Widget>[
        Image.file(File(imagePath)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            width: double.infinity,
            child: FlatButton(
              child: Text('Check if vegan', style: TextStyle(fontSize: 24)),
              onPressed: () {
                Navigator.push(context,
                  new MaterialPageRoute(
                      builder: (context) => _buildChild()
                  ), //CHANGE LATER
                );
              },
              color: new Color(0xffc3d2d5),
              textColor: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}


//A widget that displays if the ingredient list IS VEGAN
class Vegan extends StatelessWidget{

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: new Text("Vegan"),
          actions: <Widget>[
            IconButton(
              icon: new Image.asset('images/coco.png'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); //return to camera screen
              },
            )
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget> [
          Center(child: Text('This product is vegan!',
              style: TextStyle(fontSize: 36.0),
              textAlign: TextAlign.center)),
            SizedBox(height: 10),
            FlatButton(
          color: new Color(0xffc3d2d5),
          textColor: Colors.black,
          disabledColor: Colors.grey,
          disabledTextColor: Colors.black,
          padding: EdgeInsets.all(8.0),
          splashColor: Colors.blueAccent,
          onPressed: () {
            Navigator.push(
              context,
              new MaterialPageRoute(builder: (context) => new IngrList()),
            );
          },
          child: Text(
            "See ingredient list",
            style: TextStyle(fontSize: 20.0), textAlign: TextAlign.center
          ),
        )
      ],
    ));
  }
}

//A widget that displays if the ingredient list is NOT vegan
class NonVegan extends StatelessWidget{
  final String ingredient;

  NonVegan({Key key, @required this.ingredient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: new Text("Not vegan"),
          actions: <Widget>[
            IconButton(
              icon: new Image.asset('images/coco.png'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            )
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget> [
            Center(child: Text('This product is NOT vegan.',
              style: TextStyle(fontSize: 36.0),
              textAlign: TextAlign.center
            )),
            SizedBox(height: 10),
            FlatButton(
              color: new Color(0xffc3d2d5),
              textColor: Colors.black,
              disabledColor: Colors.grey,
              disabledTextColor: Colors.black,
              padding: EdgeInsets.all(8.0),
              splashColor: Colors.blueAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  new MaterialPageRoute(builder: (context) => new IngrList()),
                );
              },
              child: Text(
                "See full ingredient list",
                style: TextStyle(fontSize: 20.0),
              ),
            ),
            SizedBox(height: 10),
            Text(
                "Non-vegan ingredients:",
                style: TextStyle(fontSize: 20.0),

    ),
            Text(
                ingredient //INSERT NON VEGAN INGREDIENTS
              ),
          ],
        )
    );
  }
}

//A widget that displays the ingredient list
class IngrList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
          title: new Text("Ingredients List"),
          actions: <Widget>[
            IconButton(
              icon: new Image.asset('images/coco.png'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
              },
            )
          ],
        ),
        body: Column(
          children: <Widget>[
            Text('INSERT LIST OF INGREDIENTS') //INSERT LIST OF INGREDIENTS
          ],
        )
    );
  }
}