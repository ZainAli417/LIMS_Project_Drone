import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FirstOnBoardingScreen extends StatefulWidget {
  @override
  State<FirstOnBoardingScreen> createState() => _FirstOnBoardingScreenState();
}

class _FirstOnBoardingScreenState extends State<FirstOnBoardingScreen> {
  int _currentIndex = 0;
  final PageController textPageController = PageController();
  final PageController imagePageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          children: [
            Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 130,
                height: 125,
                child: Image.asset(
                  'images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            _space(15, 0),
            // Disable swipe gesture for image page view
            GestureDetector(
              onPanUpdate: (details) {}, // This disables swiping on the images
              child: SizedBox(
                width: 500,
                height: 305,
                child: PageView.builder(
                  controller: imagePageController,
                  itemCount: imageList.length,
                  physics: NeverScrollableScrollPhysics(), // Ensure it cannot be scrolled
                  itemBuilder: (context, index) {
                    return Image.asset(
                      imageList[index],
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
            Spacer(),
            _onBoarding(context),
          ],
        ),
      ),
    );
  }

  Widget _onBoarding(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: MediaQuery.of(context).size.width,
      height: 325,
      decoration: BoxDecoration(
        color: Colors.indigo[700],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(100),
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: PageView.builder(
              controller: textPageController,
              itemCount: pageViewItems.length,
              itemBuilder: (context, index) {
                return pageViewItems[index];
              },
              onPageChanged: (value) {
                setState(() {
                  _currentIndex = value;
                  imagePageController.animateToPage(
                    value,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                });
              },
            ),
          ),
          _space(20, 0),
          Positioned(
            left: MediaQuery.of(context).size.width * 0.1,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    _buildPageIndicator(0),
                    _buildPageIndicator(1),
                    _buildPageIndicator(2),
                    _buildPageIndicator(3),
                  ],
                ),
                _space(0, 155),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home');

                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.home_outlined,
                      size: 25,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(3),
      width: _currentIndex == index ? 32 : 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  List<Widget> get pageViewItems {
    return [
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _text('Software Only (Saas)', FontWeight.w600, 22),
          _space(3, 0),
          _text('Control Spray with One Tap Solution', FontWeight.w500, 14),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _text('Software Sprayer', FontWeight.w600, 22),
          _space(3, 0),
          _text(
              'Use our Prebuilt Sprayer for Wider and more sophisticated mechanism!',
              FontWeight.normal,
              14),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _text('Software + UGV', FontWeight.w600, 22),
          _space(3, 0),
          _text(
              'Our trained UGV for Agriculture Precision Spraying and full control on UGV',
              FontWeight.normal,
              14),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _text('Software + UAV', FontWeight.w600, 22),
          _space(3, 0),
          _text(
              'Our trained groundless UAV for Agriculture Precision Spraying and full control on UAV without hassle of obstacles or Weather Anomalies',
              FontWeight.normal,
              14),
        ],
      ),
    ];
  }

  List<String> get imageList {
    return [
      'images/splash1.png',
      'images/splash2.png',
      'images/splash3.png',
      'images/splash4.png',
    ];
  }

  Widget _text(String text, FontWeight weight, double size) {
    return SizedBox(
      width: 290,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          textStyle: TextStyle(
            fontWeight: weight,
            color: Colors.white,
            fontSize: size,
          ),
        ),
      ),
    );
  }

  Widget _space(double height, double width) {
    return SizedBox(
      height: height,
      width: width,
    );
  }
}
