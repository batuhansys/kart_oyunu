import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // true ise 'Giriş Yap' sekmesi açık, false ise 'Kayıt Ol' sekmesi açık
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Oyunun her yerinde kullanacağımız klasik masamızın yeşili
      backgroundColor: const Color(0xFF1B4D3E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo Alanı
              const Text(
                'RİSK\nGET AND GAIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 50),

              // Giriş / Kayıt Geçiş Butonları (Sekmeler)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton('GİRİŞ YAP', true),
                  const SizedBox(width: 20),
                  _buildTabButton('KAYIT OL', false),
                ],
              ),
              const SizedBox(height: 40),

              // Seçilen sekmeye göre ilgili formu ekranda gösteriyoruz
              _isLogin ? _buildLoginForm() : _buildRegisterForm(),
            ],
          ),
        ),
      ),
    );
  }

  // Sekme Butonu Tasarımı
  Widget _buildTabButton(String text, bool isLoginTab) {
    final isActive = _isLogin == isLoginTab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isLogin = isLoginTab; // Sekmeyi değiştir
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.amber : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 60,
            color: isActive ? Colors.amber : Colors.transparent, // Aktif olanın altına çizgi çeker
          )
        ],
      ),
    );
  }

  // Giriş Yap Formu
  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(Icons.email_outlined, 'E-posta Adresi'),
        const SizedBox(height: 16),
        _buildTextField(Icons.lock_outline, 'Şifre', isPassword: true),
        const SizedBox(height: 24),
        _buildActionButton('GİRİŞ YAP', Colors.amber, Colors.black),
      ],
    );
  }

  // Kayıt Ol Formu
  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildTextField(Icons.person_outline, 'Benzersiz Kullanıcı Adı'),
        const SizedBox(height: 16),
        _buildTextField(Icons.email_outlined, 'E-posta Adresi'),
        const SizedBox(height: 16),
        _buildTextField(Icons.lock_outline, 'Şifre', isPassword: true),
        const SizedBox(height: 24),
        _buildActionButton('E-POSTA İLE KAYIT OL', Colors.amber, Colors.black),
        const SizedBox(height: 16),
        const Text(
          'veya',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 16),
        // GDD'de belirttiğiniz Facebook seçeneği
        _buildActionButton(
            'FACEBOOK İLE KAYIT OL',
            const Color(0xFF1877F2),
            Colors.white,
            icon: Icons.facebook
        ),
      ],
    );
  }

  // Özel Text Field Tasarımı (Oyun Temasına Uygun Şeffaf Yapı)
  Widget _buildTextField(IconData icon, String hint, {bool isPassword = false}) {
    return TextField(
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.amber),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2), // Hafif karartılmış arkaplan
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber, width: 2), // Tıklanınca sarı olur
        ),
      ),
    );
  }

  // Tıklanabilir Büyük Buton Tasarımı
  Widget _buildActionButton(String text, Color bgColor, Color textColor, {IconData? icon}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () {
          // TODO: Bir sonraki aşamada buraya basınca Ana Menü'ye gitmesini sağlayacağız.
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
            ],
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}