import 'package:flutter/material.dart';

class LanguageSelectionStylish extends StatefulWidget {
  const LanguageSelectionStylish({super.key});

  @override
  State<LanguageSelectionStylish> createState() =>
      _LanguageSelectionStylishState();
}

class _LanguageSelectionStylishState extends State<LanguageSelectionStylish> {
  int? selectedIndex;

  final List<Map<String, String>> languages = [
    {'title': 'English', 'subtitle': 'English', 'symbol': 'A'},
    {'title': 'Hindi', 'subtitle': 'हिन्दी', 'symbol': 'अ'},
    {'title': 'Bangla', 'subtitle': 'বাংলা', 'symbol': 'অ'},
    {'title': 'Telugu', 'subtitle': 'తెలుగు', 'symbol': 'అ'},
    {'title': 'Tamil', 'subtitle': 'தமிழ்', 'symbol': 'அ'},
    {'title': 'Kannada', 'subtitle': 'ಕನ್ನಡ', 'symbol': 'ಅ'},
    {'title': 'Malayalam', 'subtitle': 'മലയാളം', 'symbol': 'അ'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Talk to experts in this language"),
        backgroundColor: Colors.pink.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade50, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  itemCount: languages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap: () => setState(() => selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blueAccent.shade100
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.blue.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? Colors.blueAccent.withOpacity(0.3)
                                  : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Text(
                                lang['symbol']!,
                                style: TextStyle(
                                  fontSize: 70,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.blue.shade100.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: Colors.white, size: 20),
                                      if (isSelected) const SizedBox(width: 6),
                                      Text(
                                        lang['title']!,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lang['subtitle']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selectedIndex != null ? Colors.blue : Colors.grey,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: selectedIndex == null
                    ? null
                    : () {
                        final lang = languages[selectedIndex!]['title'];
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Language changed to $lang"),
                            backgroundColor: Colors.blue.shade700,
                          ),
                        );
                        Navigator.pop(context);
                      },
                child: const Text(
                  "Save Changes",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 