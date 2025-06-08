import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both username and password';
        _isLoading = false;
      });
      return;
    }

    try {
      // Create HTTP client with reasonable timeouts for network requests
      final ioc = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true)
        ..connectionTimeout = const Duration(seconds: 30)  // Longer for network
        ..idleTimeout = const Duration(seconds: 60);       // Keep connections alive
      
      final httpClient = IOClient(ioc);

      // Network request with reasonable timeout for Cloudflare/Pi
      final response = await httpClient.post(
        Uri.parse('https://192.168.1.192:8443/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Connection': 'keep-alive',  // Enable connection reuse
          'Accept-Encoding': 'gzip',   // Enable compression
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 45),  // Reasonable timeout for network request
        onTimeout: () {
          throw TimeoutException('Login request timed out. Please check your connection.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isAdmin', data['is_admin'] ?? false);
        await prefs.setInt('userId', data['user_id'] ?? 0);
        await prefs.setString('username', username);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PantryList(
              isAdmin: data['is_admin'] ?? false,
              userId: data['user_id'] ?? 0,
              username: username,
            ),
          ),
        );
      } else {
        print('Login failed - Status: ${response.statusCode}, Body: ${response.body}');
        setState(() {
          _errorMessage = 'Login failed (${response.statusCode}). Check server connection.';
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _errorMessage = 'Connection timeout. Please try again.';
      });
    } on SocketException catch (e) {
      setState(() {
        _errorMessage = 'Network error. Check your internet connection.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
      });
      print('Login error: $e');  // Debug logging
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PantryBot Login'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.kitchen,
              size: 80,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              'Welcome to PantryBot',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onSubmitted: (_) => _login(),
            ),
            SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Login', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 