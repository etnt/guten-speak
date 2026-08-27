# Supporting commercial EPUB books with DRM protection

## Architectual flow

```
[Flutter UI] ---> (Passes .lcpl path & Passphrase) ---> [MethodChannel]
                                                               |
[Flutter Reader] <--- (Returns decrypted .epub path) <--- [Native OS (Swift/Kotlin)]
                                                        * Downloads book via LCPL
                                                        * Decrypts using Readium SDK
```

## Step 1: The Flutter side

You need to pick up the .lcpl file, prompt the user for their passphrase,
and send both strings over the channel.

```dart
import 'package:flutter/services.dart';
import 'dart:io';

class LcpManager {
  // Define a unique channel name
  static const MethodChannel _lcpChannel = MethodChannel('com.yourapp.lcp/decrypt');

  /// Takes an LCPL file path and user password, triggers native decryption, 
  /// and returns the absolute path to the fully decrypted, readable EPUB file.
  Future<String?> processLcpBook({
    required String lcplFilePath, 
    required String passphrase
  }) async {
    try {
      // 1. Sanity check: Ensure the file actually exists
      if (!await File(lcplFilePath).exists()) {
        throw Exception("LCPL file not found at path: $lcplFilePath");
      }

      // 2. Invoke the native method
      final String? decryptedEpubPath = await _lcpChannel.invokeMethod<String>(
        'decryptLcp',
        {
          'lcplPath': lcplFilePath,
          'passphrase': passphrase,
        },
      );

      return decryptedEpubPath; // This path can now be fed right into your Gutenberg parser!
    } on PlatformException catch (e) {
      print("Native LCP Decryption Failed: '${e.message}'. Details: ${e.details}");
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }
}
```

## Step 2: Android Implementation (Kotlin)

On Android, you will integrate the official readium-lcp dependency in your
app/build.gradle and intercept the call inside your MainActivity.

1. Add the Dependency (android/app/build.gradle):

```groovy
dependencies {
    // Check GitHub (readium/kotlin-toolkit) for the latest version tag
    implementation "org.readium.kotlin-toolkit:readium-lcp:3.0.0" 
}
```

2. Handle the Method Channel (MainActivity.kt):

```kotlin
package com.yourapp.lcp

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.readium.r2.lcp.LcpService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourapp.lcp/decrypt"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize the official Readium LCP Service
        val lcpService = LcpService(context)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodMessageHandler { call, result ->
            if (call.method == "decryptLcp") {
                val lcplPath = call.argument<String>("lcplPath")
                val passphrase = call.argument<String>("passphrase")

                if (lcplPath == null || passphrase == null) {
                    result.error("INVALID_ARGUMENTS", "Path or passphrase was null", null)
                    return@setMethodMessageHandler
                }

                // LCP processes files asynchronously/via network streams, use a Coroutine
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        val lcplFile = File(lcplPath)
                        
                        // 1. Acquire the publication license from the LCPL file
                        val license = lcpService.loadLicense(lcplFile).getOrThrow()
                        
                        // 2. Unlock the license using the user's plaintext passphrase
                        license.unlock(passphrase).getOrThrow()
                        
                        // 3. Download the actual EPUB file associated with the license
                        // Readium handles the background acquisition and places it in your cache
                        val downloadedEpubFile = license.fetchPublication().getOrThrow()
                        
                        // 4. Return the file path of the ready-to-read EPUB back to Dart
                        result.success(downloadedEpubFile.absolutePath)
                        
                    } catch (e: Exception) {
                        result.error("LCP_DECRYPTION_ERROR", e.localizedMessage, e.stackTraceToString())
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
```

## Step 3: iOS Implementation (Swift)

For iOS, you add the Readium packages via Swift Package Manager (SPM) or CocoaPods,
then implement the logic in your AppDelegate.

1. Add the Dependency:

Add the repository URL https://github.com to your Xcode project packages and check ReadiumLCP.

2. Handle the Method Channel (AppDelegate.swift):

 ```swift
 import UIKit
import Flutter
import ReadiumLCP

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let lcpChannel = FlutterMethodChannel(name: "com.yourapp.lcp/decrypt",
                                              binaryMessenger: controller.binaryMessenger)
    
    // Initialize Readium LCP Service
    let lcpService = LCPService()

    lcpChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      guard call.method == "decryptLcp" else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      guard let args = call.arguments as? [String: Any],
            let lcplPath = args["lcplPath"] as? String,
            let passphrase = args["passphrase"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path or passphrase", details: nil))
        return
      }
      
      let lcplUrl = URL(fileURLWithPath: lcplPath)
      
      // Execute asynchronously on a background thread so the Flutter UI doesn't freeze
      Task {
          do {
              // 1. Load the license from the LCPL file
              let license = try await lcpService.loadLicense(at: lcplUrl)
              
              // 2. Unlock it with the passphrase
              try await license.unlock(with: passphrase)
              
              // 3. Fetch/download the underlying publication file
              let downloadedEpubUrl = try await license.fetchPublication()
              
              // 4. Send the local file path string back to Flutter Dart
              result(downloadedEpubUrl.path)
              
          } catch {
              result(FlutterError(code: "LCP_DECRYPTION_ERROR", 
                                  message: error.localizedDescription, 
                                  details: "\(error)"))
          }
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## What Happens to the Outputted File?

When the downloadedEpubFile path is returned to Flutter, it is temporarily or
permanently stored in the application's native cache directory. Because Readium's
native SDK handled the secure verification step, the resulting .epub path contains
a file that is primed for your custom Dart code. You can pass it directly into
whatever asset pipeline or presentation logic you use for your Project Gutenberg books.