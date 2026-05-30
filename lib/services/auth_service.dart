import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Securely load from .env instead of hardcoding
  final String cloudName = dotenv.env['CLOUDINARY_NAME'] ?? '';
  final String uploadPreset = dotenv.env['CLOUDINARY_PRESET'] ?? '';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String phone,
    required String gender,
    required String defaultNeighborhood,
    required LatLng? homeLocation,
    required bool hasCar,
    String? carMake,
    String? carModel,
    String? carColor,
    String? carPlate,
    File? profileImage,
  }) async {
    try {
      final emailLower = email.trim().toLowerCase();
      if (!emailLower.endsWith('@student.aast.edu') && !emailLower.endsWith('@staff.aast.edu')) {
        throw Exception('Access denied. You must use a valid @student.aast.edu or @staff.aast.edu email.');
      }

      if (studentId.trim().length != 9) {
        throw Exception('Invalid Student ID. It must be exactly 9 digits.');
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailLower,
        password: password,
      );

      String? imageUrl;

      if (profileImage != null && userCredential.user != null) {
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(await http.MultipartFile.fromPath('file', profileImage.path));

          final response = await request.send();

          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonMap = json.decode(responseData);
            imageUrl = jsonMap['secure_url'];
          } else {
            throw Exception('Cloudinary upload failed (Status ${response.statusCode})');
          }
        } catch (e) {
          throw Exception('Failed to upload profile picture: $e');
        }
      }

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': emailLower,
          'fullName': fullName.trim(),
          'studentId': studentId.trim(),
          'phone': phone.trim(),
          'gender': gender,
          'defaultNeighborhood': defaultNeighborhood,
          'homeLocation': homeLocation != null ? {
            'lat': homeLocation.latitude,
            'lng': homeLocation.longitude,
          } : null,
          'hasCar': hasCar,
          'carInfo': hasCar ? {
            'make': carMake,
            'model': carModel,
            'color': carColor,
            'plate': carPlate,
          } : null,
          'profileImageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during registration.');
    }
  }

  Future<void> updateUserData(
      Map<String, dynamic> updatedData, {
        File? newProfileImage,
        bool removeImage = false,
      }) async {
    User? user = _auth.currentUser;
    if (user != null) {

      if (newProfileImage != null) {
        try {
          final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
          final request = http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(await http.MultipartFile.fromPath('file', newProfileImage.path));

          final response = await request.send();

          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonMap = json.decode(responseData);
            updatedData['profileImageUrl'] = jsonMap['secure_url'];
          } else {
            throw Exception('Failed to upload new image to Cloudinary.');
          }
        } catch (e) {
          throw Exception('Image Upload Error: $e');
        }
      } else if (removeImage) {
        updatedData['profileImageUrl'] = '';
      }

      await _firestore.collection('users').doc(user.uid).update(updatedData);

    } else {
      throw Exception('No user currently logged in.');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> deleteUserAccount() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
    }
  }

  Future<UserCredential?> loginUser({
    required String identifier,
    required String password,
  }) async {
    try {
      String emailToUse = identifier.trim().toLowerCase();

      if (RegExp(r'^\d{9}$').hasMatch(emailToUse)) {
        var userSnapshot = await _firestore.collection('users').where('studentId', isEqualTo: emailToUse).limit(1).get();
        if (userSnapshot.docs.isEmpty) {
          throw Exception('No account found with this Student ID.');
        }
        emailToUse = userSnapshot.docs.first.data()['email'];
      } else if (!emailToUse.contains('@')) {
        throw Exception('Please enter a valid email or 9-digit Student ID.');
      }

      return await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception('Incorrect email, Student ID, or password.');
      } else if (e.code == 'invalid-email') {
        throw Exception('This email address is not formatted correctly.');
      } else if (e.code == 'too-many-requests') {
        throw Exception('Too many failed attempts. Please try again later.');
      }
      throw Exception(e.message ?? 'Login failed. Please check your credentials.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}